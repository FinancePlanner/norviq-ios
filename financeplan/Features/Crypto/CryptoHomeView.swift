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
    @State private var isAddWatchlistPresented = false
    @State private var isBubblesPresented = false
    @State private var editingHolding: CryptoPortfolioItemResponse?
    @InjectedObservable(\Container.billingManager) private var billingManager

    private enum CryptoSegment: String, CaseIterable, Identifiable {
        case overview, portfolio, watchlist, market, news
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .portfolio: return "Portfolio"
            case .watchlist: return "Watchlist"
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
                AppTheme.Colors.pageBackground(for: colorScheme)
                    .ignoresSafeArea()

                if billingManager.isPro {
                    proContent
                } else {
                    lockedContent
                }
            }
            .vigilScreenBackground()
            .vigilNavigationTitle("Crypto")
            .aiViewSummary(.crypto)
            .vigilInlineNavigationBar()
            .navigationDestination(for: CryptoDetailRoute.self) { route in
                CryptoDetailScreen(route: route)
            }
            .refreshable {
                await reloadCrypto(force: true)
            }
            .task {
                await initialLoad()
            }

            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if billingManager.isPro, selectedSegment == .portfolio {
                        Button(action: presentAddHoldingSheet) {
                            Image(systemName: "plus")
                                .typography(.small, weight: .semibold)
                                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                                .padding(6)
                                .appGlassEffect(.capsule)
                        }
                        .accessibilityLabel("Add crypto holding")
                    }

                    if selectedSegment == .watchlist {
                        Button(action: presentAddWatchlistSheet) {
                            Image(systemName: "plus")
                                .typography(.small, weight: .semibold)
                                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                                .padding(6)
                                .appGlassEffect(.capsule)
                        }
                        .accessibilityLabel("Add crypto to watchlist")
                    }

                    Button(action: presentBubbles) {
                        Image(systemName: "circle.hexagongrid.fill")
                            .typography(.small, weight: .semibold)
                            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                            .padding(6)
                            .appGlassEffect(.capsule)
                    }
                    .accessibilityLabel("Open crypto bubbles")

                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .typography(.small, weight: .semibold)
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
            .sheet(isPresented: $isAddWatchlistPresented) {
                AddCryptoWatchlistSheet(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $isBubblesPresented) {
                CryptoBubblesView()
            }
            .sheet(item: $editingHolding) { holding in
                EditCryptoHoldingSheet(viewModel: viewModel, holding: holding)
            }
        }
    }

    private var proContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                VigilPageHeader(
                    watch: .wealth,
                    title: "Crypto"
                )
                .padding(.horizontal)

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
        .refreshable {
            await reloadCrypto(force: true)
        }
        .task {
            await initialLoad()
        }
    }

    private var lockedContent: some View {
        ProGateView(billingManager: billingManager) {
            ScrollView {
                VStack(spacing: 24) {
                    VigilPageHeader(
                        watch: .wealth,
                        title: "Crypto"
                    )
                    .padding(.horizontal)

                    segmentPicker
                    CryptoOverviewSkeleton()
                }
                .padding(.vertical)
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
        case .watchlist:
            CryptoWatchlistSection(viewModel: viewModel, onAdd: presentAddWatchlistSheet)
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

    private func presentAddWatchlistSheet() {
        isAddWatchlistPresented = true
    }

    private func presentBubbles() {
        isBubblesPresented = true
    }

    private func openSettings() {
        isSettingsPresented = true
    }
}
