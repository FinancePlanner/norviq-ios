import SwiftUI

@MainActor
class ChartExporter {
  static func exportToImage<Content: View>(
    _ content: Content,
    size: CGSize = CGSize(width: 800, height: 600)
  ) -> UIImage? {
    let renderer = ImageRenderer(content:
      content.frame(width: size.width, height: size.height)
    )
    renderer.scale = UIScreen.main.scale
    return renderer.uiImage
  }
}

struct ShareableChartView<Content: View>: View {
  let title: String
  let content: Content
  @State private var showingShareSheet = false
  @State private var exportedImage: UIImage?
  
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
        .background(Color.white.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
      }
      .padding(.top, 12)
    }
    .sheet(isPresented: $showingShareSheet) {
      if let image = exportedImage {
        ShareSheet(items: [
          LPLinkMetadataActivityItemSource(title: title, item: image, icon: image)
        ])
      }
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

    exportedImage = ChartExporter.exportToImage(exportView)
    showingShareSheet = true
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
