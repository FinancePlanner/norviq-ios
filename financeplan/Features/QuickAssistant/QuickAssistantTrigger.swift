import SwiftUI

/// The AI toolbar button. Holding it opens the Quick Q card; a tap opens the
/// screen summary, or the card for anyone without summaries.
struct QuickAssistantTrigger: View {
    let isSummaryAvailable: Bool
    let identifier: String
    let onSummary: () -> Void
    let onAsk: () -> Void

    @State private var tapGate = QuickAssistantTapGate()
    @State private var longPressCount = 0

    var body: some View {
        Button {
            guard tapGate.allowsTap() else { return }
            if isSummaryAvailable { onSummary() } else { onAsk() }
        } label: {
            Image(systemName: "sparkles")
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                tapGate.noteLongPress()
                longPressCount += 1
                onAsk()
            }
        )
        .sensoryFeedback(.impact, trigger: longPressCount)
        .accessibilityLabel(isSummaryAvailable ? "AI summary" : "Ask Q")
        .accessibilityAction(named: "Ask Q", onAsk)
        .accessibilityIdentifier(identifier)
    }
}
