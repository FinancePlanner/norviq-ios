# FinancePlan Stock Detail Product Organization

## Purpose
This document defines how the stock detail experience should evolve for manual stock insertion. The goal is to make the stock view useful for thesis-driven investors, not just as a quote screen.

## Product Principle
The stock detail experience should answer three questions:

- Why do I own this stock?
- What changed since I added it?
- What should I do next?

This means the product should emphasize thesis tracking, current context, and decision support over generic market-data browsing.

## Stock Detail Navigation

Recommended stock detail navigation:

- `Overview` as the default screen
- `History` as a dedicated screen
- `News` as a dedicated screen
- `Compare` as a dedicated screen

The user should land on `Overview` first. `History`, `News`, and `Compare` should be accessible from the same stock-level navigation.

## Overview Screen

### Purpose
The overview should be the decision screen. It should summarize the position, the investment thesis, what changed, and the next likely action.

### Sections

#### 1. Header and Position Summary
Show the current state of the investment.

- Symbol and company name
- Current price
- Daily change
- Shares owned
- Cost basis
- Position value
- Unrealized P/L
- Portfolio weight

#### 2. Thesis Summary
Make the thesis the center of the experience.

- Bear case
- Base case
- Bull case
- Target date
- Rationale
- Implied upside/downside from current price to bear/base/bull
- Optional conviction or thesis status

#### 3. Relative Valuation Summary
Show a compact comparison teaser, not the full compare workflow inline.

- Summary like `Cheaper than 4/6 peers`
- Implied fair value from the current comparison template
- Valuation spread versus current price
- CTA to open the full `Compare` screen

#### 4. Catalysts and Risks
Give the user a reason to review the thesis.

- Next earnings date
- Upcoming company or macro catalysts
- Top risks
- Thesis invalidation conditions

#### 5. Fundamentals Snapshot
Keep this short and decision-oriented.

- Forward PE
- EV/EBITDA
- Revenue growth
- EPS growth
- Gross margin
- Operating margin
- FCF yield
- Debt-related metric if relevant

#### 6. Review Log and Notes
Track how the thesis evolves.

- Date thesis was created
- Last updated date
- Review notes
- Key changes since last review

### Primary Actions

- Edit stock position
- Edit thesis
- Open compare
- Open full history
- Open full news
- Add review note
- Set review reminder
- Set price alert

## History Screen

### Purpose
History should show how price action relates to the thesis and position.

### Sections

- Price chart
- Time range selector
- Key events overlay when available
- Thesis level overlay for bear/base/bull prices
- Performance summary versus cost basis

### Primary Actions

- Change time range
- Toggle overlays
- Compare against a benchmark in later phases

### Data Source

- Price history from the market data provider, routed through the backend
- Thesis levels from user-authored stock thesis data

## News Screen

### Purpose
News should help the user assess whether the thesis is strengthening or weakening.

### Sections

- Latest headlines
- Source and timestamp
- Tags such as earnings, product, macro, regulation, management
- Optional impact label in later phases

### Primary Actions

- Open article
- Save article
- Mark as relevant to thesis in later phases

### Data Source

- News provider or market-data news feed, routed through the backend
- Relevance tagging and summarization should be backend-driven if added later

## Compare Screen

### Purpose
The compare experience should answer whether the stock looks cheap or expensive relative to peers based on the user's chosen framework.

### Placement

The `Compare` experience should live as a dedicated stock-level screen, reachable from:

- the stock detail navigation
- the `Relative Valuation Summary` card on `Overview`

This should not be only an inline section. It needs enough space for peers, inputs, and ranking logic.

### Sections

#### 1. Anchor Stock Header
- Current stock symbol
- Current price
- Current key multiple snapshot

#### 2. Peer Set
- Default peer list from backend logic or provider metadata
- User can add or remove peers
- Saved peer set for the stock

#### 3. Comparison Template
- User-selected factors such as forward PE, EV/EBITDA, growth, margins, ROIC, FCF yield
- User-defined weights
- Optional saveable templates in later phases

#### 4. Peer Table
- Peer name and symbol
- Current price
- Selected metrics
- Rank by metric
- Composite score

#### 5. Fair Value Output
- Implied fair value for the anchor stock
- Discount or premium versus current price
- Confidence or coverage indicator

### Primary Actions

- Edit peers
- Edit factor weights
- Save comparison template
- Reset to default template
- Open peer stock details

### Data Source

- Fundamentals and analyst-estimate data from a provider that supports forward metrics
- Peer metadata from backend rules, provider metadata, or editable user-defined peer lists
- Comparison score and implied fair value calculated in the backend

## Data Ownership and Source of Truth

The product should separate data into three buckets.

### 1. User-authored data

- Thesis
- Bear/base/bull values
- Rationale
- Target date
- Review notes
- Custom peer set
- Alerts and reminders

### 2. Market and vendor data

- Current price
- Historical price data
- News
- Fundamentals
- Analyst estimates
- Earnings calendar

### 3. Backend-derived data

- Upside/downside to bear/base/bull
- Annualized return to target date
- Thesis status
- Relative valuation score
- Implied fair value
- News relevance or impact labels in later phases

Important rule:

- The backend should be the source of truth for derived analytics.
- The iOS app should render and edit user-facing state, not own the final calculation logic for important investment outputs.

## MVP

The MVP should stay focused on thesis-driven manual stock tracking.

### MVP Scope

- Stock `Overview`, `History`, `News`, and `Compare` screens
- Position summary on `Overview`
- Thesis summary with bear/base/bull, rationale, and target date
- Implied upside/downside from current price to thesis values
- Simple fundamentals snapshot
- History chart with range selector
- Recent news list
- Compare screen with:
  - anchor stock
  - editable peer list
  - a limited set of factors such as forward PE, revenue growth, and margin
  - simple weighted ranking
  - implied fair value output
- Basic review notes

### MVP Actions

- Edit thesis
- Open compare
- Open full history
- Open full news
- Add note

## Later Phases

These can be added after the core stock experience is stable.

### Phase 2

- Thesis health status such as `On track`, `At risk`, `Broken`
- Earnings and catalyst timeline
- Price alerts on bear/base/bull levels
- Review reminders
- Saved comparison templates
- Benchmark comparison in history

### Phase 3

- AI-assisted news relevance classification
- AI summary of what changed since last review
- Suggested peer sets
- Thesis change diff over time
- Portfolio-level rollup of thesis status across holdings
- Compare workbench promoted to a top-level research feature

## Product Recommendation

If the product has to choose one clear angle, it should be:

- thesis tracking first
- market context second
- raw data exploration third

That positioning is stronger than trying to compete as a general-purpose stock app.
