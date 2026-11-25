import Foundation
import Observation
import PDFKit
import StockPlanShared
import SwiftUI
import UIKit

/// The Export Studio's tabs. Link needs no file, so it has no format.
nonisolated enum MarketBriefStudioTab: Hashable, CaseIterable, Sendable {
  case social, story, pdf, link

  var format: MarketBriefExportFormat? {
    switch self {
    case .social: .social
    case .story: .story
    case .pdf: .pdf
    case .link: nil
    }
  }
}

/// An export on disk, ready for the share sheet.
nonisolated struct MarketBriefExportReady: Equatable, Sendable {
  let fileURL: URL
  /// The image itself, or the first page of a PDF.
  let preview: UIImage?
  /// PDF only: the manifest's page count, else the document's.
  let pages: Int?
  /// The card drawn on the device because the backend had no file for us.
  let isNativeFallback: Bool
}

nonisolated enum MarketBriefExportState: Equatable, Sendable {
  case idle
  case loading
  case ready(MarketBriefExportReady)
  case unavailable
  case unauthorized(String)
}

/// Loads each export when its tab first shows, never all of them up front:
/// the backend has two render slots.
///
/// Only file requests are retried here: a 503 or 500 once after a pause, and a
/// 404 (the edition was regenerated) by refetching the manifest once. The
/// manifest request already retries 5xx inside `BaseHTTPClient`, so its failure
/// is final for that load. A 401 is shown as is and never falls back; any other
/// final failure gives Social the native card and Story and PDF `.unavailable`.
@MainActor
@Observable
final class MarketBriefExportStudioModel {
  nonisolated static let busyRetryDelay: Duration = .seconds(2)
  nonisolated static let pdfThumbnailSize = CGSize(width: 600, height: 848)

  var selection: MarketBriefStudioTab = .social
  private var states: [MarketBriefExportFormat: MarketBriefExportState] = [:]

  @ObservationIgnored private let payload: MarketBriefSharePayload
  @ObservationIgnored private let service: any MarketBriefExportServicing
  @ObservationIgnored private let store: MarketBriefExportFileStore
  @ObservationIgnored private let pause: @Sendable (Duration) async -> Void
  /// Shared by concurrent loads of different formats, so one manifest is fetched.
  @ObservationIgnored private var manifestTask: Task<MarketBriefExportManifest, any Error>?
  /// The work behind each format's `.loading`, so `cancel()` can stop it.
  @ObservationIgnored private var loads: [MarketBriefExportFormat: Task<Void, Never>] = [:]

  init(
    payload: MarketBriefSharePayload,
    service: any MarketBriefExportServicing,
    store: MarketBriefExportFileStore = .init(),
    pause: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
  ) {
    self.payload = payload
    self.service = service
    self.store = store
    self.pause = pause
  }

  func state(for format: MarketBriefExportFormat) -> MarketBriefExportState {
    states[format] ?? .idle
  }

  /// A no-op while the format is loading or ready.
  func load(_ format: MarketBriefExportFormat) async {
    switch state(for: format) {
    case .loading, .ready: return
    case .idle, .unavailable, .unauthorized: break
    }
    // No suspension between the check above and this line: that is what makes
    // concurrent loads of one format collapse into one.
    states[format] = .loading
    // The model owns the work, so a caller cancelled by a tab switch cannot
    // leave the format stuck in `.loading` with nothing left to finish it.
    let task = Task {
      let state = await resolve(format)
      // Cancelled by `cancel()`: the format is already back to `.idle`, and may
      // be loading again under a newer task.
      guard !Task.isCancelled else { return }
      states[format] = state
    }
    loads[format] = task
    await task.value
    if loads[format] == task { loads[format] = nil }
  }

  /// Stops every load in flight, for when the studio closes. Those formats go
  /// back to `.idle`, so the next open loads them again; ready ones are kept.
  func cancel() {
    guard !loads.isEmpty else { return }
    for (format, task) in loads {
      task.cancel()
      if state(for: format) == .loading { states[format] = .idle }
    }
    loads.removeAll()
    // Awaiting a task does not wake on cancellation, so a reopened studio must
    // not wait on this one: it fetches the manifest again instead.
    manifestTask?.cancel()
    manifestTask = nil
  }

  /// Loads again, including over a native fallback card.
  func retry(_ format: MarketBriefExportFormat) async {
    if state(for: format) == .loading { return }
    states[format] = .idle
    await load(format)
  }

  // MARK: Loading

  private func resolve(_ format: MarketBriefExportFormat) async -> MarketBriefExportState {
    do {
      let (file, manifest) = try await fetchFile(format)
      let ready = try await Self.prepare(
        file,
        format: format,
        editionId: manifest.editionId,
        revision: manifest.revision,
        manifestPages: manifest.format(format.rawValue)?.pages,
        store: store
      )
      return .ready(ready)
    } catch {
      if case let error as MarketBriefHTTPClient.Error = error, case .unauthorized = error {
        return .unauthorized(error.errorDescription ?? "")
      }
      // Closed mid-load: no native card for a studio nobody is looking at.
      if Task.isCancelled { return .idle }
      return await fallback(format)
    }
  }

  /// The file and the manifest it was requested with: another format's 404 may
  /// replace the shared manifest while this request is in flight.
  private func fetchFile(
    _ format: MarketBriefExportFormat
  ) async throws -> (MarketBriefExportFile, MarketBriefExportManifest) {
    var manifest = try await currentManifest()
    var retriedBusy = false
    var refetchedManifest = false
    while true {
      do {
        let query = manifest.format(format.rawValue)?.query ?? ""
        return (try await service.file(format, query: query, for: payload), manifest)
      } catch let error as MarketBriefHTTPClient.Error {
        let status = error.statusCode
        if (status == 500 || status == 503) && !retriedBusy {
          retriedBusy = true
          await pause(Self.busyRetryDelay)
        } else if status == 404 && !refetchedManifest {
          refetchedManifest = true
          manifest = try await refetchManifest()
        } else {
          throw error
        }
      }
    }
  }

  private func currentManifest() async throws -> MarketBriefExportManifest {
    let task = manifestTask ?? fetchManifest()
    do {
      return try await task.value
    } catch {
      // Let the next load ask again, unless a refetch has already replaced it.
      if manifestTask == task { manifestTask = nil }
      throw error
    }
  }

  private func refetchManifest() async throws -> MarketBriefExportManifest {
    manifestTask = nil
    return try await currentManifest()
  }

  private func fetchManifest() -> Task<MarketBriefExportManifest, any Error> {
    let service = service
    let payload = payload
    let task = Task { try await service.manifest(for: payload) }
    manifestTask = task
    return task
  }

  // MARK: Fallback

  private func fallback(_ format: MarketBriefExportFormat) async -> MarketBriefExportState {
    guard format == .social,
          let card = ChartExporter.exportToImage(
            MarketBriefShareCard(payload: payload),
            size: MarketBriefShareCard.size,
            scale: 1
          )
    else { return .unavailable }
    let fileName = "norviq-brief-\(payload.tradingDate)-\(payload.slot.rawValue)-social-\(payload.languageCode).png"
    do {
      return .ready(try await Self.writeNativeCard(card, fileName: fileName, store: store))
    } catch {
      return .unavailable
    }
  }

  // MARK: Off the main actor

  /// Writes the file and builds its preview: PNG decoding and PDF thumbnailing
  /// are the slow parts, so neither runs on the main actor.
  @concurrent
  private nonisolated static func prepare(
    _ file: MarketBriefExportFile,
    format: MarketBriefExportFormat,
    editionId: String,
    revision: Int,
    manifestPages: Int?,
    store: MarketBriefExportFileStore
  ) async throws -> MarketBriefExportReady {
    let url = try store.url(for: file, editionId: editionId, revision: revision)
    switch format {
    case .social, .story:
      let image = UIImage(data: file.data)
      return MarketBriefExportReady(
        fileURL: url,
        preview: image?.preparingForDisplay() ?? image,
        pages: nil,
        isNativeFallback: false
      )
    case .pdf:
      let document = PDFDocument(url: url)
      return MarketBriefExportReady(
        fileURL: url,
        preview: document?.page(at: 0)?.thumbnail(of: pdfThumbnailSize, for: .mediaBox),
        pages: manifestPages ?? document?.pageCount,
        isNativeFallback: false
      )
    }
  }

  @concurrent
  private nonisolated static func writeNativeCard(
    _ card: UIImage,
    fileName: String,
    store: MarketBriefExportFileStore
  ) async throws -> MarketBriefExportReady {
    guard let data = card.pngData() else { throw CocoaError(.fileWriteUnknown) }
    let url = try store.nativeURL(for: MarketBriefExportFile(data: data, fileName: fileName, mime: "image/png"))
    return MarketBriefExportReady(fileURL: url, preview: card, pages: nil, isNativeFallback: true)
  }
}
