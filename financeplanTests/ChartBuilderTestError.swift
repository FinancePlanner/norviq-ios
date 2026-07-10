import Foundation

enum ChartBuilderTestError: LocalizedError {
  case unavailable

  var errorDescription: String? { "Chart data is unavailable." }
}
