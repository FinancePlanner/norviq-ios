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
decorative is allowed to compete with a number. Surfaces are flat and quiet, type is system SF, and
every figure sits in tabular digits with measured contrast.

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
- Legible and correct with motion and effects off.

## 2. Colors

Tinted neutrals carry the screen; gold marks intent; green and red speak only about money.

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

**Display Font:** SF Pro (system)
**Body Font:** SF Pro (system, scaled through `UIFontMetrics`)

**Character:** One family, no display pairing. Hierarchy comes from the size ladder and weight, and
the only typographic signature is the monospaced overline and tabular numerals.

Two routes exist and both honor Dynamic Type: SwiftUI semantic styles (`.headline`, `.subheadline`,
`.caption`) on system `List` and `Form` screens, and the `Typography` ladder via `.typography(_:)`
on designed surfaces. The ladder uses fixed design sizes that scale relative to a text style.

### Hierarchy

- **Display number** (semibold, 40pt scaled as largeTitle, tabular): the one large figure on a screen.
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

## 4. Elevation

Flat by design, with glass reserved for the system. Depth is three tonal steps (page, card, elevated
card) plus a 1pt hairline. `GlassCard` is the single card surface and resolves through
`.appGlassEffect()`: native `.glassEffect` on iOS 26, and below that a card fill, a hairline stroke
and one soft shadow. That fallback is the only card shadow in the app.

### Material Vocabulary

- **Card surface** (`GlassCard` over `.appGlassEffect(.rect(cornerRadius:))`): every card-shaped surface.
- **Fallback card shadow** (`.shadow(color: .black.opacity(0.05), radius: 12, y: 6)` light;
  `0.18`, radius 16, y 10 dark): pre-iOS 26 only, applied inside `appGlassEffect`.
- **Fallback capsule and circle shadow** (`.shadow(color: .black.opacity(0.04), radius: 8, y: 3)`).
- **System materials** (`.thinMaterial`, `.regularMaterial`, `.ultraThinMaterial`): floating circles,
  sheets and the tab bar capsule. Not cards, not page backgrounds.
- **Page** (`.vigilScreenBackground()` and `.vigilListChrome()`): a flat `VigilPageBackground` canvas
  under every themed screen and list.

### Named Rules

**The One Card Rule.** Card-shaped surfaces go through `GlassCard`. Feature code does not call
`.appGlassEffect()`, stack its own material, or add a shadow.

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

- **Corner Style:** continuous corners; 20pt default on `GlassCard`, 16pt (`AppTheme.Radius.card`) for
  standard cards, 12pt (`AppTheme.Radius.control`) for controls and themed list rows.
- **Background:** `VigilCardBackground`, or native glass on iOS 26.
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

### Navigation

- `NavigationStack` with inline titles; a floating tab bar with a selection pill that morphs over
  `AppMotion.tabBar`.
- Themed screens use `VigilPageHeader` in content, with `.vigilNavigationTitle`,
  `.vigilInlineNavigationBar`, `.vigilListChrome` and `.vigilScreenBackground` applied together. A
  screen that omits them flashes the system grouped background between two themed ones.
- Sheets use detents (`.medium`, `.large`), a Cancel item on the leading side and the confirming
  action on the trailing side.

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
