import Foundation

enum ChartBuilderChartType: String, CaseIterable, Identifiable {
  case bar
  case line

  var id: String { rawValue }

  var title: String {
    switch self {
    case .bar:
      "Bar"
    case .line:
      "Line"
    }
  }
}
