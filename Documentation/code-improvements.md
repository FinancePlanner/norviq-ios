# Onboarding Reuse + MVVM Boundary Tightening

## What changed

### 1) Shared onboarding screen shell
I introduced a reusable `OnboardingStepScaffold` with `OnboardingStepScaffoldConfig` and optional `OnboardingStepBanner`.

Why:
- Stocks onboarding and Expenses onboarding had duplicated screen shell code (header/nav, background, scroll container, bottom action area, top error banner).
- Reuse is now explicit and centralized, while each flow still owns its specific content.

### 2) `InitialStockImportScreen` now uses shared scaffold
The stock method-selection onboarding step now uses `OnboardingStepScaffold` and drives CTA state via config:
- `primaryActionTitle`
- `isPrimaryActionEnabled`
- `isPrimaryActionLoading`
- `showsPrimaryActionArrow`

Why:
- Keeps behavior the same while removing duplicated layout/chrome.
- Makes CTA/loading state easier to reason about from one config object.

### 3) `ExpenseBudgetSetupScreen` now uses shared scaffold
Budget setup now renders inside the scaffold and uses scaffold banner rendering for errors.

Why:
- Same reusable shell as stock onboarding.
- Error surface is normalized and no longer repeated in screen-level wrapper code.

### 4) View-level service calls moved into view models (MVVM boundary fix)
- `ManualImportScreen` no longer calls `Container.shared.stockService()` directly.
- `ManualImportViewModel` now owns import persistence through injected stock-import dependency.
- `ExpenseBudgetSetupViewModel` now receives injected `ExpenseBudgetSetupServicing` instead of resolving service inside `createBudgetSnapshot()`.

Why:
- Views now trigger intents; view models own persistence logic.
- Dependency injection is now explicit and testable.

### 5) Focused unit tests added
Extended `ManualImportViewModelTests` with:
- stock import delegation test (`importPositions` maps to `StockRequest` correctly)
- budget setup persistence test (snapshot + valid expenses only)

Why:
- Verifies the new MVVM boundaries and request mapping without network/backend dependencies.

## Key code samples

### Shared scaffold API
```swift
struct OnboardingStepScaffoldConfig {
  let title: String
  let icon: String
  var namespace: Namespace.ID? = nil
  var primaryActionTitle: String? = nil
  var isPrimaryActionEnabled: Bool = true
  var isPrimaryActionLoading: Bool = false
  var showsPrimaryActionArrow: Bool = false
  var contentHorizontalPadding: CGFloat = 20
  var contentMaxWidth: CGFloat? = nil
}

struct OnboardingStepScaffold<TopAccessory: View, Content: View, Footer: View>: View {
  let config: OnboardingStepScaffoldConfig
  let onBack: () -> Void
  let onPrimaryAction: (() -> Void)?
  let banner: OnboardingStepBanner?
  @ViewBuilder let topAccessory: () -> TopAccessory
  @ViewBuilder let content: () -> Content
  @ViewBuilder let footer: () -> Footer
  // shared layout implementation...
}
```

### Stock onboarding using shared scaffold
```swift
OnboardingStepScaffold(
  config: OnboardingStepScaffoldConfig(
    title: "Stock Import",
    icon: "chart.line.uptrend.xyaxis",
    namespace: headerNamespace,
    primaryActionTitle: buttonTitle,
    isPrimaryActionEnabled: selectedMethod != nil && !isSubmitting,
    isPrimaryActionLoading: isSubmitting,
    showsPrimaryActionArrow: selectedMethod != nil && !isSubmitting,
    contentHorizontalPadding: 24,
    contentMaxWidth: 520
  ),
  onBack: onBack,
  onPrimaryAction: { Task { await completeImport() } },
  banner: nil,
  scrollDismissesKeyboard: .never
) {
  topActions
} content: {
  stockSelectionContent
} footer: {
  EmptyView()
}
```

### ViewModel-owned stock import persistence
```swift
final class ManualImportViewModel: ObservableObject {
  private let bulkCreateStocks: @Sendable ([StockRequest]) async throws -> BulkStockResponse

  init(stockService: any StockServicing = Container.shared.stockService()) {
    self.bulkCreateStocks = { requests in
      try await stockService.bulkCreate(stocks: requests)
    }
  }

  func importPositions(
    _ positions: [ImportedPosition],
    buyDate: String = DateFormatter.yyyyMMdd.string(from: Date())
  ) async throws {
    let requests = positions.map { position in
      StockRequest(
        symbol: position.symbol,
        shares: position.quantity,
        buyPrice: position.price,
        buyDate: buyDate,
        notes: ""
      )
    }
    _ = try await bulkCreateStocks(requests)
  }
}
```

### ViewModel-owned budget setup persistence
```swift
final class ExpenseBudgetSetupViewModel: ObservableObject {
  private let expensesService: any ExpenseBudgetSetupServicing

  init(expensesService: any ExpenseBudgetSetupServicing = Container.shared.expensesService()) {
    self.expensesService = expensesService
  }

  func createBudgetSnapshot() async throws {
    // build snapshot request...
    _ = try await expensesService.createBudgetSnapshot(request: snapshotRequest)
    // build and create expense requests...
  }
}
```

## Follow-up technical debt (out of this scope)
- Home still mixes view orchestration with direct service dependencies in places.
- Similar scaffold migration can be done for `CSVImportScreen`, `ManualImportScreen`, and `APIKeyImportScreen` to fully standardize onboarding shells.
- `OnboardingImportFlow.swift` is still large; next pass should split `OnboardingStepScaffold` and `BrokerAPIImportViewModel` into dedicated files.
