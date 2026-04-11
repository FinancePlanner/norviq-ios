# SwiftUI Refactor Wave 1 Plan

## Scope
High-impact screens prioritized by size and coupling:
1. `Features/Stocks/StockInsightsViews.swift`
2. `Features/Expenses/ExpensesPlannerScreen.swift`
3. `Features/Onboarding/OnboardingImportFlow.swift`
4. `Features/Crypto/CryptoHomeView.swift`
5. `Features/Auth/LoginScreen.swift`

## Execution Order
Refactor one screen per PR (or split into max two tightly related PRs when required).

## Per-Screen Checklist
- Reorder members to the standard top-down structure.
- Extract meaningful sections into dedicated subviews with explicit inputs.
- Move non-trivial inline actions and side effects out of `body`.
- Keep root tree stable and avoid top-level view swapping.
- Preserve behavior/layout/navigation/business logic.
- Keep view models only when they satisfy the MVVM retention criteria.

## Validation Per PR
- Build check:
  - `cd StockPlanIOSApp/financeplan && xcodebuild -project financeplan.xcodeproj -scheme financeplan -destination 'generic/platform=iOS Simulator' build`
- Manual smoke checks on touched screen:
  - Entry/navigation path
  - Primary CTA path
  - Search/filter interactions (if present)
  - Sheet/overlay present + dismiss
  - Task/refresh loading states

## Wave Exit Criteria
- All five screens refactored with no behavior regressions.
- No unresolved runtime warnings introduced by refactor.
- Follow-up bugfix issues logged for any discovered pre-existing defects.
