import Factory
import Observation
import StockPlanShared
import SwiftUI

@MainActor
@Observable
private final class FinancingPlannerViewModel {
  var title = ""
  var purchaseAmount = ""
  var downPayment = ""
  var termMonths = 84
  var monthlyPayment = ""
  var nominalRate = ""
  var effectiveRate = ""
  var firstPaymentDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
  var market: FinancingMarket = .portugal
  var purchaseType: FinancingPurchaseType = .vehicle
  var result: FinancingOfferSimulationResponse?
  var isLoading = false
  var errorMessage: String?
  var didSave = false

  private let service: any ExpensesServicing

  init(service: (any ExpensesServicing)? = nil) {
    self.service = service ?? Container.shared.expensesService()
  }

  func simulate() async {
    guard let price = Self.number(purchaseAmount), price > 0 else {
      errorMessage = "Enter a valid purchase price."
      return
    }
    let quote = Self.number(monthlyPayment)
    let nominal = Self.number(nominalRate)
    guard quote != nil || nominal != nil else {
      errorMessage = "Enter either the quoted monthly payment or nominal annual rate."
      return
    }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      let response = try await service.simulateFinancing(payload: request(price: price, quote: quote, nominal: nominal))
      result = response.results.first
    } catch {
      errorMessage = "The financing simulation could not be calculated."
    }
  }

  func save() async {
    guard let result else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      _ = try await service.createFinancingPlan(payload: FinancingPlanRequest(
        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? result.offer.name : title,
        market: market,
        purchaseType: purchaseType,
        currency: market.defaultCurrency,
        terms: result.offer
      ))
      didSave = true
    } catch {
      errorMessage = "Saving and tracking financing plans requires Norviq Pro."
    }
  }

  private func request(price: Double, quote: Double?, nominal: Double?) -> FinancingSimulationRequest {
    let offer = FinancingOfferTerms(
      name: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? purchaseType.label : title,
      purchaseAmount: price,
      downPayment: Self.number(downPayment) ?? 0,
      termMonths: termMonths,
      firstPaymentDate: Self.dayFormatter.string(from: firstPaymentDate),
      quotedMonthlyPayment: quote,
      nominalAnnualRate: nominal,
      effectiveAnnualRate: Self.number(effectiveRate),
      rateType: .fixed
    )
    return FinancingSimulationRequest(market: market, purchaseType: purchaseType, currency: market.defaultCurrency, offers: [offer])
  }

  private static func number(_ value: String) -> Double? {
    Double(value.replacingOccurrences(of: ",", with: "."))
  }

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

struct FinancingPlannerScreen: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model = FinancingPlannerViewModel()

  var body: some View {
    NavigationStack {
      Form {
        Section("Purchase") {
          TextField("Name, e.g. Tesla Model 3", text: $model.title)
          Picker("Type", selection: $model.purchaseType) {
            ForEach(FinancingPurchaseType.allCases, id: \.self) { Text($0.label).tag($0) }
          }
          Picker("Market", selection: $model.market) {
            ForEach(FinancingMarket.allCases, id: \.self) { Text($0.label).tag($0) }
          }
          TextField("Purchase price", text: $model.purchaseAmount).keyboardType(.decimalPad)
          TextField("Deposit", text: $model.downPayment).keyboardType(.decimalPad)
        }

        Section("Financing terms") {
          Stepper("\(model.termMonths) months", value: $model.termMonths, in: 1...480)
          DatePicker("First payment", selection: $model.firstPaymentDate, displayedComponents: .date)
          TextField("Quoted monthly payment", text: $model.monthlyPayment).keyboardType(.decimalPad)
          TextField("Nominal annual rate (%)", text: $model.nominalRate).keyboardType(.decimalPad)
          TextField("Effective annual rate (%)", text: $model.effectiveRate).keyboardType(.decimalPad)
        }

        Section {
          Button {
            Task { await model.simulate() }
          } label: {
            if model.isLoading { ProgressView() } else { Label("Simulate", systemImage: "function") }
          }
          .disabled(model.isLoading)
        }

        if let result = model.result {
          Section("Projection") {
            LabeledContent("Monthly payment", value: result.monthlyPayment.formatted(.currency(code: model.market.defaultCurrency)))
            LabeledContent("Total paid", value: result.totalOutOfPocket.formatted(.currency(code: model.market.defaultCurrency)))
            LabeledContent("Credit cost", value: result.totalCreditCost.formatted(.currency(code: model.market.defaultCurrency)))
            LabeledContent("Cash-flow result", value: result.affordability.cashFlowStatus.label)
            Text(result.affordability.message).font(.footnote).foregroundStyle(.secondary)
            ForEach(result.warnings, id: \.self) { Text($0).font(.footnote).foregroundStyle(.orange) }
          }
          Section("Debt-service guidance") {
            LabeledContent("Status", value: result.affordability.benchmark.status.label)
            if let ratio = result.affordability.benchmark.ratio {
              let basis = result.affordability.benchmark.incomeBasis.map { " of \($0) income" } ?? ""
              LabeledContent("Calculated ratio", value: String(format: "%.1f%%%@", ratio, basis))
            }
            if let max = result.affordability.benchmark.guidanceMaximum {
              if let min = result.affordability.benchmark.guidanceMinimum {
                LabeledContent("Published band", value: String(format: "%.0f–%.0f%%", min, max))
              } else {
                LabeledContent("Published max", value: String(format: "up to %.0f%%", max))
              }
            } else if result.affordability.benchmark.status == .notEvaluated {
              Text("This market has no universal consumer pass/fail threshold. The ratio is informational only.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Text(result.affordability.benchmark.message)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          Section {
            Button("Save to Expenses") { Task { await model.save() } }
              .disabled(model.isLoading || model.didSave)
          }
        }

        if let error = model.errorMessage {
          Section { Text(error).foregroundStyle(.red) }
        }
        if model.didSave {
          Section { Label("Plan saved. Its installments will appear in future Expenses months.", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
        }
      }
      .navigationTitle("Plan a purchase")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
    }
  }
}

private extension FinancingMarket {
  var label: String {
    switch self {
    case .portugal: "Portugal"
    case .germany: "Germany"
    case .france: "France"
    case .italy: "Italy"
    case .spain: "Spain"
    case .netherlands: "Netherlands"
    case .poland: "Poland"
    case .brazil: "Brazil"
    case .unitedStates: "United States"
    }
  }
}

private extension FinancingPurchaseType {
  var label: String {
    switch self {
    case .vehicle: "Vehicle"
    case .home: "Home or apartment"
    case .utility: "Major utility"
    case .education: "Education"
    case .other: "Other"
    }
  }
}

private extension FinancingCashFlowStatus {
  var label: String {
    switch self {
    case .doable: "Doable"
    case .tight: "Tight"
    case .notDoable: "Not doable"
    case .insufficientData: "Add income data"
    }
  }
}

private extension FinancingBenchmarkStatus {
  var label: String {
    switch self {
    case .pass: "Within published guidance"
    case .aboveGuidance: "Above published guidance"
    case .notEvaluated: "No pass/fail threshold"
    case .stale: "Stale guidance"
    }
  }
}
