import Foundation
import StockPlanShared

/// The latest brief per language, so the card paints instantly on launch and
/// across a language switch.
@MainActor
protocol MarketBriefCaching: AnyObject {
  func latest(language: String) -> MarketBriefResponse?
  func store(_ brief: MarketBriefResponse, language: String)
  func remove(language: String)
}

/// Memory first, then one small JSON file per language in Caches. A JSON file
/// rather than a SwiftData model like the news ticker's: a brief is a single
/// document read whole, and a new model would mean a schema change for it.
/// The brief is the same for every user, so the cache is not per user either.
@MainActor
final class MarketBriefCache: MarketBriefCaching {
  private var memory: [String: MarketBriefResponse] = [:]
  /// Nil keeps the cache in memory only (tests, previews).
  private let directory: URL?

  init(directory: URL? = MarketBriefCache.defaultDirectory) {
    self.directory = directory
  }

  static var defaultDirectory: URL? {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("MarketBrief", isDirectory: true)
  }

  func latest(language: String) -> MarketBriefResponse? {
    if let cached = memory[language] { return cached }
    guard let url = fileURL(for: language),
          let data = try? Data(contentsOf: url),
          let brief = try? JSONDecoder().decode(MarketBriefResponse.self, from: data)
    else { return nil }
    memory[language] = brief
    return brief
  }

  func store(_ brief: MarketBriefResponse, language: String) {
    memory[language] = brief
    guard let directory, let url = fileURL(for: language) else { return }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try JSONEncoder().encode(brief).write(to: url, options: .atomic)
    } catch {
      // Best effort: the card still works from memory and the network.
    }
  }

  func remove(language: String) {
    memory[language] = nil
    guard let url = fileURL(for: language) else { return }
    try? FileManager.default.removeItem(at: url)
  }

  private func fileURL(for language: String) -> URL? {
    // `language` is one of `AppLanguage`'s raw values; keep the file name to
    // safe characters regardless.
    let safe = language.filter { $0.isLetter || $0.isNumber || $0 == "-" }
    guard let directory, !safe.isEmpty else { return nil }
    return directory.appendingPathComponent("latest-\(safe).json")
  }
}
