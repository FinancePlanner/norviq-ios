import SwiftUI

@MainActor
class ChartExporter {
  /// `scale` should come from the presenting view's `\.displayScale`
  /// environment; `UIScreen.main` is deprecated and wrong on external displays.
  static func exportToImage<Content: View>(
    _ content: Content,
    size: CGSize = CGSize(width: 800, height: 600),
    scale: CGFloat
  ) -> UIImage? {
    let renderer = ImageRenderer(content:
      content.frame(width: size.width, height: size.height)
    )
    renderer.scale = scale
    return renderer.uiImage
  }
}

struct ShareableChartView<Content: View>: View {
  let title: String
  let content: Content
  @Environment(\.displayScale) private var displayScale
  @State private var exportedChart: ExportedChart?

  /// The rendered image, as a presentation payload rather than a bool plus a
  /// separately-managed optional.
  private struct ExportedChart: Identifiable {
    let id = UUID()
    let image: UIImage
  }
  
  init(title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }
  
  var body: some View {
    VStack(spacing: 0) {
      content
      
      Button {
        exportChart()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "square.and.arrow.up")
          Text("Share Chart")
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.tertiaryFill)
        .clipShape(.rect(cornerRadius: 8))
      }
      .padding(.top, 12)
    }
    .sheet(item: $exportedChart) { chart in
      ShareSheet(items: [
        LPLinkMetadataActivityItemSource(title: title, item: chart.image, icon: chart.image)
      ])
    }
  }

  private func exportChart() {
    let exportView = VStack(spacing: 16) {
      Text(title)
        .font(.title2.bold())
        .frame(maxWidth: .infinity, alignment: .leading)
      content
    }
    .padding(24)
    .background(Color(uiColor: .systemBackground))

    guard let image = ChartExporter.exportToImage(exportView, scale: displayScale) else { return }
    exportedChart = ExportedChart(image: image)
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
