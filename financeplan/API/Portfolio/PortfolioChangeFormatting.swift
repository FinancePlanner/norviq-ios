import Foundation
import StockPlanShared

/// Rendering for the portfolio changes the backend computes.
///
/// The dashboard used to derive its own delta from the last two points of the
/// performance series and label it "vs last period", which said nothing about
/// what was actually compared. The backend now returns the change together with
/// the window it was measured over, so the label can state it.
///
/// The rule this exists to enforce: a change the backend could not compute is
/// absent, and absent is not zero. A young account shows its value with no chip
/// rather than a "0.0%" claiming it was flat.
enum PortfolioChangeFormatting: Sendable {
    /// The words shown after the number, from the change's basis.
    ///
    /// The basis is an open set — the backend may add values a shipped build has
    /// never seen — so an unrecognized one falls back to naming the start date,
    /// which stays true even when the window has no name here.
    nonisolated static func suffix(for change: PortfolioChange) -> String {
        switch change.basis {
        case PortfolioChange.Basis.previousTradingDay:
            // Not "yesterday": days the market was shut have no data point, so
            // the comparison really is against the previous session.
            String(localized: "vs previous close")
        case PortfolioChange.Basis.week:
            String(localized: "vs last week")
        case PortfolioChange.Basis.month:
            String(localized: "vs last month")
        case PortfolioChange.Basis.ytd:
            String(localized: "year to date")
        case PortfolioChange.Basis.inception:
            String(localized: "since you started")
        default:
            String(localized: "since \(formattedDate(change.fromDate))")
        }
    }

    /// "-0.4% vs previous close".
    nonisolated static func label(for change: PortfolioChange) -> String {
        "\(percentText(change.percent)) \(suffix(for: change))"
    }

    /// The percentage on its own. `percent` is fractional, so -0.004 is -0.4%.
    nonisolated static func percentText(_ percent: Double) -> String {
        let sign = percent >= 0 ? "+" : ""
        let formatted = (percent * 100).formatted(.number.precision(.fractionLength(1)))
        return "\(sign)\(formatted)%"
    }

    /// The change to show on the hero card: the most recent movement available,
    /// falling back through longer windows when a shorter one cannot be computed
    /// yet.
    ///
    /// A portfolio with two days of history has a day change but no monthly one.
    /// Falling back shows the best available truth instead of nothing, and since
    /// every change carries its own window, the label stays accurate whichever
    /// one is used.
    nonisolated static func primary(from changes: PortfolioChanges?) -> PortfolioChange? {
        guard let changes else { return nil }
        return changes.day ?? changes.week ?? changes.month ?? changes.sinceInception
    }

    /// Built per call rather than cached in a static: DateFormatter is not
    /// Sendable, and this is only reached on the fallback path for a basis this
    /// build does not recognize.
    private nonisolated static func formattedDate(_ raw: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: raw) else { return raw }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
