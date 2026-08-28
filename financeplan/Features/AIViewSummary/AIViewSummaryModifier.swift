import Factory
import SwiftUI

extension View {
    /// Adds this screen's AI summary button and everything behind it.
    ///
    /// One line per screen, and that is the entire point. The alternative —
    /// each screen declaring its own toolbar item, its own sheet state, its own
    /// assistant hand-off — would be the same plumbing written eight times.
    /// `ExpensesPlannerScreen` already carries fourteen `.sheet` modifiers and
    /// `TaxDashboardScreen` twelve; adding two more to each is how a screen
    /// becomes unreadable.
    ///
    /// Attach it to the screen's `NavigationStack`. `.toolbar` is the mount
    /// rather than `VigilPageHeader(trailing:)` because the header is not
    /// universal — `DashboardRoot` has none, and `PortfolioRoot` keeps its in a
    /// child view — while every one of these screens has a stack.
    ///
    /// - Parameter placement: overridden only on Portfolio, whose trailing
    ///   toolbar already holds two links and a menu; a fifth item there
    ///   collapses into overflow on small devices.
    func aiViewSummary(
        _ scope: AIViewScope,
        placement: ToolbarItemPlacement = .topBarTrailing
    ) -> some View {
        modifier(AIViewSummaryModifier(scope: scope, placement: placement))
    }
}

private struct AIViewSummaryModifier: ViewModifier {
    let scope: AIViewScope
    let placement: ToolbarItemPlacement

    @State private var isSummaryPresented = false
    @State private var isAssistantPresented = false
    @State private var pendingSeed: String?
    @InjectedObservable(\.billingManager) private var billingManager

    /// Server-driven rather than a raw `isPro` read, so the feature can be
    /// turned off for a user without an App Store release. `isFeatureAvailable`
    /// already falls back to `isPro` when the server says nothing.
    private var isAvailable: Bool {
        billingManager.isFeatureAvailable("ai_insights")
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                if isAvailable {
                    ToolbarItem(placement: placement) {
                        Button {
                            isSummaryPresented = true
                        } label: {
                            Image(systemName: "sparkles")
                        }
                        .accessibilityLabel("AI summary")
                        .accessibilityIdentifier("aiSummary.open.\(scope.rawValue)")
                    }
                }
            }
            .sheet(isPresented: $isSummaryPresented) {
                AIViewSummarySheet(scope: scope) { seed in
                    // Close this sheet first and hand off on its dismissal.
                    // Presenting a second sheet while the first is still up is
                    // ignored on iOS, so the assistant would simply never open.
                    pendingSeed = seed
                    isSummaryPresented = false
                }
            }
            .onChange(of: isSummaryPresented) { _, presented in
                guard !presented, pendingSeed != nil else { return }
                isAssistantPresented = true
            }
            .sheet(isPresented: $isAssistantPresented, onDismiss: { pendingSeed = nil }) {
                // Prefilled, never sent. The reader decides whether to ask.
                // Auto-sending would also write into the conversation Telegram
                // shares, so a linked chat's scrollback would grow a message
                // nobody typed.
                PersistentAssistantView(seed: pendingSeed)
            }
    }
}
