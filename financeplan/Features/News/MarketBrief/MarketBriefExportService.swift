import Factory
import Foundation
import StockPlanShared

/// The renders the Export Studio offers. Raw values are the backend's `format` ids.
nonisolated enum MarketBriefExportFormat: String, CaseIterable, Codable, Sendable {
  case social, story, pdf

  var fileExtension: String { self == .pdf ? "pdf" : "png" }
  var mime: String { self == .pdf ? "application/pdf" : "image/png" }
}

/// A rendered export as the backend sent it.
nonisolated struct MarketBriefExportFile: Sendable, Equatable {
  let data: Data
  let fileName: String
  let mime: String
}

/// The export manifest and files of one brief, in the brief's own language.
protocol MarketBriefExportServicing: Sendable {
  /// `fresh` bypasses the URL cache, for the refetch after a superseded file.
  func manifest(for payload: MarketBriefSharePayload, fresh: Bool) async throws -> MarketBriefExportManifest
  func file(
    _ format: MarketBriefExportFormat,
    query: String,
    for payload: MarketBriefSharePayload
  ) async throws -> MarketBriefExportFile
}

extension MarketBriefExportServicing {
  func manifest(for payload: MarketBriefSharePayload) async throws -> MarketBriefExportManifest {
    try await manifest(for: payload, fresh: false)
  }
}

struct DefaultMarketBriefExportService: MarketBriefExportServicing {
  private let client: MarketBriefHTTPClient

  init(environmentManager: AppEnvironmentManager, session: any HTTPClientSession = URLSession.shared) {
    self.client = MarketBriefHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { await Container.shared.authSessionStore().authToken }
    )
  }

  func manifest(for payload: MarketBriefSharePayload, fresh: Bool) async throws -> MarketBriefExportManifest {
    try await client.exports(lang: payload.languageCode, slot: payload.slot, date: payload.tradingDate, fresh: fresh)
  }

  func file(
    _ format: MarketBriefExportFormat,
    query: String,
    for payload: MarketBriefSharePayload
  ) async throws -> MarketBriefExportFile {
    try await client.exportFile(
      lang: payload.languageCode,
      slot: payload.slot,
      date: payload.tradingDate,
      format: format,
      query: query
    )
  }
}
