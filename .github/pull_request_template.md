## Summary
- 

## SwiftUI Refactor Checklist (MV-First Hybrid)
- [ ] I applied `swiftui-view-refactor` guidance where relevant to touched screens.
- [ ] I kept behavior/layout/navigation/business logic unchanged (or called out intentional fixes).
- [ ] I moved non-trivial inline actions/side effects out of `body` where feasible.
- [ ] I used dedicated section subviews with explicit inputs (`let`, `@Binding`, callbacks).
- [ ] I preserved a stable root view tree (no unnecessary top-level branch swapping).
- [ ] For iOS 17+ `@Observable` owners, ownership uses `@State` in the root owner where appropriate.
- [ ] I only kept/used view models where complex async/domain coordination justifies it.

## Validation
- [ ] Build passes:
  - `cd StockPlanIOSApp/financeplan && xcodebuild -project financeplan.xcodeproj -scheme financeplan -destination 'generic/platform=iOS Simulator' build`
- [ ] Manual smoke checks passed for changed screen(s):
  - [ ] Screen entry/navigation
  - [ ] Primary CTA interactions
  - [ ] Search/filter flows (if present)
  - [ ] Sheet/overlay presentation and dismissal
  - [ ] Loading/refresh/task states

## No UX/Behavior Change Note
Describe why this PR is behavior-preserving (or list explicit bug fixes with evidence):

- 
