import Factory
import StockPlanShared
import SwiftUI

/// The share button at the end of the brief header: the permalink through the
/// share sheet, the Export Studio, prefilled X / Reddit / WhatsApp posts,
/// Discord markdown, or a copied link. Every action is counted as
/// `market_brief_shared`; the studio counts its own.
///
/// Actions are buttons rather than `ShareLink`s because a `ShareLink` inside a
/// `Menu` gives no callback to count the share with.
struct MarketBriefShareMenu: View {
  let payload: MarketBriefSharePayload
  @Binding var toast: ToastData?
  var telemetry = MarketBriefShareTelemetry()

  @Environment(\.openURL) private var openURL
  @State private var shareSheet: ShareSheetRequest?
  /// Kept after the sheet closes, so reopening it for the same brief shows
  /// what already loaded instead of fetching again.
  @State private var studio: StudioSession?
  /// The presented studio; `.sheet(item:)` clears it on dismiss.
  @State private var presentedStudio: StudioSession?

  var body: some View {
    Menu {
      Section {
        Button("Share link…", systemImage: "link") {
          share(.link)
        }
        Button("Export…", systemImage: "square.and.arrow.up.on.square") {
          openStudio()
        }
      }

      Section {
        channelButton(.x, name: "X", systemImage: "bubble.left.and.bubble.right")
        channelButton(.reddit, name: "Reddit", systemImage: "text.bubble")
        channelButton(.whatsapp, name: "WhatsApp", systemImage: "phone.bubble")
        channelButton(.discord, name: "Discord", systemImage: "message")
      }

      Button("Copy link", systemImage: "doc.on.doc") {
        share(.copyLink)
      }
    } label: {
      Label("Share brief", systemImage: "square.and.arrow.up")
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(.rect)
    }
    .sheet(item: $shareSheet) { request in
      ShareSheet(items: request.items)
        .presentationDetents([.medium, .large])
    }
    .sheet(item: $presentedStudio, onDismiss: { studio?.model.cancel() }) { session in
      MarketBriefExportStudio(model: session.model, toast: $toast, telemetry: telemetry)
    }
  }

  /// Reuses the studio for the same brief: date, slot, language and generation.
  private func openStudio() {
    let key = MarketBriefStudioKey(payload)
    if studio?.key != key {
      studio = StudioSession(
        key: key,
        model: MarketBriefExportStudioModel(payload: payload, service: Container.shared.marketBriefExportService())
      )
    }
    presentedStudio = studio
  }

  private func channelButton(
    _ channel: MarketBriefShareChannel,
    name: String,
    systemImage: String
  ) -> some View {
    Button {
      share(channel)
    } label: {
      Label {
        Text(verbatim: name)
      } icon: {
        Image(systemName: systemImage)
      }
    }
  }

  private func share(_ channel: MarketBriefShareChannel) {
    // The Export Studio shares and counts these; the menu never offers them,
    // and must not count them with its own surface.
    guard !Self.studioChannels.contains(channel) else { return }
    telemetry.shared(payload, channel: channel)
    switch channel {
    case .link:
      let url = payload.permalink(for: .link)
      presentShareSheet([
        payload.linkMessage,
        LPLinkMetadataActivityItemSource(title: payload.title, item: url)
      ])
    case .x:
      launcher.open(payload.xIntentURL, fallbackItems: [payload.xText])
    case .reddit:
      launcher.open(payload.redditURL, fallbackItems: [payload.title, payload.permalink(for: .reddit)])
    case .whatsapp:
      launcher.open(payload.whatsAppURL, fallbackItems: [payload.whatsAppText])
    case .discord:
      launcher.shareToDiscord(payload.discordMarkdown)
    case .copyLink:
      launcher.copyToPasteboard(payload.permalink(for: .copyLink).absoluteString)
      toast = .success(String(localized: "Link copied"))
    case .image, .social, .story, .pdf:
      break // Returned above.
    }
  }

  private static let studioChannels: Set<MarketBriefShareChannel> = [.image, .social, .story, .pdf]

  private var launcher: ChannelShareLauncher {
    ChannelShareLauncher(
      openURL: openURL,
      presentShareSheet: presentShareSheet,
      showToast: { toast = $0 }
    )
  }

  private func presentShareSheet(_ items: [Any]) {
    shareSheet = ShareSheetRequest(items: items)
  }

  private struct ShareSheetRequest: Identifiable {
    let id = UUID()
    let items: [Any]
  }

  private struct StudioSession: Identifiable {
    let key: MarketBriefStudioKey
    let model: MarketBriefExportStudioModel
    var id: MarketBriefStudioKey { key }
  }
}

/// One studio per brief. The same date, slot and language reuse it, as long
/// as the brief was not regenerated: a regeneration is a new edition revision,
/// whose exports differ. The brief carries no revision, so `generatedAt`, which
/// every regeneration renews, stands in for it.
struct MarketBriefStudioKey: Hashable {
  let tradingDate: String
  let slot: MarketBriefSlot
  let languageCode: String
  let generatedAt: String?

  init(_ payload: MarketBriefSharePayload) {
    tradingDate = payload.tradingDate
    slot = payload.slot
    languageCode = payload.languageCode
    generatedAt = payload.brief.generatedAt
  }
}
