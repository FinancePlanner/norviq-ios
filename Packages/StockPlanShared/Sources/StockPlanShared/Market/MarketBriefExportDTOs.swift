import Foundation

/// One entry of `GET /v1/market/brief/exports`. `query` is the backend's
/// cache-busting query string (`rev=…&v=…`), used verbatim.
public struct MarketBriefExportFormatInfo: Codable, Sendable, Equatable {
    public let id: String
    public let width: Int?
    public let height: Int?
    public let pages: Int?
    public let mime: String
    public let query: String

    public init(
        id: String,
        width: Int? = nil,
        height: Int? = nil,
        pages: Int? = nil,
        mime: String,
        query: String
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.pages = pages
        self.mime = mime
        self.query = query
    }
}

/// `GET /v1/market/brief/exports`. Unknown top-level keys (`contentHash`) are
/// ignored; a malformed `formats` entry is skipped, not fatal.
public struct MarketBriefExportManifest: Codable, Sendable, Equatable {
    public let editionId: String
    public let revision: Int
    public let rendererVersion: Int
    public let formats: [MarketBriefExportFormatInfo]

    public init(
        editionId: String,
        revision: Int,
        rendererVersion: Int,
        formats: [MarketBriefExportFormatInfo]
    ) {
        self.editionId = editionId
        self.revision = revision
        self.rendererVersion = rendererVersion
        self.formats = formats
    }

    private enum CodingKeys: String, CodingKey {
        case editionId, revision, rendererVersion, formats
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        editionId = try container.decode(String.self, forKey: .editionId)
        revision = try container.decode(Int.self, forKey: .revision)
        rendererVersion = try container.decode(Int.self, forKey: .rendererVersion)
        formats = try container.decode([LossyItem].self, forKey: .formats).compactMap(\.item)
    }

    private struct LossyItem: Decodable {
        let item: MarketBriefExportFormatInfo?

        init(from decoder: Decoder) throws {
            item = try? MarketBriefExportFormatInfo(from: decoder)
        }
    }

    public func format(_ id: String) -> MarketBriefExportFormatInfo? {
        formats.first { $0.id == id }
    }
}
