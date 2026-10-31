import Foundation

/// A country-specific fiscal receipt QR format. New formats (e.g. Spain
/// TicketBAI) conform and register with `FiscalReceiptQRParser`.
public protocol FiscalQRFormat: Sendable {
    /// Whether this format recognizes the raw payload.
    func matches(_ payload: String) -> Bool
    /// Parse a matching payload into a draft. Returns nil if parsing fails.
    func parse(_ payload: String) -> ReceiptDraft?
}

/// Registry that tries each known fiscal QR format in turn. Used identically by
/// iOS (on-device) and the backend (for web-submitted QR strings) so a receipt
/// parses the same everywhere.
public struct FiscalReceiptQRParser: Sendable {
    private let formats: [any FiscalQRFormat]

    public init(formats: [any FiscalQRFormat] = FiscalReceiptQRParser.defaultFormats) {
        self.formats = formats
    }

    public static let defaultFormats: [any FiscalQRFormat] = [
        PortugalATFiscalQRFormat(),
    ]

    /// Parse a decoded QR string. Returns nil when no registered format matches.
    public func parse(_ payload: String) -> ReceiptDraft? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for format in formats where format.matches(trimmed) {
            if let draft = format.parse(trimmed) {
                return draft
            }
        }
        return nil
    }
}

/// Parser for the Portuguese Autoridade Tributária (AT) receipt QR code.
/// The payload is an asterisk-delimited list of `key:value` fields defined by
/// Portaria 195/2020. Relevant fields:
///
/// - `A`  issuer (merchant) NIF
/// - `D`  document type (FT, FS, FR, …)
/// - `F`  document date, `YYYYMMDD`
/// - `I3`–`I8` VAT bases/amounts per bracket
/// - `N`  total taxes (VAT)
/// - `O`  total including taxes (the amount paid)
///
/// The QR carries no merchant name — only the NIF — so `merchant` is left nil
/// and surfaced as `taxId` for the user to label.
public struct PortugalATFiscalQRFormat: FiscalQRFormat {
    public init() {}

    public func matches(_ payload: String) -> Bool {
        // AT payloads start with the issuer-NIF field `A:` and use `*` separators.
        payload.hasPrefix("A:") && payload.contains("*")
    }

    public func parse(_ payload: String) -> ReceiptDraft? {
        let fields = Self.fields(from: payload)
        guard !fields.isEmpty else { return nil }

        let total = fields["O"].flatMap(Self.parseAmount)
        let taxTotal = fields["N"].flatMap(Self.parseAmount)
        let date = fields["F"].flatMap(Self.parseDate)
        let taxId = fields["A"]?.trimmingCharacters(in: .whitespaces)

        // A payload with neither a total nor a date isn't a usable receipt.
        guard total != nil || date != nil else { return nil }

        return ReceiptDraft(
            merchant: nil,
            total: total,
            currency: "EUR",
            date: date,
            taxId: taxId,
            taxTotal: taxTotal,
            vatLines: Self.vatLines(from: fields),
            confidence: 1.0,
            source: .qr,
            rawPayload: payload
        )
    }

    static func fields(from payload: String) -> [String: String] {
        var result: [String: String] = [:]
        for part in payload.split(separator: "*") {
            guard let separator = part.firstIndex(of: ":") else { continue }
            let key = String(part[part.startIndex ..< separator])
            let value = String(part[part.index(after: separator)...])
            guard !key.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    /// AT amounts use a dot decimal separator (e.g. "12.34").
    static func parseAmount(_ raw: String) -> Double? {
        Double(raw.trimmingCharacters(in: .whitespaces))
    }

    /// Converts `YYYYMMDD` into `YYYY-MM-DD` (ExpenseRequest.occurredOn format).
    static func parseDate(_ raw: String) -> String? {
        let digits = raw.trimmingCharacters(in: .whitespaces)
        guard digits.count == 8, digits.allSatisfy(\.isNumber) else { return nil }
        let year = digits.prefix(4)
        let month = digits.dropFirst(4).prefix(2)
        let day = digits.dropFirst(6).prefix(2)
        return "\(year)-\(month)-\(day)"
    }

    /// Maps the AT bracket fields (I3/I4 reduced, I5/I6 intermediate, I7/I8
    /// standard) into labelled VAT lines, skipping empty brackets.
    static func vatLines(from fields: [String: String]) -> [ReceiptVATLine] {
        let brackets: [(label: String, baseKey: String, amountKey: String)] = [
            ("reduced", "I3", "I4"),
            ("intermediate", "I5", "I6"),
            ("standard", "I7", "I8"),
        ]
        return brackets.compactMap { bracket in
            let base = fields[bracket.baseKey].flatMap(parseAmount)
            let amount = fields[bracket.amountKey].flatMap(parseAmount)
            guard base != nil || amount != nil else { return nil }
            return ReceiptVATLine(rate: bracket.label, base: base, amount: amount)
        }
    }
}
