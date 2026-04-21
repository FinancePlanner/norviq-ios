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

  func compactCurrency(code: String = "USD") -> String {
    let absolute = abs(self)
    let prefix = self < 0 ? "-" : ""
    
    switch absolute {
    case 1_000_000_000_000...:
      return prefix + String(format: "$%.1fT", absolute / 1_000_000_000_000)
    case 1_000_000_000...:
      return prefix + String(format: "$%.1fB", absolute / 1_000_000_000)
    case 1_000_000...:
      return prefix + String(format: "$%.1fM", absolute / 1_000_000)
    case 1_000...:
      return prefix + String(format: "$%.1fk", absolute / 1_000)
    default:
      return self.currency
    }
  }

  func signedCurrencyText() -> String {
    let prefix = self >= 0 ? "+" : "-"
    return prefix + abs(self).currency
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
