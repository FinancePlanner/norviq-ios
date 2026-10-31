import Foundation

/// One quadro / schedule of a national filing form, rows pre-formatted the
/// way the form wants them (dates split into year/month, money as "0.00").
public struct FilingPackSectionDTO: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let columns: [String]
    public let rows: [[String]]
    public let totals: [String: Decimal]
    public let notes: [String]

    public init(
        id: String,
        title: String,
        columns: [String],
        rows: [[String]],
        totals: [String: Decimal],
        notes: [String]
    ) {
        self.id = id
        self.title = title
        self.columns = columns
        self.rows = rows
        self.totals = totals
        self.notes = notes
    }
}

/// `GET /v1/tax/filing/preview?taxYear=` — the same numbers the annual filing
/// pack report will contain, so clients can show them before generating.
public struct FilingPackPreviewResponse: Codable, Sendable, Equatable {
    public let jurisdiction: TaxJurisdiction
    public let taxYear: Int
    public let reportingCurrency: String
    public let formName: String
    public let rulePackVersion: String
    public let sections: [FilingPackSectionDTO]
    public let summary: [String: Decimal]
    public let disclaimer: String
    public let disposalCount: Int
    public let dividendCount: Int
    public let unsupportedCount: Int

    public init(
        jurisdiction: TaxJurisdiction,
        taxYear: Int,
        reportingCurrency: String,
        formName: String,
        rulePackVersion: String,
        sections: [FilingPackSectionDTO],
        summary: [String: Decimal],
        disclaimer: String,
        disposalCount: Int,
        dividendCount: Int,
        unsupportedCount: Int
    ) {
        self.jurisdiction = jurisdiction
        self.taxYear = taxYear
        self.reportingCurrency = reportingCurrency
        self.formName = formName
        self.rulePackVersion = rulePackVersion
        self.sections = sections
        self.summary = summary
        self.disclaimer = disclaimer
        self.disposalCount = disposalCount
        self.dividendCount = dividendCount
        self.unsupportedCount = unsupportedCount
    }
}
