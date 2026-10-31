import Foundation
import Testing
@testable import StockPlanShared

@Suite("Fiscal Receipt QR Parser")
struct FiscalReceiptQRParserTests {
    private let parser = FiscalReceiptQRParser()

    /// A representative Portuguese AT simplified-invoice payload.
    private let sampleAT =
        "A:509442013*B:123456789*C:PT*D:FS*E:N*F:20260712*G:FS 01P2026/1234"
            + "*H:CSDF7T5H-1234*I1:PT*I7:12.20*I8:2.80*N:2.80*O:15.00*Q:kZ5X*R:9999"

    @Test("Parses total, date, tax id, and VAT from an AT payload")
    func parsesAT() throws {
        let draft = try #require(parser.parse(sampleAT))
        #expect(draft.source == .qr)
        #expect(draft.confidence == 1.0)
        #expect(draft.total == 15.00)
        #expect(draft.taxTotal == 2.80)
        #expect(draft.currency == "EUR")
        #expect(draft.date == "2026-07-12")
        #expect(draft.taxId == "509442013")
        #expect(draft.merchant == nil)
        #expect(draft.vatLines.contains { $0.rate == "standard" && $0.amount == 2.80 })
    }

    @Test("Returns nil for a non-fiscal QR string")
    func ignoresUnknownPayload() {
        #expect(parser.parse("https://example.com/pay/123") == nil)
        #expect(parser.parse("") == nil)
    }

    @Test("Returns nil for AT prefix without usable total or date")
    func rejectsEmptyAT() {
        #expect(parser.parse("A:509442013*B:999999990*C:PT") == nil)
    }

    @Test("Malformed date field is dropped, total still parses")
    func toleratesBadDate() throws {
        let payload = "A:509442013*F:2026-07-12*O:9.99"
        let draft = try #require(parser.parse(payload))
        #expect(draft.total == 9.99)
        #expect(draft.date == nil)
    }
}
