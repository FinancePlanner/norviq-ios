import Foundation

/// What a broker screenshot turned out to be.
///
/// The extractor classifies before it extracts, because the two layouts mean
/// different things: a holdings list states what you own now, while a trade
/// list states what you bought and when. Getting this wrong would silently
/// import a position's *current* value as its cost basis.
public enum ScreenshotImportKind: String, Codable, Sendable, CaseIterable {
    /// A positions/holdings list: symbol and quantity, rarely a real cost basis.
    case holdings
    /// Trade confirmations or order history: per-lot price and execution date.
    case trades
    /// Not a portfolio screenshot, or too illegible to classify. Carries no rows.
    case unknown

    /// Decodes an unrecognised value as `.unknown` rather than failing, so a
    /// newer backend can add a kind without breaking older clients.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ScreenshotImportKind(rawValue: raw) ?? .unknown
    }
}

/// Response for `POST /v1/brokers/import/screenshot`.
///
/// Deliberately shaped as `CsvImportPreviewResponse` plus a `kind`: screenshot
/// rows flow through exactly the same review → commit path as CSV rows, so the
/// clients reuse one review UI and the server reuses one import service.
public struct ScreenshotImportPreviewResponse: Codable, Sendable, Equatable {
    public let provider: String
    public let kind: ScreenshotImportKind
    /// Rows across every uploaded image, with `line` re-indexed over the whole
    /// batch so per-line errors stay unambiguous.
    public let items: [CsvImportPreviewItem]
    public let errors: [CsvImportPreviewError]
    /// How many images were processed, for usage display and cost attribution.
    public let imageCount: Int

    public init(
        provider: String,
        kind: ScreenshotImportKind,
        items: [CsvImportPreviewItem],
        errors: [CsvImportPreviewError],
        imageCount: Int
    ) {
        self.provider = provider
        self.kind = kind
        self.items = items
        self.errors = errors
        self.imageCount = imageCount
    }
}

/// Request body for `POST /v1/brokers/import/screenshot/commit`.
///
/// Carries the rows the user actually approved, not a session id. Nothing about
/// the extraction is expensive to redo and no image is held server-side, so the
/// edited rows *are* the state — the server re-validates them from scratch.
public struct ScreenshotImportCommitRequest: Codable, Sendable, Equatable {
    public let provider: String
    public let portfolioListId: String?
    public let items: [CsvImportPreviewItem]
    /// Permission to absorb holdings the import did not create.
    ///
    /// An import only ever replaces rows it owns, so a symbol the user added by
    /// hand would otherwise end up beside the imported one — two AMDs in one
    /// list. The preview already reports those collisions as
    /// `existingPositionKind`, so the client can ask before setting this.
    /// Absent or false, a commit that would collide is refused rather than
    /// silently overwriting a position the user typed in themselves.
    public let confirmMergeExisting: Bool

    public init(
        provider: String,
        portfolioListId: String? = nil,
        items: [CsvImportPreviewItem],
        confirmMergeExisting: Bool = false
    ) {
        self.provider = provider
        self.portfolioListId = portfolioListId
        self.items = items
        self.confirmMergeExisting = confirmMergeExisting
    }

    /// Older clients do not send the flag; absent means "not confirmed".
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(String.self, forKey: .provider)
        portfolioListId = try container.decodeIfPresent(String.self, forKey: .portfolioListId)
        items = try container.decode([CsvImportPreviewItem].self, forKey: .items)
        confirmMergeExisting = try container.decodeIfPresent(Bool.self, forKey: .confirmMergeExisting) ?? false
    }
}
