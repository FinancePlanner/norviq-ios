import SwiftUI

/// Muse Chat bubble, shared design contract (`_reviews/muse-chat-contract.md`).
///
/// User: tint fill with `onTint` text (white on the Vigil cyan measures 1.39:1,
/// see `AppTheme.Colors.onTint`), right-aligned, at most 85% of the row.
/// Agent: card fill with foreground text, left-aligned, at most 94%.
/// Radius 24 for both. No avatar, no per-message name label.
struct MuseChatBubble<Content: View>: View {
    let isUser: Bool
    @ViewBuilder let content: Content

    static var cornerRadius: CGFloat { 24 }

    var body: some View {
        BubbleWidthLayout(fraction: isUser ? 0.85 : 0.94, trailing: isUser) {
            content
                .font(.body)
                .foregroundStyle(isUser ? AppTheme.Colors.onTint : AppTheme.Colors.foreground)
                .tint(isUser ? AppTheme.Colors.onTint : AppTheme.Colors.tint)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    isUser ? AppTheme.Colors.tint : AppTheme.Colors.cardBackground,
                    in: .rect(cornerRadius: Self.cornerRadius)
                )
        }
        .padding(.horizontal, 16)
    }
}

extension MuseChatBubble where Content == Text {
    /// Agent replies render inline Markdown (bold, italics, links, code);
    /// bullets survive as typed because whitespace is preserved. User text is
    /// shown verbatim.
    init(text: String, isUser: Bool) {
        self.isUser = isUser
        self.content = Self.render(text, markdown: !isUser)
    }

    private static func render(_ text: String, markdown: Bool) -> Text {
        guard markdown,
              let attributed = try? AttributedString(
                  markdown: text,
                  options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
              )
        else { return Text(verbatim: text) }
        return Text(attributed)
    }
}

/// Caption above a proactive agent bubble: 11pt uppercase, secondary, aligned
/// with the bubble's text ("STANDING TASK", "DAILY TIP").
struct MuseProactiveCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Gives the bubble at most `fraction` of the row width and pins it to one
/// edge, without the bubble stretching when its text is short.
struct BubbleWidthLayout: Layout {
    let fraction: CGFloat
    let trailing: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let size = child.sizeThatFits(ProposedViewSize(width: proposal.width.map { $0 * fraction }, height: nil))
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard let child = subviews.first else { return }
        let size = child.sizeThatFits(ProposedViewSize(width: bounds.width * fraction, height: nil))
        let x = trailing ? bounds.maxX - size.width : bounds.minX
        child.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(size))
    }
}

#Preview("MuseChatBubble") {
    VStack(spacing: 12) {
        MuseChatBubble(text: "Add a €12 lunch expense", isUser: true)
        MuseChatBubble(
            text: "Done. **Lunch** · €12.00 added to *Food*. You have €188 left in that budget this month.",
            isUser: false
        )
        MuseChatBubble(isUser: false) { ProgressView().controlSize(.small) }
    }
    .padding(.vertical, 16)
    .frame(maxHeight: .infinity)
    .background(AppTheme.Colors.pageBackground)
}
