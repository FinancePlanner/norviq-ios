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

## 7) Reports Data Correctness (Implemented)
- Backend now guarantees a month snapshot exists when creating an expense:
  - `DefaultExpensesService.createExpense` normalizes `occurredOn` to UTC month start.
  - Auto-creates snapshot for that month (clone latest salary/target shares, fallback defaults) before inserting expense.
- Report month aggregation hardened to month-range matching (`>= monthStart && < nextMonthStart`) to avoid date-equality misses.
- Reports screen now reloads on every appearance:
  - `ExpensesComparisonScreen` triggers `reportsViewModel.load(force: true)` in `onAppear`.
- Cross-tab refresh added:
  - `BudgetPlannerViewModel` posts `.budgetPlannerDataDidChange` after successful snapshot/plan-item/expense writes.
  - `ExpensesComparisonScreen` and `HomeScreen` listen to this signal and refresh immediately.
- Portfolio fallback in reports:
  - `ReportsViewModel` now falls back to holdings from `StockServicing.fetchPortfolio()` when `/v1/reports/overview` returns zero positions/value.

## 8) Request/Contract Hardening (Implemented)
- iOS expenses endpoints now build payload dictionaries explicitly in snake_case (instead of relying on encoder strategy):
  - snapshots: `month_start`, `net_salary`, `target_shares`
  - expenses: `occurred_on`, `split_mode`, `user_share_percent`
  - plan items: `snapshot_id`, `planned_amount`, `split_mode`, `user_share_percent`
- Backend snapshot decode path now mirrors expense/plan-item tolerance:
  - `BudgetController` uses a `BudgetSnapshotPayload` that accepts both snake_case and camelCase keys (`month_start`/`monthStart`, etc.).

## 9) Validation Notes / Current External Blockers
- iOS auth suite blocker resolved:
  - `StockChannelShareSupport.swift` now uses fully-qualified `StockPlanShared` types for share formatter inputs.
  - `StockDetailsScreen.swift` call site for `StockOverviewTab` aligned with current initializer.
- Backend APNS compile blocker resolved:
  - `PushNotificationSender.swift` now returns `any APNSClientProtocol` instead of `APNSGenericClient`.

### Re-run status (2026-04-11)
- iOS:
  - `xcodebuild -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' -only-testing:financeplanTests/AuthHTTPClientTests test`
  - Result: **PASS** (`EXIT:0`)
- Backend:
  - `swift test --filter ExpensesTests/expenseAutoCreatesSnapshotForMonth`
  - Result: **PASS** (Swift Testing case passed: “Saving expense in a month without snapshot auto-creates snapshot and reports include it”)
