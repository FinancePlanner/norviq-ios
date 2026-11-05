import Factory
import SwiftUI

/// The always-there way into Quick Q, resting just above the tab bar.
struct QuickAssistantFloatingButton: View {
    /// The tab bar sits outside this view, so its height isn't in the safe area.
    private static let tabBarHeight: CGFloat = 49

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(AppTheme.Colors.tint, in: .circle)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask Q")
        .accessibilityIdentifier("quickAssistant.floatingButton")
        .padding(.trailing, 16)
        .padding(.bottom, Self.tabBarHeight + 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        // The keyboard covers it, rather than lifting it over a form's fields.
        .ignoresSafeArea(.keyboard)
    }
}

extension View {
    /// For a pushed screen with its own controls at the bottom, such as a composer,
    /// where the floating button would sit on top of them.
    func hidesQuickAssistantButton() -> some View {
        modifier(QuickAssistantButtonHider())
    }
}

private struct QuickAssistantButtonHider: ViewModifier {
    @InjectedObservable(\.quickAssistantCoordinator) private var coordinator
    @State private var isHiding = false

    func body(content: Content) -> some View {
        content
            .onAppear { setHiding(true) }
            .onDisappear { setHiding(false) }
    }

    private func setHiding(_ hiding: Bool) {
        guard hiding != isHiding else { return }
        isHiding = hiding
        coordinator.setFloatingButtonHidden(hiding)
    }
}
