import Foundation

/// How a receipt draft was produced.
public enum ReceiptSource: String, Codable, Sendable, CaseIterable {
    /// Parsed from a structured fiscal QR code (e.g. Portuguese AT format).
    case qr
    /// Extracted from a photo via optical character recognition.
    case ocr
}

/// A single VAT bracket extracted from a fiscal receipt.
public struct ReceiptVATLine: Codable, Sendable, Equatable {
    /// VAT rate label as reported by the receipt (e.g. "reduced", "standard").
    public let rate: String
    /// Net taxable base for this bracket.
    public let base: Double?
    /// VAT amount for this bracket.
    public let amount: Double?

    public init(rate: String, base: Double? = nil, amount: Double? = nil) {
        self.rate = rate
        self.base = base
        self.amount = amount
    }
}

/// A single purchased line on a receipt.
///
/// Only emitted by OCR — fiscal QR codes carry totals and VAT brackets, never
/// individual articles. `amount` is the line total as printed (quantity already
/// applied), so a review UI can sum `lineItems` and compare against `total`
/// without re-multiplying.
public struct ReceiptLineItem: Codable, Sendable, Equatable {
    /// Article description as printed on the receipt.
    public let description: String
    /// Line total in the receipt's currency, including tax when the receipt is tax-inclusive.
    public let amount: Double
    /// Units purchased when the receipt states them. Nil for single-unit or unpriced-per-unit lines.
    public let quantity: Double?

    public init(description: String, amount: Double, quantity: Double? = nil) {
        self.description = description
        self.amount = amount
        self.quantity = quantity
    }
}

/// A pre-filled expense draft extracted from a scanned receipt. The client turns
/// this into an expense once the user assigns a budget pillar and category — the
/// draft intentionally carries no pillar/category so scanning never guesses those.
public struct ReceiptDraft: Codable, Sendable, Equatable {
    /// Merchant display name when known. Fiscal QR codes carry only a tax id, so
    /// this is often empty for QR-sourced drafts and filled from OCR text.
    public let merchant: String?
    /// Total amount paid, including tax.
    public let total: Double?
    /// ISO 4217 currency code (e.g. "EUR"). Nil when the source doesn't state it.
    public let currency: String?
    /// Purchase date as `YYYY-MM-DD`, matching `ExpenseRequest.occurredOn`.
    public let date: String?
    /// Merchant tax identifier (e.g. Portuguese NIF) when present in a fiscal QR.
    public let taxId: String?
    /// Total VAT/tax amount when reported.
    public let taxTotal: Double?
    /// Per-bracket VAT breakdown when reported.
    public let vatLines: [ReceiptVATLine]
    /// Individual purchased articles when OCR could read them. Empty for QR-sourced
    /// drafts and for receipts whose line items were not legible. The sum of these
    /// need not equal `total` — see `lineItemsSum` and `lineItemsReconcile`.
    public let lineItems: [ReceiptLineItem]
    /// Extraction confidence in `0...1`. QR parses are 1.0; OCR is lower.
    public let confidence: Double
    /// Whether this draft came from a QR parse or OCR.
    public let source: ReceiptSource
    /// The raw fiscal QR payload, retained for QR-sourced drafts for auditing.
    public let rawPayload: String?

    public init(
        merchant: String? = nil,
        total: Double? = nil,
        currency: String? = nil,
        date: String? = nil,
        taxId: String? = nil,
        taxTotal: Double? = nil,
        vatLines: [ReceiptVATLine] = [],
        lineItems: [ReceiptLineItem] = [],
        confidence: Double,
        source: ReceiptSource,
        rawPayload: String? = nil
    ) {
        self.merchant = merchant
        self.total = total
        self.currency = currency
        self.date = date
        self.taxId = taxId
        self.taxTotal = taxTotal
        self.vatLines = vatLines
        self.lineItems = lineItems
        self.confidence = confidence
        self.source = source
        self.rawPayload = rawPayload
    }

    private enum CodingKeys: String, CodingKey {
        case merchant, total, currency, date, taxId, taxTotal
        case vatLines, lineItems, confidence, source, rawPayload
    }

    /// Decoded leniently on the two collection keys so a client built against a
    /// newer contract keeps working against an older backend that omits them —
    /// the synthesized decoder would throw on the missing key instead.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant)
        total = try container.decodeIfPresent(Double.self, forKey: .total)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        taxId = try container.decodeIfPresent(String.self, forKey: .taxId)
        taxTotal = try container.decodeIfPresent(Double.self, forKey: .taxTotal)
        vatLines = try container.decodeIfPresent([ReceiptVATLine].self, forKey: .vatLines) ?? []
        lineItems = try container.decodeIfPresent([ReceiptLineItem].self, forKey: .lineItems) ?? []
        confidence = try container.decode(Double.self, forKey: .confidence)
        source = try container.decode(ReceiptSource.self, forKey: .source)
        rawPayload = try container.decodeIfPresent(String.self, forKey: .rawPayload)
    }

    /// Sum of the extracted line items, or nil when none were read.
    public var lineItemsSum: Double? {
        lineItems.isEmpty ? nil : lineItems.reduce(0) { $0 + $1.amount }
    }

    /// Whether the line items add up to the printed total, within a cent.
    ///
    /// Nil when there is nothing to compare (no line items, or no total). A `false`
    /// means OCR misread at least one figure: show both numbers at review rather
    /// than silently trusting either, and never split an expense on items that
    /// don't reconcile.
    public var lineItemsReconcile: Bool? {
        guard let sum = lineItemsSum, let total else { return nil }
        return abs(sum - total) < 0.01
    }
}

/// Request body for `POST /v1/receipts/parse-qr`: the raw decoded QR string.
public struct ReceiptParseQRRequest: Codable, Sendable, Equatable {
    public let payload: String

    public init(payload: String) {
        self.payload = payload
    }
}

/// Response wrapping a parsed draft. `recognized` is false when no supported
/// fiscal QR format matched, so clients can fall back to OCR or manual entry.
public struct ReceiptDraftResponse: Codable, Sendable, Equatable {
    public let recognized: Bool
    public let draft: ReceiptDraft?

    public init(recognized: Bool, draft: ReceiptDraft?) {
        self.recognized = recognized
        self.draft = draft
    }
}
