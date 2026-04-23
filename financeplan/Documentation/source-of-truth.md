# Client Source of Truth

This document defines where each feature gets its authoritative data, what is cached locally, and which mock paths are allowed. Runtime UI for a signed-in user should use API data or an explicit empty state. Demo data belongs in previews, tests, or explicit debug fixtures only.

| Feature | API Source | SwiftData Cache | Local/Draft State | Dev/Mock Only | Refresh Trigger | Ownership Boundary | Main Tests |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Auth | `/v1/auth/*` | None | Keychain/session store tokens and current user id | Auth HTTP mocks in tests | Login, token refresh, logout | Token subject defines current user | `AuthHTTPClientTests`, `AuthSessionManagerTests`, `LoginViewModelTests` |
| Billing | `/v1/billing/me`, RevenueCat webhook backend state | None | Paywall/settings display state | StoreKit/TestFlight sandbox only | App launch, settings open, purchase restore | Backend entitlement rows by user id | Backend `BillingTests` |
| Home | `/v1/dashboard`, `/v1/dashboard/insights`, `/v1/activity`, goals/focus APIs | Reads portfolio/expense local stores indirectly | Selected tab, sheets, quick-add inputs | Preview cards only | App foreground, dashboard appear, pull-to-refresh | Current user id from session and local cache owner id | `HomeDashboardTests`, dashboard backend tests |
| Portfolio | `/v1/stocks`, `/v1/portfolio/*` | `SDPortfolioStock` with `ownerUserId` | Add/edit/sell sheets and list selection | Preview holdings only | Portfolio appear, list switch, mutation success | `ownerUserId` plus backend bearer token | `PortfolioViewModelTests`, stock backend tests |
| Watchlist | `/v1/watchlist/*` | `SDWatchlistItem` with `ownerUserId` | Add/edit sheets and selected list | Preview symbols only | Watchlist appear, list switch, mutation success | `ownerUserId` plus backend bearer token | `WatchlistViewModelTests`, stock backend tests |
| Stock Details | `/v1/stocks/*`, `/v1/market/*`, `/v1/earnings/*` | None currently | Selected tab, chart range, DCF draft | Stock insight seeds and statement mocks only in previews/tests | Detail appear, tab/range changes | Backend validates authenticated user where user-owned data is involved | `StockDetailsViewModelTests`, market backend tests |
| Market Data | `/v1/market/*`, `/v1/assets/search` | Backend cache only | Search query and selected filters | API client mocks in tests | Search submit, chart/statement tab load | Mostly shared market data; provider limits enforced backend-side | `MarketDataHTTPClientTests`, `MarketDataServiceTests` |
| Expenses Planner | `/v1/budget/*`, `/v1/expenses/*`, `/v1/reports/*` | Expense, budget, category, recurring rows with `ownerUserId` | Plan item drafts, record-spend drafts, editor sheets | Preview rows only | Planner appear, month switch, mutation success, sync retry | `ownerUserId` plus backend bearer token | `BudgetPlannerViewModelTests`, `ExpensesHTTPClientTests`, backend expenses tests |
| Reports | `/v1/reports/*`, statistics endpoints | Reads expense/portfolio cache only as fallback where explicitly coded | Dashboard card order/preferences | Statistics mocks only in tests/previews | Reports appear, date range change, card refresh | Backend reports must aggregate by authenticated user | `ReportsViewModelTests`, backend report tests |
| Crypto | `/v1/crypto/*` | None currently | Portfolio form drafts | Demo refinements only in previews/tests | Crypto screen appear, mutation success | Backend crypto rows by authenticated user | `CryptoViewModelTests`, backend crypto tests |
| Notifications | `/v1/push/devices/*`, APNS | None | Permission state, pending token, route queue | Coordinator mocks in tests | Permission change, token registration, push receive | Device token registered to current user id | `PushNotificationsCoordinatorTests`, backend push tests |
| Profile | `/v1/users/me`, `/v1/users/{id}` | None | Edit form fields | Demo profile service responses only in previews/tests | Settings/profile appear, save success | Current user only unless explicitly authorized backend-side | `UserProfileHTTPClientTests`, backend profile tests |
| Badges & Activity | `/v1/badges`, `/v1/activity` | None | Presentation/filter state | API mocks in tests | Home/settings appear, relevant user action | Backend badge/activity rows by authenticated user | `BadgesViewModelTests`, `UserActivityTests` |

## Rules

- API is authoritative for server-owned financial data.
- SwiftData is a cache or offline queue, never a cross-user source of truth.
- Every SwiftData row that can appear in authenticated UI must be scoped by `ownerUserId`.
- Empty accounts render empty states, not sample holdings, sample expenses, or synthetic performance.
- Mock data may be used in SwiftUI previews, unit tests, and explicit debug fixtures only.
- Any new public API route must update backend `openapi.yaml` and the source-of-truth row for the affected feature.
