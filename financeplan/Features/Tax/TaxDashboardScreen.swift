import SwiftUI
import StockPlanShared
import Factory

struct TaxDashboardScreen: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var model: TaxDashboardViewModel
  @State private var isSettingsPresented = false
  @State private var isReportsPresented = false
  @State private var isMarketAdmissionPresented = false
  @State private var isFundClassificationPresented = false
  @State private var isFundAnnualInputPresented = false
  @State private var isProfilePresented = false
  @State private var isCarryforwardPresented = false
  @State private var isPaywallPresented = false
  private let service: TaxServiceProtocol

  init() {
    let container = Container.shared
    let service = TaxService(
      environment: container.appEnvironment(),
      auth: container.authSessionManager()
    )
    self.service = service
    _model = State(initialValue: TaxDashboardViewModel(service: service))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          jurisdictionPicker
          supportLevelBanner
          profileStatus
          if model.isLoading && model.dashboard == nil { loadingState }
          else if let dashboard = model.dashboard {
            summary(dashboard)
            assumptions(dashboard)
            opportunities(dashboard)
          }
          else { ContentUnavailableView("Tax estimate unavailable", systemImage: "building.columns") }
        }
        .padding()
      }
      .navigationTitle("Tax strategy")
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          if model.selectedJurisdiction == .spain {
            Button("Markets", systemImage: "building.columns") { isMarketAdmissionPresented = true }
          }
          if model.selectedJurisdiction == .germany {
            Button("Funds", systemImage: "chart.pie") { isFundClassificationPresented = true }
            Button("Fund values", systemImage: "calendar.badge.plus") {
              presentPro { isFundAnnualInputPresented = true }
            }
          }
          if model.selectedJurisdiction == .portugal
            || model.selectedJurisdiction == .germany
            || model.selectedJurisdiction == .unitedStates
            || model.selectedJurisdiction == .spain {
            Button("Losses", systemImage: "calendar.badge.clock") {
              presentPro { isCarryforwardPresented = true }
            }
          }
          Button("Profile", systemImage: "person.crop.circle") {
            presentPro { isProfilePresented = true }
          }
          Button("Reports", systemImage: "doc.text") { isReportsPresented = true }
          Button("Settings", systemImage: "gearshape") {
            presentPro { isSettingsPresented = true }
          }
        }
      }
      .refreshable { await model.load() }
      .task { await model.load() }
      .onChange(of: model.selectedJurisdiction) { _, _ in Task { await model.load() } }
      .alert("Tax strategy", isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.errorMessage = nil } }
      )) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "") }
      .sheet(item: $model.scenario) { scenario in scenarioSheet(scenario) }
      .sheet(item: $model.actionPlan) { plan in actionPlanSheet(plan) }
      .sheet(isPresented: $isSettingsPresented) { TaxSettingsSheet(service: service) }
      .sheet(isPresented: $isReportsPresented) { TaxReportsSheet(service: service) }
      .sheet(isPresented: $isPaywallPresented) { PaywallView(billingManager: billingManager) }
      .sheet(isPresented: $isProfilePresented) {
        if let context = model.profileContext {
          TaxProfileSetupSheet(service: service, context: context) {
            Task { await model.load() }
          }
        }
      }
      .sheet(isPresented: $isCarryforwardPresented) {
        TaxLossCarryforwardSheet(
          service: service,
          jurisdiction: model.selectedJurisdiction,
          taxYear: Calendar.current.component(.year, from: Date())
        )
      }
      .sheet(isPresented: $isMarketAdmissionPresented) {
        TaxMarketAdmissionSheet(
          service: service,
          instruments: model.profileContext?.instruments ?? []
        ) { Task { await model.reloadProfileContext() } }
      }
      .sheet(isPresented: $isFundClassificationPresented) {
        TaxFundClassificationSheet(
          service: service,
          instruments: model.profileContext?.instruments ?? []
        ) { Task { await model.reloadProfileContext() } }
      }
      .sheet(isPresented: $isFundAnnualInputPresented) {
        TaxFundAnnualInputSheet(
          service: service,
          context: model.profileContext
        )
      }
    }
  }

  private var jurisdictionPicker: some View {
    Picker("Tax jurisdiction", selection: $model.selectedJurisdiction) {
      ForEach(TaxJurisdiction.allCases, id: \.self) { Text($0.displayName).tag($0) }
    }
    .pickerStyle(.menu)
    .accessibilityHint("Changes the rules used for estimates")
  }

  private var supportLevelBanner: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(model.selectedJurisdiction.supportBannerTitle)
        .font(.subheadline.weight(.semibold))
      Text(model.selectedJurisdiction.supportBannerDetail)
        .font(.caption)
        .foregroundStyle(.secondary)
      if model.selectedJurisdiction == .spain {
        Text("Market admission is user-attested only; Norviq does not auto-classify ISINs.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  private var profileStatus: some View {
    Button { presentPro { isProfilePresented = true } } label: {
      HStack(spacing: 14) {
        Image(systemName: model.profileContext?.profile?.isComplete == true ? "checkmark.seal.fill" : "person.text.rectangle")
          .font(.title2)
          .foregroundStyle(model.profileContext?.profile?.isComplete == true ? .green : .orange)
        VStack(alignment: .leading, spacing: 3) {
          Text(model.profileContext?.profile?.isComplete == true ? "Tax profile complete" : "Complete your tax profile")
            .font(.headline)
          Text(model.profileContext?.profile?.isComplete == true
               ? "Review income, rates, and account classifications"
               : "Required before opportunities can become actionable")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
      }
      .padding(16)
      .background(AppTheme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(model.profileContext == nil)
  }

  private func presentPro(_ action: () -> Void) {
    if billingManager.isPro {
      action()
    } else {
      isPaywallPresented = true
    }
  }

  private var loadingState: some View {
    VStack(spacing: 12) { ProgressView(); Text("Calculating from your tax lots…").foregroundStyle(.secondary) }
      .frame(maxWidth: .infinity, minHeight: 220)
  }

  private func summary(_ dashboard: TaxDashboardResponse) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Estimated tax drag").font(.subheadline).foregroundStyle(.secondary)
      Text(money(dashboard.summary.embeddedUnrealizedLiability)).font(.system(.largeTitle, design: .rounded, weight: .semibold))
      Divider()
      LabeledContent("Potential net benefit", value: money(dashboard.summary.estimatedNetBenefit))
      Text(dashboard.disclaimer).font(.caption).foregroundStyle(.secondary)
    }
    .padding(18)
    .background(AppTheme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  @ViewBuilder
  private func assumptions(_ dashboard: TaxDashboardResponse) -> some View {
    if !dashboard.assumptions.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("Rule pack assumptions").font(.headline)
        ForEach(dashboard.assumptions, id: \.self) { line in
          Text("• \(line)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(16)
      .background(AppTheme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private func opportunities(_ dashboard: TaxDashboardResponse) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Opportunities").font(.title2.bold())
      if dashboard.opportunities.isEmpty {
        Text(dashboard.profileComplete ? "No supported opportunities meet your threshold today." : "Complete your tax profile to unlock personalized opportunities.")
          .foregroundStyle(.secondary).padding(.vertical, 24)
      }
      ForEach(Array(dashboard.opportunities.enumerated()), id: \.element.id) { index, item in
        Button { Task { await model.simulate(item) } } label: {
          HStack(spacing: 14) {
            Image(systemName: item.status == .actionable ? "leaf.fill" : "exclamationmark.shield")
              .foregroundStyle(item.status == .actionable ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
              Text(item.symbol).font(.headline).foregroundStyle(.primary)
              Text("Loss \(money(item.unrealizedLoss)) · Benefit \(money(item.estimatedTaxBenefit))")
                .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
          }
          .padding(16)
          .background(AppTheme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(item.status != .actionable)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.28, bounce: 0.08).delay(Double(index) * 0.035), value: dashboard.generatedAt)
      }
    }
  }

  private func scenarioSheet(_ scenario: TaxScenarioResponse) -> some View {
    NavigationStack {
      List {
        Section("Harvest now vs hold") {
          LabeledContent("Hold — current year", value: money(scenario.baseline.currentYearTax))
          LabeledContent("Harvest — current year", value: money(scenario.harvestNow.currentYearTax))
          LabeledContent("Estimated net benefit", value: money(scenario.estimatedNetBenefit))
        }
        Section { Text("This is an estimate, not tax advice. Review fees, replacement activity, and local rules.") }
      }
      .navigationTitle("Scenario")
      .safeAreaInset(edge: .bottom) {
        Button("Create action plan") { Task { await model.applyScenario() } }
          .buttonStyle(.borderedProminent).controlSize(.large).padding()
      }
    }
  }

  private func actionPlanSheet(_ plan: TaxActionPlanResponse) -> some View {
    NavigationStack {
      List(plan.steps, id: \.id) { step in Label { VStack(alignment: .leading) { Text(step.title); Text(step.detail).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: "circle") } }
        .navigationTitle("Action plan")
        .safeAreaInset(edge: .bottom) { Text("Norviq does not place trades. Complete these steps with your broker.").font(.footnote).foregroundStyle(.secondary).padding() }
    }
  }

  private func money(_ value: TaxMoney) -> String {
    value.amount.formatted(.currency(code: value.currency))
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

  var supportBannerTitle: String {
    switch self {
    case .unitedStates:
      return "US · actionable when profile is complete"
    case .france, .italy:
      return "\(displayName) · professional review only"
    case .portugal, .spain, .germany:
      return "\(displayName) · estimate only until validated"
    }
  }

  var supportBannerDetail: String {
    switch self {
    case .unitedStates:
      return "Opportunities can become actionable under the US rule pack. Review with a tax professional before filing or trading."
    case .france, .italy:
      return "No production capital-gains rule pack is enabled. Norviq will not invent rates or loss ledgers for this jurisdiction yet."
    case .portugal, .germany:
      return "Detailed rules are implemented, but production remains estimate-only while TAX_VALIDATED_JURISDICTIONS is limited to US."
    case .spain:
      return "Estimates use user-attested market admission for homogeneous securities. Actionable recommendations stay disabled until professional validation."
    }
  }
}
