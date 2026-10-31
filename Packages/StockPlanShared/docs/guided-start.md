# Guided start and first-run funnel

The canonical contract for Norviq's onboarding on web and iOS. Every platform
implements the same funnel resume rule, the same three guided steps, the same
completion signals, and the same visibility rule. When a platform disagrees
with this file, this file wins.

Modelled on LuminaVault's `LuminaVaultShared/docs/guided-start.md`, minus the
mascot. Read that file's implementation notes before building an overlay.

## Why it is shaped this way

Norviq already has a first-run funnel (questionnaire → paywall → welcome →
import → budget → done), but its position lives in the web session and in iOS
`UserDefaults`. Log out, switch device, or reinstall, and the user starts over
or skips it entirely. The funnel position moves to the server so an unfinished
funnel resumes wherever the user signs in next.

After the funnel, new users land on the dashboard with no idea which of the
eight areas matters first. The guided card teaches by having them do the real
thing once: **add a holding, set a budget, set a goal.** Portfolio, spending,
and a target — the three things every other screen builds on.

It is a persistent card whose rows launch short steps, not a blocking tour.
Checklist-launched steps complete at several times the rate of auto-started
tours, and a tour before the user has data teaches nothing they can act on.

## The funnel

The funnel's steps and screens stay as they are. What changes is where the
position is stored.

| Field | Meaning | Written by |
|---|---|---|
| `funnelStep` | id of the step the user is on (`questionnaire`, `paywall`, `welcome`, `import`, `budget`, `done`) | client, on every advance and back |
| `funnelCompletedAt` | when the funnel finished or was skipped | client, once; one-way |

- On sign-in, a client reads onboarding state. If `funnelCompletedAt` is null,
  it opens the funnel **at `funnelStep`** (or the first step if null) and emits
  `onboarding_funnel_resumed` when `funnelStep` was non-null — at most once per
  session on both platforms. iOS guards it once per app session. Web settles it
  on the session's first read of an unfinished funnel, defers it while the
  PostHog capture-once slot is taken (e.g. by `user_logged_in`) so a later
  request emits it, and never emits it for a session that signed up or found
  no stored step.
- Web: `internal/onboarding/gate.go` and `RequireOnboardingComplete` read this
  instead of the session keys. The session keeps a copy for the request only.
- iOS: `ContentView` reads this instead of the per-user `UserDefaults` flags.
  `UserDefaults` stays as an offline cache and never overrides a server value.
- Questionnaire answers that are not already persisted stay client-local; only
  the position syncs.
- The server row is the only authority. `gate.go`'s old "has holdings means
  done" shortcut goes away: a user who imported holdings and left before the
  budget step resumes at `budget`. Accounts that predate this contract are
  covered by the launch backfill, not by the shortcut.
- Web records the step when each funnel page is shown and caches completion in
  the session, so the gate calls the backend at most until the funnel is done.
- iOS runs part of the funnel before sign-in, where nothing can be stored on
  the server. It resumes at flow granularity:

  | `funnelStep` | iOS shows |
  |---|---|
  | `questionnaire`, `paywall` | the authenticated paywall screen |
  | null, `welcome`, `import`, `budget` | `OnboardingImportFlow` from its menu |
  | any, with `funnelCompletedAt` set | Home |

  iOS PATCHes `import` when the paywall screen completes and `funnelCompleted`
  when the import flow finishes. If the read fails, iOS falls back to its
  `UserDefaults` flags.

## The three guided steps

| id | Card row | Line | Spotlight target | Done when |
|---|---|---|---|---|
| `add_holding` | Add a holding | "Add one stock or ETF you own." | `holding-add` | `addHoldingCompleted` |
| `set_budget` | Set your budget | "Enter your monthly take-home pay." | `budget-salary` | `setBudgetCompleted` |
| `set_goal` | Set a goal | "Pick one thing you're saving for." | `goal-create` | `setGoalCompleted` |

Card headline: **Get started with Norviq**. Progress reads `n of 3`.
Completion line: **"You're set up. Everything else builds on these three."**
Skip label: **Skip**. Dismiss is an `×` on the card.

The step id is also the analytics `step` property.

Targets are a separate vocabulary from steps — a target is a place in the UI.
On the web they are `data-guide` attribute values; on iOS they are anchor keys.

| Target | Web | iOS |
|---|---|---|
| `holding-add` | "Add position" (`portfolio-add-btn`) in `pages/portfolio/holdings.templ`, on `/portfolio` | `portfolio.addPositionButton` in the empty portfolio state, Portfolio tab |
| `budget-salary` | "Net salary" trigger (`expenses-budget-salary`) in `pages/expenses/planner.templ`, on `/expenses` | the "Add Budget" empty state and the inline "Create"/"Set" button in `ExpensesPlannerScreen`, Expenses tab — not the sheet itself |
| `goal-create` | "New goal" in `pages/goals/page.templ`, on `/goals` (financial goals) — not the dashboard's existing "Set goal" link, which opens focus-point goals on `/dashboard/insights` | two hops: `goal-card` (`GoalPlanningDashboardCard` on Home), then `goal-create` ("New goal" / "Create your first goal") inside the `GoalPlanningScreen` full-screen cover, which carries its own overlay |

If a target is not on screen — the user already has holdings and "Add position"
lives in a toolbar menu, say — the step shows its line without a dim. That is
the no-anchor rule below, working as intended.

## Completion is the server's word, never the client's

A client must **never** set a guided latch. The server latches each as a side
effect of the real write, through one idempotent upsert
(`INSERT … ON CONFLICT (user_id) DO UPDATE SET x = COALESCE(x, now())`). It is
awaited after the write succeeds and logs, never throws, on failure — a latch
failure must not fail the user's action.

| Latch | Set in | Deliberately not set in |
|---|---|---|
| `firstHoldingAt` | `StockServiceImpl.create`; `StockServiceImpl.bulkCreate` when `created > 0`; `BrokerController.importCsvCommit` and `importScreenshotCommit` when anything was inserted or updated | IBKR background sync, portfolio clone |
| `firstBudgetAt` | `BudgetController.createSnapshot` / `updateSnapshot`, only when `netSalary > 0` — in the controller, never in `ExpensesService` | `ensureCurrentMonthRollover` / `ensureSnapshotExists` (runs on every `GET /v1/budget/snapshots`), budgeting-engine clone |
| `firstGoalAt` | `GoalPlanningController.create` (`POST /v1/financial-goals`) | `POST /v1/goals` (focus-point goals, a different feature); `ScenarioController.createGoal` is unrouted |

Crypto holdings do not count toward `add_holding`. The backend latches
`firstHoldingAt` only when the created, inserted, or updated holding has
`category != crypto` (`AssetCategory.countsTowardAddHolding`); a bulk create or
broker commit latches when at least one such row is non-crypto. CSV and
screenshot imports store `category = stock`, so they always count. The launch
backfill applies the same rule in SQL.

After the user acts, poll `GET /v1/onboarding` at 1s, 2s, 4s, 8s, then every
10s, giving up after 5 minutes (emit `step_timed_out` and close the step
quietly). A local success signal triggers an immediate poll.

## API

`GET /v1/onboarding` returns the row, creating it on first read.
`PATCH /v1/onboarding` accepts only:

- `funnelStep` (string, any known id)
- `funnelCompleted: true` (one-way; `false` is rejected)
- `guidedStartDismissed` (bool; the only two-way guided field)

Any latch field in a PATCH is rejected with 400.

Response shape (`OnboardingStateDTO` in `StockPlanShared/Onboarding/`):

```
funnelStep            String?
funnelCompletedAt     Date?
addHoldingCompleted   Bool     firstHoldingAt  Date?
setBudgetCompleted    Bool     firstBudgetAt   Date?
setGoalCompleted      Bool     firstGoalAt     Date?
guidedStartDismissedAt Date?
```

The web reaches it through a hand-written `DoJSON` wrapper in
`norviq-web/internal/api/`, like `dca_capacity.go`, and `openapi.yaml` gains
both operations.

## Visibility

```
loaded    := an onboarding snapshot is in hand   (nil or loading → render nothing)
allDone   := addHoldingCompleted && setBudgetCompleted && setGoalCompleted
dismissed := guidedStartDismissedAt != nil
visible   := loaded && funnelCompletedAt != nil && !allDone && !dismissed
```

- **Dismiss** hides optimistically, then PATCHes; on failure, un-hide and say so.
- **Settings › "Show me around"** clears the dismissal. If everything is done,
  show the completed card for that session only.
- **Starting a step** refreshes first; if its latch is already true, skip to the
  first incomplete step.
- **A latch flipping elsewhere while a step is open** completes it normally,
  with `completed_elsewhere: true`.
- **Dismissal from another device** hides the card at the next refresh, after
  any open step closes.

At most one step is ever active.

## Sharing the dashboard

While the card is visible it owns the top of the dashboard. On the web,
`OverviewAttentionPanel` and the "Finish setup" panel stay hidden; on iOS, any
promotional or setup strip in `DashboardContentSection` does the same. They
return once the card is completed or dismissed.

## Navigating to targets

Every target is on another page or tab.

- **Web:** starting a step stores it in the session and redirects to the
  target page. Every app page renders the step layer while the session holds a
  step, so it survives the user's own form submit and the redirect after it.
  Polling uses a server-returned `hx-trigger="load delay:Ns"` that escalates,
  because `every` cannot back off; the first poll after any page load is at
  1s, which is how a local action gets its prompt check. The handlers behind
  the three targets note a local action in the session, which is what makes
  `completed_elsewhere` false.
- **iOS:** the coordinator lives in `HomeScreen` next to `selectedTab` and asks
  for a tab through `requestedTab`. The overlay sits above the `TabView`,
  ignores safe areas, and filters anchors by the active tab. The goal cover
  attaches a second overlay for its own anchors. Dismissing the add-position,
  salary, or goal sheet counts as the local action.

## Spotlight rules

- Nothing is blocked, on web or iOS: the scrim ignores touches everywhere, not
  only in the hole, so the page keeps scrolling and the control being taught
  stays usable. Only the bubble takes touches.
- **No anchor, no dim.** If the target has not reported a frame, show the bubble
  without a scrim rather than a dim with nothing to tap.
- Not modal to assistive technology. Focus moves to the step's line when it
  opens, Skip is a real button, Escape skips.
- Every transition respects reduced motion.

## Analytics

PostHog. Names are identical on web and iOS, unprefixed, matching Norviq's existing
events (`onboarding_completed`, `cta_clicked`); the SDK's `$lib` tells platforms apart.

```
guided_start_card_shown        (none)
guided_start_step_started      step, source(auto|settings)
guided_start_step_completed    step, elapsed_ms, completed_elsewhere
guided_start_step_skipped      step, elapsed_ms
guided_start_step_timed_out    step, elapsed_ms
guided_start_dismissed         (none)
guided_start_reopened          (none)
guided_start_completed         (none)

onboarding_funnel_resumed      step
```

`card_shown` fires once per app session. `completed` fires when the wizard
reaches its finished state (the completed card is showing), not when the last
latch flips on the server. `dismissed` fires only after the dismissal PATCH
succeeds, on both platforms. Existing funnel events keep
their names.

## Launch migration

One migration creates `onboarding_state` and backfills every existing user:

```sql
INSERT INTO onboarding_state (user_id, first_holding_at, first_budget_at, first_goal_at,
                              funnel_completed_at, guided_start_dismissed_at)
SELECT u.id,
       (SELECT min(s.created_at) FROM stocks s WHERE s.user_id = u.id AND s.category <> 'crypto'),
       (SELECT min(b.created_at) FROM budget_snapshots b WHERE b.user_id = u.id AND b.net_salary > 0),
       (SELECT min(g.created_at) FROM financial_goals g WHERE g.user_id = u.id),
       now(), now()
FROM users u
ON CONFLICT (user_id) DO NOTHING;
```

Existing accounts are therefore funnel-complete and dismissed; "Show me around"
brings the card back with their real progress. Only signups after the
migration see it automatically.

## Out of scope

- No mascot or reaction states.
- No change to funnel screens, paywall, or questionnaire content.
- `GET /v1/dashboard/insights` is not a signal for anything here — iOS calls it
  on every Home load.
