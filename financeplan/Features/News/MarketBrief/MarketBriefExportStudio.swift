import StockPlanShared
import SwiftUI
import UIKit

/// The brief's Export Studio: the backend's social image, story image and PDF
/// report, plus the permalink, each with its own share action. A format is
/// fetched when its tab first shows; the model keeps what loaded, so the menu
/// reopens the same studio for the same brief.
struct MarketBriefExportStudio: View {
  @Bindable var model: MarketBriefExportStudioModel
  /// "Link copied". Shown inside the sheet too, since the card's own overlay is under it.
  @Binding var toast: ToastData?
  var telemetry: MarketBriefShareTelemetry

  @Environment(\.dismiss) private var dismiss
  @State private var share: MarketBriefStudioShare?
  @State private var sheetHeight: CGFloat = 0

  init(
    model: MarketBriefExportStudioModel,
    toast: Binding<ToastData?> = .constant(nil),
    telemetry: MarketBriefShareTelemetry = .init()
  ) {
    self.model = model
    _toast = toast
    self.telemetry = telemetry
  }

  /// The model's brief, never the menu's live one: the exports, the title and
  /// the links must all describe the same brief.
  private var payload: MarketBriefSharePayload { model.payload }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: AppTheme.Spacing.lg) {
          Picker("Export", selection: $model.selection) {
            ForEach(MarketBriefStudioTab.allCases, id: \.self) { tab in
              Text(tab.title).tag(tab)
            }
          }
          .pickerStyle(.segmented)

          panel
        }
        .padding()
      }
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
      // Under the navigation bar, where it cannot cover "Done".
      .toastOverlay($toast)
      .navigationTitle("Export")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.large])
    .task(id: model.selection) {
      if let format = model.selection.format {
        await model.load(format)
      }
    }
    .sheet(item: $share) { share in
      ShareSheet(items: share.items) { completed in
        share.finish(completed: completed, telemetry: telemetry)
      }
      .presentationDetents([.medium, .large])
    }
  }

  @ViewBuilder
  private var panel: some View {
    if let format = model.selection.format {
      exportPanel(format)
    } else {
      linkPanel
    }
  }

  // MARK: Social, Story, PDF

  @ViewBuilder
  private func exportPanel(_ format: MarketBriefExportFormat) -> some View {
    switch model.state(for: format) {
    case .idle, .loading:
      RoundedRectangle(cornerRadius: AppTheme.Radius.control)
        .fill(AppTheme.Colors.tertiaryFill)
        .aspectRatio(format.previewAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: previewMaxHeight)
        .overlay { ProgressView() }
    case let .ready(ready):
      readyPanel(ready, format: format)
    case .unavailable:
      VStack(spacing: AppTheme.Spacing.md) {
        Text("This export isn't available right now.")
          .typography(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button("Try again") {
          Task { await model.retry(format) }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, AppTheme.Spacing.xl)
    case let .unauthorized(message):
      Text(verbatim: message)
        .typography(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xl)
    }
  }

  private func readyPanel(_ ready: MarketBriefExportReady, format: MarketBriefExportFormat) -> some View {
    VStack(spacing: AppTheme.Spacing.md) {
      if let image = ready.preview {
        previewImage(image, format: format)
      }

      if ready.isNativeFallback {
        Text("Offline version")
          .typography(.caption)
          .foregroundStyle(.secondary)
        // The renderer may only have been busy: ask the backend again.
        Button("Try again") {
          Task { await model.retry(format) }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
      }

      if format == .pdf, let pages = ready.pages {
        Text("\(pages) pages")
          .typography(.small)
          .foregroundStyle(.secondary)
      }

      Button {
        share = .file(ready, format: format, payload: payload)
      } label: {
        Label("Share…", systemImage: "square.and.arrow.up")
          .typography(.button)
      }
      .buttonStyle(GlowingButtonStyle())
    }
  }

  private func previewImage(_ image: UIImage, format: MarketBriefExportFormat) -> some View {
    let shape = RoundedRectangle(cornerRadius: AppTheme.Radius.control)
    return Image(uiImage: image)
      .resizable()
      .scaledToFit()
      .clipShape(shape)
      // A light render on a light sheet needs an edge; the PDF's white page most of all.
      .overlay { shape.strokeBorder(AppTheme.Colors.separator, lineWidth: 1) }
      .frame(maxWidth: .infinity, maxHeight: previewMaxHeight)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(format.previewLabel))
      .accessibilityAddTraits(.isImage)
  }

  /// About 60% of the sheet, so the share button stays in view.
  private var previewMaxHeight: CGFloat? {
    sheetHeight > 0 ? sheetHeight * 0.6 : nil
  }

  // MARK: Link

  private var linkPanel: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
        Text(verbatim: payload.title)
          .typography(.headline)
        Text(verbatim: payload.permalink(for: .link).absoluteString)
          .typography(.small)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Button {
        share = .link(payload)
      } label: {
        Label("Share link…", systemImage: "link")
          .typography(.button)
      }
      .buttonStyle(GlowingButtonStyle())

      Button {
        UIPasteboard.general.string = MarketBriefStudioShare.copyLink(payload, telemetry: telemetry)
        toast = .success(String(localized: "Link copied"))
      } label: {
        Label("Copy link", systemImage: "doc.on.doc")
          .typography(.button)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .controlSize(.large)
    }
  }
}

/// One share from the studio. It is counted when the share sheet reports the
/// share was completed, never when it was dismissed.
struct MarketBriefStudioShare: Identifiable {
  static let surface = "studio"
  static let shareMethod = "share"
  static let copyMethod = "copy"

  let id = UUID()
  let items: [Any]
  let channel: MarketBriefShareChannel
  let payload: MarketBriefSharePayload

  /// An export file. The native fallback card counts as `image`, so the
  /// fallback rate stays measurable; the message's link carries the same channel.
  static func file(
    _ ready: MarketBriefExportReady,
    format: MarketBriefExportFormat,
    payload: MarketBriefSharePayload
  ) -> Self {
    let channel: MarketBriefShareChannel = ready.isNativeFallback ? .image : format.shareChannel
    return Self(
      items: [
        LPLinkMetadataActivityItemSource(
          title: payload.title,
          item: ready.fileURL,
          icon: ready.preview,
          previewImage: ready.preview
        ),
        payload.message(for: channel)
      ],
      channel: channel,
      payload: payload
    )
  }

  static func link(_ payload: MarketBriefSharePayload) -> Self {
    Self(
      items: [
        payload.linkMessage,
        LPLinkMetadataActivityItemSource(title: payload.title, item: payload.permalink(for: .link))
      ],
      channel: .link,
      payload: payload
    )
  }

  /// Counts the copy and returns the link to put on the pasteboard.
  static func copyLink(_ payload: MarketBriefSharePayload, telemetry: MarketBriefShareTelemetry) -> String {
    telemetry.shared(payload, channel: .copyLink, method: copyMethod, surface: surface)
    return payload.permalink(for: .copyLink).absoluteString
  }

  func finish(completed: Bool, telemetry: MarketBriefShareTelemetry) {
    guard completed else { return }
    telemetry.shared(payload, channel: channel, method: Self.shareMethod, surface: Self.surface)
  }
}

extension MarketBriefStudioTab {
  var title: LocalizedStringKey {
    switch self {
    case .social: "Social"
    case .story: "Story"
    case .pdf: "PDF"
    case .link: "Link"
    }
  }
}

private extension MarketBriefExportFormat {
  var shareChannel: MarketBriefShareChannel {
    switch self {
    case .social: .social
    case .story: .story
    case .pdf: .pdf
    }
  }

  /// Width over height: 1080×1350, 1080×1920 and an A4 page.
  var previewAspectRatio: CGFloat {
    switch self {
    case .social: 1080 / 1350
    case .story: 1080 / 1920
    case .pdf: 595 / 842
    }
  }

  var previewLabel: LocalizedStringKey {
    switch self {
    case .social: "Social image of this edition"
    case .story: "Story image of this edition"
    case .pdf: "First page of the PDF report"
    }
  }
}

#if DEBUG
/// Canned exports for the canvas; never talks to the network.
private struct PreviewMarketBriefExportService: MarketBriefExportServicing {
  func manifest(for payload: MarketBriefSharePayload, fresh: Bool) async throws -> MarketBriefExportManifest {
    MarketBriefExportManifest(
      editionId: "preview",
      revision: 1,
      rendererVersion: 1,
      formats: [MarketBriefExportFormatInfo(id: "pdf", pages: 3, mime: "application/pdf", query: "rev=1&v=1")]
    )
  }

  func file(
    _ format: MarketBriefExportFormat,
    query: String,
    for payload: MarketBriefSharePayload
  ) async throws -> MarketBriefExportFile {
    // Busy: Social shows the offline card, Story and PDF the unavailable state.
    throw MarketBriefHTTPClient.Error.invalidStatus(503)
  }
}

#Preview("Export Studio") {
  @Previewable @State var toast: ToastData?
  let brief = MarketBriefResponse(
    enabled: true,
    tradingDate: "2026-11-25",
    slot: .morning,
    language: "en",
    greeting: "Good morning. Europe opens lower.",
    groups: [],
    items: [MarketBriefItem(kind: .highlight, text: "Chipmakers slip after a weak outlook.", tickers: ["ASML"], sourceUrl: nil)],
    generatedAt: "2026-11-25T07:16:00Z",
    degraded: false
  )
  if let payload = MarketBriefSharePayload(brief: brief) {
    MarketBriefExportStudio(
      model: MarketBriefExportStudioModel(
        payload: payload,
        service: PreviewMarketBriefExportService(),
        pause: { _ in }
      ),
      toast: $toast
    )
  }
}
#endif
