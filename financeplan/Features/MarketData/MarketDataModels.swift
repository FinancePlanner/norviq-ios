import Foundation
import StockPlanShared

extension CompanyProfileResponse {
  var displayName: String? {
    name?.nonEmptyTrimmed
  }

  var displayTicker: String? {
    ticker?.nonEmptyTrimmed
  }

  var websiteURL: URL? {
    guard let weburl = weburl?.nonEmptyTrimmed else { return nil }
    return URL(string: weburl)
  }

  var localizedCountryName: String? {
    guard let countryCode = country?.nonEmptyTrimmed?.uppercased() else { return nil }
    if let localized = Locale.current.localizedString(forRegionCode: countryCode), !localized.isEmpty {
      return "\(localized) (\(countryCode))"
    }
    return countryCode
  }

  var marketCapitalizationAmount: Double? {
    marketCapitalization.map { $0 * 1_000_000 }
  }

  var sharesOutstandingAmount: Double? {
    shareOutstanding.map { $0 * 1_000_000 }
  }
}

extension QuoteResponse {
  var resolvedChange: Double {
    if let change {
      return change
    }

    guard let previousClose else {
      return 0
    }

    return currentPrice - previousClose
  }

  var resolvedPercentChange: Double? {
    if let percentChange {
      return percentChange / 100
    }

    guard let previousClose, previousClose != 0 else {
      return nil
    }

    return resolvedChange / previousClose
  }
}

private extension String {
  var nonEmptyTrimmed: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
