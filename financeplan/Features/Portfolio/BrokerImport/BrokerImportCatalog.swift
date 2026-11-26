import Foundation

/// How a broker's holdings can be brought in. Mirrors the web
/// `ImportMethod` in `norviq-web-v2/src/lib/features/portfolio/import/brokers.ts`.
nonisolated enum ImportMethod: Equatable, Sendable {
  case screenshot
  case askQ
  case csv

  var label: String {
    switch self {
    case .screenshot: "Screenshots"
    case .askQ: "Ask Q"
    case .csv: "CSV file"
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

  static let askQGuide =
    "Attach your screenshots to Q and ask it to update your holdings. You review every row before anything is saved."

  /// The provider every CSV import from the picker uses, so a CSV is never
  /// labelled `ibkr` (disconnecting IBKR deletes those holdings).
  static let csvProvider = "generic"

  static func screenshotGuide(for broker: BrokerGuide) -> String {
    let who = broker.id == "other" ? "your broker's" : "the \(broker.name)"
    return "Open your positions list in \(who) app or website and take screenshots that show every holding. You can import up to 3 at a time."
  }

  static func csvReplaceNote(symbol: String) -> String {
    "Replaces your existing \(symbol)"
  }
}
