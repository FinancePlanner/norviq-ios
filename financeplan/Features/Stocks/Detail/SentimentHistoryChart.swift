import Charts
import SwiftUI

/// Daily sentiment score over time.
///
/// The Y domain is pinned to the full -100…100 range rather than auto-scaled.
/// Letting Swift Charts fit the axis to the data would turn a week of
/// near-neutral noise into a dramatic-looking swing — exactly the misreading
/// this chart must not invite. The zero rule makes the bullish/bearish boundary
/// explicit.
struct SentimentHistoryChart: View {
    let history: [SymbolSentiment]

    private struct Point: Identifiable {
        let id: String
        let date: String
        let score: Double
    }

    private var points: [Point] {
        history.compactMap { entry in
            guard let score = entry.score else { return nil }
            return Point(id: entry.asOfDate, date: entry.asOfDate, score: score * 100)
        }
    }

    private var lineColor: Color {
        guard let last = points.last else { return .secondary }
        return last.score >= 0 ? .green : .red
    }

    var body: some View {
        Chart {
            RuleMark(y: .value("Neutral", 0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.secondary.opacity(0.4))

            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Sentiment", point.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(lineColor)
            }
        }
        .chartYScale(domain: -100 ... 100)
        .chartYAxis {
            AxisMarks(values: [-100, -50, 0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let score = value.as(Int.self) {
                        Text("\(score)")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .accessibilityLabel("Daily retail sentiment history")
    }
}
