import Foundation

/// How a broker's holdings can be brought in. Mirrors the web
/// `ImportMethod` in `norviq-web-v2/src/lib/features/portfolio/import/brokers.ts`.
nonisolated enum ImportMethod: String, Equatable, Identifiable, Sendable {
  case screenshot
  case askQ = "ask-q"
  case csv

  /// Stable, language-independent id (the web's method ids).
  var id: String { rawValue }

  /// Localized label; English is identical to the web's.
  var label: String {
    switch self {
    case .screenshot: String(localized: "Screenshots")
    case .askQ: String(localized: "Ask Q")
    case .csv: String(localized: "CSV file")
    }
  }

  var systemImage: String {
    switch self {
    case .screenshot: "photo.on.rectangle.angled"
    case .askQ: "sparkle"
    case .csv: "square.and.arrow.down.on.square"
    }
  }
}

nonisolated struct BrokerGuide: Equatable, Identifiable, Sendable {
  let id: String
  let name: String
  let methods: [ImportMethod]
}

/// The broker catalogue and its copy. Same ids, names, order, methods and
/// wording as the shipped web app: change them there and here together.
nonisolated enum BrokerImportCatalog {
  static let brokers: [BrokerGuide] = [
    BrokerGuide(id: "ibkr", name: "IBKR", methods: [.screenshot, .askQ]),
    BrokerGuide(id: "degiro", name: "DEGIRO", methods: [.screenshot, .askQ]),
    BrokerGuide(id: "trading212", name: "Trading 212", methods: [.screenshot, .askQ]),
    BrokerGuide(id: "revolut", name: "Revolut", methods: [.screenshot, .askQ]),
    BrokerGuide(id: "other", name: "Other broker (CSV)", methods: [.csv, .screenshot, .askQ]),
  ]

  static var askQGuide: String {
    String(
      localized:
        "Attach your screenshots to Q and ask it to update your holdings. You review every row before anything is saved."
    )
  }

  /// The provider every CSV import from the picker uses, so a CSV is never
  /// labelled `ibkr` (disconnecting IBKR deletes those holdings).
  static let csvProvider = "generic"

  static func screenshotGuide(for broker: BrokerGuide) -> String {
    if broker.id == "other" {
      return String(
        localized:
          "Open your positions list in your broker's app or website and take screenshots that show every holding. You can import up to 3 at a time."
      )
    }
    return String(
      localized:
        "Open your positions list in the \(broker.name) app or website and take screenshots that show every holding. You can import up to 3 at a time."
    )
  }

  static func csvReplaceNote(symbol: String) -> String {
    String(localized: "Replaces your existing \(symbol)")
  }
}
