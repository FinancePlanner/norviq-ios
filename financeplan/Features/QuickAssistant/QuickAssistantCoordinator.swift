import Foundation
import Observation

/// Opens and closes the Quick Q card from the Q entry point. The card is mounted
/// once, on `HomeScreen`.
@Observable @MainActor
final class QuickAssistantCoordinator {
    private(set) var isPresented = false
    private(set) var scope: AIViewScope?

    /// How many things hide Q: visible screens with their own controls where
    /// Q sits, plus an active guided-start step.
    private(set) var qHiders = 0

    /// Whether a guided-start step is counted in `qHiders`.
    private var isGuidedStepActive = false

    /// Swallows the lift that ends a hold on Q.
    private var tapGate = QuickAssistantTapGate()

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
        setPresented(true)
    }

    func dismiss() {
        setPresented(false)
    }

    /// A change of card re-arms tap. Closing the card makes the next tap a
    /// tap, however soon after the hold that opened it.
    private func setPresented(_ presented: Bool) {
        if presented != isPresented { tapGate = QuickAssistantTapGate() }
        isPresented = presented
    }

    /// Call after the hold has acted, so the lift that follows is swallowed.
    func noteQHold() {
        tapGate.noteLongPress()
    }

    func allowsQTap() -> Bool {
        tapGate.allowsTap()
    }

    func setQAccessoryHidden(_ hidden: Bool) {
        qHiders = max(0, qHiders + (hidden ? 1 : -1))
    }

    /// A guided-start step hides Q, as on the web. Idempotent: a step counts
    /// once however often it is reported.
    func setGuidedStepActive(_ active: Bool) {
        guard active != isGuidedStepActive else { return }
        isGuidedStepActive = active
        setQAccessoryHidden(active)
    }

    /// Idempotent per id, so a scope that appears twice needs one pop.
    func pushScope(_ scope: AIViewScope, id: UUID) {
        scopes.removeAll { $0.id == id }
        scopes.append((id, scope))
    }

    /// By id, not from the top: a screen underneath can disappear first.
    func popScope(id: UUID) {
        scopes.removeAll { $0.id == id }
    }

    /// The next account must not inherit a scope, a hider or a guided step that
    /// a torn-down screen left behind. A late unhide still clamps at 0.
    func resetForSignOut() {
        dismiss()
        scopes.removeAll()
        qHiders = 0
        isGuidedStepActive = false
        tapGate = QuickAssistantTapGate()
    }
}

/// A long press ends with the finger lifting, and a `Button` can read that lift
/// as a tap. This swallows that one tap, so holding Q opens the card and not the
/// summary as well.
nonisolated struct QuickAssistantTapGate {
    /// A tap this long after the press is a new tap. The window also covers the
    /// case where the lift never reached the button. It bounds how long a hold
    /// can last, not how long a reader waits: closing the card re-arms tap.
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
