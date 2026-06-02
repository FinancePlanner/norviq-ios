import StockPlanShared
import SwiftUI

struct InsightCardView: View {
    let kind: AIInsightKind
    let state: InsightsViewModel.CardState
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.iconName)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(kind.displayTitle)
                .font(.headline)
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            VStack(alignment: .leading, spacing: 12) {
                Text(kind.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(action: onGenerate) {
                    Label("Generate insight", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("insight.generate.\(kind.rawValue)")
            }

        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Analyzing your data…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .loaded(card):
            loaded(card)

        case let .failed(message):
            VStack(alignment: .leading, spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Try again", action: onGenerate)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func loaded(_ card: AIInsightCardResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.title)
                .font(.title3.weight(.semibold))
            Text(card.body)
                .font(.body)
                .foregroundStyle(.primary)

            if !card.highlights.isEmpty {
                FlexibleHighlights(highlights: card.highlights)
            }

            Text(card.disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(action: onGenerate) {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("insight.regenerate.\(card.kind.rawValue)")
        }
    }
}

private struct FlexibleHighlights: View {
    let highlights: [AIInsightHighlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(highlights) { highlight in
                HStack {
                    Text(highlight.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        if let symbol = trendSymbol(highlight.trend) {
                            Image(systemName: symbol)
                                .font(.caption2)
                        }
                        Text(highlight.value)
                            .font(.callout.weight(.semibold))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func trendSymbol(_ trend: String?) -> String? {
        switch trend?.lowercased() {
        case "up": "arrow.up.right"
        case "down": "arrow.down.right"
        case "flat": "arrow.right"
        default: nil
        }
    }
}

private extension AIInsightKind {
    var displayTitle: String {
        switch self {
        case .expenses: "Where your money went"
        case .portfolio: "Your portfolio at a glance"
        case .summary: "Your financial snapshot"
        }
    }

    var prompt: String {
        switch self {
        case .expenses: "A plain-language look at your recent spending by category."
        case .portfolio: "An overview of your holdings, allocation, and performance."
        case .summary: "A combined view of your spending and portfolio."
        }
    }

    var iconName: String {
        switch self {
        case .expenses: "creditcard"
        case .portfolio: "chart.pie"
        case .summary: "sparkles"
        }
    }
}
