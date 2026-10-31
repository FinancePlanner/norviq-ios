import Foundation

/// Response for `POST /v1/receipts/scan`: one result per uploaded image, in the
/// order the images were sent, so a client can pair a failure with its photo.
public struct ReceiptBatchScanResponse: Codable, Sendable, Equatable {
    public let results: [ReceiptDraftResponse]

    public init(results: [ReceiptDraftResponse]) {
        self.results = results
    }

    /// Drafts that were actually recognised, for a client that only wants those.
    public var drafts: [ReceiptDraft] {
        results.compactMap(\.draft)
    }
}

/// One expense the user confirmed on the review screen.
///
/// Carries a full `ExpenseRequest` rather than a receipt draft, because by this
/// point the user has assigned the pillar and category that scanning
/// deliberately never guesses. A receipt split into line items produces several
/// of these, each with the same `receiptMetadata`.
public struct ReceiptImportItem: Codable, Sendable, Equatable {
    /// Stable identity for the source line, so re-scanning the same receipt
    /// does not double-insert. Build it from the receipt's own identifying
    /// fields — tax id, date, total — plus the line index.
    public let externalId: String?
    public let expense: ExpenseRequest

    public init(externalId: String? = nil, expense: ExpenseRequest) {
        self.externalId = externalId
        self.expense = expense
    }
}

/// Request body for `POST /v1/expenses/import/receipts/commit`.
public struct ReceiptImportCommitRequest: Codable, Sendable, Equatable {
    public let items: [ReceiptImportItem]

    public init(items: [ReceiptImportItem]) {
        self.items = items
    }
}

public struct ReceiptImportRowError: Codable, Sendable, Equatable {
    /// Index into the submitted `items`.
    public let index: Int
    public let message: String

    public init(index: Int, message: String) {
        self.index = index
        self.message = message
    }
}

/// Result of committing reviewed receipt expenses. Mirrors
/// `SpreadsheetImportCommitResponse` so the two import flows report the same way.
public struct ReceiptImportCommitResponse: Codable, Sendable, Equatable {
    public let imported: Int
    /// Rows recognised as already present, and therefore not inserted again.
    public let skipped: Int
    public let failed: Int
    /// "YYYY-MM" for every month touched, so the client can link straight to them.
    public let monthsTouched: [String]
    public let errors: [ReceiptImportRowError]

    public init(
        imported: Int,
        skipped: Int,
        failed: Int,
        monthsTouched: [String] = [],
        errors: [ReceiptImportRowError] = []
    ) {
        self.imported = imported
        self.skipped = skipped
        self.failed = failed
        self.monthsTouched = monthsTouched
        self.errors = errors
    }
}
