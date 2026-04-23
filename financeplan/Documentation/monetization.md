# Monetization

## Honest Assessment

Right now this is a **tough sell as a subscription**, not because the product is weak, but because the value proposition competes directly with free alternatives.

The free tier currently offers 10 holdings + 15 watchlist symbols + 5 DD notes. Yahoo Finance, TradingView, and most broker apps already give users unlimited holdings and real-time quotes at no cost. Charging $7.99/month for "unlimited rows in a spreadsheet" and CSV import is a hard pitch against well-funded incumbents.

To justify a subscription, the product needs **at least one lock-in feature** that:
1. Saves hours of manual work per month
2. Provides insight users cannot easily get elsewhere
3. Solves a painful, recurring problem (usually taxes or reporting)

---

## Recommended Model

Use a **subscription model** with three tiers.

This product has ongoing value and ongoing costs:

- portfolio imports
- stock news
- earnings transcripts and summaries
- future voice features
- server-side processing and storage

Because of that, ads and a one-time purchase are a poor fit. The cleanest launch path is a free app with paid auto-renewable subscriptions.

### Suggested Launch Structure

| Tier | Price | Target User |
|------|-------|-------------|
| **Free** | $0 | Casual investors trying the app |
| **Pro** | $5.99/mo or $59.99/yr | Active investors wanting automation |
| **Premium** | $11.99/mo or $119.99/yr | Power users, traders, and planners |

Avoid launching with too many tiers. Start with these three, gate value rather than basic access, and split further only when usage data justifies it.

---

## MVP Feature Monetization Map

The app has five core domains already built or in flight. Every feature should map to a tier so the backend can enforce entitlements as APIs come online.

### Authentication & Onboarding

| Feature | Tier | Rationale |
|---------|------|-----------|
| Login / register | Free | Table stakes |
| Onboarding (manual setup) | Free | Reduces time-to-value |
| Onboarding CSV import | Free | Still manual work; gets users to their first portfolio faster |

### Portfolio & Holdings

| Feature | Tier | Rationale |
|---------|------|-----------|
| Manual add/edit/delete positions | Free | Commodity; every broker app does this |
| Basic P&L summary | Free | Needed to see value immediately |
| Watchlist (unlimited symbols) | Free | Row limits are a bad free-tier gate |
| Delayed / end-of-day quotes | Free | Real-time costs money; delayed is table stakes |
| Real broker auto-sync (1 broker) | **Pro** | Saves time every week; strongest upgrade motivator |
| Multiple portfolio workspaces | **Pro** | Power-user organization feature |
| 15-min delayed / near real-time quotes | **Pro** | Data feed costs justify the gate |
| Risk analytics (correlation, beta, drawdown, sector concentration) | **Pro** | Insight users cannot get from free broker apps easily |
| Price / dividend / earnings alerts (up to 15) | **Pro** | Automation + push costs |
| Unlimited alerts | **Premium** | Scale feature for active traders |
| Unlimited broker connections | **Premium** | Users with multiple accounts are power users |

### Stock Details & Research

| Feature | Tier | Rationale |
|---------|------|-----------|
| Current price, basic info, news headlines | Free | Table stakes |
| Basic research notes (thesis, risks, catalysts) | Free | Habit-building; notes are sticky |
| Share/export text snapshot | Free | Viral marketing; free users posting screenshots is acquisition |
| Real stock fundamentals, metrics, financial results | **Pro** | Requires paid data provider APIs (e.g. FMP, Polygon) |
| Real earnings data & transcripts | **Pro** | Same as above; data costs money |
| Bear/base/bull projections | **Pro** | Requires backend-hydrated fundamentals to be valuable |
| 3-stock comparison (metrics side-by-side) | **Pro** | Research depth feature; appeals to active investors |
| Valuation editing & fair value tracking | **Pro** | Power-user research workflow |
| Export chart/research as PNG | **Pro** | Sharable content; slightly better than text free version |
| Custom benchmark comparison | **Premium** | Advanced analytics |
| Scenario planning ("what if I buy X more shares?") | **Premium** | Portfolio simulation; appeals to planners |
| Dividend tracking & income projections | **Premium** | Retirees and dividend investors will pay for this |
| DRIP reinvestment tracking | **Premium** | Advanced income feature |

### Expenses & Budget Planner

| Feature | Tier | Rationale |
|---------|------|-----------|
| Manual expense entry (local-only) | Free | Lets users try the feature without commitment |
| 3-month local history | Free | Enough to see utility, not enough to rely on |
| Basic category breakdown (current month) | Free | Simple view of where money went |
| Cloud sync across devices | **Pro** | Backend storage + sync is a clear paid value |
| Unlimited historical expense data | **Pro** | Requires backend persistence |
| Salary-aware monthly planner | **Pro** | Core budgeting value; requires API |
| Month duplication & planned categories | **Pro** | Workflow automation for budgeters |
| Pillars view (Fundamentals / Future You / Fun) | **Pro** | Structured budgeting framework; premium-feeling feature |
| Year-over-year expense trends | **Premium** | Long-term planning insight |
| Tax-ready expense export | **Premium** | Direct money-saving feature during tax season |

### Reports

| Feature | Tier | Rationale |
|---------|------|-----------|
| Current month summary (local) | Free | Derived from free expense data |
| Monthly comparison views | **Pro** | Requires multi-month backend data |
| Yearly comparison views | **Pro** | Same as above |
| SwiftUI charts & pillar breakdowns | **Pro** | Visual reporting feels premium |
| Spending vs planning variance analysis | **Pro** | Actual insight, not just raw data |
| PDF report export | **Premium** | Useful for accountants, landlords, loan applications |
| Custom date range reports | **Premium** | Flexibility power users want |
| Combined portfolio + expense net-worth view | **Premium** | Holistic financial picture; high-value feature |

### Imports

| Feature | Tier | Rationale |
|---------|------|-----------|
| CSV import (manual export/upload) | Free | Friction-based; users still do the work |
| API-based broker import (auto-sync) | **Pro** | Automation saves time |
| Scheduled/auto-refresh of holdings | **Premium** | True set-and-forget |

---

## Tier Definitions

### Free (Acquisition)

Goal: let users build habit and trust without feeling artificially crippled.

- Unlimited manual holdings and watchlist symbols
- Unlimited basic research notes
- Manual CSV import (this is still manual work; do not charge for friction)
- Delayed or end-of-day quotes
- Basic P&L summary
- 1 portfolio workspace
- Local-only expense entry (3 months history)
- Current month expense summary
- Basic stock info, news, and text share/export

CSV import stays free because it requires the user to manually export from their broker and upload. It is a value-building feature, not an automation feature.

### Pro (Main Revenue)

This tier should sell **time savings, automation, and research depth**.

- **Real broker auto-sync** (1 connected broker) — IBKR, Alpaca, Schwab, etc.
- Cloud sync for expenses, budgets, and reports across devices
- Unlimited historical expense and report data
- Salary-aware monthly planner with pillars (Fundamentals / Future You / Fun)
- Monthly and yearly report comparisons with charts
- Real stock fundamentals, earnings data, and financial results
- Bear, base, and bull case projections (backend-hydrated)
- 3-stock comparison with real metrics
- Valuation editing & fair value tracking
- Risk analytics suite (correlation matrix, max drawdown, portfolio beta, sector concentration)
- Up to 15 active price, dividend, and earnings alerts
- PNG chart/research export

Broker auto-sync is the strongest differentiator. Manually exporting and importing CSVs is friction most users abandon within weeks. Auto-sync justifies the subscription on its own.

### Premium (Power Users)

This tier should sell **tax peace of mind, advanced planning, and holistic finance**.

- Everything in Pro
- **Tax & reporting tools**
  - Realized/unrealized P&L reports formatted for Schedule D / Form 8949
  - Tax-loss harvesting alerts ("Sell X to harvest $Y in losses before year-end")
  - Wash sale warnings
  - Cost basis tracking across multiple lots (FIFO, LIFO, specific ID)
  - Tax-ready expense and portfolio export packages for accountants ($4.99 one-time per tax year could also be a consumable)
- **Scenario & planning tools**
  - "What if I buy 50 more shares of AAPL?" instant impact on weight, cost basis, risk
  - "What if I rebalance to 60/40 tech/healthcare?"
  - Future value projections based on bull/bear targets
- **Dividend tracking & income projections**
  - Track yield, upcoming payments, projected annual income
  - DRIP reinvestment tracking
- Combined portfolio + expense net-worth dashboard
- PDF report export
- Custom date range reports
- Unlimited broker connections
- Unlimited alerts
- Custom benchmark comparison (not just S&P 500)
- API access for advanced users
- Priority support

Tax features are under-served by free apps and highly valued during Q1. A user who saves one hour with their CPA has already justified the annual subscription cost.

---

## Feature Gating Principles

### Charge for automation, not for rows

Do not gate:
- Number of holdings
- Number of watchlist symbols
- Number of basic notes
- CSV import (manual)

These are commodities. Free competitors already offer unlimited versions.

Do gate:
- Auto-sync with brokers
- Tax reports
- Advanced risk analytics
- Real-time or faster data refresh
- Alert volume and automation
- Scenario/planning simulations
- Export to PDF/accountant formats

---

## Pricing to Test

| Plan | Monthly | Annual | Notes |
|------|---------|--------|-------|
| Pro | $5.99 | $59.99 (save ~17%) | Highlighted as default on paywall |
| Premium | $11.99 | $119.99 (save ~17%) | For power users and tax season |

- Offer a **7-day or 14-day free trial** on annual plans
- Consider a **launch lifetime deal**: one-time $99.99 for Pro, capped at 500 licenses to create urgency and seed early adopters
- Annual should be the default highlighted option on the paywall

Why lower than before? $7.99 competes with Netflix. For a niche finance tool, $5.99 feels like an easy yes if broker sync works. $11.99 for tax features is cheap compared to one hour of a CPA.

---

## Launch Strategy: What to Ship on Day One

### Should you launch without all monetization built?

**Yes. Ship a Minimum Viable Paywall, not a perfect one.**

Launching without every feature tier-mapped and gated is not only acceptable, it is the right move. Here's why:

1. **You cannot optimize what you cannot measure.** A paywall with zero traffic teaches you nothing. Get real users first, then iterate on tier boundaries based on actual behavior.
2. **Over-engineering gates kills launch momentum.** Building entitlement middleware, usage counters, and feature flags for every possible Premium feature before launch adds weeks of backend work with zero revenue to show for it.
3. **Users forgive a simple paywall on a new product.** They do not forgive a buggy core experience because you spent two weeks building tier-gated analytics instead of fixing sync.

### What you MUST have at launch

| Item | Why |
|------|-----|
| Free tier with clear value | Users need to trust the app before they pay |
| Pro tier with **one strong differentiator** | Broker auto-sync or cloud sync — something that saves real time |
| Functional paywall in the app | RevenueCat or StoreKit integration actually working |
| Backend entitlement check (basic) | At minimum, an `isPro` flag on the user record |
| 7-day or 14-day free trial on annual | Critical for conversion; see below |

### What you can safely defer to post-launch

| Item | Defer to |
|------|----------|
| Premium tier | Month 2-3, after you see Pro uptake |
| Advanced analytics gating | When the analytics are actually built |
| Usage counters & upgrade prompts | After 100+ active users |
| Tax export / consumable purchases | Tax season (Q1) or when Premium launches |
| Full entitlement middleware | Start with hardcoded feature checks |
| AI features | 100+ paying users, as stated above |

### Recommended launch tiers

At MVP launch, ship **only two tiers**:

| Tier | Price | Includes |
|------|-------|----------|
| **Free** | $0 | Manual tracking, local expenses, basic quotes, CSV import |
| **Pro** | $5.99/mo or $59.99/yr | Cloud sync, real broker auto-sync, real fundamentals, projections, reports, alerts |

Do **not** launch with Premium visible. It creates choice paralysis and spreads your engineering focus too thin. You can add Premium later as an upsell for users who hit Pro limits.

### Should you keep the 7/14 day trial?

**Absolutely. Do not launch without a trial.**

A trial is not a discount. It is a **risk reversal tool**. Users do not know if your app is worth $5.99 until they use it. A trial lets them prove value to themselves.

| Trial length | When to use |
|--------------|-------------|
| **7 days** | If your core value is obvious within a week (broker sync, first report) |
| **14 days** | If your value compounds over time (expense trends, target tracking) |

For this product, **14 days is better**. The "decision journal" value becomes clear after a user has tracked a few positions and set targets. One week may not be enough for habit formation.

### Trial best practices

- Put the trial on the **annual plan only**. Monthly can be instant pay. Annual is your real revenue driver and the trial reduces sticker shock.
- Show the user exactly what they get during the trial. A checklist on day one: "Try broker sync, set your first target, run your first report."
- Send a day-12 reminder before billing. Not day-1 (too early) and not day-14 (too late to act).
- Do not require a credit card for TestFlight beta. Do require it for App Store launch — App Store trials auto-convert and the friction filters out non-buyers.

### What happens if you launch completely free?

**Don't.** Launching entirely free and adding a paywall later is painful:
- Existing free users feel betrayed ("you took away my features")
- You have no revenue data to prioritize what to build
- You attract a user base that will never pay, polluting your feedback loop

The only exception: a 100% free beta via TestFlight for 2-4 weeks to collect feedback. But the App Store launch should have a working paywall from day one.

### Post-launch monetization rollout

| Timeline | Action |
|----------|--------|
| **Week 1-2** | Monitor trial-to-paid conversion rate. Target: 10-15% |
| **Week 3-4** | Interview 5-10 non-converting trial users. Ask what was missing. |
| **Month 2** | Add first upgrade prompt (gentle, context-aware) |
| **Month 2-3** | Launch Premium tier if Pro conversion is healthy (>10%) |
| **Month 3-6** | Add consumables (tax export) and refine gating |
| **Month 6+** | Evaluate AI tier if revenue justifies the cost |

---

## Product Positioning

Recommended positioning shift:

- From: "Your personal finance operating system."
- To: **"The decision journal for investors."**

Or:

- **"Plan your money. Research your stocks. Hold yourself accountable."**

Portfolio tracking is a commodity. Free apps do it well. What is not a commodity is **investment discipline**.

Lean into:
- "Did you stick to your thesis?"
- "Your AAPL bull target was $200; it is at $195. Time to revisit?"
- "You wrote 'sell if margins drop' — margins dropped 2%, but you did not sell."

Build scheduled "review" prompts, target hit logging, and thesis vs outcome tracking into the product. That narrative discipline is worth money to serious investors in a way that basic tracking is not.

This keeps the product framed as planning and research support, not financial advice.

---

## What To Avoid

- Ads
- Affiliate-heavy broker pushing at launch
- Separate paid plans for Expenses and Stocks at MVP
- Claiming stock picks or investment advice
- Charging for manual CSV import (you are charging for friction, not value)
- Gating row counts when competitors offer unlimited for free

Finance products need trust. Ads and overly aggressive monetization weaken that immediately.

---

## Recommended App Store Setup

Use one subscription group with:

- one monthly product (Pro)
- one annual product (Pro)
- one monthly product (Premium)
- one annual product (Premium)

Keep the app free to download. Gate premium workflows inside the app.

Use RevenueCat for App Store subscription handling — it manages receipts, trials, and grace periods with a Swift SDK. Add a backend webhook receiver at `POST /webhooks/revenuecat` to receive subscription lifecycle events (new purchase, renewal, cancellation, billing issue).

---

## Backend Changes to Support Billing

- Add `subscriptions` and `entitlements` tables
- Add middleware/policies for limits by tier (symbols, refresh frequency, sync jobs, analytics depth)
- Track monthly usage counters for upgrade prompts
- Build entitlement middleware that reads the user's subscription tier and enforces feature gates

---

## AI Integration (Post-Revenue Only)

**Do not build AI features pre-revenue.**

- LLM API costs will eat margin at low subscriber counts
- You do not yet know what users actually struggle with — you might build the wrong AI feature
- It is a perfect **Premium upsell story** later ("Now with AI portfolio analysis")

When you do add AI (target: 100+ paying users), consider:
- Summarize DD notes and flag contradictions (bullish thesis but bearish target?)
- Generate "earnings prep" briefings from held positions
- Natural language portfolio queries ("What is my tech exposure?")
- Auto-tag research notes by sentiment/theme
- AI-powered insight suggestions based on target progress and news sentiment

These are cheap to run per-user and feel magical, but only after revenue funds the experimentation.

---

## Go-to-Market Ideas

- **Product Hunt Launch**: Submit with a compelling tagline — "The stock tracker for investors who actually do research"
- **Finance Subreddits & Communities**: Share on r/investing, r/stocks, r/SwiftUI with a genuine "I built this" post
- **App Store Optimization**: Use positioning around decision journaling and DD notes; add screenshots showing target scenarios and research workflow
- **Content Marketing**: Write blog posts about building a full-stack Swift finance app — appeals to both investors and developers
- **Indie Hacker Channels**: Post on IndieHackers, Hacker News (Show HN), and Twitter/X with build-in-public updates
- **TestFlight Beta Program**: Launch a private beta with 100 users to get feedback and App Store reviews ready for day one

---

## Future Monetization Options

Later, if usage justifies it:

- Add a higher AI tier
- Add consumable credits for heavy voice usage
- Add team/family plans if collaborative use appears
- B2B / team plans for small fund managers or investment clubs ($29.99/mo per team)
- Data export add-ons for tax prep ($4.99 one-time per tax year)
- Affiliate / broker referrals (non-intrusive, surfaced as "Connect a Broker" in settings)

Do not add complexity until retention and conversion data justify it.

---

## References

- Apple auto-renewable subscriptions
- Apple App Store Small Business Program
- RevenueCat
- YNAB pricing
- Monarch pricing
- Copilot pricing
- Simply Wall St pricing
