# Product

Derived on 2026-11-10 from `apps/norviq/docs/precision-identity.md` (the canonical identity spec),
`AppTheme.swift`, `AppMotion.swift` and the README. Nothing here was invented; where the identity
spec and this file disagree, the spec wins and this file is stale.

## Register

product

## Users

Disciplined retail investors: people who plan before they act. They hold a real portfolio, track
spending against a budget, and come to Norviq to check a position, a plan or a number, usually in a
short session on an iPhone. They are literate in their own finances and do not need to be sold to or
entertained while they read their money.

## Product Purpose

Norviq is a financial intelligence system: portfolio planning, stock research, expenses and budget,
tax and scenario tools, and an AI assistant (Q) that answers questions about the user's own positions.
It reads accounts; it never places trades or moves money. Success is a user who can see where they
stand and what their plan says, quickly, and trusts every figure on screen.

## Brand Personality

Precision Intelligence. Calm, declarative, literal about money. An instrument, not a feed: the
interface represents discipline, the data represents reality, and nothing decorative competes with a
number. Tagline: "Discipline creates freedom."

Voice: no exclamation marks, no hype, no promises about returns, no em dashes. The mascot Vig (a lynx)
observes; Vig never celebrates gains, mourns losses or nudges anyone to trade. Vig appears in
onboarding, empty states and the assistant, never in data views and never next to a gain or loss.

## Anti-references

- Trading apps that gamify: confetti on a buy, streaks, green fireworks, urgency.
- Glow, mesh gradients, neon, decorative circuitry, "AI" sparkle.
- Gold used as profit, or green and red used as decoration.
- The default SwiftUI tutorial stack: identical shadowed cards, a hero metric with a gradient accent.
- Invented prices, balances or tickers anywhere in the product, including illustrations.

## Design Principles

1. **Nothing competes with a number.** Figures get tabular digits, real contrast and quiet surroundings.
   Never animate a changing value in a table.
2. **Gold is brand, never money.** Gold marks the primary action, selection and focus, on about 10% of a
   screen. Gain and loss colors mean financial direction only, and never stand alone: always a sign,
   an arrow or a spoken label.
3. **Say exactly what the app does with money and data.** Read-only means read-only, "not imported yet"
   is said plainly, pricing and trial terms stay explicit.
4. **Legible with every effect off.** Each screen must stay correct and readable with motion, glass and
   gradients disabled.
5. **Earned familiarity.** System controls and platform patterns first; one design system
   (`AppTheme`, `AppMotion`, `GlassCard`, the `vigil*` screen modifiers) shared with the web app, with
   no forked values.

## Accessibility & Inclusion

- WCAG AA contrast, measured: every text pair in the identity spec is 4.5:1 or better on its own
  surface, including gain/loss text on a 12% chip of itself.
- Light and dark are both first class and user selectable (`app_appearance`).
- Dynamic Type through semantic text styles; `.monospacedDigit()` wherever numbers sit together.
- Reduce Motion: opacity only, via `appAnimation` and `AppTransition`; the loading emblem is static.
- Localization: English source, Portuguese (pt-PT). User-facing strings go through the String Catalog.
