import Factory
import SwiftUI

/// The always-there way into Quick Q, resting just above the tab bar.
struct QuickAssistantFloatingButton: View {
    /// The tab bar sits outside this view, so its height isn't in the safe area.
    private static let tabBarHeight: CGFloat = 49

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickAssistantMascotStar()
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask Q")
        .accessibilityIdentifier("quickAssistant.floatingButton")
        .padding(.trailing, 12)
        .padding(.bottom, Self.tabBarHeight + 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        // The keyboard covers it, rather than lifting it over a form's fields.
        .ignoresSafeArea(.keyboard)
    }
}

/// Vig's face inside a four-point star, with the assistant's small sparkles beside
/// it. The star stays light in dark mode, because Vig is navy and would disappear.
private struct QuickAssistantMascotStar: View {
    var body: some View {
        ZStack {
            FourPointStar(waist: 0.3)
                .fill(Color(red: 0.99, green: 0.98, blue: 0.95))
            Image("VigIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .offset(y: 5)
                .clipShape(FourPointStar(waist: 0.3))
            FourPointStar(waist: 0.3)
                .stroke(AppTheme.Colors.tint, lineWidth: 1.5)
            FourPointStar(waist: 0.2)
                .fill(AppTheme.Colors.tint)
                .frame(width: 13, height: 13)
                .offset(x: -24, y: -24)
            FourPointStar(waist: 0.2)
                .fill(AppTheme.Colors.tint)
                .frame(width: 8, height: 8)
                .offset(x: -14, y: -30)
        }
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
