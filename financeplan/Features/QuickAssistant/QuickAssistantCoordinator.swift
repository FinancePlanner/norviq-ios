import Foundation
import Observation

/// Opens and closes the Quick Q card from the Q entry point. The card is mounted
/// once, on `HomeScreen`.
@Observable @MainActor
final class QuickAssistantCoordinator {
    private(set) var isPresented = false
    private(set) var scope: AIViewScope?

    /// How many visible screens have their own controls where Q sits.
    private(set) var qHiders = 0

    /// The screens on show that said what they are about, oldest first.
    private var scopes: [(id: UUID, scope: AIViewScope)] = []

    /// Below iOS 26, whether the floating Q button is drawn.
    var showsQEntry: Bool {
        !isPresented && qHiders == 0
    }

    /// What the newest screen still on show is about.
    var currentScope: AIViewScope? {
        scopes.last?.scope
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

    func setQAccessoryHidden(_ hidden: Bool) {
        qHiders = max(0, qHiders + (hidden ? 1 : -1))
    }

    func pushScope(_ scope: AIViewScope, id: UUID) {
        scopes.append((id, scope))
    }

    /// By id, not from the top: a screen underneath can disappear first.
    func popScope(id: UUID) {
        scopes.removeAll { $0.id == id }
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
