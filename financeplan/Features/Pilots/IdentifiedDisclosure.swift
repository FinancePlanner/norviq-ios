import StockPlanShared

/// A disclosure with an identity drawn from its own fields, so a refresh that
/// adds a filing at the top doesn't shift every row's identity the way a
/// position would. Identical filings (same symbol, side, instrument, dates
/// and amounts) are numbered in order, so ids stay unique.
struct IdentifiedDisclosure: Identifiable {
  let id: String
  let item: PilotDisclosureItem

  static func identify(_ items: [PilotDisclosureItem]) -> [IdentifiedDisclosure] {
    var seen: [String: Int] = [:]
    return items.map { item in
      let key = [
        item.symbol, item.side, item.instrument,
        item.transactionDate ?? "", item.disclosureDate ?? "", item.period ?? "",
        item.amountMin.map { "\($0)" } ?? "", item.amountMax.map { "\($0)" } ?? "",
      ].joined(separator: "|")
      let occurrence = seen[key, default: 0]
      seen[key] = occurrence + 1
      return IdentifiedDisclosure(id: "\(key)#\(occurrence)", item: item)
    }
  }
}
