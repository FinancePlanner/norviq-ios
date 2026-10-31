import Foundation

/// One terminal scenario's inputs. Every number is a user assumption except
/// `currentSharePrice`, which is optional and manual in v1.
public struct TerminalScenarioInput: Sendable, Equatable {
    public var terminalShareCount: Double
    public var terminalMarketCap: Double
    public var valueWanted: Double
    public var sharesOwned: Double
    public var currentSharePrice: Double?

    public init(
        terminalShareCount: Double,
        terminalMarketCap: Double,
        valueWanted: Double,
        sharesOwned: Double = 0,
        currentSharePrice: Double? = nil
    ) {
        self.terminalShareCount = terminalShareCount
        self.terminalMarketCap = terminalMarketCap
        self.valueWanted = valueWanted
        self.sharesOwned = sharesOwned
        self.currentSharePrice = currentSharePrice
    }
}

/// Why a scenario cannot be evaluated. Raw values travel to clients as
/// `scenarioError`, which they show as an inline error.
public enum TerminalScenarioError: String, Codable, Sendable, Equatable, Error {
    case shareCountNotPositive = "share_count_not_positive"
    case marketCapNotPositive = "market_cap_not_positive"
    case invalidNumber = "invalid_number"
}

public struct TerminalScenarioResult: Sendable, Equatable {
    public let terminalSharePrice: Double
    public let sharesNeeded: Double
    public let capitalAtTodayPrice: Double?
    public let progress: Double
    public let sharesStillNeeded: Double
    public let gapValueAtTerminal: Double

    public init(
        terminalSharePrice: Double,
        sharesNeeded: Double,
        capitalAtTodayPrice: Double?,
        progress: Double,
        sharesStillNeeded: Double,
        gapValueAtTerminal: Double
    ) {
        self.terminalSharePrice = terminalSharePrice
        self.sharesNeeded = sharesNeeded
        self.capitalAtTodayPrice = capitalAtTodayPrice
        self.progress = progress
        self.sharesStillNeeded = sharesStillNeeded
        self.gapValueAtTerminal = gapValueAtTerminal
    }
}

/// Terminal position sizing: "if the company reaches market cap D with share
/// count C, how many shares make my position worth F?" Planning math only —
/// not a trade recommendation and not a stop-loss sizer. These are the only
/// formulas; every surface (backend, iOS, web via the backend) uses them.
public enum TerminalMath {
    public static func evaluate(_ input: TerminalScenarioInput)
        -> Result<TerminalScenarioResult, TerminalScenarioError>
    {
        let numbers = [input.terminalShareCount, input.terminalMarketCap, input.valueWanted, input.sharesOwned]
            + [input.currentSharePrice].compactMap(\.self)
        guard numbers.allSatisfy(\.isFinite) else { return .failure(.invalidNumber) }
        guard input.terminalShareCount > 0 else { return .failure(.shareCountNotPositive) }
        guard input.terminalMarketCap > 0 else { return .failure(.marketCapNotPositive) }
        guard input.valueWanted >= 0, input.sharesOwned >= 0 else { return .failure(.invalidNumber) }

        // Dividing by the terminal price (rather than multiplying valueWanted by the
        // share count first) avoids an intermediate overflow; the value is the same.
        let terminalSharePrice = input.terminalMarketCap / input.terminalShareCount
        let sharesNeeded = input.valueWanted == 0 ? 0 : input.valueWanted / terminalSharePrice
        let sharesStillNeeded = max(0, sharesNeeded - input.sharesOwned)
        let capital = input.currentSharePrice.flatMap { $0 > 0 ? sharesNeeded * $0 : nil }
        let progress = sharesNeeded == 0 ? 0 : input.sharesOwned / sharesNeeded
        let gapValueAtTerminal = sharesStillNeeded * terminalSharePrice

        // Derived values can still overflow or underflow to inf/nan even when every input is
        // finite. Such a result must fail here, not reach the JSON encoder downstream.
        let derived = [terminalSharePrice, sharesNeeded, progress, sharesStillNeeded, gapValueAtTerminal]
            + [capital].compactMap(\.self)
        guard derived.allSatisfy(\.isFinite) else { return .failure(.invalidNumber) }

        return .success(TerminalScenarioResult(
            terminalSharePrice: terminalSharePrice,
            sharesNeeded: sharesNeeded,
            capitalAtTodayPrice: capital,
            progress: progress,
            sharesStillNeeded: sharesStillNeeded,
            gapValueAtTerminal: gapValueAtTerminal
        ))
    }

    /// "Round down to whole shares" — a display toggle; the stored target is unchanged.
    public static func wholeShares(_ shares: Double) -> Double {
        guard shares.isFinite, shares > 0 else { return 0 }
        return shares.rounded(.down)
    }
}

/// How often an autobuy runs. `bimonthly` means every two months.
public enum AutobuyCadence: String, Codable, Sendable, CaseIterable {
    case weekly
    case biweekly
    case bimonthly
    case monthly
    case percentOfContribution
    case unknown

    /// A cadence added later must not break decoding on clients already shipped.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AutobuyCadence(rawValue: raw) ?? .unknown
    }
}

public enum AutobuyMath {
    /// weekly ×52/12, biweekly ×26/12, bimonthly ×6/12, monthly ×1;
    /// percentOfContribution uses `amount` as the monthly base: base × percent.
    public static func monthlyEquivalent(amount: Double, cadence: AutobuyCadence, percent: Double?) -> Double? {
        guard amount.isFinite, amount >= 0 else { return nil }
        let monthly: Double?
        switch cadence {
        case .weekly: monthly = amount * 52 / 12
        case .biweekly: monthly = amount * 26 / 12
        case .bimonthly: monthly = amount * 6 / 12
        case .monthly: monthly = amount
        case .percentOfContribution:
            guard let percent, percent.isFinite, percent > 0, amount > 0 else { return nil }
            monthly = amount * percent
        case .unknown: monthly = nil
        }
        // A huge amount can overflow to inf during the multiplication; treat that as unknown.
        guard let monthly, monthly.isFinite else { return nil }
        return monthly
    }

    /// Active rows only; rows without a monthly equivalent are skipped.
    public static func monthlyTotal(
        // swiftlint:disable:next large_tuple
        _ items: [(amount: Double, cadence: AutobuyCadence, percent: Double?, active: Bool)]
    ) -> Double {
        items.reduce(0) { total, item in
            guard item.active, let monthly = monthlyEquivalent(
                amount: item.amount,
                cadence: item.cadence,
                percent: item.percent
            ) else {
                return total
            }
            return total + monthly
        }
    }
}
