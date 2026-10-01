import Foundation
import StockPlanShared
import SwiftUI

/// Full-screen bubbles for the shared markets timeframe. Colour follows the
/// server's scale for the window, so a 3% day and a 3% year do not look alike.
struct CryptoBubblesView: View {
    @ObservedObject var viewModel: CryptoMarketsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine = BubbleEngine()
    @State private var metric: BubbleSizeMetric = .marketCap
    @State private var canvasSize: CGSize = .zero
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.isLoading && viewModel.response == nil {
                    ProgressView()
                        .tint(.white)
                } else if let error = viewModel.errorMessage, viewModel.response == nil {
                    errorState(error)
                } else {
                    bubbleField
                }

                VStack {
                    CryptoTimeframePicker(viewModel: viewModel, onDark: true)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Spacer()
                    if let attribution = viewModel.response?.attribution {
                        Text(attribution)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
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
                engine.configure(inputs: inputs, bounds: canvasSize, metric: metric)
            }
            .onChange(of: inputs) { _, newInputs in
                engine.configure(inputs: newInputs, bounds: canvasSize, metric: metric)
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var bubbleField: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: reduceMotion || scenePhase != .active)) { timeline in
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
                        if let hit = engine.hitTest(value.location), let detail = hit.detailSymbol {
                            path.append(CryptoDetailRoute(symbol: detail, name: hit.name))
                        }
                    }
            )
            .onAppear {
                canvasSize = proxy.size
                engine.configure(inputs: inputs, bounds: proxy.size, metric: metric)
            }
            .onChange(of: proxy.size) { _, newSize in
                canvasSize = newSize
                engine.updateBounds(newSize)
            }
        }
    }

    private func draw(_ bubble: CryptoBubble, in context: inout GraphicsContext) {
        let shade = CryptoHeatColor.fraction(
            bubble.changePercent,
            scaleMax: viewModel.response?.colorScaleMaxPct ?? 10,
            mode: viewModel.response?.colorMode ?? .change
        )
        let isUp = shade >= 0
        let magnitude = abs(shade)
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

        let pctText = Text(formatCryptoPercent(bubble.changePercent, digits: 1))
            .font(.system(size: min(bubble.radius * 0.30, 13), weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
        context.draw(pctText, at: CGPoint(x: bubble.position.x, y: bubble.position.y + bubble.radius * 0.30))
    }

    private var inputs: [CryptoBubbleInput] {
        CryptoBubbleInput.from(viewModel.response?.coins ?? [])
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
            engine.setMetric(newMetric, inputs: inputs)
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
