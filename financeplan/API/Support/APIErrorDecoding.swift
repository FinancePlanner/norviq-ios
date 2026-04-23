import Foundation
import StockPlanShared

enum APIErrorDecoding {
  static func message(from data: Data, decoder: JSONDecoder = .stockPlanShared) -> String? {
    if let standard = try? decoder.decode(StandardAPIErrorEnvelope.self, from: data),
       !standard.reason.isEmpty {
      return standard.reason
    }

    if let shared = try? decoder.decode(StockPlanShared.APIErrorResponse.self, from: data),
       !shared.error.isEmpty {
      return shared.error
    }

    if let wrapped = try? decoder.decode(APIEnvelope<StockPlanShared.APIErrorResponse>.self, from: data) {
      if let nested = wrapped.data?.error, !nested.isEmpty {
        return nested
      }
      if let message = wrapped.message, !message.isEmpty {
        return message
      }
    }

    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      return message(from: json)
    }

    let body = String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return body?.isEmpty == false ? body : nil
  }

  private static func message(from json: [String: Any]) -> String? {
    if let error = json["error"] as? String, !error.isEmpty {
      return error
    }
    if let reason = json["reason"] as? String, !reason.isEmpty {
      return reason
    }
    if let message = json["message"] as? String, !message.isEmpty {
      return message
    }
    if let detail = json["detail"] as? String, !detail.isEmpty {
      return detail
    }
    if let data = json["data"] as? [String: Any] {
      return message(from: data)
    }
    return nil
  }
}

private struct StandardAPIErrorEnvelope: Decodable {
  let error: Bool
  let code: String
  let reason: String
  let details: [String: String]?
  let requestId: String?
}
