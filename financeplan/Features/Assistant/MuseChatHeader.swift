import SwiftUI

/// Muse Chat header, shared design contract (`_reviews/muse-chat-contract.md`).
///
/// A 56pt bar with a 40pt circular button on the left and a "New chat" pill on
/// the right, a centred 110pt avatar that overhangs the transcript, and a pill
/// naming the agent with its status underneath. Place it with
/// `.safeAreaInset(edge: .top)` so the transcript starts below it and scrolls
/// beneath the scrim.
///
/// Stage A is restyle only: `status` is a plain string the caller owns. The
/// avatar states (listening / working ring / celebrating) arrive in Stage B.
struct MuseChatHeader: View {
    var name: String = "Vig"
    var status: String = "Ready"
    var leadingSystemImage: String = "clock.arrow.circlepath"
    var leadingAccessibilityLabel: LocalizedStringKey = "Conversations"
    var onLeading: () -> Void
    var onNewChat: () -> Void

    static let barHeight: CGFloat = 56
    static let avatarSize: CGFloat = 110
    static let scrimHeight: CGFloat = 120

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                HStack {
                    leadingButton
                    Spacer()
                    newChatButton
                }
                .frame(height: Self.barHeight)
                .padding(.horizontal, 16)

                avatar
            }
            namePill
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
        .background(alignment: .top) { scrim }
    }

    private var leadingButton: some View {
        Button(action: onLeading) {
            Image(systemName: leadingSystemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.foreground)
                .frame(width: 40, height: 40)
                .background(AppTheme.Colors.tintSoft, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(leadingAccessibilityLabel)
    }

    private var newChatButton: some View {
        Button(action: onNewChat) {
            Text("New chat")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.foreground)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(AppTheme.Colors.tintSoft, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private var avatar: some View {
        Image("VigIcon")
            .resizable()
            .scaledToFit()
            .padding(10)
            .frame(width: Self.avatarSize, height: Self.avatarSize)
            .background(AppTheme.Colors.cardBackground, in: .circle)
            .overlay { Circle().strokeBorder(AppTheme.Colors.separator, lineWidth: 1) }
            .clipShape(.circle)
            .accessibilityHidden(true)
    }

    private var namePill: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.foreground)
            Text(status)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(AppTheme.Colors.tintSoft, in: .capsule)
        .accessibilityElement(children: .combine)
    }

    /// Required fallback for blur (Reduce Transparency, Low Power): canvas at
    /// the top fading to clear over 120pt, extended up under the status bar.
    private var scrim: some View {
        LinearGradient(
            colors: [AppTheme.Colors.pageBackground, AppTheme.Colors.pageBackground.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Self.scrimHeight + Self.barHeight)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

#Preview("MuseChatHeader") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(0..<12) { index in
                MuseChatBubble(
                    text: index.isMultiple(of: 2)
                        ? "How much did I spend on groceries this month?"
                        : "You spent **€412** on groceries in September, 8% under your budget.",
                    isUser: index.isMultiple(of: 2)
                )
            }
        }
        .padding(.vertical, 16)
    }
    .safeAreaInset(edge: .top, spacing: 0) {
        MuseChatHeader(onLeading: {}, onNewChat: {})
    }
    .background(AppTheme.Colors.pageBackground)
}

#Preview("MuseChatHeader · Dark") {
    MuseChatHeader(status: "is thinking", onLeading: {}, onNewChat: {})
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppTheme.Colors.pageBackground)
        .preferredColorScheme(.dark)
}
