import Factory
import StockPlanShared
import SwiftUI

struct PortfolioWorkspaceScreen: View {
  @InjectedObservable(\.billingManager) private var billingManager
  @State private var model = PortfolioWorkspaceViewModel()
  @State private var isCreating = false
  @State private var isComparing = false

  var body: some View {
    List {
      if !billingManager.isPro {
        ContentUnavailableView(
          "Advanced portfolios are Pro",
          systemImage: "sparkles",
          description: Text(
            "Your personal portfolio remains available. Upgrade for joint, retirement, and what-if portfolios."
          )
        )
      }

      Section("Portfolios") {
        ForEach(model.portfolios) { portfolio in
          NavigationLink {
            PortfolioDetailScreen(portfolio: portfolio, model: model)
          } label: {
            PortfolioWorkspaceRow(portfolio: portfolio)
          }
        }
      }
    }
    .overlay {
      if model.isLoading, model.portfolios.isEmpty {
        ProgressView()
      }
    }
    .navigationTitle("Portfolios")
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        if model.portfolios.count > 1 {
          Button("Compare", systemImage: "arrow.left.arrow.right") { isComparing = true }
            .labelStyle(.iconOnly)
        }
        Button("New portfolio", systemImage: "plus") { isCreating = true }
          .labelStyle(.iconOnly)
      }
    }
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $isCreating) {
      CreatePortfolioSheet(model: model, isPro: billingManager.isPro)
    }
    .sheet(isPresented: $isComparing) {
      PortfolioComparisonSheet(model: model)
    }
    .alert("Couldn’t complete the request", isPresented: errorBinding) {
      Button("OK") { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "Please try again.")
    }
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { model.errorMessage != nil },
      set: {
        if !$0 {
          model.errorMessage = nil
        }
      }
    )
  }
}

private struct PortfolioWorkspaceRow: View {
  let portfolio: Portfolio

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(portfolio.mode == .hypothetical ? Color.orange : Color.accentColor)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text(portfolio.name).font(.headline)
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      if portfolio.currentUserRole == .editor {
        Text("Shared").font(.caption2).foregroundStyle(.secondary)
      }
    }
  }

  private var icon: String {
    if portfolio.mode == .hypothetical {
      return "flask"
    }
    if portfolio.purpose == .retirement {
      return "sun.horizon"
    }
    if portfolio.ownership == .joint {
      return "person.2"
    }
    return "briefcase"
  }

  private var subtitle: String {
    [portfolio.purpose.rawValue.capitalized, portfolio.ownership.rawValue.capitalized, portfolio.baseCurrency]
      .joined(separator: " · ")
  }
}

private struct CreatePortfolioSheet: View {
  @Environment(\.dismiss) private var dismiss
  let model: PortfolioWorkspaceViewModel
  let isPro: Bool
  @State private var name = ""
  @State private var currency = "USD"
  @State private var purpose = PortfolioPurpose.personal
  @State private var ownership = PortfolioOwnership.individual
  @State private var mode = PortfolioMode.actual

  var body: some View {
    NavigationStack {
      Form {
        Section("Portfolio") {
          TextField("Name", text: $name)
          TextField("Base currency", text: $currency)
            .textInputAutocapitalization(.characters)
          Picker("Purpose", selection: $purpose) {
            ForEach(PortfolioPurpose.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
          }
          Picker("Ownership", selection: $ownership) {
            ForEach(PortfolioOwnership.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
          }
          Picker("Mode", selection: $mode) {
            ForEach(PortfolioMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
          }
        }
        if !isPro {
          Text("Free accounts can create one personal, individual, actual portfolio.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }
      .navigationTitle("New portfolio")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            Task {
              let created = await model.create(
                PortfolioCreateRequest(
                  name: name,
                  purpose: purpose,
                  ownership: ownership,
                  mode: mode,
                  baseCurrency: currency.uppercased()
                )
              )
              if created {
                dismiss()
              }
            }
          }
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || model.isSaving)
        }
      }
    }
  }
}

private struct PortfolioComparisonSheet: View {
  @Environment(\.dismiss) private var dismiss
  let model: PortfolioWorkspaceViewModel
  @State private var leftId = ""
  @State private var rightId = ""

  var body: some View {
    NavigationStack {
      Form {
        Picker("Portfolio", selection: $leftId) {
          ForEach(model.portfolios) { Text($0.name).tag($0.id) }
        }
        Picker("Compare with", selection: $rightId) {
          ForEach(model.portfolios) { Text($0.name).tag($0.id) }
        }
        Button("Compare") {
          guard
            let left = model.portfolios.first(where: { $0.id == leftId }),
            let right = model.portfolios.first(where: { $0.id == rightId })
          else { return }
          Task { await model.compare(left: left, right: right) }
        }
        .disabled(leftId.isEmpty || rightId.isEmpty || leftId == rightId)

        if let comparison = model.comparison {
          Section("Summary") {
            LabeledContent(
              comparison.left.name,
              value: comparison.left.totalValue.formatted(.currency(code: comparison.left.baseCurrency))
            )
            LabeledContent(
              comparison.right.name,
              value: comparison.right.totalValue.formatted(.currency(code: comparison.right.baseCurrency))
            )
          }
          Section("Largest differences") {
            ForEach(comparison.holdings.prefix(10)) { holding in
              LabeledContent(
                holding.symbol,
                value: holding.valueDifference.formatted(.number.precision(.fractionLength(0...2)))
              )
            }
          }
        }
      }
      .navigationTitle("Compare portfolios")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .onAppear {
        leftId = model.portfolios.first?.id ?? ""
        rightId = model.portfolios.dropFirst().first?.id ?? ""
      }
    }
  }
}
