import StockPlanShared
import SwiftUI

/// The share button at the end of the brief header: the permalink or a
/// rendered image through the share sheet, prefilled X / Reddit / WhatsApp
/// posts, Discord markdown, or a copied link. Every action is counted as
/// `market_brief_shared`.
///
/// Actions are buttons rather than `ShareLink`s because a `ShareLink` inside a
/// `Menu` gives no callback to count the share with.
struct MarketBriefShareMenu: View {
  let payload: MarketBriefSharePayload
  @Binding var toast: ToastData?
  var telemetry = MarketBriefShareTelemetry()

  @Environment(\.openURL) private var openURL
  @State private var shareSheet: ShareSheetRequest?
  /// Rendered on first use and kept for this brief.
  @State private var renderedImage: RenderedImage?

  var body: some View {
    Menu {
      Section {
        Button("Share link…", systemImage: "link") {
          share(.link)
        }
        Button("Share image…", systemImage: "photo") {
          share(.image)
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
    telemetry.shared(payload, channel: channel)
    switch channel {
    case .link:
      let url = payload.permalink(for: .link)
      presentShareSheet([
        payload.linkMessage,
        LPLinkMetadataActivityItemSource(title: payload.title, item: url)
      ])
    case .image:
      guard let image = cardImage() else {
        toast = .error(String(localized: "Could not create the image."))
        return
      }
      presentShareSheet([
        LPLinkMetadataActivityItemSource(title: payload.title, item: image, icon: image),
        payload.imageMessage
      ])
    case .x:
      launcher.open(payload.xIntentURL, fallbackItems: [payload.xText])
    case .reddit:
      launcher.open(payload.redditURL, fallbackItems: [payload.title, payload.permalink(for: .reddit)])
    case .whatsapp:
      launcher.open(payload.whatsAppURL, fallbackItems: [payload.whatsAppText])
    case .discord:
      launcher.copyForDiscordAndOpen(payload.discordMarkdown)
    case .copyLink:
      launcher.copyToPasteboard(payload.permalink(for: .copyLink).absoluteString)
      toast = .success(String(localized: "Link copied"))
    }
  }

  /// Renders `MarketBriefShareCard` the first time an image is shared, and
  /// again only when the brief changes. Drawing one card is a few tens of
  /// milliseconds, so it happens on the tap rather than on every dashboard load.
  private func cardImage() -> UIImage? {
    if let renderedImage, renderedImage.payload == payload {
      return renderedImage.image
    }
    let image = ChartExporter.exportToImage(
      MarketBriefShareCard(payload: payload),
      size: MarketBriefShareCard.size,
      scale: 1
    )
    renderedImage = image.map { RenderedImage(payload: payload, image: $0) }
    return image
  }

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

  private struct RenderedImage {
    let payload: MarketBriefSharePayload
    let image: UIImage
  }
}
