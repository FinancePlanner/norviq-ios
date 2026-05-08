import SwiftUI
import StockPlanShared

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
