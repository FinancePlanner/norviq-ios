import SwiftUI

private let tickIntervalMs: Double = 800.0

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
        let interval = Duration.milliseconds(max(1, Int((tickIntervalMs / Double(steps)).rounded())))

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
