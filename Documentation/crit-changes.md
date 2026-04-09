# Critical Changes (SwiftUI Modernization)

## Scope
This document records the implemented critical/major updates for the current modernization pass in `financeplan`.

## 1) Unified Budget/Expense Source of Truth
- Consolidated budget and expense write flows in `BudgetPlannerViewModel` to update local store state deterministically after successful API calls.
- Removed dependence on forced full reload as the primary mechanism for UI correctness after saving.
- Expense saves now insert/update local activity state and recompute derived month/year summaries immediately.
- Snapshot updates (`updateNetSalary`, `updateTargetShares`) now upsert local snapshot state and refresh all derived totals immediately.
- Home quick-add expense now writes through the same shared budget store (`recordExpenseAndWait`) to keep Home + Expenses consistent in the same frame.

### Impact
- Adding/editing expenses updates:
  - monthly totals
  - category cards
  - “recent spend”/activity data
  without logout/login.

## 2) Actor-Isolation and Concurrency Safety
- Removed stale nonisolated sample-data builders in `BudgetPlannerViewModel` that produced actor-isolation diagnostics.
- Fixed `UserProfileView` initializer default argument pattern that triggered main-actor initialization warnings.
- Updated async sleep usage in the previously touched onboarding/content flows to structured concurrency (`Task.sleep(for:)`).

### Impact
- Cleaner Swift 6.2 / MainActor-default isolation behavior.
- Reduced false-positive runtime/state drift from mixed isolation patterns.

## 3) Monolith Reduction (Home Feature)
- Extracted Home activity feed and financial-health UI state into dedicated file:
  - `Features/Home/UnifiedActivityFeed.swift`
- Extracted Home quick expense sheet into dedicated file:
  - `Features/Home/HomeQuickExpenseSheet.swift`
- Removed dead mock `ActivityFeedItem` artifact from `HomeScreen.swift`.

### Impact
- Lower regression risk in `HomeScreen.swift`.
- Clearer boundaries for testing and future updates.

## 4) Modern API + Hygiene Fixes
- Removed deprecated/no-op `.onChange` usage in `CryptoHomeView` add sheet.
- Removed imported-type conformance warning (`BudgetPillar: Identifiable`) by switching `ForEach` to explicit `id: \.self`.
- Fixed unused result warning in onboarding expense creation (`_ = try await createExpense(...)`).

## 5) Shared Interfaces Introduced
- Added store contracts:
  - `BudgetPlannerStoreProtocol`
  - `ActivityTimelineStoreProtocol`
- Added shared money parser utility:
  - `MoneyInputParser`
- Reused parser in expenses/home/onboarding entry points where parsing was duplicated.

## 6) Tests Added/Updated
- Added coverage to validate immediate propagation after snapshot edits:
  - salary update reflects in available-after-plan/spend
  - target share update reflects in pillar targets
- Updated `BudgetPlannerServiceMock` to support `updateSnapshot` request capture and configured responses.
- Updated expense-record tests to use `recordExpenseAndWait` (deterministic save path).

### Current test/build status
- `xcodebuild ... build`: **succeeds**
- `BudgetPlannerViewModelTests`: **passes**
- Existing `ExpensesHTTPClientTests` failures are present and are not part of this specific critical state-flow refactor.
