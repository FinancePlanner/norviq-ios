import Foundation
import Testing
@testable import StockPlanShared

@Suite("Receipt line items")
struct ReceiptLineItemTests {
    private let decoder = JSONDecoder()

    @Test("A draft from an older backend, with neither collection key, still decodes")
    func decodesWithoutCollections() throws {
        let json = #"{"confidence":0.8,"source":"ocr","total":15.0}"#
        let draft = try decoder.decode(ReceiptDraft.self, from: Data(json.utf8))
        #expect(draft.lineItems.isEmpty)
        #expect(draft.vatLines.isEmpty)
        #expect(draft.total == 15.0)
    }

    @Test("Line items decode and round-trip")
    func roundTrips() throws {
        let draft = ReceiptDraft(
            total: 5.50,
            lineItems: [
                ReceiptLineItem(description: "Bread", amount: 2.10),
                ReceiptLineItem(description: "Milk", amount: 3.40, quantity: 2),
            ],
            confidence: 0.7,
            source: .ocr
        )
        let decoded = try decoder.decode(ReceiptDraft.self, from: JSONEncoder().encode(draft))
        #expect(decoded == draft)
        #expect(decoded.lineItems[1].quantity == 2)
    }

    @Test("Items that add up to the total reconcile")
    func reconcilesWhenSumMatches() {
        let draft = ReceiptDraft(
            total: 5.50,
            lineItems: [
                ReceiptLineItem(description: "Bread", amount: 2.10),
                ReceiptLineItem(description: "Milk", amount: 3.40),
            ],
            confidence: 0.7,
            source: .ocr
        )
        #expect(draft.lineItemsSum == 5.50)
        #expect(draft.lineItemsReconcile == true)
    }

    @Test("A misread figure fails reconciliation rather than being trusted")
    func failsReconciliationWhenSumDiverges() {
        let draft = ReceiptDraft(
            total: 5.50,
            lineItems: [ReceiptLineItem(description: "Bread", amount: 2.10)],
            confidence: 0.7,
            source: .ocr
        )
        #expect(draft.lineItemsReconcile == false)
    }

    @Test("Nothing to compare yields no verdict")
    func noVerdictWithoutBothSides() {
        let noItems = ReceiptDraft(total: 5.50, confidence: 1.0, source: .qr)
        #expect(noItems.lineItemsSum == nil)
        #expect(noItems.lineItemsReconcile == nil)

        let noTotal = ReceiptDraft(
            lineItems: [ReceiptLineItem(description: "Bread", amount: 2.10)],
            confidence: 0.7,
            source: .ocr
        )
        #expect(noTotal.lineItemsReconcile == nil)
    }
}

@Suite("Screenshot portfolio import DTOs")
struct ScreenshotImportDTOsTests {
    private let decoder = JSONDecoder()

    @Test("An unrecognised kind degrades to .unknown instead of failing the response")
    func unknownKindDegrades() throws {
        let json = #"""
        {"provider":"manual","kind":"futures_ladder","items":[],"errors":[],"imageCount":1}
        """#
        let response = try decoder.decode(ScreenshotImportPreviewResponse.self, from: Data(json.utf8))
        #expect(response.kind == .unknown)
    }

    @Test("A review UI can post back a row carrying only the user-editable fields")
    func commitAcceptsMinimalEditedRow() throws {
        let json = #"""
        {"provider":"manual","items":[{"line":0,"symbol":"AAPL","shares":10,"buyPrice":150.5}]}
        """#
        let request = try decoder.decode(ScreenshotImportCommitRequest.self, from: Data(json.utf8))
        let row = try #require(request.items.first)
        #expect(row.symbol == "AAPL")
        #expect(row.shares == 10)
        #expect(row.existingPositionKind == .none)
        #expect(row.willReplaceExistingImport == false)
        #expect(row.confidence == nil)
    }

    @Test("Confidence survives the preview round-trip")
    func confidenceRoundTrips() throws {
        let item = CsvImportPreviewItem(line: 0, symbol: "MSFT", shares: 3, confidence: 0.42)
        let decoded = try decoder.decode(CsvImportPreviewItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.confidence == 0.42)
    }

    @Test("A CSV-sourced row reports no confidence, because it was read not inferred")
    func csvRowsHaveNoConfidence() {
        #expect(CsvImportPreviewItem(line: 1, symbol: "VOO").confidence == nil)
    }
}
