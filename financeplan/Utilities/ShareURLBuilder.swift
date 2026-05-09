import Foundation

enum ShareURLBuilder {
  static func stock(symbol: String, baseURL: URL = Constants.Norviq.shareBaseUrl) -> URL {
    let normalized = sanitize(symbol)
    return baseURL.appendingPathComponent("share/stock/\(normalized)")
  }

  static func app(baseURL: URL = Constants.Norviq.shareBaseUrl) -> URL {
    baseURL.appendingPathComponent("share/app")
  }

  private static func sanitize(_ raw: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
    let prefix = raw.unicodeScalars.prefix { allowed.contains($0) }
    return String(String.UnicodeScalarView(prefix)).uppercased()
  }
}
