import Foundation

public func configure<T>(_ object: T, using closure: (inout T) -> Void) -> T {
  var object = object
  closure(&object)
  return object
}

extension Double {
  var currency: String {
    CurrencyFormatter.shared.string(from: NSNumber(value: self)) ?? "$0.00"
  }
}

private enum CurrencyFormatter {
  static let shared: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter
  }()
}
