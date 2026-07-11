import Foundation
import StockPlanShared

/// Decodes a single element without failing its container: a malformed element
/// becomes `nil` instead of throwing, so one bad row can't blank an entire list.
struct FailableDecodable<Wrapped: Decodable>: Decodable {
  let value: Wrapped?

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    value = try? container.decode(Wrapped.self)
  }
}

/// Lenient list-item shape for `GET /v1/stocks`. `createdAt` is optional here
/// (it is unused on-device — pagination uses the `X-Next-Cursor` header), so a
/// backend that omits it degrades to a nil timestamp instead of throwing and
/// failing the whole holdings-list decode.
struct StockListItemDTO: Codable, Sendable {
  let id: String
  let symbol: String
  let shares: Double
  let buyPrice: Double
  let buyDate: String
  let notes: String?
  let category: AssetCategory
  let portfolioListId: String?
  let createdAt: String?

  func asStockResponse() -> StockResponse {
    StockResponse(
      id: id,
      symbol: symbol,
      shares: shares,
      buyPrice: buyPrice,
      buyDate: buyDate,
      notes: notes,
      category: category,
      portfolioListId: portfolioListId,
      createdAt: createdAt ?? ""
    )
  }
}

/// Response wrapper for `GET /v1/stocks` that survives partial corruption:
/// each element is decoded independently and unparseable rows are dropped
/// rather than failing the entire portfolio list.
struct LenientStockList: Codable, Sendable {
  let items: [StockListItemDTO]
  /// Rows that failed to decode and were skipped (for logging/telemetry).
  let droppedCount: Int

  init(from decoder: Decoder) throws {
    let wrapped = try [FailableDecodable<StockListItemDTO>](from: decoder)
    items = wrapped.compactMap(\.value)
    droppedCount = wrapped.count - items.count
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    for item in items {
      try container.encode(item)
    }
  }
}
