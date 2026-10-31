import Foundation

// Contracts for the AI-assisted spreadsheet (.xlsx) expense import.
//
// The flow is analyze -> (preview)* -> commit, against a server-held session:
// the client never re-uploads the file to change its mind about a mapping.
//
// Two deliberate choices worth knowing before editing:
//
// 1. `SpreadsheetImportField` and `SpreadsheetImportRowStatus` decode unknown
//    strings to `.unknown` instead of throwing. Older shipped clients must keep
//    working when the backend learns a new column role or row status. Enums
//    elsewhere in this package (BudgetPillar, ExpenseReceiptSource) throw on
//    unrecognised values, which is exactly why they can't be extended safely.
//
// 2. Nothing here trusts the model. Every mapping carries a confidence and the
//    `source` that produced it, and the server re-derives all rows from the
//    stored grid, so a proposal is only ever a suggestion the user confirms.

// MARK: - Enums

/// What a spreadsheet column maps to on an expense.
public enum SpreadsheetImportField: String, Codable, Sendable, Equatable, CaseIterable {
    case title
    case amount
    case date
    case category
    case pillar
    case notes
    case currency
    case externalId
    case ignore
    /// A role this client build doesn't know. Treated as `ignore` for display.
    case unknown

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SpreadsheetImportField(rawValue: raw) ?? .unknown
    }
}

/// Where a mapping decision came from, so the UI can badge low-confidence guesses.
public enum SpreadsheetMappingSource: String, Codable, Sendable, Equatable {
    /// Deterministic detection: header aliases, column content shape.
    case heuristic
    /// Proposed by the model, then validated server-side.
    case ai
    /// Set explicitly by the person doing the import. Never overridden.
    case user
    case unknown

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SpreadsheetMappingSource(rawValue: raw) ?? .unknown
    }
}

/// How the amount column encodes an expense.
public enum SpreadsheetImportAmountSign: String, Codable, Sendable, Equatable {
    case positiveIsExpense
    case negativeIsExpense
    /// Bank exports that split outgoings and incomings across two columns.
    case separateDebitCredit
}

/// Per-row verdict. Only `.ok` rows are written on commit.
public enum SpreadsheetImportRowStatus: String, Codable, Sendable, Equatable {
    case ok
    /// Matches an earlier row in this same file.
    case duplicateInFile
    /// Matches an expense the user already has.
    case duplicateExisting
    case invalidDate
    case invalidAmount
    case missingTitle
    /// The source category maps to a pillar the user hasn't confirmed yet.
    case needsCategory
    /// Row is in a currency with no exchange rate supplied.
    case needsExchangeRate
    /// A totals/subtotal row. Excluded by default; the user can re-include it.
    case aggregateRow
    case skippedByUser
    case unknown

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SpreadsheetImportRowStatus(rawValue: raw) ?? .unknown
    }

    /// Whether this row would be written as-is.
    public var isImportable: Bool {
        self == .ok
    }
}

// MARK: - Structure

/// One detected column, with samples so the review screen can show its content.
public struct SpreadsheetImportColumn: Codable, Sendable, Equatable {
    /// Spreadsheet column letter, e.g. "G".
    public let letter: String
    /// Text found in the header row, when there was one.
    public let header: String?
    public let detectedType: String
    public let sampleValues: [String]
    public let field: SpreadsheetImportField
    public let confidence: Double
    public let source: SpreadsheetMappingSource

    public init(
        letter: String,
        header: String? = nil,
        detectedType: String,
        sampleValues: [String] = [],
        field: SpreadsheetImportField,
        confidence: Double,
        source: SpreadsheetMappingSource
    ) {
        self.letter = letter
        self.header = header
        self.detectedType = detectedType
        self.sampleValues = sampleValues
        self.field = field
        self.confidence = confidence
        self.source = source
    }
}

/// One worksheet and the region within it that looks like expense data.
public struct SpreadsheetImportSheet: Codable, Sendable, Equatable {
    public let name: String
    public let index: Int
    public let rowCount: Int
    /// 1-based row holding the headers. Frequently not row 1.
    public let headerRow: Int
    public let dataStartRow: Int
    public let dataEndRow: Int
    /// Whether this sheet is imported at all. Non-expense tabs default to false.
    public let include: Bool
    /// The best candidate, pre-selected in the UI.
    public let isRecommended: Bool
    public let columns: [SpreadsheetImportColumn]
    /// Rows excluded up front — totals, subtotals, blank separators.
    public let excludedRows: [Int]
    public let notes: [String]

    public init(
        name: String,
        index: Int,
        rowCount: Int,
        headerRow: Int,
        dataStartRow: Int,
        dataEndRow: Int,
        include: Bool,
        isRecommended: Bool = false,
        columns: [SpreadsheetImportColumn] = [],
        excludedRows: [Int] = [],
        notes: [String] = []
    ) {
        self.name = name
        self.index = index
        self.rowCount = rowCount
        self.headerRow = headerRow
        self.dataStartRow = dataStartRow
        self.dataEndRow = dataEndRow
        self.include = include
        self.isRecommended = isRecommended
        self.columns = columns
        self.excludedRows = excludedRows
        self.notes = notes
    }
}

/// Maps one distinct value from the source category column onto Norviq's model.
///
/// `pillar` is optional on purpose: the server refuses to invent a pillar it
/// can't match against the standard set or the user's existing custom pillars,
/// and leaves the decision to the user rather than minting a new one.
public struct SpreadsheetImportCategoryMapping: Codable, Sendable, Equatable {
    public let sourceValue: String
    public let pillar: BudgetPillar?
    public let categoryId: String?
    public let categoryName: String?
    /// Create `categoryName` as a new category on commit.
    public let createCategory: Bool
    public let confidence: Double
    public let source: SpreadsheetMappingSource

    public init(
        sourceValue: String,
        pillar: BudgetPillar? = nil,
        categoryId: String? = nil,
        categoryName: String? = nil,
        createCategory: Bool = false,
        confidence: Double,
        source: SpreadsheetMappingSource
    ) {
        self.sourceValue = sourceValue
        self.pillar = pillar
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.createCategory = createCategory
        self.confidence = confidence
        self.source = source
    }
}

// MARK: - Preview

public struct SpreadsheetImportPreviewRow: Codable, Sendable, Equatable {
    public let sheetName: String
    /// 1-based worksheet row, so it matches what the user sees in Excel.
    public let row: Int
    public let title: String?
    public let amount: Double?
    public let currency: String?
    public let occurredOn: String?
    public let pillar: BudgetPillar?
    public let categoryId: String?
    public let categoryName: String?
    public let sourceCategoryValue: String?
    public let status: SpreadsheetImportRowStatus
    public let message: String?

    public init(
        sheetName: String,
        row: Int,
        title: String? = nil,
        amount: Double? = nil,
        currency: String? = nil,
        occurredOn: String? = nil,
        pillar: BudgetPillar? = nil,
        categoryId: String? = nil,
        categoryName: String? = nil,
        sourceCategoryValue: String? = nil,
        status: SpreadsheetImportRowStatus,
        message: String? = nil
    ) {
        self.sheetName = sheetName
        self.row = row
        self.title = title
        self.amount = amount
        self.currency = currency
        self.occurredOn = occurredOn
        self.pillar = pillar
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.sourceCategoryValue = sourceCategoryValue
        self.status = status
        self.message = message
    }
}

/// Counts cover the whole import; `rows` is capped so a 1 000-row file doesn't
/// have to be shipped to the client in full.
public struct SpreadsheetImportPreview: Codable, Sendable, Equatable {
    public let totalRows: Int
    public let importableRows: Int
    public let duplicateRows: Int
    public let needsAttentionRows: Int
    public let excludedRows: Int
    public let detectedCurrencies: [String]
    public let dateRangeStart: String?
    public let dateRangeEnd: String?
    public let totalAmount: Double
    public let rows: [SpreadsheetImportPreviewRow]
    /// True when `rows` holds fewer entries than `totalRows`.
    public let truncated: Bool

    public init(
        totalRows: Int,
        importableRows: Int,
        duplicateRows: Int,
        needsAttentionRows: Int,
        excludedRows: Int,
        detectedCurrencies: [String] = [],
        dateRangeStart: String? = nil,
        dateRangeEnd: String? = nil,
        totalAmount: Double,
        rows: [SpreadsheetImportPreviewRow] = [],
        truncated: Bool = false
    ) {
        self.totalRows = totalRows
        self.importableRows = importableRows
        self.duplicateRows = duplicateRows
        self.needsAttentionRows = needsAttentionRows
        self.excludedRows = excludedRows
        self.detectedCurrencies = detectedCurrencies
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.totalAmount = totalAmount
        self.rows = rows
        self.truncated = truncated
    }
}

// MARK: - Requests

/// A single row the user edited by hand in the review screen.
public struct SpreadsheetImportRowOverride: Codable, Sendable, Equatable {
    public let sheetName: String
    public let row: Int
    public let include: Bool
    public let title: String?
    public let amount: Double?
    public let occurredOn: String?
    public let pillar: BudgetPillar?
    public let categoryId: String?

    public init(
        sheetName: String,
        row: Int,
        include: Bool = true,
        title: String? = nil,
        amount: Double? = nil,
        occurredOn: String? = nil,
        pillar: BudgetPillar? = nil,
        categoryId: String? = nil
    ) {
        self.sheetName = sheetName
        self.row = row
        self.include = include
        self.title = title
        self.amount = amount
        self.occurredOn = occurredOn
        self.pillar = pillar
        self.categoryId = categoryId
    }
}

/// Everything the user decided. Sent to both preview and commit — preview is
/// just commit without the writes, so the two can never diverge.
public struct SpreadsheetImportDecisionRequest: Codable, Sendable, Equatable {
    public let sheets: [SpreadsheetImportSheet]
    public let categoryMappings: [SpreadsheetImportCategoryMapping]
    public let rowOverrides: [SpreadsheetImportRowOverride]
    public let amountSign: SpreadsheetImportAmountSign
    /// Explicit rather than inferred: `03/04/2026` is ambiguous and getting it
    /// wrong silently files expenses in the wrong month.
    public let dateFormat: String?
    public let decimalSeparator: String?
    public let currency: String?
    /// Rate per source currency, applied to every row in that currency. Rows in
    /// an unrated foreign currency are skipped rather than guessed at.
    public let exchangeRates: [String: Double]

    public init(
        sheets: [SpreadsheetImportSheet],
        categoryMappings: [SpreadsheetImportCategoryMapping] = [],
        rowOverrides: [SpreadsheetImportRowOverride] = [],
        amountSign: SpreadsheetImportAmountSign = .positiveIsExpense,
        dateFormat: String? = nil,
        decimalSeparator: String? = nil,
        currency: String? = nil,
        exchangeRates: [String: Double] = [:]
    ) {
        self.sheets = sheets
        self.categoryMappings = categoryMappings
        self.rowOverrides = rowOverrides
        self.amountSign = amountSign
        self.dateFormat = dateFormat
        self.decimalSeparator = decimalSeparator
        self.currency = currency
        self.exchangeRates = exchangeRates
    }
}

// MARK: - Responses

public struct SpreadsheetImportAnalysisResponse: Codable, Sendable, Equatable {
    public let sessionId: String
    public let fileName: String
    /// ISO-8601. The session is deleted after this; the client should offer a
    /// re-upload rather than a retry once it passes.
    public let expiresAt: String
    public let sheets: [SpreadsheetImportSheet]
    public let categoryMappings: [SpreadsheetImportCategoryMapping]
    public let amountSign: SpreadsheetImportAmountSign
    public let detectedCurrency: String?
    public let baseCurrency: String?
    public let dateFormat: String?
    public let preview: SpreadsheetImportPreview
    /// False when the model was unavailable or disabled. The import still works
    /// from heuristics alone; the UI should say so rather than fail.
    public let aiAvailable: Bool
    public let aiConfidence: Double?
    /// Things the user should read before committing, e.g. formula cells with
    /// no saved result, or an ambiguous date format.
    public let warnings: [String]

    public init(
        sessionId: String,
        fileName: String,
        expiresAt: String,
        sheets: [SpreadsheetImportSheet],
        categoryMappings: [SpreadsheetImportCategoryMapping] = [],
        amountSign: SpreadsheetImportAmountSign = .positiveIsExpense,
        detectedCurrency: String? = nil,
        baseCurrency: String? = nil,
        dateFormat: String? = nil,
        preview: SpreadsheetImportPreview,
        aiAvailable: Bool,
        aiConfidence: Double? = nil,
        warnings: [String] = []
    ) {
        self.sessionId = sessionId
        self.fileName = fileName
        self.expiresAt = expiresAt
        self.sheets = sheets
        self.categoryMappings = categoryMappings
        self.amountSign = amountSign
        self.detectedCurrency = detectedCurrency
        self.baseCurrency = baseCurrency
        self.dateFormat = dateFormat
        self.preview = preview
        self.aiAvailable = aiAvailable
        self.aiConfidence = aiConfidence
        self.warnings = warnings
    }
}

public struct SpreadsheetImportPreviewResponse: Codable, Sendable, Equatable {
    public let sessionId: String
    /// The server's normalised echo of the decisions it actually applied, which
    /// may differ from what was sent if something failed validation.
    public let sheets: [SpreadsheetImportSheet]
    public let categoryMappings: [SpreadsheetImportCategoryMapping]
    public let preview: SpreadsheetImportPreview
    public let warnings: [String]

    public init(
        sessionId: String,
        sheets: [SpreadsheetImportSheet],
        categoryMappings: [SpreadsheetImportCategoryMapping] = [],
        preview: SpreadsheetImportPreview,
        warnings: [String] = []
    ) {
        self.sessionId = sessionId
        self.sheets = sheets
        self.categoryMappings = categoryMappings
        self.preview = preview
        self.warnings = warnings
    }
}

public struct SpreadsheetImportRowResult: Codable, Sendable, Equatable {
    public let sheetName: String
    public let row: Int
    public let status: SpreadsheetImportRowStatus
    public let message: String?
    public let expenseId: String?

    public init(
        sheetName: String,
        row: Int,
        status: SpreadsheetImportRowStatus,
        message: String? = nil,
        expenseId: String? = nil
    ) {
        self.sheetName = sheetName
        self.row = row
        self.status = status
        self.message = message
        self.expenseId = expenseId
    }
}

public struct SpreadsheetImportCommitResponse: Codable, Sendable, Equatable {
    public let sessionId: String
    public let imported: Int
    public let skipped: Int
    public let failed: Int
    public let createdCategories: [String]
    /// "YYYY-MM" for every month touched, so the client can link straight to them.
    public let monthsTouched: [String]
    public let rows: [SpreadsheetImportRowResult]

    public init(
        sessionId: String,
        imported: Int,
        skipped: Int,
        failed: Int,
        createdCategories: [String] = [],
        monthsTouched: [String] = [],
        rows: [SpreadsheetImportRowResult] = []
    ) {
        self.sessionId = sessionId
        self.imported = imported
        self.skipped = skipped
        self.failed = failed
        self.createdCategories = createdCategories
        self.monthsTouched = monthsTouched
        self.rows = rows
    }
}
