# SwiftUI Refactor Standard (MV-First Hybrid)

## Goal
Keep SwiftUI screens smaller and easier to scan without changing behavior or visuals.

## Default Architecture
- Default to MV for view orchestration.
- Prefer `@State`, `@Environment`, `.task`, `.task(id:)`, `onChange`, and explicit callbacks.
- Keep business logic in services/models.
- Keep existing MVVM where it clearly handles complex async/domain coordination.

## When to Keep a ViewModel
Keep or introduce a view model only when one or more are true:
- Multi-request async coordination with loading/error lifecycle across sections.
- Cross-screen shared state ownership.
- Complex caching, pagination, or debounced data pipelines.
- Non-trivial domain transformation that should not live in the view.

If none of the above applies, prefer direct MV orchestration in the view.

## Required Refactor Rules (from `swiftui-view-refactor`)
- Ordering: environment -> constants/lets -> state -> non-view computed vars -> init -> body -> view helpers -> helper methods.
- Extract meaningful sections into dedicated `View` types with small explicit inputs (`let`, `@Binding`, callbacks).
- Avoid replacing a giant `body` with many large computed `some View` fragments.
- Move non-trivial button/task/change actions out of `body` into small methods.
- Keep root view tree stable; avoid top-level branch swapping when localized conditions/modifiers work.
- For iOS 17+ `@Observable` owners, use `@State` in the owning view.

## Refactor Acceptance Criteria
For pure refactor PRs:
- No UX/behavior change.
- No navigation flow change.
- No API contract change.
- Build passes before and after changes.
- Smoke interactions still work (entry, primary CTA, search/filter, sheet open/close, refresh/task).

## Rollout Model
- Do not do big-bang repo-wide architecture rewrites.
- Apply to touched screens and scheduled wave screens.
- Keep PRs small and bounded by feature area.
