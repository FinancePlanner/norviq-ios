import Foundation

struct PortfolioAllocationImpact: Equatable, Sendable {
  let symbol: String
  let beforePercentage: Double
  let afterPercentage: Double

  var didChange: Bool {
    abs(beforePercentage - afterPercentage) >= 0.05
  }
}

enum PortfolioAllocationImpactCalculator {
  struct Holding: Equatable, Sendable {
    let id: String
    let symbol: String
    let shares: Double
    let buyPrice: Double

    var value: Double {
      max(0, shares) * max(0, buyPrice)
    }
  }

  enum Change: Equatable, Sendable {
    case newPosition(symbol: String, shares: Double, buyPrice: Double)
    case replacePosition(id: String, symbol: String, shares: Double, buyPrice: Double)
    case sellPosition(id: String, symbol: String, remainingShares: Double, buyPrice: Double, cashProceeds: Double)
  }

  static func preview(
    holdings: [Holding],
    cashBalance: Double,
    change: Change
  ) -> PortfolioAllocationImpact? {
    let normalizedCashBalance = max(0, cashBalance)
    let beforeValues = valuesBySymbol(from: holdings)
    let beforeTotal = beforeValues.values.reduce(normalizedCashBalance, +)
    var changedHoldings = holdings
    var afterCashBalance = normalizedCashBalance
    let changedSymbol: String

    switch change {
    case let .newPosition(symbol, shares, buyPrice):
      let normalizedSymbol = normalizedSymbol(symbol)
      guard !normalizedSymbol.isEmpty, shares > 0, buyPrice > 0 else { return nil }
      changedSymbol = normalizedSymbol
      changedHoldings.append(
        Holding(id: "draft-\(normalizedSymbol)", symbol: normalizedSymbol, shares: shares, buyPrice: buyPrice)
      )
    case let .replacePosition(id, symbol, shares, buyPrice):
      let normalizedSymbol = normalizedSymbol(symbol)
      guard !id.isEmpty, !normalizedSymbol.isEmpty, shares >= 0, buyPrice > 0 else { return nil }
      changedSymbol = normalizedSymbol
      changedHoldings.removeAll { $0.id == id }
      if shares > 0 {
        changedHoldings.append(Holding(id: id, symbol: normalizedSymbol, shares: shares, buyPrice: buyPrice))
      }
    case let .sellPosition(id, symbol, remainingShares, buyPrice, cashProceeds):
      let normalizedSymbol = normalizedSymbol(symbol)
      guard !id.isEmpty, !normalizedSymbol.isEmpty, remainingShares >= 0, buyPrice > 0, cashProceeds >= 0 else { return nil }
      changedSymbol = normalizedSymbol
      changedHoldings.removeAll { $0.id == id }
      if remainingShares > 0 {
        changedHoldings.append(Holding(id: id, symbol: normalizedSymbol, shares: remainingShares, buyPrice: buyPrice))
      }
      afterCashBalance += cashProceeds
    }

    let afterValues = valuesBySymbol(from: changedHoldings)
    let afterTotal = afterValues.values.reduce(afterCashBalance, +)

    return PortfolioAllocationImpact(
      symbol: changedSymbol,
      beforePercentage: percentage(value: beforeValues[changedSymbol] ?? 0, total: beforeTotal),
      afterPercentage: percentage(value: afterValues[changedSymbol] ?? 0, total: afterTotal)
    )
  }

  private static func valuesBySymbol(from holdings: [Holding]) -> [String: Double] {
    holdings.reduce(into: [:]) { values, holding in
      let symbol = normalizedSymbol(holding.symbol)
      guard !symbol.isEmpty else { return }
      values[symbol, default: 0] += holding.value
    }
  }

  private static func percentage(value: Double, total: Double) -> Double {
    guard total > 0 else { return 0 }
    return (value / total) * 100
  }

  private static func normalizedSymbol(_ symbol: String) -> String {
    symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  }
}
