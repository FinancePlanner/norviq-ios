import AVFoundation
import PhotosUI
import SwiftUI

struct MediaPicker: View {
  @Binding var isPresented: Bool
  var allowsVideo: Bool = false
  var onMediaSelected: (SelectedMedia) -> Void
  var onSourceUnavailable: (() -> Void)?

  @State private var selectedItems: [PhotosPickerItem] = []

  private var filter: PHPickerFilter {
    if allowsVideo {
      return .any(of: [.images, .videos])
    }
    return .images
  }

  var body: some View {
    PhotosPicker(
      selection: $selectedItems,
      maxSelectionCount: 1,
      matching: filter
    ) {
      EmptyView()
    }
    .photosPickerStyle(.inline)
    .onChange(of: selectedItems) { _, newItems in
      guard let item = newItems.first else { return }
      Task {
        await processSelectedItem(item)
      }
    }
  }

  @MainActor
  private func processSelectedItem(_ item: PhotosPickerItem) async {
    // Try loading as video first if video is allowed
    if allowsVideo, let movieURL = try? await item.loadTransferable(type: VideoTransferable.self) {
      let thumbnail = await Self.generateThumbnailData(for: movieURL.url)
      onMediaSelected(.video(movieURL.url, thumbnail: thumbnail))
      isPresented = false
      return
    }

    // Load as image data
    if let imageData = try? await item.loadTransferable(type: Data.self) {
      onMediaSelected(.image(imageData))
      isPresented = false
      return
    }

    // Nothing could be loaded
    onSourceUnavailable?()
    isPresented = false
  }

  private static func generateThumbnailData(for url: URL) async -> Data? {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 320, height: 320)
    let time = CMTime(seconds: 0, preferredTimescale: 600)
    guard let (cgImage, _) = try? await generator.image(at: time) else { return nil }
    let bitmapRep = CGImage.pngData(cgImage)
    return bitmapRep
  }
}

// MARK: - Video Transferable

private struct VideoTransferable: Transferable {
  let url: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(contentType: .movie) { video in
      SentTransferredFile(video.url)
    } importing: { received in
      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mp4")
      try FileManager.default.copyItem(at: received.file, to: tempURL)
      return Self(url: tempURL)
    }
  }
}

// MARK: - CGImage PNG helper

extension CGImage {
  fileprivate static func pngData(_ image: CGImage) -> Data? {
    let mutableData = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        mutableData, "public.png" as CFString, 1, nil)
    else {
      return nil
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }
    return mutableData as Data
  }
}
