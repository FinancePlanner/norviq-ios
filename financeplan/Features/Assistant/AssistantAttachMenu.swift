import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The "+" in the full Q composer: Photos, Camera and Files. It hands back what
/// the user chose and leaves the checking to the caller.
struct AssistantAttachMenu: View {
    let imagesEnabled: Bool
    let documentsEnabled: Bool
    /// How many more files this turn can take.
    let room: Int
    let isDisabled: Bool
    let onPhotos: ([PhotosPickerItem]) -> Void
    let onCamera: (Data) -> Void
    let onFiles: ([URL]) -> Void

    @State private var showsPhotos = false
    @State private var showsCamera = false
    @State private var showsFiles = false
    @State private var photoSelection: [PhotosPickerItem] = []

    private var allowedFileTypes: [UTType] {
        var types: [UTType] = []
        if documentsEnabled { types += [.pdf, .commaSeparatedText] }
        if imagesEnabled { types.append(.image) }
        return types
    }

    var body: some View {
        Menu {
            if imagesEnabled {
                Button { showsPhotos = true } label: { Label("Photos", systemImage: "photo.on.rectangle") }
                    .accessibilityIdentifier("assistant.attach.photos")
                if CameraCaptureView.isAvailable {
                    Button { showsCamera = true } label: { Label("Camera", systemImage: "camera") }
                        .accessibilityIdentifier("assistant.attach.camera")
                }
            }
            if documentsEnabled {
                Button { showsFiles = true } label: { Label("Files", systemImage: "folder") }
                    .accessibilityIdentifier("assistant.attach.files")
            }
        } label: {
            Image(systemName: "plus.circle")
                .font(.title3)
                .frame(width: 34, height: 34)
        }
        .foregroundStyle(AppTheme.Colors.tint)
        .disabled(isDisabled || room == 0)
        .accessibilityLabel("Attach")
        .accessibilityIdentifier("assistant.attach")
        .photosPicker(
            isPresented: $showsPhotos,
            selection: $photoSelection,
            // What is left of the turn's 3, so the picker itself stops at the cap.
            maxSelectionCount: max(room, 1),
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            // Emptied so the picker never reopens on the last selection.
            photoSelection = []
            onPhotos(items)
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraCaptureView { data in
                showsCamera = false
                if let data { onCamera(data) }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: allowedFileTypes, allowsMultipleSelection: true) { result in
            // A cancelled or failed import attaches nothing.
            if case let .success(urls) = result, !urls.isEmpty { onFiles(urls) }
        }
    }
}
