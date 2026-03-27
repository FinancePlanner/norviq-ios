# MVP Roadmap

Status snapshot for the current iOS app scope.

## Already Done

### App Foundation

- [x] Authentication flow with login, validation, session handling, and token utilities
- [x] iOS-native app shell with five primary tabs: Home, Portfolio, Expenses, Reports, Settings
- [x] Shared visual system with light/dark mode support, finance-friendly color semantics, and reusable cards/backgrounds
- [x] MVVM structure across the main product areas already implemented so far

### Portfolio

- [x] Portfolio separated into its own feature folder with dedicated MVVM structure
- [x] Portfolio list with summary, add position, edit position, and delete position flows
- [x] Navigation from portfolio positions into stock details
- [x] Portfolio view-model tests

### Stock Details

- [x] Stock overview screen with valuation, history, news, and placeholders for thesis, earnings, and fundamentals
- [x] Edit valuation flow
- [x] Share/export stock snapshot for X, Discord, StockTwits, and similar channels
- [x] New stock detail tabs for `Overview`, `Projections`, and `Compare`
- [x] Mocked 5-year bear/base/bull stock projection model on the client
- [x] Mocked 3-stock comparison view for mandatory and advanced metrics on the client
- [x] Stock details view-model tests for sharing and mocked insights state

### Expenses

- [x] Expenses feature built around the three pillars: `Fundamentals`, `Future You`, and `Fun`
- [x] Salary-aware monthly planner on the client
- [x] Monthly plan editing, planned categories, actual expense recording, and month duplication
- [x] Expenses feature organized with its own MVVM structure
- [x] Budget planner view-model tests

### Reports

- [x] Reports tab connected to the same planner state as Expenses
- [x] Monthly and yearly comparison views
- [x] SwiftUI charts and list-based report summaries for spending, planning, and pillar breakdowns

### Onboarding and Profile

- [x] Onboarding flow for stock import/manual setup
- [x] User profile and settings screens
- [x] Existing auth, onboarding, and profile test coverage

## Still Missing For MVP

### Backend Integration

- [ ] Expenses API to persist salary, monthly plans, planned items, and actual expenses
- [ ] Reports API to return aggregated month/year/pillar analytics
- [ ] Real stock fundamentals, metrics, and financial results API integration for the new stock tabs
- [ ] Real earnings and fundamentals API integration in stock details

### Portfolio and Imports

- [ ] Finish portfolio polish where needed after backend integration
- [ ] End-to-end CSV stock import flow wired to production data flow
- [ ] API-based stock import flow

### Data Persistence and Sync

- [ ] Replace local in-memory planner/report state with backend-backed persistence
- [ ] Ensure stock projections and comparison tabs are hydrated from backend data instead of mocks
- [ ] Add refresh/error/empty-state behavior for all new backend-driven surfaces

### Testing Gaps

- [ ] Dedicated model tests for projection math in stock insights
- [ ] Dedicated tests for stock comparison metric formatting and grouping
- [ ] UI smoke tests for stock detail tab switching
- [ ] UI smoke tests for expenses planner and reports flows

### Release Readiness

- [ ] Verify accessibility on real devices for Dynamic Type, VoiceOver, contrast, and Reduce Motion
- [ ] Add final App Store readiness checks for production API configuration and error handling

## Recommended Next Order

- [ ] Build Expenses API
- [ ] Build Reports API
- [ ] Finish portfolio/API integration work
- [ ] Finish CSV stock import
- [ ] Build API stock import

## Notes

- App-side structure is ahead of backend integration.
- Expenses and Reports are the biggest remaining MVP gap because they still rely on client-side state.
- Stock projections and stock comparison are intentionally mocked on the client for now and should later read from your API.
