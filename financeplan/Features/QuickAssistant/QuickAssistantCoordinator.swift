import Foundation
import Observation

/// Opens and closes the Quick Q card from the floating button or any screen's AI
/// button. The card and the floating button are mounted once, on `HomeScreen`.
@Observable @MainActor
final class QuickAssistantCoordinator {
    private(set) var isPresented = false
    private(set) var scope: AIViewScope?

    /// How many visible screens have their own controls where the button sits.
    private var floatingButtonHiders = 0

    var showsFloatingButton: Bool {
        !isPresented && floatingButtonHiders == 0
    }

    private let allowsAI: @MainActor () -> Bool
    private let presentConsent: @MainActor () -> Void

    init(allowsAI: @escaping @MainActor () -> Bool, presentConsent: @escaping @MainActor () -> Void) {
        self.allowsAI = allowsAI
        self.presentConsent = presentConsent
    }

    func present(scope: AIViewScope?) {
        guard allowsAI() else {
            presentConsent()
            return
        }
        self.scope = scope
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    func setFloatingButtonHidden(_ hidden: Bool) {
        floatingButtonHiders = max(0, floatingButtonHiders + (hidden ? 1 : -1))
    }
}

/// A long press ends with the finger lifting, and a `Button` can read that lift
/// as a tap. This swallows that one tap, so holding the AI button opens the card
/// and not the summary as well.
nonisolated struct QuickAssistantTapGate {
    /// A tap this long after the press is a new tap. The window also covers the
    /// case where the lift never reached the button.
    private static let releaseWindow: TimeInterval = 5
    private var longPressAt: Date?

    mutating func noteLongPress(at date: Date = .now) {
        longPressAt = date
    }

    mutating func allowsTap(at date: Date = .now) -> Bool {
        guard let pressed = longPressAt else { return true }
        longPressAt = nil
        return date.timeIntervalSince(pressed) >= Self.releaseWindow
    }
}
