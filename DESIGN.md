---
name: Norviq
description: Financial intelligence for people who plan before they act. Discipline creates freedom.
colors:
  tint: VigilTint
  tint-soft: VigilTintSoft
  tint-secondary: VigilSecondaryTint
  on-tint: OnTint
  accent: AccentColor
  page: VigilPageBackground
  card: VigilCardBackground
  card-elevated: VigilElevatedCard
  top-bar: VigilTopBarBackground
  launch: LaunchBackground
  text: VigilForeground
  text-secondary: VigilSecondaryText
  text-tertiary: VigilTertiaryText
  separator: VigilSeparator
  fill-tertiary: TertiaryFill
  gain: VigilGain
  loss: VigilLoss
  flat: VigilFlat
  info: VigilInfo
  warning: VigilWarning
typography:
  display-number:
    fontFamily: "SF Pro"
    fontSize: "40"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "normal"
  display-title:
    fontFamily: "Brygada 1918"
    fontSize: "28"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "normal"
  hero:
    fontFamily: "SF Pro"
    fontSize: "32"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "normal"
  title:
    fontFamily: "SF Pro"
    fontSize: "24"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "normal"
  headline:
    fontFamily: "SF Pro"
    fontSize: "20"
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: "normal"
  body:
    fontFamily: "SF Pro"
    fontSize: "17"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "normal"
  label:
    fontFamily: "SF Pro"
    fontSize: "15"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "normal"
  caption:
    fontFamily: "SF Pro"
    fontSize: "12"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "normal"
  overline:
    fontFamily: "SF Mono"
    fontSize: "caption2"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "1.2"
rounded:
  control: "12"
  card: "16"
  hero: "20"
spacing:
  xs: "4"
  sm: "8"
  md: "12"
  lg: "16"
  xl: "24"
  xxl: "32"
components:
  button-primary:
    backgroundColor: "{colors.tint}"
    textColor: "{colors.on-tint}"
    rounded: "{rounded.card}"
    padding: "15 0"
  button-primary-pressed:
    backgroundColor: "{colors.tint}"
    textColor: "{colors.on-tint}"
  card:
    backgroundColor: "{colors.card}"
    textColor: "{colors.text}"
    rounded: "{rounded.hero}"
    padding: "16 16"
  card-elevated:
    backgroundColor: "{colors.card-elevated}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
  input:
    textColor: "{colors.text}"
    typography: "{typography.label}"
    rounded: "8"
    padding: "13 16"
  input-focused:
    backgroundColor: "{colors.tint-soft}"
  status-chip:
    backgroundColor: "{colors.gain}"
    textColor: "{colors.gain}"
    padding: "4 8"
---

# Design System: Norviq

## 1. Overview

**Creative North Star: "The Precision Instrument"**

Norviq is an instrument for reading your own money, not a feed. The identity is Precision
Intelligence: obsidian and midnight navy in dark, warm paper in light, with one metal, gold, used
sparingly. The interface represents discipline and the data represents reality, so nothing
decorative is allowed to compete with a number. Surfaces are flat and quiet, type is system SF (with
Brygada 1918 for page titles and the Home greeting only), and every figure sits in tabular digits
with measured contrast.

Density is deliberate: these are disciplined investors checking a position or a plan in a short
session. Screens favor system structure (`NavigationStack`, inset grouped `List`, `Form`, sheets with
detents) over invented chrome, and reach for the shared primitives (`AppTheme`, `AppMotion`,
`GlassCard`, the `vigil*` screen modifiers) before anything bespoke. Dark is the flagship appearance;
light is first class and user selectable.

Motion is restrained and tokenized in `AppMotion`: press 0.15 s, state 0.2 s, structural spring
without overshoot, one data reveal at 0.24 s, and an opacity-only fallback under Reduce Motion. A
changing value in a table is never animated. The system rejects glow, mesh gradients, neon,
decorative circuitry, gamified trading cues, and the default SwiftUI tutorial stack of identical
shadowed cards. Token names keep the `Vigil` prefix on purpose: bare role names collide with
SwiftUI's own `ShapeStyle` members.

**Key Characteristics:**

- Flat, bordered surfaces; depth comes from three tonal steps, not shadow.
- One accent metal on about 10% of a screen.
- Financial color is a separate vocabulary from brand color.
- System controls and SF type; Dynamic Type everywhere.
- One display serif, Brygada 1918, for page titles and the greeting. Never for a number.
- Legible and correct with motion and effects off.

`DESIGN.json` at the repo root is historical and not read by code. This file, `Design/tokens.json`
and the code are the current sources.

## 2. Colors

Tinted neutrals carry the screen; gold marks intent; green and red speak only about money.

**Source.** Every `Theme/*.colorset` is generated from `financeplan/Design/tokens.json` by
`scripts/tokens/generate_colorsets.py` (`make tokens`). Never edit a colour set by hand. Edit the web
master `norviq-web-v2/design/tokens.json`, copy it here byte for byte, then run `make tokens`.
`make tokens-check` (CI) fails on a stale or hand-edited set, and `VigilDesignSystemTests` asserts
every set equals its token exactly, light and dark, alpha included. Each set's token is the one whose
`$extensions.norviq.ios` names it. `AccentColor` and `LaunchBackground` sit outside `Theme/` and are
not generated.

### Primary / Accent

- **Deep Gold / Champagne Gold** (Color Set: `VigilTint`, dark-mode variant: yes): the primary action
  fill, selection, focus and the active nav item. Deep gold in light, champagne in dark.
  `AccentColor` carries the same pair for system controls.
- **Gold Wash** (Color Set: `VigilTintSoft`, dark-mode variant: yes): a 10 to 12% gold fill behind a
  focused input or a selected row.
- **Precision Gold** (Color Set: `VigilSecondaryTint`, dark-mode variant: yes): the brighter second
  gold for overlines and scope chips. `ember` and `bronze` in code alias to it.
- **Ink on Gold** (Color Set: `OnTint`, dark-mode variant: yes): text on a gold fill. White in light,
  obsidian in dark, because white on champagne gold fails contrast.

### Background / Surface

- **Warm Paper / Obsidian** (Color Set: `VigilPageBackground`): the page canvas. `LaunchBackground`
  matches it so launch does not flash.
- **Card / Midnight Navy** (Color Set: `VigilCardBackground`): cards and chart surfaces.
- **Raised Paper / Armor Blue** (Color Set: `VigilElevatedCard`): elevated panels, popovers, themed
  list rows.
- **Top Bar** (Color Set: `VigilTopBarBackground`): navigation and tab bar chrome.

### Label / Text

- **Deep Navy / Platinum** (Color Set: `VigilForeground`): primary text.
- **Slate / Muted Silver** (Color Set: `VigilSecondaryText`): secondary text and metadata.
- **Quiet Slate** (Color Set: `VigilTertiaryText`): tertiary text; never for anything the user must read.
- **Hairline** (Color Set: `VigilSeparator`): the 1pt border on every card and the glass fallback
  stroke. Decorative only; it is below 3:1 by design. `TertiaryFill` is the matching quiet fill.

### Semantic / State

- **Gain** (Color Set: `VigilGain`) and **Loss** (Color Set: `VigilLoss`): direction of money. In code,
  `success` and `danger` alias to them for status (connected, failed).
- **Flat** (Color Set: `VigilFlat`): unchanged.
- **Information** (Color Set: `VigilInfo`) and **Warning** (Color Set: `VigilWarning`).

All twenty Color Sets carry a Dark Appearance variant. There are no gaps.

### Named Rules

**The Gold Is Not Money Rule.** Gold never means profit. It marks the primary action, selection and
focus, on about 10% of a screen. Not every card, not every border.

**The Never Color Alone Rule.** Gain and loss always travel with a sign, an arrow or a spoken label.
Raw `.green` and `.red` are forbidden; `make check-pnl-colors` fails the build on them.

**The Twelve Percent Chip Rule.** A status or direction chip is the semantic color as text on a 12%
fill of itself. That is the pair the identity spec measured at 4.5:1 or better.

## 3. Typography

**Display Font:** Brygada 1918 (OFL), page titles and the Home greeting only
**Body Font:** SF Pro (system, scaled through `UIFontMetrics`)

**Character:** SF carries the product. Hierarchy comes from the size ladder and weight, with the
monospaced overline and tabular numerals as its signature. One editorial serif, Brygada 1918, sets
the page title in `VigilPageHeader` and the Home greeting, and nothing else (DS 2.0 § 9.0 Q2).

**Display face files.** `financeplan/Resources/Fonts/Brygada1918-SemiBold.ttf` (a static TTF, the
same file the brief export embeds) with `OFL.txt`, which ships with it, registered through
`UIAppFonts` in `Info.plist`. PostScript name `Brygada1918-SemiBold`. Only SemiBold ships because no
role sets the display face lighter; any weight on `.displayTitle` resolves to it. If it fails to
register, `.displayTitle` falls back to the system serif (New York) at the same size, never to
nothing. `Design/tokens.json` is excluded from the Release bundle; it is read by tests and scripts,
not by the app.

Two routes exist and both honor Dynamic Type: SwiftUI semantic styles (`.headline`, `.subheadline`,
`.caption`) on system `List` and `Form` screens, and the `Typography` ladder via `.typography(_:)`
on designed surfaces. The ladder uses fixed design sizes that scale relative to a text style.

### Hierarchy

- **Display number** (semibold, 40pt scaled as largeTitle, tabular): the one large figure on a screen.
- **Display title** (Brygada 1918 SemiBold, 28pt scaled as title, `.typography(.displayTitle)`): the
  page title in `VigilPageHeader` and the Home greeting (iOS 26 large-title slot; iOS 18 keeps the
  system title). Wraps, never truncates: the greeting takes up to two lines, then shrinks to 80%. A
  ticker title (stock and crypto detail) passes `titleStyle: .title` and stays SF.
- **Hero** (bold, 32pt scaled as title): a screen's lead statement.
- **Title** (bold, 24pt scaled as title2): section and card titles. `metricNumber` shares the size,
  semibold and tabular.
- **Headline** (semibold, 20pt scaled as title3): card headings.
- **Body** (regular, 17pt): reading text. `numeric` shares the size, tabular.
- **Label** (regular, 15pt scaled as callout): form fields, controls, secondary lines.
- **Caption** (regular, 12pt) and **Footnote** (regular, 11pt): metadata.
- **Overline** (bold monospaced caption2, tracking 1.2, uppercase, via `.vigilOverline()`): the kicker
  on page headers and themed section headers. The only uppercase in the product.

### Named Rules

**The Tabular Rule.** Any number that can sit next to another number uses tabular digits:
`.monospacedDigit()` or a numeric `Typography` role.

**The Steps You Can See Rule.** The ladder is 17 / 15 / 13 / 12 / 11. Do not add a size between two
steps; a 1pt difference is not hierarchy.

**The Display Face Rule.** Brygada 1918 sets page titles and the greeting. Never a number, a ticker,
a table, a control or body text. Figures stay SF tabular; `DisplayFontTests` fails if a numeric role resolves
to the serif.

### Money

`MoneyFormatter` (`financeplan/Utilities/MoneyFormatter.swift`) is the one way to print money
(spec § 5.4). The currency comes from the data and is never defaulted to USD: a missing or blank
code prints the number followed by " —". The locale follows the app language (en → en_US,
pt-PT → pt_PT), not the phone's region. Call sites pass the finished string to `Text`; they do not
use `Text(_, format:)` or `.formatted()` for money.

Output is normalised to the shared golden fixtures, `docs/design-system-fixtures/money.json`, which
web and Android run too. `financeplanTests/Fixtures/money.json` is a byte copy (never edit it here),
and `MoneyFormatterTests.testFixtures` proves every iOS case against it.

## 4. Elevation

Flat by design, with glass reserved for chrome and controls. Depth is three tonal steps (page, card,
elevated card) plus a 1pt hairline. Content is solid: `GlassCard` (the name is historical) and every
other card, panel, list row and sheet content block draw `.appCardSurface(cornerRadius:)`, a
`VigilCardBackground` fill plus a 1pt `VigilSeparator` stroke, with no material and no shadow.

Native Liquid Glass goes only on chrome and controls: the tab bar, nav bars and toolbars, the range
control, filter and segment chips, floating buttons and the toast. They go through `.appGlassEffect()`
(`GlassEffect+Compat.swift`): native `.glassEffect` on iOS 26, and below that a fill, a hairline stroke
and one soft shadow. With Reduce Transparency on, chrome falls back to a solid `VigilTopBarBackground`
fill plus the separator stroke.

### Material Vocabulary

- **Card surface** (`GlassCard` over `.appCardSurface(cornerRadius:)`): every card-shaped surface.
  Solid on every OS version.
- **Chrome glass** (`.appGlassEffect(_:tint:interactive:)`, `AppGlassContainer`, `appGlassEffectID`):
  chrome and controls only. Feature code never calls `.glassEffect`, `GlassEffectContainer` or
  `.glassEffectID` directly (`LiquidGlassTests` enforces it).
- **Fallback chrome shadow** (`.shadow(color: .black.opacity(0.05), radius: 12, y: 6)` light;
  `0.18`, radius 16, y 10 dark): pre-iOS 26 only, applied inside `appGlassEffect`.
- **Fallback capsule and circle shadow** (`.shadow(color: .black.opacity(0.04), radius: 8, y: 3)`).
- **System materials** (`.thinMaterial`, `.regularMaterial`, `.ultraThinMaterial`): floating circles,
  sheets and the tab bar capsule. Not cards, not page backgrounds.
- **Page** (`.vigilScreenBackground()` and `.vigilListChrome()`): a flat `VigilPageBackground` canvas
  under every themed screen and list.

### Named Rules

**The One Card Rule.** Card-shaped surfaces go through `GlassCard` or `.appCardSurface`. Feature code
does not put `.appGlassEffect()` on content, stack its own material, or add a shadow.

**The No Glow Rule.** No glow, no colored shadow, no gradient wash, no rim highlight.

## 5. Components

### Buttons

- **Shape:** softly squared (16pt radius), full width for the primary action.
- **Primary:** `GlowingButtonStyle`: `VigilTint` fill, `OnTint` label, 15pt vertical padding. The name
  is historical; there is no glow. System `.borderedProminent` tinted with `VigilTint` is the
  equivalent inside lists, forms and gates.
- **Press state:** `PressableStyle` for any tappable card, row or custom button: scale 0.97 and
  opacity 0.9 over `AppMotion.press`; scale is dropped under Reduce Motion.
- **Busy:** keep the title and add a trailing `ProgressView`; disable the control. Never swap the
  title for a spinner.
- **Destructive:** system `role: .destructive`, confirmed with a `confirmationDialog`.

### Cards / Containers

- **Corner Style:** continuous corners; 16pt (`AppTheme.Radius.card`) default on `GlassCard` and
  `appCardSurface`, 20pt (`AppTheme.Radius.hero`) passed explicitly for hero cards, 12pt
  (`AppTheme.Radius.control`) for controls and themed list rows.
- **Background:** solid `VigilCardBackground`, on every OS version. Never glass.
- **Shadow / Material Strategy:** see Elevation; none added by feature code.
- **Border:** 1pt `VigilSeparator`.
- **Internal Padding:** SwiftUI adaptive `.padding()` by default; pass an explicit value only when
  converting a surface that had none.
- A metric does not earn a card, and cards are never nested.

### Inputs / Fields

- **Style:** `FormTextField` inside a `FormCard`: no stroke, clear background, 8pt radius, 16pt by
  13pt padding, optional leading symbol at 24pt width. System `TextField` and `SecureField` inside
  `Form` for short credential sheets.
- **Focus:** a `VigilTintSoft` fill behind the field.
- **Error / Disabled:** `FormErrorBanner` (a `VigilLoss` tinted surface) or inline `VigilLoss` text
  next to the field. The error must be visible on the surface where the action was taken.

### Navigation (DS 2.0)

Five tabs, one stack per tab, one resolver. The design record for every name, hub row and gate is
the destination table, `../../docs/superpowers/plans/2026-11-25-ds2-p3-destinations.md` in the
norviq workspace docs (outside this repo). Labels come from it verbatim, and a destination has one
name on every platform.

#### Tabs

| Tab | pt-PT | Symbol | Root |
|---|---|---|---|
| Today | Hoje | `sun.max` | `DashboardRoot`. The toolbar has the bell (Notifications) and the account avatar (Settings) |
| Money | Dinheiro | `creditcard` | `ExpensesPlannerScreen`, titled "Budget" |
| Wealth | Património | `chart.line.uptrend.xyaxis` | `PortfolioRoot`. Crypto is pushed from its Planning menu |
| Plan | Plano | `target` | `PlanHubScreen`, a hub, with "New goal" (opens Goals) in the toolbar |
| More | Mais | `ellipsis.circle` | `MoreHubScreen`, a hub. Its tab badge is the Groups and Friends counts added up |

`AppTab` holds the order, titles and symbols. The `TabView` is `.sidebarAdaptable`: on iPad the
sidebar lists the five tabs only. Hub sections as sidebar groups are deferred, so one resolver
serves iPhone and iPad.

#### Hubs

Plan and More are lists of rows, built by `PlanHubModel` and `MoreHubModel` and drawn by
`HubSectionsView`:

- **Plan:** Goals (Goals); Your future (Net worth forecast, Retirement, Scenarios, Simulator, Grow,
  Tools); Tax (Tax strategy, Terminal sizing).
- **More:** the account row (avatar, name, Pro or Free; opens Settings); Intelligence (Market brief,
  Markets, Economy, Insights, Reports, Chart builder); Community (Groups, Friends, Boards); Account
  (Brokers and imports, Settings).

Rules:

- A row whose feature is switched off is left out, never shown disabled: Groups needs `groups`,
  Friends needs `social`. Boards has no switch, so Community is never empty.
- A Pro row carries `ProBadge`: Insights, Net worth forecast and Scenarios. A user who isn't Pro
  gets `PaywallView` as a sheet presented by the hub itself, in place: nothing is pushed and the
  tab never changes. Tax strategy and Chart builder are free on iOS today, so they have no badge,
  although the table gates them on web.
- Market brief is a card on Today, so its row selects Today and opens the card. It is the only row
  that leaves its tab.
- Groups and Friends each show their own "N new" count.

#### One stack per tab

- Each tab root owns the tab's only `NavigationStack`. A pushed screen never adds a stack of its own
  and shows Back, never Close.
- Hub rows and deep links push `AppDestination` values, and `destinationView` builds the screen.
  Settings is a push (More › Settings, the account row, the Today avatar), not a sheet.
- Today, Plan and More bind their stacks to paths held by `HomeScreen`, so a request can land
  there. Money's and Wealth's roots keep a plain stack, because no request lands above them.
- Themed screens use `VigilPageHeader` in content, with `.vigilNavigationTitle`,
  `.vigilInlineNavigationBar`, `.vigilListChrome` and `.vigilScreenBackground` applied together. A
  screen that omits them flashes the system grouped background between two themed ones.
- Sheets use detents (`.medium`, `.large`), a Cancel item on the leading side and the confirming
  action on the trailing side.

#### The resolver

`NavigationResolver.target(for:groupsEnabled:socialEnabled:)` is the one place that maps a
`NavigationRequest` (a push, a deep link, or a hub row that leaves its tab) to a tab and a path. It
returns `nil` when the request needs a feature that is off. It decides only where to land; side
effects such as a pending symbol, a pending invite or group link, or the brief router stay with
`HomeScreen`.

`NavigationTarget.path(replacing:)` replaces whatever is open on the tab, except that a tab already
on the target keeps what sits above it, so an open group is not popped mid-link. Accepted owner
decision: a friend request tapped inside Groups replaces Groups with Friends, so Back goes to More.

#### Q entry point

- **iOS 26 and later:** Q is the tab bar's bottom accessory, attached once to the `TabView` with
  `.qAccessory(...)`.
- **Below iOS 26:** a floating button at the trailing edge, above the tab bar, drawn in each tab
  root by `.qEntryPoint()`. Both carry the id `q.entry`.
- **`.hidesQAccessory()`:** for a pushed screen with its own controls at the bottom, where Q would
  cover them (Rebalancing, a group chat, a board post). On iOS 26.1 and later it hides the accessory
  through `tabViewBottomAccessory(isEnabled:)`, which keeps the pushed screen. Below 26 the floating
  button hides. An active guided-start step hides Q the same way.
- **iOS 26.0 (accepted owner decision):** the accessory never hides. 26.0 has no `isEnabled`, and
  adding or removing the accessory rebuilds the `TabView` and pops the screen that asked. The
  accessory joins the safe area there, so a bottom action sits above it.
- **Tap:** for anyone with summaries (`ai_insights`: Pro, unless the server says otherwise), a tap
  opens the AI summary of what is on screen, using the screen's `qScope` or, failing that, the
  tab's. A free user gets the Quick Q card, and so does everyone on More's hub, which has nothing to
  summarise. `QEntryRoute.resolve` holds these rules.
- **Hold:** always the card.
- **While the card is open (accepted owner decision):** the accessory stays visible, dimmed behind
  the card's scrim, on iOS 26.1 and later too, where it could hide. Below 26 the floating button
  gives way to the card and comes back when it closes.

### SF Symbols usage

- **Rendering mode:** monochrome, tinted by the surrounding foreground style.
- **Weight matching:** symbols take the weight of the adjacent text through `.font()`.
- Decorative symbols are `.accessibilityHidden(true)`; a symbol that carries meaning has a label.

### Empty, loading and gated states

- **Empty:** `ContentUnavailableView`, or `EmptyStateView` where Vig appears. Vig belongs in empty
  states, onboarding and the assistant, never in a data view.
- **3D Vig (beta-only experiment, BRD-001):** in Debug and Beta builds only, the Welcome screen may
  show Vig as a real-time 3D bust: a non-AR `RealityView` with a virtual camera, transparent over
  SwiftUI. The flat bust (`vig-poster.png`, fetched with the model; `VigFull` without it) shows
  until the first frame, and stays under Reduce Motion and Low Power Mode. Motion comes only from `vig-motion.json` (entrance, ±4° sway, drag tilt), with no
  blink and no glow, and lights use `AppTheme.Colors`. The Release build excludes the model and the
  code (`EXCLUDED_SOURCE_FILE_NAMES`), and `scripts/verify-release-no-3d.sh` proves it. Canonical
  rule: `../../docs/precision-identity.md`. Backlog and architecture: `norviq-web-v2/docs/BACKLOG.md`
  BRD-001, `norviq-web-v2/docs/vig-3d.md`.
- **Loading:** inline `ProgressView` at the action, or `LoadingEmblem` (a four-point star, static
  under Reduce Motion). Make no claim about state until the first load answers.
- **Pro gate:** `ProGateView` blurs its content and shows one upgrade prompt for the whole gated
  group, sized so a short row grows to fit it.
- **Feedback:** `ToastBanner` for transient results; `appSensoryFeedback(success:destructive:)` on
  completion and on destructive results.

### Components (DS 2.0)

Canonical set from the design-system spec (§6.1). The semantic names are the shared vocabulary with web
and Android; the SwiftUI column is what iOS uses. Status is as of DS 2.0 P2b.

| Semantic component | SwiftUI | Status |
|---|---|---|
| Page | `vigilScreen` modifiers + `VigilPageHeader` (see Navigation) | exists |
| Section (rule, not card) | `Section` in `List` / a `VigilSection` | not yet (P3/P4) |
| Card (actionable object only) | `GlassCard` (renamed `NorviqCard` in P5, alias kept) | exists; rename P5 |
| MoneyText / DeltaText | `MoneyText`, `DeltaText` (pure `DeltaText.Model`), on top of `MoneyFormatter` | done (P2b) |
| MetricTile | `MetricTile`, tones neutral/gain/loss/warning, value style `.regular` (24pt `metricNumber`) or `.compact` (~17pt `numeric`, for rows of three or more, e.g. the portfolio hero); replaces the Budget `MetricItem` view, `SummaryMetric` and `PortfolioMetricPill` | done (P2b); other tiles (e.g. `PillarMetricItem` in `ExpensesPlannerScreen`, stock-insight tiles) stay legacy until P4 |
| DataTable | `Table` (iPad) / `List` rows | not yet (P3/P4) |
| RangeControl | `RangePicker` (native segmented) over `ChartRange`; replaces `PortfolioRangeButton` (removed) | done (P2b) |
| SegmentedControl | native `.segmented` picker | exists (system) |
| Chart | Swift Charts wrappers (`Components/Charts`); `InteractiveLineChart` is still custom | partial; line-chart move legacy / P4 |
| EmptyState | `ContentUnavailableView` (+ Vig via `EmptyStateView` only on onboarding-type empties) | exists |
| Skeleton / ErrorRetry / StaleData | `.redacted` / `.shimmer()`, `ErrorRetryView`, `AsOfText` | exists; `AsOfText` done (P2b) |
| Buttons | `GlowingButtonStyle` → `PrimaryButtonStyle`, system bordered | `PrimaryButtonStyle` not yet (P5) |
| Toast | `ToastPresenter` / `ToastBanner` | exists |
| Floating action zone | `tabViewBottomAccessory` on iOS 26+, floating button below (see Q entry point) | done (P3) |

#### Money, change and staleness

- Amounts go through `MoneyFormatter` (`string`, `signed`, `percentSigned`) via `MoneyText` and
  `DeltaText`. A missing currency renders " —", never "$". Do not add new `Double.currency` or
  `compactCurrency` calls.
- A change always carries its basis: `DeltaText(fraction:basis:...)` and `DeltaText.Model.make` take `basis` as a required `String` (pass "" only where no period exists). Its VoiceOver label uses the catalog keys `up %@`, `down %@` and `unchanged %@` with the percent as the argument, as on web.
- `AsOf.isStale(_:now:calendar:)` is true when the last point is
  more than 4 calendar days old; the change is then hidden and `AsOfText` shows "Prices as of
  {date}" in the warning colour. `AsOf.label(_:locale:calendar:)` is a fixed `d MMM yyyy`.
- **Calendar rule.** Dates parsed from `yyyy-MM-dd` series strings are UTC midnight. Pass a UTC
  Gregorian calendar to `AsOfText(_:now:calendar:)`, `AsOf.isStale` and `AsOf.label`, as
  `PortfolioHeroModel` does. With `.current`, the label and the staleness shift by a day in
  non-UTC zones. Web compares civil dates in UTC, so this keeps the platforms equal.

#### Six states (every data view)

Each data view handles all six; none is skipped silently.

1. **Loading:** `.redacted(reason: .placeholder)` or `.shimmer()` skeleton at the final size. No
   claim about state before the first load answers.
2. **Empty (first-time):** `ContentUnavailableView`. `EmptyStateView` (with Vig) only for
   onboarding-type empties.
3. **Empty (filtered):** `ContentUnavailableView.search` or one with a "clear filters" action.
4. **Error with retry:** `ErrorRetryView`.
5. **Stale:** `AsOfText` (see above).
6. **Pro-gated:** `ProGateView`.

Never show synthetic data in place of a state.

#### Chart ranges

The display vocabulary is `1D 1W 1M 3M YTD 1Y 5Y ALL` (`ChartRange`). A chart offers only the ranges
its data supports, through `RangePicker`:

| List | Ranges |
|---|---|
| `ChartRange.portfolio` | 1W 1M 3M 1Y ALL (YTD hidden until the portfolio API serves it) |
| `ChartRange.asset` | 1D 1W 1M 3M 1Y 5Y (`PriceChartRange` has no YTD or ALL) |
| `ChartRange.crypto` | 1D 1W 1M 3M YTD 1Y ALL |

Each API keeps its own wire values. Convert with the failable inits (`PortfolioScreen.TimeRange(_:)`,
`PriceChartRange(_:)`, `CryptoChartRange(_:)`, and `ChartRange(_:)` back); a `nil` means the chart does
not offer that range. `RangePicker` requests a 44pt minimum height; whether the real segment hit area reaches 44pt is an owner device check.

#### Lint: design literals

`.swiftlint.yml` has two custom rules at error severity, for new code under `financeplan/` (tests,
packages and tooling excluded):

- `design_literal_corner_radius`: no `cornerRadius: <number>`. Use `AppTheme.Radius` (control 12,
  card 16, hero 20).
- `design_raw_font_size`: no `.font(.system(size:`. Use `.typography(...)`.

The existing violations (339: 294 radius, 45 font size) are in `.swiftlint.baseline.json`, and
`scripts/format.sh` passes `--baseline`, so only new violations fail. The baseline matches by file,
rule and line text: **editing a baselined line makes its violation reappear. Fix it by using the
token, not by re-baselining.**

To regenerate the baseline after burning entries down, run from the repo root and write it filtered
to the two design rules only. The repo has about 616 other SwiftLint warnings, and an unfiltered
`--write-baseline` would swallow them:

```bash
swiftlint lint --quiet --config .swiftlint.yml \
  --only-rule design_literal_corner_radius --only-rule design_raw_font_size \
  --write-baseline .swiftlint.baseline.json >/dev/null || true
```

Entries are keyed by relative path, so run it from the repo root. Check the result contains only
those two rule identifiers, and that `scripts/format.sh --lint-only` is clean.

## 6. Do's and Don'ts

### Do:

- **Do** take every color from `AppTheme.Colors`, which resolves the `Vigil*` Color Sets. Use the
  plain properties (`AppTheme.Colors.tint`); the `(for: scheme)` overloads are deprecated shims.
- **Do** use `AppTheme.Spacing` (4, 8, 12, 16, 24, 32) and `AppTheme.Radius` (12, 16, 20).
- **Do** use `AppMotion` tokens with `.appAnimation(_:value:)` and `AppTransition`, so Reduce Motion
  is handled once.
- **Do** put numbers in tabular digits and pair every gain or loss with a sign, arrow or label.
- **Do** route user-facing text through the String Catalog. A `String` variable or a ternary of
  string literals passed to `Text` skips it; use `LocalizedStringKey` or `String(localized:)`.
- **Do** say plainly what the app does with money and data: read-only, not imported yet, trial ends
  in N days.

### Don't:

- **Don't** use gold as profit, or green and red as decoration.
- **Don't** add glow, mesh gradients, neon, decorative circuitry or "AI" sparkle.
- **Don't** gamify trading: no confetti on a buy, no streaks, no green fireworks, no urgency.
- **Don't** build the default SwiftUI tutorial stack: identical shadowed cards, or a hero metric
  with a gradient accent.
- **Don't** show invented prices, balances or tickers anywhere, including illustrations.
- **Don't** use `Color(red:green:blue:)`, hex literals, raw `.green` / `.red`, or `Color.white` /
  `Color.black` for surfaces.
- **Don't** use em dashes or exclamation marks in copy, and don't promise returns.
- **Don't** animate a changing value in a table.
- **Don't** place Vig next to a gain or a loss, or have Vig react to a trade.
- **Don't** call `.appGlassEffect()` or `.ultraThinMaterial` from feature code for a card, and never
  use a material as a page background.
