import Charts
import SwiftUI

/// Daily simulated value of a portfolio follow, oldest first.
struct PilotFollowValueChart: View {
  let points: [PilotValuePoint]
  let currency: String

  var body: some View {
    if points.count < 2 {
      ContentUnavailableView(
        "Chart starts after two days",
        systemImage: "chart.xyaxis.line",
        description: Text("Norviq records the simulated value once a day.")
      )
    } else {
      Chart(points) { point in
        LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
          .interpolationMethod(.monotone)
      }
      .chartYScale(domain: .automatic(includesZero: false))
      .chartYAxis {
        AxisMarks { value in
          AxisGridLine()
          AxisValueLabel {
            if let amount = value.as(Double.self) {
              Text(amount, format: .currency(code: currency).precision(.fractionLength(0)))
            }
          }
        }
      }
      .frame(height: 200)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Simulated value")
      .accessibilityValue(accessibilitySummary)
    }
  }

  private var accessibilitySummary: String {
    guard let first = points.first, let last = points.last else { return "" }
    let start = PilotFormatting.money(first.value, currency: currency)
    let end = PilotFormatting.money(last.value, currency: currency)
    return String(localized: "From \(start) to \(end)")
  }
}
