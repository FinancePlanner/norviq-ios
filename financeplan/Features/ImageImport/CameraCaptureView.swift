import SwiftUI
import UIKit

/// Takes a single photo with the system camera.
///
/// `PhotosPicker` reads the library only, which is why the app had no
/// take-a-photo path even though `NSCameraUsageDescription` has always
/// promised one ("...and photograph receipts for expense entry"). This closes
/// that gap for receipts, where the photo usually does not exist yet.
@MainActor
struct CameraCaptureView: UIViewControllerRepresentable {
  /// Called with JPEG data, or nil when the user cancels.
  let onCapture: (Data?) -> Void

  /// False in the simulator and on a device whose camera is unavailable, so
  /// callers can hide the entry point rather than present a dead sheet.
  static var isAvailable: Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera)
  }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_: UIImagePickerController, context _: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onCapture: onCapture)
  }

  @MainActor
  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let onCapture: (Data?) -> Void

    init(onCapture: @escaping (Data?) -> Void) {
      self.onCapture = onCapture
    }

    func imagePickerController(
      _: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      // Downscale here rather than at the call site: a full-resolution capture
      // is several megabytes and would trip the backend's 8 MB cap.
      guard
        let image = info[.originalImage] as? UIImage,
        let data = UploadImagePreparer.downscaled(image).jpegData(compressionQuality: 0.7)
      else {
        onCapture(nil)
        return
      }
      onCapture(data)
    }

    func imagePickerControllerDidCancel(_: UIImagePickerController) {
      onCapture(nil)
    }
  }
}
