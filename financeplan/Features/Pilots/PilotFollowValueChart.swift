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
      // Points are UTC midnights (snapshot days). Label them in UTC so each
      // one reads as its own day in every device time zone, not the day before.
      .environment(\.timeZone, .gmt)
      .environment(\.calendar, Self.utcCalendar)
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

  private static let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  private var accessibilitySummary: String {
    guard let first = points.first, let last = points.last else { return "" }
    let start = PilotFormatting.money(first.value, currency: currency)
    let end = PilotFormatting.money(last.value, currency: currency)
    return String(localized: "From \(start) to \(end)")
  }
}
