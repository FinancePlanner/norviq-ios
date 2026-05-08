import Combine
import Factory
import StockPlanShared
import SwiftUI

struct ExpenseBudgetSetupScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel = ExpenseBudgetSetupViewModel()
  @State private var errorMessage: String?
  var headerNamespace: Namespace.ID?

  let onBack: () -> Void
  let onDone: () -> Void

  private var totalPercent: Double {
    viewModel.pillars.values.reduce(0, +)
  }

  private var isValid: Bool {
    viewModel.hasValidMonthlyIncome && abs(totalPercent - 100) < 0.001
  }

  var body: some View {
    OnboardingStepScaffold(
      config: OnboardingStepScaffoldConfig(
        title: "Budget Setup",
        icon: "dollarsign.circle.fill",
        namespace: headerNamespace,
        contentHorizontalPadding: 0
      ),
      onBack: onBack,
      onPrimaryAction: nil,
      banner: errorMessage.map { OnboardingStepBanner(message: $0, style: .error) },
      scrollDismissesKeyboard: .interactively
    ) {
      EmptyView()
    } content: {
      VStack(spacing: 24) {
        instructionsSection
        monthlyIncomeSection
        budgetPillarsSection
        initialExpensesSection
        Spacer(minLength: 100)
      }
    } footer: {
      bottomBarSection
    }
    .task(id: errorMessage) {
      guard let current = errorMessage else { return }
      try? await Task.sleep(for: .seconds(3))
      guard errorMessage == current else { return }
      withAnimation(.easeInOut(duration: 0.2)) {
        errorMessage = nil
      }
    }
  }

  @ViewBuilder
  private var instructionsSection: some View {
    HStack(spacing: 12) {
      Image(systemName: "info.circle.fill")
        .font(.title3)
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))

      Text(
        "Set up your monthly budget (salary + side income) and allocate it across spending pillars."
      )
      .typography(.small)
      .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .appGlassEffect(.rect(cornerRadius: 14), tint: AppTheme.Colors.tintSoft(for: colorScheme).opacity(0.4))
    .padding(.horizontal, 20)
    .padding(.top, 16)
  }

  @ViewBuilder
  private var monthlyIncomeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Monthly Budget")
        .typography(.label, weight: .semibold)
        .padding(.horizontal, 4)

      HStack(spacing: 12) {
        Image(systemName: "banknote.fill")
          .font(.title3)
          .foregroundStyle(AppTheme.Colors.success)
          .frame(width: 32)

        TextField("Enter your total monthly budget", text: $viewModel.monthlyIncome)
          .keyboardType(.decimalPad)
          .typography(.label, weight: .semibold)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .appGlassEffect(.rect(cornerRadius: 16))

      if let monthlyBudget = viewModel.parsedMonthlyIncome, monthlyBudget > 0 {
        Text("Monthly budget will be set to \(monthlyBudget.currency). Include salary and side income. You can edit this later in Expenses.")
          .typography(.nano)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 4)
      }
    }
    .padding(.horizontal, 20)
  }

  @ViewBuilder
  private var budgetPillarsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Budget Pillars")
          .typography(.label, weight: .semibold)

        Spacer()

        Text("\(Int(totalPercent))%")
          .typography(.label, weight: .bold)
          .foregroundStyle(totalPercent == 100 ? AppTheme.Colors.success : AppTheme.Colors.warning)
      }
      .padding(.horizontal, 4)

      ForEach(BudgetPillar.allCases, id: \.self) { pillar in
        PillarAllocationCard(
          pillar: pillar,
          percentage: Binding(
            get: { viewModel.pillars[pillar] ?? 0 },
            set: { viewModel.pillars[pillar] = $0 }
          ),
          monthlyIncome: viewModel.monthlyIncomeValue
        )
      }
    }
    .padding(.horizontal, 20)
  }

  @ViewBuilder
  private var initialExpensesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Add Initial Expenses (Optional)")
          .typography(.label, weight: .semibold)

        Spacer()

        Button {
          withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            viewModel.addExpense()
          }
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.title3)
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        }
      }
      .padding(.horizontal, 4)

      if viewModel.expenses.isEmpty {
        Text("You can add expenses later from the Expenses tab")
          .typography(.nano)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 4)
      } else {
          ForEach($viewModel.expenses) { $expense in
              let index = viewModel.expenses.firstIndex(where: { $0.id == expense.id }) ?? 0
              ExpenseEntryCard(
                  expense: $expense,
                  index: index + 1,
                  onDelete: {
                      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                          viewModel.expenses.removeAll(where: { $0.id == expense.id })
                      }
                  }
              )
              .transition(.asymmetric(
                  insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
                  removal: .scale(scale: 0.9).combined(with: .opacity)
              ))
          }
      }
    }
    .padding(.horizontal, 20)
  }

  @ViewBuilder
  private var bottomBarSection: some View {
    VStack(spacing: 0) {
      Divider().opacity(0.3)

      HStack(spacing: 12) {
        if !isValid {
          Text(totalPercent != 100 ? "Pillars must total 100%" : "Enter a valid monthly budget greater than 0")
            .typography(.small)
            .foregroundStyle(AppTheme.Colors.warning)
        }

        Spacer()

        Button {
          submitBudgetSetup()
        } label: {
          HStack(spacing: 6) {
            Text("Continue")
              .font(.headline)
              .fontWeight(.bold)
            Image(systemName: "arrow.right")
              .font(.subheadline.weight(.bold))
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(
            Capsule()
              .fill(AppTheme.Colors.tint(for: colorScheme))
          )
          .shadow(
            color: AppTheme.Colors.tint(for: colorScheme).opacity(0.25),
            radius: 8, x: 0, y: 4
          )
        }
        .disabled(!isValid)
        .opacity(isValid ? 1 : 0.5)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
      .appGlassEffect(.rect(cornerRadius: 0))
      .ignoresSafeArea(edges: .bottom)
    }
  }

  private func submitBudgetSetup() {
    errorMessage = nil
    Task {
      do {
        try await viewModel.createBudgetSnapshot()
        onDone()
      } catch {
        errorMessage =
          (error as? LocalizedError)?.errorDescription
          ?? "Could not create budget: \(error.localizedDescription)"
      }
    }
  }
}

// MARK: - Pillar Allocation Card

private struct PillarAllocationCard: View {
  let pillar: BudgetPillar
  @Binding var percentage: Double
  let monthlyIncome: Double
  @Environment(\.colorScheme) private var colorScheme

  private var allocatedAmount: Double {
    monthlyIncome * (percentage / 100)
  }

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        HStack(spacing: 10) {
          Image(systemName: pillar.symbol)
            .font(.title3)
            .foregroundStyle(pillar.color(for: colorScheme))
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 2) {
            Text(pillar.title)
              .typography(.label, weight: .semibold)

            if monthlyIncome > 0 {
              Text(allocatedAmount.formatted(.currency(code: "USD")))
                .typography(.nano)
                .foregroundStyle(.secondary)
            }
          }
        }

        Spacer()

        HStack(spacing: 4) {
          TextField("0", value: $percentage, format: .number.precision(.fractionLength(0)))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .typography(.label, weight: .bold)
            .frame(width: 40)

          Text("%")
            .typography(.label)
            .foregroundStyle(.secondary)
        }
      }

      // Slider
      Slider(value: $percentage, in: 0...100, step: 5)
        .tint(pillar.color(for: colorScheme))
    }
    .padding(16)
    .appGlassEffect(.rect(cornerRadius: 16))
  }
}

// MARK: - Expense Entry Card

private struct ExpenseEntryCard: View {
  @Binding var expense: ExpenseEntry
  let index: Int
  let onDelete: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var focusedField: ExpenseField?

  private enum ExpenseField { case title, amount }

  var body: some View {
    VStack(spacing: 0) {
      // Header row
      HStack {
        Text("Expense \(index)")
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)

        Spacer()

        Button(action: onDelete) {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary.opacity(0.5))
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 10)

      // Title
      HStack(spacing: 10) {
        Image(systemName: "text.alignleft")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextField("Expense name (e.g. Groceries)", text: $expense.title)
          .focused($focusedField, equals: .title)
          .submitLabel(.next)
          .onSubmit { focusedField = .amount }
          .typography(.label, weight: .semibold)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        AppTheme.Colors.elevatedCardBackground(for: colorScheme)
          .opacity(0.6)
      )

      Divider().padding(.leading, 16).opacity(0.3)

      // Amount & Pillar row
      HStack(spacing: 0) {
        HStack(spacing: 8) {
          Text("$")
            .typography(.label)
            .foregroundStyle(.secondary)

          TextField("0.00", text: $expense.amount)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: .amount)
            .typography(.label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider().frame(height: 28).opacity(0.3)

        Menu {
          ForEach(BudgetPillar.allCases, id: \.self) { pillar in
            Button {
              expense.pillar = pillar
            } label: {
              Label(pillar.title, systemImage: pillar.symbol)
            }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: expense.pillar.symbol)
              .font(.subheadline)
            Text(expense.pillar.title)
              .typography(.small, weight: .medium)
            Image(systemName: "chevron.down")
              .font(.caption2.weight(.bold))
          }
          .foregroundStyle(expense.pillar.color(for: colorScheme))
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
      }
      .background(
        AppTheme.Colors.elevatedCardBackground(for: colorScheme)
          .opacity(0.6)
      )
    }
    .appGlassEffect(.rect(cornerRadius: 18))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

// MARK: - View Model

@MainActor
final class ExpenseBudgetSetupViewModel: ObservableObject {
  @Published var monthlyIncome: String = ""
  @Published var pillars: [BudgetPillar: Double] = [
    .fundamentals: 50,
    .futureYou: 30,
    .fun: 20
  ]
  @Published var expenses: [ExpenseEntry] = []
  private let expensesService: any ExpenseBudgetSetupServicing

  init(expensesService: any ExpenseBudgetSetupServicing = Container.shared.expensesService()) {
    self.expensesService = expensesService
  }

  var parsedMonthlyIncome: Double? {
    Self.parseMonetaryValue(monthlyIncome)
  }

  var monthlyIncomeValue: Double {
    parsedMonthlyIncome ?? 0
  }

  var hasValidMonthlyIncome: Bool {
    monthlyIncomeValue > 0
  }

  func addExpense() {
    expenses.append(ExpenseEntry())
  }

  func createBudgetSnapshot() async throws {
    // Create budget snapshot
    let calendar = Calendar.current
    let now = Date()
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone.current

    var targetShares: [String: Double] = [:]
    for (pillar, percentage) in pillars {
      targetShares[pillar.rawValue] = percentage / 100
    }

    let snapshotRequest = BudgetSnapshotRequest(
      monthStart: dateFormatter.string(from: monthStart),
      netSalary: monthlyIncomeValue,
      targetShares: targetShares
    )

    _ = try await expensesService.createBudgetSnapshot(request: snapshotRequest)

    // Create expenses if any
    for expense in expenses where !expense.title.isEmpty {
      guard let amount = Self.parseMonetaryValue(expense.amount), amount > 0 else { continue }

      let expenseRequest = ExpenseRequest(
        title: expense.title,
        amount: amount,
        pillar: expense.pillar,
        occurredOn: dateFormatter.string(from: now),
        linkedPlanItemId: nil,
        splitMode: .personal,
        userSharePercent: 100
      )

      _ = try await expensesService.createExpense(request: expenseRequest)
    }
  }

  private static func parseMonetaryValue(_ raw: String) -> Double? {
    MoneyInputParser.parse(raw)
  }
}

struct ExpenseEntry: Identifiable {
  let id = UUID()
  var title: String = ""
  var amount: String = ""
  var pillar: BudgetPillar = .fundamentals
}
