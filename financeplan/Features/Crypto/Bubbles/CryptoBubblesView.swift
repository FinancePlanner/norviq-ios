import Combine
import Factory
import Foundation
import StockPlanShared
import SwiftUI

@MainActor
final class CryptoBubblesViewModel: ObservableObject {
    @Published var quotes: [CryptoQuoteResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let cryptoService: any CryptoServicing
    private let maxCoins = 60

    init(cryptoService: any CryptoServicing = Container.shared.cryptoService()) {
        self.cryptoService = cryptoService
    }

    func load() async {
        guard quotes.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await cryptoService.fetchCryptoList()
            let symbols = list.prefix(maxCoins).map(\.symbol)
            guard !symbols.isEmpty else { return }
            let fetched = try await cryptoService.fetchCryptoQuote(symbols: symbols.joined(separator: ","))
            // Keep only coins with a usable market cap, largest first.
            quotes = fetched
                .filter { ($0.marketCap ?? 0) > 0 }
                .sorted { ($0.marketCap ?? 0) > ($1.marketCap ?? 0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CryptoBubblesView: View {
    @StateObject private var viewModel = CryptoBubblesViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var engine = BubbleEngine()
    @State private var metric: BubbleSizeMetric = .marketCap
    @State private var canvasSize: CGSize = .zero
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.isLoading && viewModel.quotes.isEmpty {
                    ProgressView()
                        .tint(.white)
                } else if let error = viewModel.errorMessage, viewModel.quotes.isEmpty {
                    errorState(error)
                } else {
                    bubbleField
                }

                VStack {
                    Spacer()
                    metricPicker
                        .padding(.bottom, 12)
                }
            }
            .navigationTitle("Bubbles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: CryptoDetailRoute.self) { route in
                CryptoDetailScreen(route: route)
            }
            .task {
                await viewModel.load()
                engine.configure(quotes: viewModel.quotes, bounds: canvasSize, metric: metric)
            }
            .onChange(of: viewModel.quotes.count) { _, _ in
                engine.configure(quotes: viewModel.quotes, bounds: canvasSize, metric: metric)
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var bubbleField: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    engine.updateBounds(size)
                    engine.step(to: timeline.date.timeIntervalSinceReferenceDate)
                    for bubble in engine.bubbles {
                        draw(bubble, in: &context)
                    }
                }
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let hit = engine.hitTest(value.location) {
                            path.append(CryptoDetailRoute(symbol: hit.symbol, name: hit.name))
                        }
                    }
            )
            .onAppear {
                canvasSize = proxy.size
                engine.configure(quotes: viewModel.quotes, bounds: proxy.size, metric: metric)
            }
            .onChange(of: proxy.size) { _, newSize in
                canvasSize = newSize
                engine.updateBounds(newSize)
            }
        }
    }

    private func draw(_ bubble: CryptoBubble, in context: inout GraphicsContext) {
        let isUp = bubble.changePercent >= 0
        let magnitude = min(abs(bubble.changePercent) / 10.0, 1.0)
        let base: Color = isUp ? .green : .red
        let fill = base.opacity(0.25 + 0.45 * magnitude)
        let stroke = base.opacity(0.9)

        let rect = CGRect(
            x: bubble.position.x - bubble.radius,
            y: bubble.position.y - bubble.radius,
            width: bubble.radius * 2,
            height: bubble.radius * 2
        )
        let circle = Path(ellipseIn: rect)
        context.fill(circle, with: .color(fill))
        context.stroke(circle, with: .color(stroke), lineWidth: 2)

        // Labels (only if the bubble is big enough to read).
        guard bubble.radius >= 28 else { return }

        let symbolText = Text(displaySymbol(bubble.symbol))
            .font(.system(size: min(bubble.radius * 0.42, 18), weight: .bold))
            .foregroundStyle(.white)
        context.draw(symbolText, at: CGPoint(x: bubble.position.x, y: bubble.position.y - bubble.radius * 0.18))

        let pctText = Text("\(isUp ? "+" : "")\(bubble.changePercent, specifier: "%.1f")%")
            .font(.system(size: min(bubble.radius * 0.30, 13), weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
        context.draw(pctText, at: CGPoint(x: bubble.position.x, y: bubble.position.y + bubble.radius * 0.30))
    }

    private func displaySymbol(_ symbol: String) -> String {
        symbol.replacingOccurrences(of: "USD", with: "")
    }

    private var metricPicker: some View {
        Picker("Size by", selection: $metric) {
            ForEach(BubbleSizeMetric.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 40)
        .onChange(of: metric) { _, newMetric in
            engine.setMetric(newMetric, quotes: viewModel.quotes)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
