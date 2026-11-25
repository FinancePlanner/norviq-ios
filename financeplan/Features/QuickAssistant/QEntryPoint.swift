import Factory
import SwiftUI

// The one way into Q, the same on every tab.
//
// iOS 26 and later: the tab bar's bottom accessory.
// iOS 18 to 25: a floating button inside each tab's content. The safe area
// there already stops above the tab bar, so nothing guesses its height.

extension View {
    /// Attach to the `TabView`. On iOS 26 it adds the accessory; on every
    /// version it hands the tap and hold to each tab's `qEntryPoint()`.
    ///
    /// - Parameter isSummaryAvailable: whether a tap opens a summary, so
    ///   VoiceOver names what the tap does.
    func qAccessory(
        coordinator: QuickAssistantCoordinator,
        isSummaryAvailable: Bool,
        onTap: @escaping () -> Void,
        onHold: @escaping () -> Void
    ) -> some View {
        modifier(
            QAccessoryModifier(
                coordinator: coordinator,
                actions: QEntryActions(isSummaryAvailable: isSummaryAvailable, onTap: onTap, onHold: onHold)
            )
        )
    }

    /// Attach to each tab's root. Draws the floating button below iOS 26.
    func qEntryPoint() -> some View {
        modifier(QEntryPointModifier())
    }

    /// What this screen is about, so a tap on Q summarises it.
    func qScope(_ scope: AIViewScope) -> some View {
        modifier(QScopeModifier(scope: scope))
    }

    /// For a pushed screen with its own controls at the bottom, such as a
    /// composer, where Q would sit on top of them.
    func hidesQAccessory() -> some View {
        modifier(QAccessoryHider())
    }
}

/// Where a tap or a hold on Q goes.
nonisolated enum QEntryRoute: Equatable {
    case summary(AIViewScope)
    case card(AIViewScope?)

    /// A tap summarises what is on screen for anyone with summaries, using the
    /// screen's scope or failing that the tab's. Everyone else, a hold, and a
    /// tab with nothing to summarise get the card.
    static func resolve(
        hasSummaries: Bool,
        screenScope: AIViewScope?,
        tabScope: AIViewScope?,
        isHold: Bool
    ) -> QEntryRoute {
        let scope = screenScope ?? tabScope
        if !isHold, hasSummaries, let scope { return .summary(scope) }
        return .card(scope)
    }
}

/// What a tap and a hold on Q do. Decided by `HomeScreen`.
struct QEntryActions {
    let isSummaryAvailable: Bool
    let onTap: () -> Void
    let onHold: () -> Void
}

private struct QEntryActionsKey: EnvironmentKey {
    static let defaultValue: QEntryActions? = nil
}

extension EnvironmentValues {
    /// Set by `qAccessory`. Nil outside the tab shell, where there is no Q.
    var qEntryActions: QEntryActions? {
        get { self[QEntryActionsKey.self] }
        set { self[QEntryActionsKey.self] = newValue }
    }
}

private struct QAccessoryModifier: ViewModifier {
    let coordinator: QuickAssistantCoordinator
    let actions: QEntryActions

    func body(content: Content) -> some View {
        accessory(on: content.environment(\.qEntryActions, actions))
    }

    @ViewBuilder
    private func accessory(on content: some View) -> some View {
        if #available(iOS 26.1, *) {
            // `isEnabled` hides it and keeps the TabView's identity, so the
            // screen that asked stays pushed.
            content.tabViewBottomAccessory(isEnabled: coordinator.qHiders == 0) {
                QAccessoryButton(actions: actions)
            }
        } else if #available(iOS 26, *) {
            // 26.0 has no `isEnabled`. Adding and removing the accessory
            // rebuilds the TabView and pops the screen that asked, so it stays
            // up. It joins the safe area, so a bottom action sits above it.
            content.tabViewBottomAccessory {
                QAccessoryButton(actions: actions)
            }
        } else {
            content
        }
    }
}

private struct QEntryPointModifier: ViewModifier {
    @InjectedObservable(\.quickAssistantCoordinator) private var coordinator
    @Environment(\.qEntryActions) private var actions

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.overlay {
                // Animates the button alone: on the tab root, a push that hides
                // it would run inside this animation too.
                ZStack {
                    if let actions, coordinator.showsQEntry {
                        QuickAssistantFloatingButton(actions: actions)
                            .transition(.opacity)
                    }
                }
                .appAnimation(AppMotion.structural, value: coordinator.showsQEntry)
            }
        }
    }
}

private struct QScopeModifier: ViewModifier {
    let scope: AIViewScope

    @InjectedObservable(\.quickAssistantCoordinator) private var coordinator
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { coordinator.pushScope(scope, id: id) }
            .onDisappear { coordinator.popScope(id: id) }
    }
}

private struct QAccessoryHider: ViewModifier {
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
        coordinator.setQAccessoryHidden(hiding)
    }
}

/// Q's tap and hold, shared by the accessory and the floating button.
///
/// A hold always opens the card. A long press ends with the finger lifting,
/// and the button can read that lift as a tap; the coordinator's gate
/// swallows it, and closing the card re-arms tap.
struct QEntryButton<Label: View>: View {
    let actions: QEntryActions
    @ViewBuilder let label: () -> Label

    @InjectedObservable(\.quickAssistantCoordinator) private var coordinator
    @State private var holdCount = 0

    var body: some View {
        Button {
            guard coordinator.allowsQTap() else { return }
            actions.onTap()
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                holdCount += 1
                actions.onHold()
                // After the hold has opened the card, whose opening re-arms tap.
                coordinator.noteQHold()
            }
        )
        .sensoryFeedback(.impact, trigger: holdCount)
        // The tap's own name; the card stays one action away when a tap
        // summarises instead.
        .accessibilityLabel(actions.isSummaryAvailable ? "AI summary" : "Ask Q")
        .accessibilityActions {
            if actions.isSummaryAvailable {
                Button("Ask Q", action: actions.onHold)
            }
        }
        .accessibilityIdentifier("q.entry")
    }
}

/// The accessory's content, "✦ Ask Q". The system draws the capsule.
struct QAccessoryButton: View {
    let actions: QEntryActions

    var body: some View {
        QEntryButton(actions: actions) {
            Label("Ask Q", systemImage: "sparkle")
                .foregroundStyle(AppTheme.Colors.tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule())
        }
    }
}
