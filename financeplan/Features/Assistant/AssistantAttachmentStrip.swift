import SwiftUI
import UIKit

/// What is waiting to go with the next message. Draws nothing when empty.
struct AssistantAttachmentStrip: View {
    let attachments: [AssistantAttachment]
    let preparingCount: Int
    let notice: String?
    let onRemove: (AssistantAttachment.ID) -> Void

    var body: some View {
        if !attachments.isEmpty || preparingCount > 0 || notice != nil {
            VStack(alignment: .leading, spacing: 6) {
                if !attachments.isEmpty || preparingCount > 0 {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(attachments) { attachment in
                                AssistantAttachmentChip(attachment: attachment) { onRemove(attachment.id) }
                            }
                            ForEach(0..<preparingCount, id: \.self) { _ in
                                ProgressView()
                                    .frame(width: AssistantAttachmentChip.side, height: AssistantAttachmentChip.side)
                                    .background(AppTheme.Colors.tintSoft, in: .rect(cornerRadius: 10))
                                    .accessibilityLabel("Preparing attachment")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                if let notice {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.danger)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .background(AppTheme.Colors.pageBackground)
        }
    }
}

/// A thumbnail for an image, a symbol and the filename for a PDF or a CSV.
struct AssistantAttachmentChip: View {
    static let side: CGFloat = 56
    static let documentWidth: CGFloat = 132

    let attachment: AssistantAttachment
    let onRemove: () -> Void
    @Environment(\.displayScale) private var displayScale
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(attachment.isDocument ? "Remove file" : "Remove image")
        }
        .task { if !attachment.isDocument { thumbnail = await makeThumbnail() } }
    }

    @ViewBuilder
    private var content: some View {
        if attachment.isDocument {
            HStack(spacing: 6) {
                Image(systemName: Self.symbol(for: attachment))
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.tint)
                Text(attachment.filename)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.foreground)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 8)
            .frame(width: Self.documentWidth, height: Self.side, alignment: .leading)
            .background(AppTheme.Colors.tintSoft, in: .rect(cornerRadius: 10))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Attached file")
            .accessibilityValue(attachment.filename)
        } else {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable().scaledToFill()
                } else {
                    AppTheme.Colors.tintSoft
                }
            }
            .frame(width: Self.side, height: Self.side)
            .clipShape(.rect(cornerRadius: 10))
            .accessibilityElement()
            .accessibilityLabel("Attached image")
        }
    }

    static func symbol(for attachment: AssistantAttachment) -> String {
        if case .csv = attachment { "tablecells" } else { "doc.text" }
    }

    /// `byPreparingThumbnail` stretches to the size it is given, so the size keeps
    /// the picture's shape: its short edge fills the chip.
    private func makeThumbnail() async -> UIImage? {
        guard let image = UIImage(data: attachment.data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = Self.side * displayScale / min(image.size.width, image.size.height)
        return await image.byPreparingThumbnail(ofSize: CGSize(width: image.size.width * scale, height: image.size.height * scale))
    }
}
