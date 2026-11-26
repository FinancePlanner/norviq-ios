import SwiftUI

extension View {
    /// Shows the AI summary for `scope` while it is set, and hands off to the
    /// assistant if the reader continues from it.
    ///
    /// Mounted once, on `HomeScreen`, which sets the scope when a Pro reader
    /// taps Q. One presenter rather than one per screen: Q is shared by every
    /// tab, and a tab with no screen-level scope still has a summary.
    func aiSummaryPresentation(scope: Binding<AIViewScope?>) -> some View {
        modifier(AIViewSummaryPresentation(scope: scope))
    }
}

private struct AIViewSummaryPresentation: ViewModifier {
    @Binding var scope: AIViewScope?

    @State private var isAssistantPresented = false
    @State private var pendingSeed: String?

    func body(content: Content) -> some View {
        content
            .sheet(item: $scope) { scope in
                AIViewSummarySheet(scope: scope) { seed in
                    // Close this sheet first and hand off on its dismissal.
                    // Presenting a second sheet while the first is still up is
                    // ignored on iOS, so the assistant would simply never open.
                    pendingSeed = seed
                    self.scope = nil
                }
            }
            .onChange(of: scope == nil) { _, closed in
                guard closed, pendingSeed != nil else { return }
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

nonisolated extension AIViewScope: Identifiable {
    var id: Self { self }
}
