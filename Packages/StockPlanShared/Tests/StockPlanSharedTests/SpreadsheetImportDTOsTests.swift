import Foundation
import Testing
@testable import StockPlanShared

@Suite("Spreadsheet import contracts")
struct SpreadsheetImportDTOsTests {
    @Test("analysis response round trips")
    func analysisRoundTrip() throws {
        let response = SpreadsheetImportAnalysisResponse(
            sessionId: UUID().uuidString,
            fileName: "Orçamento 2026.xlsx",
            expiresAt: "2026-07-31T10:00:00Z",
            sheets: [
                .init(
                    name: "Gastos 2026",
                    index: 0,
                    rowCount: 12,
                    headerRow: 5,
                    dataStartRow: 6,
                    dataEndRow: 13,
                    include: true,
                    isRecommended: true,
                    columns: [
                        .init(
                            letter: "G",
                            header: "Data",
                            detectedType: "date",
                            sampleValues: ["2026-01-03"],
                            field: .date,
                            confidence: 0.98,
                            source: .heuristic
                        ),
                        .init(
                            letter: "J",
                            header: "Valor",
                            detectedType: "number",
                            sampleValues: ["84.20"],
                            field: .amount,
                            confidence: 0.91,
                            source: .ai
                        ),
                    ],
                    excludedRows: [14],
                    notes: ["Row 14 looks like a totals row."]
                ),
            ],
            categoryMappings: [
                .init(
                    sourceValue: "Lazer",
                    pillar: .fun,
                    categoryName: "Leisure",
                    createCategory: true,
                    confidence: 0.8,
                    source: .ai
                ),
            ],
            detectedCurrency: "EUR",
            baseCurrency: "EUR",
            dateFormat: "dd/MM/yyyy",
            preview: .init(
                totalRows: 8, importableRows: 7, duplicateRows: 1, needsAttentionRows: 0, excludedRows: 1,
                detectedCurrencies: ["EUR"], dateRangeStart: "2026-01-03", dateRangeEnd: "2026-03-22",
                totalAmount: 1830.51,
                rows: [
                    .init(
                        sheetName: "Gastos 2026",
                        row: 6,
                        title: "Continente",
                        amount: 84.20,
                        currency: "EUR",
                        occurredOn: "2026-01-03",
                        pillar: .fundamentals,
                        sourceCategoryValue: "Supermercado",
                        status: .ok
                    ),
                ],
                truncated: true
            ),
            aiAvailable: true,
            aiConfidence: 0.87,
            warnings: ["Some formula cells had no saved result."]
        )

        let data = try JSONEncoder().encode(response)
        #expect(try JSONDecoder().decode(SpreadsheetImportAnalysisResponse.self, from: data) == response)
    }

    @Test("decision request round trips, including its dictionaries")
    func decisionRoundTrip() throws {
        let request = SpreadsheetImportDecisionRequest(
            sheets: [
                .init(
                    name: "Despesas",
                    index: 0,
                    rowCount: 7,
                    headerRow: 4,
                    dataStartRow: 5,
                    dataEndRow: 9,
                    include: true
                ),
            ],
            categoryMappings: [
                .init(
                    sourceValue: "Casa",
                    pillar: .fundamentals,
                    categoryId: UUID().uuidString,
                    confidence: 1,
                    source: .user
                ),
            ],
            rowOverrides: [
                .init(sheetName: "Despesas", row: 7, include: false),
                .init(
                    sheetName: "Despesas",
                    row: 8,
                    include: true,
                    title: "Rent",
                    amount: 750,
                    occurredOn: "2026-03-01",
                    pillar: .fundamentals
                ),
            ],
            amountSign: .separateDebitCredit,
            dateFormat: "dd/MM/yyyy",
            decimalSeparator: ",",
            currency: "GBP",
            exchangeRates: ["GBP": 1.17, "USD": 0.92]
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SpreadsheetImportDecisionRequest.self, from: data)
        #expect(decoded == request)
        #expect(decoded.exchangeRates["GBP"] == 1.17)
    }

    @Test("commit response round trips")
    func commitRoundTrip() throws {
        let response = SpreadsheetImportCommitResponse(
            sessionId: UUID().uuidString,
            imported: 7,
            skipped: 1,
            failed: 0,
            createdCategories: ["Leisure"],
            monthsTouched: ["2026-01", "2026-02", "2026-03"],
            rows: [
                .init(sheetName: "Gastos 2026", row: 6, status: .ok, expenseId: UUID().uuidString),
                .init(sheetName: "Gastos 2026", row: 7, status: .duplicateExisting),
            ]
        )

        let data = try JSONEncoder().encode(response)
        #expect(try JSONDecoder().decode(SpreadsheetImportCommitResponse.self, from: data) == response)
    }

    /// A backend that learns a new column role or row status must not break
    /// clients already in the App Store. These decode to .unknown rather than
    /// throwing -- unlike BudgetPillar and ExpenseReceiptSource, which is
    /// precisely why those two can't be extended safely.
    @Test("unknown enum values decode instead of throwing")
    func unknownEnumValuesDecode() throws {
        let column = try JSONDecoder().decode(
            SpreadsheetImportColumn.self,
            from: Data(
                #"{"letter":"A","detectedType":"text","sampleValues":[],"field":"someFutureRole","confidence":0.5,"source":"someFutureSource"}"#
                    .utf8
            )
        )
        #expect(column.field == .unknown)
        #expect(column.source == .unknown)

        let row = try JSONDecoder().decode(
            SpreadsheetImportPreviewRow.self,
            from: Data(#"{"sheetName":"S","row":2,"status":"someFutureStatus"}"#.utf8)
        )
        #expect(row.status == .unknown)
        #expect(row.status.isImportable == false)
    }

    @Test("only ok rows count as importable")
    func importableStatuses() {
        let importable = SpreadsheetImportRowStatus.allStatuses.filter(\.isImportable)
        #expect(importable == [.ok])
    }
}

private extension SpreadsheetImportRowStatus {
    static let allStatuses: [SpreadsheetImportRowStatus] = [
        .ok, .duplicateInFile, .duplicateExisting, .invalidDate, .invalidAmount,
        .missingTitle, .needsCategory, .needsExchangeRate, .aggregateRow,
        .skippedByUser, .unknown,
    ]
}
