import StockPlanShared
import SwiftUI

struct InsightsScreen: View {
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    intro

                    ForEach(AIInsightKind.allCases, id: \.self) { kind in
                        InsightCardView(
                            kind: kind,
                            state: viewModel.state(for: kind),
                            onGenerate: { Task { await viewModel.generate(kind) } }
                        )
                    }

                    Text(AIInsightCardResponse.standardDisclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("Insights")
            .accessibilityIdentifier("insights.screen")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI Insights")
                .font(.title2.weight(.bold))
            Text("Educational summaries generated from your own data. Tap to generate.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
