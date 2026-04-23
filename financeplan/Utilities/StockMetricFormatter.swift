//
//  StockMetricFormatter.swift

import Foundation

struct StockMetricFormatter {
    static func percentText(_ value: Double?, precision: Int = 1, locale: Locale = .current)
        -> String
    {
        guard let value else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(precision)).locale(locale))
    }

    static func multipleText(_ value: Double, decimals: Int = 1, locale: Locale = .current)
        -> String
    {
        let formattedValue = value.formatted(
            .number.precision(.fractionLength(decimals)).locale(locale))
        return "\(formattedValue)x"
    }

    static func compactCurrency(_ value: Double, locale: Locale = .current) -> String {
        let absolute = abs(value)
        let prefix = value < 0 ? "-" : ""

        switch absolute {
        case 1_000_000_000_000...:
            let scaled = absolute / 1_000_000_000_000
            let formatted = scaled.formatted(.number.precision(.fractionLength(2)).locale(locale))
            return "\(prefix)$\(formatted)T"
        case 1_000_000_000...:
            let scaled = absolute / 1_000_000_000
            let formatted = scaled.formatted(.number.precision(.fractionLength(1)).locale(locale))
            return "\(prefix)$\(formatted)B"
        case 1_000_000...:
            let scaled = absolute / 1_000_000
            let formatted = scaled.formatted(.number.precision(.fractionLength(1)).locale(locale))
            return "\(prefix)$\(formatted)M"
        default:
            return value.formatted(.currency(code: "USD").locale(locale))
        }
    }

    static func compactNumber(_ value: Double, locale: Locale = .current) -> String {
        let absolute = abs(value)
        switch absolute {
        case 1_000_000_000...:
            let scaled = value / 1_000_000_000
            let formatted = scaled.formatted(.number.precision(.fractionLength(2)).locale(locale))
            return "\(formatted)B"
        case 1_000_000...:
            let scaled = value / 1_000_000
            let formatted = scaled.formatted(.number.precision(.fractionLength(1)).locale(locale))
            return "\(formatted)M"
        default:
            return value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
        }
    }

    static func signedCurrencyText(_ value: Double, locale: Locale = .current) -> String {
        let prefix = value >= 0 ? "+" : "-"
        return prefix + abs(value).formatted(.currency(code: "USD").locale(locale))
    }

    static func signedPercentText(_ value: Double, locale: Locale = .current) -> String {
        let prefix = value >= 0 ? "+" : "-"
        return prefix + percentText(abs(value), locale: locale)
    }

    static func formattedValue(
        for metric: StockComparisonMetric, value: Double?, locale: Locale = .current
    ) -> String {
        guard let value else { return "N/A" }

        switch metric.format {
        case .multiple:
            return multipleText(value, locale: locale)
        case .percent:
            return percentText(value, locale: locale)
        case .plain:
            if metric == .dcfFairValue {
                return value.formatted(.currency(code: "USD").locale(locale))
            }
            return value.formatted(.number.precision(.fractionLength(2)).locale(locale))
        }
    }

    static func currencyText(
        _ value: Double, code: String?, decimals: Int = 2, locale: Locale = .current
    ) -> String {
        let currencyCode = (code == nil || code?.isEmpty == true) ? "USD" : code!
        return value.formatted(
            .currency(code: currencyCode)
                .precision(.fractionLength(decimals))
                .locale(locale)
        )
    }

    static func compactStatementCurrency(_ value: Double, code: String?, locale: Locale = .current)
        -> String
    {
        let absolute = abs(value)
        let prefix = value < 0 ? "-" : ""
        let normalizedCode = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let currencySymbol =
            (normalizedCode == nil || normalizedCode == "USD") ? "$" : "\(normalizedCode!) "

        switch absolute {
        case 1_000_000_000_000...:
            let scaled = absolute / 1_000_000_000_000
            return prefix + currencySymbol
                + scaled.formatted(.number.precision(.fractionLength(2)).locale(locale)) + "T"
        case 1_000_000_000...:
            let scaled = absolute / 1_000_000_000
            return prefix + currencySymbol
                + scaled.formatted(.number.precision(.fractionLength(1)).locale(locale)) + "B"
        case 1_000_000...:
            let scaled = absolute / 1_000_000
            return prefix + currencySymbol
                + scaled.formatted(.number.precision(.fractionLength(1)).locale(locale)) + "M"
        default:
            let finalCode =
                (normalizedCode == nil || normalizedCode?.isEmpty == true) ? "USD" : normalizedCode!
            return value.formatted(
                .currency(code: finalCode)
                    .precision(.fractionLength(0))
                    .locale(locale)
            )
        }
    }
}
