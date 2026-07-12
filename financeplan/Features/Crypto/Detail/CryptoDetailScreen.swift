import SwiftUI
import StockPlanShared

struct CryptoDetailScreen: View {
    @StateObject private var viewModel: CryptoDetailViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(route: CryptoDetailRoute) {
        _viewModel = StateObject(wrappedValue: CryptoDetailViewModel(symbol: route.symbol, name: route.name))
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    GlassCard {
                        CryptoPriceChartTab(
                            points: viewModel.points,
                            selectedRange: viewModel.selectedRange,
                            isLoading: viewModel.isLoadingChart,
                            errorMessage: viewModel.errorMessage,
                            onSelectRange: { range in
                                Task { await viewModel.selectRange(range) }
                            }
                        )
                    }

                    if let quote = viewModel.quote {
                        statsCard(quote)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.initialLoad()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .overlay(
                    Text(String(viewModel.symbol.prefix(1)))
                        .foregroundStyle(.white)
                        .font(.title2.bold())
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.name)
                    .font(.title3.bold())
                Text(viewModel.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let quote = viewModel.quote {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(quote.price.formatted(.currency(code: "USD")))
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("\(quote.changePercentage >= 0 ? "+" : "")\(quote.changePercentage.formatted(.number.precision(.fractionLength(2))))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(quote.changePercentage >= 0 ? .green : .red)
                }
            } else if viewModel.isLoadingQuote {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stats

    private func statsCard(_ quote: CryptoQuoteResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Market stats")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statItem("Market cap", currencyCompact(quote.marketCap))
                    statItem("Volume", currencyCompact(quote.volume))
                    statItem("Day high", currency(quote.dayHigh))
                    statItem("Day low", currency(quote.dayLow))
                    statItem("Year high", currency(quote.yearHigh))
                    statItem("Year low", currency(quote.yearLow))
                }
            }
        }
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func currency(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.currency(code: "USD"))
    }

    private func currencyCompact(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.currency(code: "USD").notation(.compactName))
    }
}
