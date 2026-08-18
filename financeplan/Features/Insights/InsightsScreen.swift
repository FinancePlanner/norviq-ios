import StockPlanShared
import SwiftUI

struct InsightsScreen: View {
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VigilPageHeader(
                        watch: .intelligence,
                        title: "Insights"
                    )

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
            .vigilScreenBackground()
            .vigilNavigationTitle("Insights")
            .accessibilityIdentifier("insights.screen")
        }
    }
}
