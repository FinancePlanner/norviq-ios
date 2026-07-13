import SwiftUI
import StockPlanShared

struct TaxProfileSetupSheet: View {
  private struct AccountDraft: Identifiable {
    let id: String
    let displayName: String
    let broker: String
    var wrapper: TaxAccountWrapper
    var lotSelectionMethod: TaxLotSelectionMethod
  }

  @Environment(\.dismiss) private var dismiss
  let service: TaxServiceProtocol
  let context: TaxProfileContextResponse
  let onSaved: () -> Void

  @State private var filingStatus: TaxFilingStatus
  @State private var estimatedIncome: String
  @State private var primaryRate: String
  @State private var shortTermRate: String
  @State private var longTermRate: String
  @State private var capitalGainsTaxationMode: TaxCapitalGainsTaxationMode
  @State private var remainingCapitalIncomeAllowance: String
  @State private var churchTaxRate: Decimal
  @State private var shortLossCarryover: String
  @State private var longLossCarryover: String
  @State private var accounts: [AccountDraft]
  @State private var isSaving = false
  @State private var errorMessage: String?

  init(
    service: TaxServiceProtocol,
    context: TaxProfileContextResponse,
    onSaved: @escaping () -> Void
  ) {
    self.service = service
    self.context = context
    self.onSaved = onSaved
    let profile = context.profile?.profile
    _filingStatus = State(initialValue: profile?.filingStatus ?? .single)
    _estimatedIncome = State(initialValue: Self.decimalText(profile?.estimatedTaxableIncome))
    _primaryRate = State(initialValue: Self.percentText(profile?.marginalIncomeTaxRate))
    _shortTermRate = State(initialValue: Self.percentText(profile?.shortTermCapitalGainsRate))
    _longTermRate = State(initialValue: Self.percentText(profile?.longTermCapitalGainsRate))
    _capitalGainsTaxationMode = State(initialValue: profile?.capitalGainsTaxationMode ?? .jurisdictionDefault)
    _remainingCapitalIncomeAllowance = State(initialValue: Self.decimalText(profile?.remainingCapitalIncomeAllowance))
    _churchTaxRate = State(initialValue: profile?.churchTaxRate ?? 0)
    _shortLossCarryover = State(initialValue: Self.decimalText(profile?.priorShortTermLossCarryover))
    _longLossCarryover = State(initialValue: Self.decimalText(profile?.priorLongTermLossCarryover))
    _accounts = State(initialValue: context.accounts.map {
      AccountDraft(
        id: $0.id,
        displayName: $0.displayName,
        broker: $0.broker,
        wrapper: $0.wrapper,
        lotSelectionMethod: $0.lotSelectionMethod
      )
    })
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent("Jurisdiction", value: context.jurisdiction.displayName)
          LabeledContent("Tax year", value: String(context.taxYear))
          Picker("Filing status", selection: $filingStatus) {
            ForEach(TaxFilingStatus.allCases, id: \.self) { status in
              Text(status.displayName).tag(status)
            }
          }
          TextField("Estimated taxable income", text: $estimatedIncome)
            .keyboardType(.decimalPad)
          LabeledContent("Reporting currency", value: context.defaultReportingCurrency)
        } header: {
          Text("Tax household")
        } footer: {
          Text("Use a reasonable full-year estimate. You can revise it whenever your circumstances change.")
        }

        Section("Tax rates") {
          if context.jurisdiction == .unitedStates {
            percentageField("Short-term capital gains", text: $shortTermRate)
            percentageField("Long-term capital gains", text: $longTermRate)
          } else if context.jurisdiction != .germany {
            percentageField("Marginal income tax rate", text: $primaryRate)
          }
          if context.jurisdiction == .portugal {
            Picker("Securities taxation", selection: $capitalGainsTaxationMode) {
              Text("Use legal default").tag(TaxCapitalGainsTaxationMode.jurisdictionDefault)
              Text("28% autonomous taxation").tag(TaxCapitalGainsTaxationMode.autonomous)
              Text("Aggregate with income").tag(TaxCapitalGainsTaxationMode.aggregateWithIncome)
            }
          }
        }

        if context.jurisdiction == .germany {
          Section {
            TextField("Remaining saver allowance", text: $remainingCapitalIncomeAllowance)
              .keyboardType(.decimalPad)
            Picker("Church tax", selection: $churchTaxRate) {
              Text("None").tag(Decimal.zero)
              Text("8%").tag(Decimal(string: "0.08")!)
              Text("9%").tag(Decimal(string: "0.09")!)
            }
          } header: {
            Text("German capital income")
          } footer: {
            Text("Enter only the saver allowance still unused across all banks and brokers. Leave it blank if unknown. Church tax varies by federal state and denomination.")
          }
        }

        Section("Prior loss carryovers") {
          TextField("Short-term", text: $shortLossCarryover).keyboardType(.decimalPad)
          TextField("Long-term", text: $longLossCarryover).keyboardType(.decimalPad)
        }

        Section {
          if accounts.isEmpty {
            ContentUnavailableView("No investment accounts", systemImage: "tray")
          }
          ForEach($accounts) { $account in
            VStack(alignment: .leading, spacing: 10) {
              VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName).font(.headline)
                Text(account.broker).font(.caption).foregroundStyle(.secondary)
              }
              Picker("Tax treatment", selection: $account.wrapper) {
                ForEach(TaxAccountWrapper.allCases, id: \.self) { wrapper in
                  Text(wrapper.displayName).tag(wrapper)
                }
              }
              if context.jurisdiction == .germany {
                LabeledContent("Lot selection", value: "FIFO per depot")
              } else {
                Picker("Lot selection", selection: $account.lotSelectionMethod) {
                  ForEach(TaxLotSelectionMethod.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                  }
                }
              }
            }
            .padding(.vertical, 4)
          }
        } header: {
          Text("Account classification")
        } footer: {
          Text("Unknown accounts keep recommendations in preview mode. Select the legal wrapper shown by your broker or custodian.")
        }
      }
      .navigationTitle(context.profile == nil ? "Set up tax profile" : "Tax profile")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(isSaving || !canSave)
        }
      }
      .overlay { if isSaving { ProgressView().controlSize(.large) } }
      .alert("Could not save profile", isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
  }

  private var canSave: Bool {
    decimal(estimatedIncome) != nil
      && !accounts.isEmpty
      && accounts.allSatisfy { $0.wrapper != .unknown }
      && validRates
      && (remainingCapitalIncomeAllowance.isEmpty || decimal(remainingCapitalIncomeAllowance).map { $0 >= 0 } == true)
  }

  private var validRates: Bool {
    switch context.jurisdiction {
    case .unitedStates:
      return percent(shortTermRate) != nil && percent(longTermRate) != nil
    case .germany:
      return true
    default:
      return percent(primaryRate) != nil
    }
  }

  private func percentageField(_ title: String, text: Binding<String>) -> some View {
    HStack {
      TextField(title, text: text).keyboardType(.decimalPad)
      Text("%").foregroundStyle(.secondary)
    }
  }

  private func save() async {
    guard let income = decimal(estimatedIncome) else { return }
    isSaving = true
    defer { isSaving = false }
    let existingMembers = context.profile?.profile.members ?? []
    let members = existingMembers.isEmpty
      ? [TaxHouseholdMember(id: "self", displayName: "You", relationship: "self")]
      : existingMembers
    let ownerID = members[0].id
    let existingByAccount = Dictionary(uniqueKeysWithValues:
      (context.profile?.profile.accounts ?? []).map { ($0.accountId, $0) }
    )
    let classifications = accounts.map { account in
      let existing = existingByAccount[account.id]
      return TaxAccountClassification(
        id: existing?.id ?? account.id,
        accountId: account.id,
        ownerMemberId: existing?.ownerMemberId ?? ownerID,
        wrapper: account.wrapper,
        countryWrapperCode: existing?.countryWrapperCode,
        lotSelectionMethod: context.jurisdiction == .germany ? .fifo : account.lotSelectionMethod
      )
    }
    let request = TaxProfileRequest(
      jurisdiction: context.jurisdiction,
      taxYear: context.taxYear,
      filingStatus: filingStatus,
      reportingCurrency: context.defaultReportingCurrency,
      estimatedTaxableIncome: income,
      marginalIncomeTaxRate: context.jurisdiction == .unitedStates ? nil : percent(primaryRate),
      shortTermCapitalGainsRate: context.jurisdiction == .unitedStates ? percent(shortTermRate) : nil,
      longTermCapitalGainsRate: context.jurisdiction == .unitedStates ? percent(longTermRate) : nil,
      capitalGainsTaxationMode: context.jurisdiction == .portugal ? capitalGainsTaxationMode : nil,
      remainingCapitalIncomeAllowance: context.jurisdiction == .germany
        ? decimal(remainingCapitalIncomeAllowance)
        : nil,
      churchTaxRate: context.jurisdiction == .germany && churchTaxRate > 0 ? churchTaxRate : nil,
      priorShortTermLossCarryover: decimal(shortLossCarryover) ?? 0,
      priorLongTermLossCarryover: decimal(longLossCarryover) ?? 0,
      members: members,
      accounts: classifications
    )
    do {
      _ = try await service.saveProfile(request)
      onSaved()
      dismiss()
    } catch {
      errorMessage = "Check the entered rates and account classifications, then try again."
    }
  }

  private func decimal(_ text: String) -> Decimal? {
    Decimal(string: text.replacingOccurrences(of: ",", with: "."))
  }

  private func percent(_ text: String) -> Decimal? {
    decimal(text).map { $0 / 100 }
  }

  private static func decimalText(_ value: Decimal?) -> String {
    value.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
  }

  private static func percentText(_ value: Decimal?) -> String {
    value.map { NSDecimalNumber(decimal: $0 * 100).stringValue } ?? ""
  }
}

private extension TaxJurisdiction {
  var displayName: String {
    switch self {
    case .unitedStates: "United States"
    case .portugal: "Portugal"
    case .spain: "Spain"
    case .germany: "Germany"
    case .france: "France"
    case .italy: "Italy"
    }
  }
}

private extension TaxFilingStatus {
  var displayName: String {
    switch self {
    case .single: "Single"
    case .marriedJoint: "Married, filing jointly"
    case .marriedSeparate: "Married, filing separately"
    case .domesticPartnership: "Domestic partnership"
    }
  }
}

private extension TaxAccountWrapper {
  var displayName: String {
    switch self {
    case .taxable: "Taxable brokerage"
    case .traditionalIRA: "Traditional IRA"
    case .rothIRA: "Roth IRA"
    case .pension: "Pension"
    case .taxExempt: "Tax exempt"
    case .countrySpecific: "Country-specific wrapper"
    case .unknown: "Choose treatment"
    }
  }
}

private extension TaxLotSelectionMethod {
  var displayName: String {
    switch self {
    case .fifo: "FIFO"
    case .lifo: "LIFO"
    case .specificID: "Specific ID"
    case .jurisdictionDefault: "Jurisdiction default"
    }
  }
}
