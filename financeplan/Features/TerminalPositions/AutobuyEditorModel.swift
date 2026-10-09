import Foundation
import Observation
import StockPlanShared

extension AutobuyCadence {
  var title: String {
    switch self {
    case .weekly: String(localized: "Weekly")
    case .biweekly: String(localized: "Every two weeks")
    case .bimonthly: String(localized: "Every two months")
    case .monthly: String(localized: "Monthly")
    case .percentOfContribution: String(localized: "Percent of a monthly base")
    case .unknown: String(localized: "Other")
    }
  }
}

@MainActor @Observable
final class AutobuyEditorModel {
  struct Inputs: Equatable {
    var label: String
    var ticker: String
    /// For percent cadence this is the monthly base the percent applies to.
    var amount: TerminalNumberInput
    var cadence: AutobuyCadence
    /// Typed as 0–100; sent as 0–1.
    var percent: TerminalNumberInput
    var active: Bool
  }

  /// `.unknown` is a decoding fallback, never a choice.
  static let cadences: [AutobuyCadence] = [.weekly, .biweekly, .bimonthly, .monthly, .percentOfContribution]

  private static let noChanges = AutobuyUpdateRequest(
    ticker: nil, label: nil, amount: nil, cadence: nil, percent: nil, active: nil, clear: nil
  )

  let original: AutobuyResponse?
  let currency: String
  var inputs: Inputs
  var isSaving = false
  var errorMessage: String?

  private let initialInputs: Inputs
  private let service: any TerminalPositionsServicing
  private let locale: Locale

  init(
    autobuy: AutobuyResponse? = nil,
    currency: String,
    service: any TerminalPositionsServicing,
    locale: Locale = .current
  ) {
    original = autobuy
    self.currency = currency
    self.service = service
    self.locale = locale
    let inputs = Inputs(
      label: autobuy?.label ?? "",
      ticker: autobuy?.ticker ?? "",
      amount: TerminalNumberInput(value: autobuy?.amount, usesUnits: false, locale: locale),
      cadence: autobuy?.cadence ?? .monthly,
      percent: TerminalNumberInput(value: autobuy?.percent.map { $0 * 100 }, usesUnits: false, locale: locale),
      active: autobuy?.active ?? true
    )
    self.inputs = inputs
    initialInputs = inputs
  }

  var isEditing: Bool { original != nil }

  var isPercentCadence: Bool { inputs.cadence == .percentOfContribution }

  var percentFraction: Double? {
    guard let percent = inputs.percent.value(locale: locale), percent <= 100 else { return nil }
    return percent / 100
  }

  var monthlyEquivalent: Double? {
    guard let amount = inputs.amount.value(locale: locale) else { return nil }
    return AutobuyMath.monthlyEquivalent(
      amount: amount,
      cadence: inputs.cadence,
      percent: isPercentCadence ? percentFraction : nil
    )
  }

  private var trimmedLabel: String { inputs.label.trimmingCharacters(in: .whitespacesAndNewlines) }

  private var normalizedTicker: String? {
    let ticker = inputs.ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    return ticker.isEmpty ? nil : ticker
  }

  var tickerProblem: String? {
    guard let ticker = normalizedTicker else { return nil }
    return ticker.range(of: #"^[A-Z0-9.\-]{1,12}$"#, options: .regularExpression) == nil
      ? String(localized: "Use 1–12 letters, digits, dots or dashes.")
      : nil
  }

  var amountProblem: String? {
    switch inputs.amount.reading(locale: locale) {
    case .empty, .value: nil
    case .invalid: String(localized: "Enter a number.")
    case .negative: String(localized: "Can't be negative.")
    }
  }

  var percentProblem: String? {
    guard isPercentCadence else { return nil }
    switch inputs.percent.reading(locale: locale) {
    case .empty: return nil
    case .invalid, .negative: return String(localized: "Enter a percent between 0 and 100.")
    case let .value(percent): return percent <= 100 ? nil : String(localized: "Enter a percent between 0 and 100.")
    }
  }

  var canSave: Bool {
    !isSaving
      && !trimmedLabel.isEmpty
      && tickerProblem == nil
      && inputs.amount.value(locale: locale) != nil
      && (!isPercentCadence || percentFraction != nil)
  }

  func makeCreateRequest() -> AutobuyCreateRequest? {
    guard canSave, let amount = inputs.amount.value(locale: locale) else { return nil }
    return AutobuyCreateRequest(
      ticker: normalizedTicker,
      label: trimmedLabel,
      amount: amount,
      cadence: inputs.cadence,
      percent: isPercentCadence ? percentFraction : nil,
      active: inputs.active
    )
  }

  /// Only the fields the user touched. A cleared ticker goes in `clear`, and so
  /// does a percent left behind when the cadence moves away from percent.
  func makeUpdateRequest() -> AutobuyUpdateRequest? {
    guard let original, canSave, let amount = inputs.amount.value(locale: locale) else { return nil }
    let start = initialInputs
    var clear: [String] = []

    var ticker: String?
    if inputs.ticker != start.ticker {
      if let newTicker = normalizedTicker { ticker = newTicker } else { clear.append("ticker") }
    }

    var percent: Double?
    if isPercentCadence {
      if inputs.percent != start.percent || inputs.cadence != start.cadence { percent = percentFraction }
    } else if original.percent != nil {
      clear.append("percent")
    }

    return AutobuyUpdateRequest(
      ticker: ticker,
      label: trimmedLabel == original.label ? nil : trimmedLabel,
      amount: inputs.amount == start.amount ? nil : amount,
      cadence: inputs.cadence == start.cadence ? nil : inputs.cadence,
      percent: percent,
      active: inputs.active == start.active ? nil : inputs.active,
      clear: clear.isEmpty ? nil : clear
    )
  }

  func save() async -> AutobuyResponse? {
    guard canSave else { return nil }
    // Built before `isSaving` is set: `canSave` is false while saving, so
    // building the request afterwards would silently return nil.
    let createRequest = original == nil ? makeCreateRequest() : nil
    let updateRequest = original == nil ? nil : makeUpdateRequest()
    isSaving = true
    defer { isSaving = false }
    do {
      if let original {
        guard let request = updateRequest else { return nil }
        if request == Self.noChanges { return original }
        return try await service.updateAutobuy(id: original.id, request)
      }
      guard let request = createRequest else { return nil }
      return try await service.createAutobuy(request)
    } catch {
      errorMessage = TerminalPositionsErrorText.message(
        for: error,
        fallback: String(localized: "The autobuy could not be saved."),
        notFound: String(localized: "This autobuy was deleted on another device.")
      )
      return nil
    }
  }
}
