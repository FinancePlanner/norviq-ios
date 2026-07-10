import SwiftUI
import StockPlanShared
import Factory
import OSLog

struct CryptoHomeView: View {
    @Binding var isSettingsPresented: Bool
    @StateObject private var viewModel = CryptoViewModel()
    @State private var selectedSegment: CryptoSegment = .overview
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAddCryptoPresented = false
    @State private var editingHolding: CryptoPortfolioItemResponse?

    private enum CryptoSegment: String, CaseIterable, Identifiable {
        case overview, portfolio, market, news
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .portfolio: return "Portfolio"
            case .market: return "Market"
            case .news: return "News"
            }
        }
    }

    private var isShowingLoadingState: Bool {
        viewModel.isLoading && viewModel.topAssets.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        segmentPicker

                        if isShowingLoadingState {
                            CryptoOverviewSkeleton()
                                .transition(.opacity)
                        } else {
                            segmentContent
                                .transition(.opacity)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Crypto")
            .refreshable {
                await reloadCrypto(force: true)
            }
            .task {
                await initialLoad()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if selectedSegment == .portfolio {
                        Button(action: presentAddHoldingSheet) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                                .padding(6)
                                .appGlassEffect(.capsule)
                        }
                        .accessibilityLabel("Add crypto holding")
                    }

                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                            .padding(6)
                            .appGlassEffect(.capsule)
                    }
                    .accessibilityLabel("Open settings")
                }
            }
            .sheet(isPresented: $isAddCryptoPresented) {
                AddCryptoHoldingSheet(viewModel: viewModel)
            }
            .sheet(item: $editingHolding) { holding in
                EditCryptoHoldingSheet(viewModel: viewModel, holding: holding)
            }
        }
    }

    private var segmentPicker: some View {
        Picker("Crypto section", selection: $selectedSegment) {
            ForEach(CryptoSegment.allCases) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var segmentContent: some View {
        switch selectedSegment {
        case .overview:
            CryptoOverviewSection(viewModel: viewModel)
        case .portfolio:
            CryptoPortfolioSection(viewModel: viewModel, editingHolding: $editingHolding)
        case .market:
            CryptoMarketSection(viewModel: viewModel)
        case .news:
            CryptoNewsSection(viewModel: viewModel)
        }
    }

    private func initialLoad() async {
        await reloadCrypto()
    }

    private func reloadCrypto(force: Bool = false) async {
        await viewModel.load(force: force)
    }

    private func presentAddHoldingSheet() {
        isAddCryptoPresented = true
    }

    private func openSettings() {
        isSettingsPresented = true
    }
}
