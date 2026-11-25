import Foundation
import Testing
@testable import StockPlanShared

struct MarketBriefExportDTOsTests {
    private func decode(_ json: String) throws -> MarketBriefExportManifest {
        try JSONDecoder().decode(MarketBriefExportManifest.self, from: Data(json.utf8))
    }

    @Test
    func `manifest decodes the backend shape`() throws {
        let manifest = try decode("""
        {"editionId":"MI-2026-11-25-O","revision":1,"contentHash":"313c8d532961e1ee","rendererVersion":1,"formats":[
        {"id":"og","width":1200,"height":630,"mime":"image/png","query":"rev=1&v=1"},
        {"id":"social","width":1080,"height":1350,"mime":"image/png","query":"rev=1&v=1"},
        {"id":"story","width":1080,"height":1920,"mime":"image/png","query":"rev=1&v=1"},
        {"id":"pdf","pages":3,"mime":"application/pdf","query":"rev=1&v=1"}]}
        """)
        #expect(manifest.editionId == "MI-2026-11-25-O")
        #expect(manifest.revision == 1)
        #expect(manifest.rendererVersion == 1)
        #expect(manifest.formats.map(\.id) == ["og", "social", "story", "pdf"])
        let social = try #require(manifest.format("social"))
        #expect(social.width == 1080)
        #expect(social.height == 1350)
        #expect(social.pages == nil)
        #expect(social.mime == "image/png")
        #expect(social.query == "rev=1&v=1")
        let pdf = try #require(manifest.format("pdf"))
        #expect(pdf.pages == 3)
        #expect(pdf.width == nil)
        #expect(pdf.height == nil)
        #expect(pdf.mime == "application/pdf")
    }

    @Test
    func `unknown and malformed formats are skipped not fatal`() throws {
        let manifest = try decode("""
        {"editionId":"MI-2026-11-25-O","revision":2,"rendererVersion":1,"extra":{"a":1},"formats":[
        {"id":"gif","width":10,"height":10,"mime":"image/gif","query":"rev=2&v=1"},
        {"id":"social","width":1080,"height":1350,"query":"rev=2&v=1"},
        {"id":"story","width":1080,"height":1920,"mime":"image/png","query":"rev=2&v=1"}]}
        """)
        #expect(manifest.formats.map(\.id) == ["gif", "story"])
    }

    @Test
    func `legacy manifest decodes`() throws {
        let manifest = try decode("""
        {"editionId":"MI-2026-11-10-C","revision":1,"rendererVersion":1,"formats":[]}
        """)
        #expect(manifest.editionId == "MI-2026-11-10-C")
        #expect(manifest.revision == 1)
        #expect(manifest.rendererVersion == 1)
        #expect(manifest.formats.isEmpty)
    }

    @Test
    func `format lookup by id`() throws {
        let manifest = try decode("""
        {"editionId":"MI-2026-11-25-O","revision":1,"rendererVersion":1,"formats":[
        {"id":"og","width":1200,"height":630,"mime":"image/png","query":"rev=1&v=1"},
        {"id":"pdf","pages":3,"mime":"application/pdf","query":"rev=1&v=1"}]}
        """)
        #expect(manifest.format("pdf")?.pages == 3)
        #expect(manifest.format("og") != nil)
        #expect(manifest.format("nope") == nil)
    }
}
