import Foundation
import StockPlanShared

struct StockShareSnapshot: Equatable {
    let title: String
    let body: String
}

enum StockShareFormatter {
    static func makeSnapshot(
        details: StockDetails,
        valuation: StockValuationRequest?,
        history: [StockHistory],
        news: [StockNews]
    ) -> StockShareSnapshot {
        var sections: [String] = []
        let symbolLine = details.symbol.hasPrefix("$") ? details.symbol : "$\(details.symbol)"

        sections.append(
            """
            \(symbolLine) position snapshot
            Position: \(formattedShares(details.shares)) shares @ \(details.buyPrice.currency)
            Cost basis: \((details.shares * details.buyPrice).currency)
            Buy date: \(details.buyDate)
            """
        )

        if let latestClose = history.first {
            sections.append(
                """
                Market
                - Latest close: \(latestClose.close.currency)
                - Session range: \(latestClose.low.currency) - \(latestClose.high.currency)
                - Date: \(latestClose.date)
                """
            )
        }

        if let valuation {
            var valuationLines = [
                "Valuation",
                "- Bear: \(formatted(range: valuation.bearCase))",
                "- Base: \(formatted(range: valuation.baseCase))",
                "- Bull: \(formatted(range: valuation.bullCase))"
            ]

            if let targetDate = valuation.targetDate, !targetDate.isEmpty {
                valuationLines.append("- Target date: \(targetDate)")
            }

            if let rationale = valuation.rationale?.normalizedShareBlock, !rationale.isEmpty {
                valuationLines.append("- Rationale: \(rationale)")
            }

            sections.append(valuationLines.joined(separator: "\n"))
        }

        if let notes = details.notes?.normalizedShareBlock, !notes.isEmpty {
            sections.append(
                """
                Notes
                \(notes)
                """
            )
        }

        if !news.isEmpty {
            let headlines = news.prefix(3).enumerated().map { index, item in
                "\(index + 1). \(item.title.normalizedShareBlock) (\(item.date))"
            }
            sections.append(
                """
                Recent news
                \(headlines.joined(separator: "\n"))
                """
            )
        }

        return StockShareSnapshot(
            title: "\(details.symbol) stock snapshot",
            body: sections.joined(separator: "\n\n")
        )
    }

    private static func formatted(range: PriceRange) -> String {
        "\(range.low.currency) - \(range.high.currency)"
    }

    private static func formattedShares(_ shares: Double) -> String {
        shares.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private extension String {
    var normalizedShareBlock: String {
        split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
