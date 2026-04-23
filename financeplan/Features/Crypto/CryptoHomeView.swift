import SwiftUI
import StockPlanShared
import Factory
import OSLog

private let cryptoHomeLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "CryptoHome"
)

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
            .animation(.smooth(duration: 0.3), value: selectedSegment)
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

private struct CryptoOverviewSection: View {
    @ObservedObject var viewModel: CryptoViewModel
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Market Quick Stats
            HStack(spacing: 16) {
                MarketSentimentCard(value: viewModel.sentimentValue, label: viewModel.sentimentLabel)
                GasTrackerCard(gwei: viewModel.ethGasGwei)
            }
            .padding(.horizontal)

            // Your Balance
            if !viewModel.userHoldings.isEmpty {
                YourCryptoBalanceCard(holdings: viewModel.userHoldings, topAssets: viewModel.topAssets)
                    .padding(.horizontal)
            }

            // Market Dominance
            MarketDominanceCard(data: viewModel.dominance)
                .padding(.horizontal)

            // Featured Card
            if let btc = viewModel.topAssets.first(where: { $0.symbol.contains("BTC") }) {
                FeaturedCryptoCard(asset: btc)
                    .padding(.horizontal)

                MarketQuickStatsCard(asset: btc)
                    .padding(.horizontal)
            }

            // Top Movers
            TopMoversSection(gainers: viewModel.topGainers, losers: viewModel.topLosers)

            // Market Leaders
            if viewModel.topAssets.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    OverviewSectionLabel(title: "Market Leaders", color: .blue)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.topAssets.prefix(10)) { asset in
                                TrendingCryptoCard(asset: asset)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            // Latest News Preview
            if !viewModel.marketNews.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    OverviewSectionLabel(title: "Latest News", color: .purple)

                    ForEach(viewModel.marketNews.prefix(3)) { news in
                        CryptoNewsRow(news: news)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}

private struct CryptoPortfolioSection: View {
    @ObservedObject var viewModel: CryptoViewModel
    @Binding var editingHolding: CryptoPortfolioItemResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.userHoldings.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bitcoinsign.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("No Crypto Holdings")
                        .font(.headline)
                    Text("Add your first cryptocurrency to start tracking your portfolio performance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                YourCryptoBalanceCard(holdings: viewModel.userHoldings, topAssets: viewModel.topAssets)
                    .padding(.horizontal)

                Text("Your Assets")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    ForEach(viewModel.userHoldings) { holding in
                        let currentPrice = viewModel.topAssets.first(where: { $0.symbol == holding.symbol })?.price
                        CryptoHoldingRow(holding: holding, currentPrice: currentPrice)
                            .padding(.horizontal)
                            .contextMenu {
                                Button {
                                    editingHolding = holding
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.removeHolding(itemId: holding.id)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}

private struct CryptoMarketSection: View {
    @ObservedObject var viewModel: CryptoViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.topAssets) { asset in
                CryptoListRow(asset: asset)
                    .padding(.horizontal)
                Divider()
                    .padding(.leading, 70)
                    .opacity(0.3)
            }
        }
    }
}

private struct CryptoNewsSection: View {
    @ObservedObject var viewModel: CryptoViewModel

    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.marketNews) { news in
                CryptoNewsCard(news: news)
                    .padding(.horizontal)
            }
        }
    }
}

// UI Components

struct YourCryptoBalanceCard: View {
    let holdings: [CryptoPortfolioItemResponse]
    let topAssets: [CryptoQuoteResponse]

    var totalValue: Double {
        holdings.reduce(0) { total, holding in
            let currentPrice = topAssets.first(where: { $0.symbol == holding.symbol })?.price ?? holding.averageBuyPrice
            return total + (holding.quantity * currentPrice)
        }
    }

    var totalProfit: Double {
        holdings.reduce(0) { total, holding in
            let currentPrice = topAssets.first(where: { $0.symbol == holding.symbol })?.price ?? holding.averageBuyPrice
            let currentValue = holding.quantity * currentPrice
            let costBasis = holding.quantity * holding.averageBuyPrice
            return total + (currentValue - costBasis)
        }
    }

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Crypto Balance")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(totalValue.formatted(.currency(code: "USD")))
                            .font(.title2.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(totalProfit >= 0 ? "+" : "")\(totalProfit.formatted(.currency(code: "USD")))")
                            .font(.subheadline.bold())
                            .foregroundStyle(totalProfit >= 0 ? .green : .red)
                        Text("Profit")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(holdings) { holding in
                            HoldingCircle(symbol: holding.symbol)
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.orange.opacity(0.6), .purple.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct CryptoHoldingRow: View {
    let holding: CryptoPortfolioItemResponse
    let currentPrice: Double?

    var value: Double {
        (currentPrice ?? holding.averageBuyPrice) * holding.quantity
    }

    var profit: Double {
        let current = currentPrice ?? holding.averageBuyPrice
        return (current - holding.averageBuyPrice) * holding.quantity
    }

    var profitPercent: Double {
        let current = currentPrice ?? holding.averageBuyPrice
        guard holding.averageBuyPrice != 0 else { return 0 }
        return (current - holding.averageBuyPrice) / holding.averageBuyPrice
    }

    var body: some View {
        GlassCard(cornerRadius: 12) {
            HStack(spacing: 16) {
                HoldingCircle(symbol: holding.symbol)

                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.name)
                        .font(.subheadline.bold())
                    Text("\(holding.quantity.formatted(.number.precision(.fractionLength(0...8)))) \(holding.symbol.replacingOccurrences(of: "USD", with: ""))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(value.formatted(.currency(code: "USD")))
                        .font(.subheadline.bold())
                    HStack(spacing: 4) {
                        Image(systemName: profit >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(profit >= 0 ? "+" : "")\(profitPercent.formatted(.percent.precision(.fractionLength(2))))")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(profit >= 0 ? .green : .red)
                }
            }
        }
    }
}

struct HoldingCircle: View {
    let symbol: String

    var body: some View {
        Text(String(symbol.prefix(1)))
            .font(.caption2.bold())
            .frame(width: 32, height: 32)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(Circle().stroke(.orange.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Sparkline Shapes

struct SparklineShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        guard values.count >= 2 else { return Path() }
        var path = Path()
        let stepX = rect.width / CGFloat(values.count - 1)

        for (i, value) in values.enumerated() {
            let x = CGFloat(i) * stepX
            let y = rect.height * (1 - value)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                let prevX = CGFloat(i - 1) * stepX
                let prevY = rect.height * (1 - values[i - 1])
                let midX = (prevX + x) / 2
                path.addCurve(
                    to: CGPoint(x: x, y: y),
                    control1: CGPoint(x: midX, y: prevY),
                    control2: CGPoint(x: midX, y: y)
                )
            }
        }
        return path
    }
}

struct SparklineAreaShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        guard values.count >= 2 else { return Path() }
        var path = SparklineShape(values: values).path(in: rect)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Featured Crypto Card

struct FeaturedCryptoCard: View {
    let asset: CryptoQuoteResponse
    @Environment(\.colorScheme) private var colorScheme
    @State private var chartProgress: CGFloat = 0
    @State private var isPressed = false

    private var sparklineValues: [CGFloat] {
        let points: [Double] = [
            asset.dayLow ?? asset.price * 0.97,
            asset.open ?? asset.price * 0.99,
            asset.priceAvg50 ?? asset.price,
            asset.price,
            asset.dayHigh ?? asset.price * 1.02
        ]
        let minVal = points.min() ?? 0
        let maxVal = points.max() ?? 1
        let range = maxVal - minVal
        guard range > 0 else { return points.map { _ in CGFloat(0.5) } }
        return points.map { CGFloat(($0 - minVal) / range) }
    }

    private var isPositive: Bool { asset.change >= 0 }
    private var accentColor: Color { isPositive ? .green : .red }

    var body: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.name)
                            .font(.title3.bold())
                        Text(asset.symbol)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.price.formatted(.currency(code: "USD")))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    HStack(spacing: 6) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        Text("\(isPositive ? "+" : "")\(asset.change.formatted(.currency(code: "USD")))")
                        Text("(\(asset.changePercentage.formatted(.percent.precision(.fractionLength(2)))))")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(accentColor)
                }

                // Animated sparkline
                ZStack {
                    SparklineAreaShape(values: sparklineValues)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.25), accentColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(chartProgress)

                    SparklineShape(values: sparklineValues)
                        .trim(from: 0, to: chartProgress)
                        .stroke(
                            accentColor,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                }
                .frame(height: 60)
                .clipped()
            }
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                chartProgress = 1.0
            }
        }
    }
}

struct TrendingCryptoCard: View {
    let asset: CryptoQuoteResponse

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(asset.symbol.prefix(3))
                        .font(.caption.bold())
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                    Spacer()
                    Text("\(asset.changePercentage >= 0 ? "+" : "")\(asset.changePercentage.formatted(.percent.precision(.fractionLength(1))))")
                        .font(.caption2.bold())
                        .foregroundStyle(asset.changePercentage >= 0 ? .green : .red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name)
                        .font(.subheadline.bold())
                    Text(asset.price.formatted(.currency(code: "USD")))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100)
        }
    }
}

struct CryptoNewsRow: View {
    let news: StockNews

    var body: some View {
        GlassCard(cornerRadius: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(news.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text("\(news.source ?? "News") • \(formatRelativeDate(news.date))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let imageURL = news.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                }
            }
        }
    }

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return dateString }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}

struct CryptoNewsCard: View {
    let news: StockNews

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                if let imageURL = news.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(minHeight: 160, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.gray.opacity(0.2))
                        .frame(minHeight: 160, maxHeight: 200)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(news.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text(news.summary ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    HStack {
                        Text(news.source ?? "Crypto")
                            .font(.caption.bold())
                        Spacer()
                        Text(news.date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct CryptoListRow: View {
    let asset: CryptoQuoteResponse

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(asset.symbol.prefix(1)))
                        .foregroundStyle(.white)
                        .bold()
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.headline)
                Text(asset.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(asset.price.formatted(.currency(code: "USD")))
                    .font(.subheadline.bold())
                Text("\(asset.changePercentage >= 0 ? "+" : "")\(asset.changePercentage.formatted(.percent.precision(.fractionLength(2))))")
                    .font(.caption)
                    .foregroundStyle(asset.changePercentage >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 12)
    }
}

struct AddCryptoHoldingSheet: View {
    @ObservedObject var viewModel: CryptoViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var symbol = ""
    @State private var name = ""
    @State private var quantity = ""
    @State private var buyPrice = ""
    @State private var isSaving = false
    @State private var searchText = ""
    @State private var allAssets: [CryptoAssetResponse] = []
    @State private var isLoadingAssets = false

    private let cryptoService: any CryptoServicing = Container.shared.cryptoService()

    var filteredAssets: [CryptoAssetResponse] {
        if searchText.isEmpty {
            return allAssets.prefix(20).map { $0 }
        }
        return allAssets.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }.prefix(50).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Search Asset") {
                    ZStack(alignment: .trailing) {
                        TextField("Search by symbol or name", text: $searchText)

                        if isLoadingAssets {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    if !filteredAssets.isEmpty && symbol.isEmpty {
                        List {
                            ForEach(filteredAssets) { asset in
                                Button {
                                    self.symbol = asset.symbol
                                    self.name = asset.name
                                    self.searchText = asset.symbol
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(asset.symbol).bold()
                                            Text(asset.name).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(minHeight: 200, maxHeight: 300)
                    }
                }

                if !symbol.isEmpty {
                    Section("Selected Asset") {
                        HStack {
                            Text(symbol).bold()
                            Text("-")
                            Text(name)
                            Spacer()
                            Button("Clear") {
                                symbol = ""
                                name = ""
                                searchText = ""
                            }
                            .font(.caption)
                        }
                    }

                    Section("Position") {
                        TextField("Quantity", text: $quantity)
                            .keyboardType(.decimalPad)
                        TextField("Average Buy Price (USD)", text: $buyPrice)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Add Crypto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        save()
                    }
                    .disabled(symbol.isEmpty || quantity.isEmpty || buyPrice.isEmpty || isSaving)
                }
            }
            .task {
                isLoadingAssets = true
                do {
                    allAssets = try await cryptoService.fetchCryptoList()
                } catch {
                    cryptoHomeLogger.error("Failed to fetch crypto list: \(error.localizedDescription, privacy: .public)")
                }
                isLoadingAssets = false
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
    }

    private func save() {
        guard let qty = Double(quantity), let price = Double(buyPrice) else { return }
        isSaving = true
        Task {
            let success = await viewModel.addHolding(symbol: symbol, name: name, quantity: qty, price: price)
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Overview Enhancements

struct MarketSentimentCard: View {
    let value: Int
    let label: String
    @State private var animatedValue: CGFloat = 0
    @State private var displayValue: Int = 0
    @State private var counterTask: Task<Void, Never>?

    var sentimentColor: Color {
        if value < 25 { return .red }
        if value < 45 { return .orange }
        if value < 55 { return .yellow }
        if value < 75 { return .green }
        return .cyan
    }

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Fear & Greed")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(displayValue)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                    Text(label)
                        .font(.caption.bold())
                        .foregroundStyle(sentimentColor)
                        .padding(.bottom, 4)
                }

                // Animated gradient gauge
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.gray.opacity(0.15))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)
                        .mask(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle()
                                    .frame(width: geo.size.width * animatedValue)
                            }
                        }

                    GeometryReader { geo in
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .shadow(color: sentimentColor.opacity(0.6), radius: 4)
                            .offset(x: max(0, geo.size.width * animatedValue - 6))
                    }
                    .frame(height: 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedValue = CGFloat(value) / 100.0
            }
            animateCounter(to: value)
        }
        .onDisappear {
            counterTask?.cancel()
        }
    }

    private func animateCounter(to end: Int) {
        counterTask?.cancel()
        let steps = max(1, end)
        let interval = Duration.milliseconds(max(1, Int((800.0 / Double(steps)).rounded())))

        counterTask = Task { @MainActor in
            for i in 0...steps {
                guard !Task.isCancelled else { return }
                displayValue = i

                guard i < steps else { return }
                try? await Task.sleep(for: interval)
            }
        }
    }
}

struct GasTrackerCard: View {
    let gwei: Int
    @State private var isPulsing = false

    private var statusColor: Color {
        gwei < 20 ? .green : gwei < 40 ? .yellow : .orange
    }

    private var statusText: String {
        gwei < 20 ? "Low · Cheap" : gwei < 40 ? "Normal" : "Congested"
    }

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("ETH Gas")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isPulsing ? 1.4 : 0.8)
                        .opacity(isPulsing ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                }

                HStack(alignment: .bottom, spacing: 4) {
                    Image(systemName: "fuelpump.fill")
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .padding(.bottom, 4)
                    Text("\(gwei)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Gwei")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }

                Text(statusText)
                    .font(.caption2.bold())
                    .foregroundStyle(statusColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(statusColor.opacity(0.25), lineWidth: 1)
        )
        .onAppear { isPulsing = true }
    }
}

struct MarketDominanceCard: View {
    let data: [CryptoViewModel.DominanceData]
    @State private var barProgress: CGFloat = 0

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Market Dominance")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                // Animated multi-colored bar
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(data) { item in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.color.gradient)
                                .frame(width: max(0, (geometry.size.width * CGFloat(item.percentage / 100) * barProgress) - 2))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 12)

                // Legend
                HStack(spacing: 16) {
                    ForEach(data) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.symbol)
                                .font(.caption2.bold())
                            Text(item.percentage.formatted(.number.precision(.fractionLength(1))) + "%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                barProgress = 1.0
            }
        }
    }
}

struct TopMoversSection: View {
    let gainers: [CryptoQuoteResponse]
    let losers: [CryptoQuoteResponse]
    @State private var showingGainers = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(showingGainers ? "Top Gainers" : "Top Losers")
                    .font(.headline)
                Spacer()
                Picker("Movers", selection: $showingGainers) {
                    Text("Gainers").tag(true)
                    Text("Losers").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(showingGainers ? gainers : losers) { asset in
                        MoverCard(asset: asset)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MoverCard: View {
    let asset: CryptoQuoteResponse

    private var isPositive: Bool { asset.changePercentage >= 0 }

    var body: some View {
        GlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(asset.symbol.replacingOccurrences(of: "USD", with: ""))
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: isPositive ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                        .font(.caption2)
                        .foregroundStyle(isPositive ? .green : .red)
                }

                Text(asset.changePercentage.formatted(.percent.precision(.fractionLength(1))))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(isPositive ? .green : .red)

                Text(asset.price.formatted(.currency(code: "USD")))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 95)
        }
    }
}

// MARK: - Helper Components

struct OverviewSectionLabel: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 16)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal)
    }
}

struct MarketQuickStatsCard: View {
    let asset: CryptoQuoteResponse

    var body: some View {
        GlassCard(cornerRadius: 16) {
            HStack(spacing: 0) {
                QuickStatColumn(
                    title: "24h Volume",
                    value: shortFormat(asset.volume ?? 0)
                )

                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 8)

                QuickStatColumn(
                    title: "Market Cap",
                    value: shortFormat(asset.marketCap ?? 0)
                )

                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 8)

                QuickStatColumn(
                    title: "24h Range",
                    value: "\(shortPrice(asset.dayLow)) – \(shortPrice(asset.dayHigh))"
                )
            }
        }
    }

    private func shortFormat(_ value: Double) -> String {
        if value >= 1_000_000_000_000 { return String(format: "$%.1fT", value / 1_000_000_000_000) }
        if value >= 1_000_000_000 { return String(format: "$%.1fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        return "$\(Int(value))"
    }

    private func shortPrice(_ value: Double?) -> String {
        guard let v = value else { return "–" }
        if v >= 1000 { return "$\(Int(v).formatted())" }
        return v.formatted(.currency(code: "USD"))
    }
}

private struct QuickStatColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading Skeleton

struct CryptoOverviewSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.gray.opacity(0.12))
                    .frame(minHeight: 110)
                    .shimmer()
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.gray.opacity(0.12))
                    .frame(minHeight: 110)
                    .shimmer()
            }
            .padding(.horizontal)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.gray.opacity(0.12))
                .frame(minHeight: 70)
                .shimmer()
                .padding(.horizontal)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.gray.opacity(0.12))
                .frame(minHeight: 200)
                .shimmer()
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.gray.opacity(0.12))
                            .frame(width: 120, height: 100)
                            .shimmer()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct EditCryptoHoldingSheet: View {
    @ObservedObject var viewModel: CryptoViewModel
    let holding: CryptoPortfolioItemResponse
    @Environment(\.dismiss) private var dismiss

    @State private var quantity = ""
    @State private var buyPrice = ""
    @State private var isSaving = false

    init(viewModel: CryptoViewModel, holding: CryptoPortfolioItemResponse) {
        self.viewModel = viewModel
        self.holding = holding
        _quantity = State(initialValue: String(holding.quantity))
        _buyPrice = State(initialValue: String(holding.averageBuyPrice))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset Info") {
                    HStack {
                        Text("Symbol")
                        Spacer()
                        Text(holding.symbol).bold()
                    }
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(holding.name).foregroundStyle(.secondary)
                    }
                }

                Section("Position") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("Average Buy Price (USD)", text: $buyPrice)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(quantity.isEmpty || buyPrice.isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
    }

    private func save() {
        guard let qty = Double(quantity), let price = Double(buyPrice) else { return }
        isSaving = true
        Task {
            let success = await viewModel.updateHolding(
                itemId: holding.id,
                symbol: holding.symbol,
                name: holding.name,
                quantity: qty,
                price: price
            )
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}
