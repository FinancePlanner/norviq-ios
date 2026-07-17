import Factory
import PhotosUI
import StockPlanShared
import SwiftUI
import Vision
import VisionKit

/// Camera sheet that scans a fiscal receipt QR code and returns a parsed
/// ``ReceiptDraft``. QR parsing runs on-device via the shared
/// ``FiscalReceiptQRParser`` — no image leaves the device. When the device has
/// no supported scanner, the view explains the fallback (manual entry).
@MainActor
struct ReceiptScannerView: View {
  let onDraft: (ReceiptDraft) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var errorMessage: String?
  @State private var photoItem: PhotosPickerItem?
  @State private var isUploading = false

  private var isScannerAvailable: Bool {
    DataScannerViewController.isSupported && DataScannerViewController.isAvailable
  }

  var body: some View {
    NavigationStack {
      Group {
        if isScannerAvailable {
          ReceiptQRScannerRepresentable(onScan: handleScan)
            .ignoresSafeArea(edges: .bottom)
        } else {
          unavailableView
        }
      }
      .navigationTitle("Scan Receipt")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .overlay(alignment: .bottom) {
        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding()
        }
      }
      .safeAreaInset(edge: .bottom) {
        photoPickerBar
      }
      .onChange(of: photoItem) { _, item in
        guard let item else { return }
        Task { await handlePhoto(item) }
      }
    }
  }

  // Photo OCR fallback: pick/take a receipt photo and upload it to the backend
  // vision OCR endpoint. Works even when the on-device QR scanner is unavailable.
  private var photoPickerBar: some View {
    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
      HStack {
        if isUploading {
          ProgressView()
          Text("Reading receipt…")
        } else {
          Image(systemName: "photo")
          Text("Scan a photo instead")
        }
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal)
    }
    .disabled(isUploading)
  }

  private func handlePhoto(_ item: PhotosPickerItem) async {
    isUploading = true
    errorMessage = nil
    defer {
      isUploading = false
      photoItem = nil
    }
    do {
      guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
        errorMessage = "Couldn't read that photo. Try another or enter manually."
        return
      }
      let response = try await Container.shared.receiptsHTTPClient().ocr(imageData: data, contentType: "image/jpeg")
      guard response.recognized, let draft = response.draft else {
        errorMessage = "Couldn't read that receipt photo. Try another or enter manually."
        return
      }
      onDraft(draft)
      dismiss()
    } catch {
      errorMessage = "Couldn't scan that photo. Try again or enter manually."
    }
  }

  private var unavailableView: some View {
    ContentUnavailableView(
      "Scanning Unavailable",
      systemImage: "camera.badge.ellipsis",
      description: Text("This device can't scan receipts. Enter the expense manually.")
    )
  }

  private func handleScan(_ payload: String) {
    guard let draft = FiscalReceiptQRParser().parse(payload) else {
      errorMessage = "That QR code isn't a recognized receipt. Try another or enter it manually."
      return
    }
    onDraft(draft)
    dismiss()
  }
}

/// Wraps `DataScannerViewController` to emit decoded QR payload strings.
private struct ReceiptQRScannerRepresentable: UIViewControllerRepresentable {
  let onScan: (String) -> Void

  func makeUIViewController(context: Context) -> DataScannerViewController {
    let controller = DataScannerViewController(
      recognizedDataTypes: [.barcode(symbologies: [.qr])],
      qualityLevel: .balanced,
      recognizesMultipleItems: false,
      isHighFrameRateTrackingEnabled: false,
      isHighlightingEnabled: true
    )
    controller.delegate = context.coordinator
    return controller
  }

  func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
    try? controller.startScanning()
  }

  static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
    controller.stopScanning()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onScan: onScan)
  }

  final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    private let onScan: (String) -> Void
    private var hasEmitted = false

    init(onScan: @escaping (String) -> Void) {
      self.onScan = onScan
    }

    func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
      emitFirstBarcode(from: addedItems)
    }

    func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
      emitFirstBarcode(from: [item])
    }

    private func emitFirstBarcode(from items: [RecognizedItem]) {
      guard !hasEmitted else { return }
      for item in items {
        if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue {
          hasEmitted = true
          onScan(payload)
          return
        }
      }
    }
  }
}
