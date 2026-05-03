<wizard-report>
# PostHog post-wizard report

The wizard has completed a deep integration of PostHog analytics into the Norviqa iOS app (financeplan). The PostHog iOS SDK was already installed and initialized in the app entry point alongside existing Sentry and Amplitude integrations. This session extended event coverage with 7 new events across the watchlist, onboarding, portfolio, and billing flows, supplementing the 12 events that were already instrumented.

Key integration points:
- **PostHog initialization** in `NorviqaApp.init()` with `captureApplicationLifecycleEvents` enabled, reading credentials from Info.plist via a `PostHogEnv` enum
- **User identification** via `PostHogSDK.shared.identify()` on every login, and `PostHogSDK.shared.reset()` on logout
- **AnalyticsService** (`financeplan/Features/Analytics/AnalyticsService.swift`) forwards all Amplitude events to PostHog in parallel
- **19 business events** instrumented across 8 files covering authentication, portfolio actions, watchlist, onboarding, stock engagement, and Pro subscription conversion

## Events

| Event | Description | File |
|-------|-------------|------|
| `App Launched` | App started and main view appeared | `financeplan/NorviqaApp.swift` (via AnalyticsService) |
| `user_signed_up` | User successfully created a new account | `financeplan/Features/Auth/LoginViewModel.swift` |
| `user_logged_in` | User authenticated and logged in (also triggers `identify`) | `financeplan/Features/Auth/LoginViewModel.swift` |
| `user_logged_out` | User initiated logout (also triggers `reset`) | `financeplan/Features/UserProfile/UserProfileView.swift` |
| `upgrade_to_pro_tapped` | User tapped the Upgrade to Pro button in Settings | `financeplan/Features/UserProfile/UserProfileView.swift` |
| `paywall_viewed` | Pro upgrade paywall was shown to the user (includes `source` property) | `financeplan/Features/Portfolio/PortfolioScreen.swift`, `financeplan/Features/Stocks/StockDetailsScreen.swift`, `financeplan/Features/UserProfile/UserProfileView.swift` |
| `position_added` | New stock/asset position added to portfolio | `financeplan/Features/Portfolio/PortfolioScreen.swift` |
| `position_edited` | Existing portfolio position saved with changes | `financeplan/Features/Portfolio/PortfolioScreen.swift` |
| `position_deleted` | Portfolio position deleted | `financeplan/Features/Portfolio/PortfolioScreen.swift` |
| `stock_detail_viewed` | User opened a stock detail screen | `financeplan/Features/Stocks/StockDetailsScreen.swift` |
| `position_sold` | User sold shares of a stock position | `financeplan/Features/Stocks/StockDetailsScreen.swift` |
| `subscription_purchased` | Pro subscription successfully purchased | `financeplan/Features/UserProfile/BillingManager.swift` |
| `watchlist_item_added` | User added a symbol to their watchlist | `financeplan/Features/Stocks/Watchlist/WatchlistViewModel.swift` |
| `watchlist_item_removed` | User removed a symbol from their watchlist | `financeplan/Features/Stocks/Watchlist/WatchlistViewModel.swift` |
| `csv_import_loaded` | User loaded a CSV file during portfolio import (includes `row_count`) | `financeplan/Features/Onboarding/CSVImportViewModel.swift` |
| `onboarding_completed` | User completed the onboarding import flow | `financeplan/Features/Onboarding/OnboardingImportViewModel.swift` |
| `target_alert_set` | User set a price target alert for a stock symbol | `financeplan/Features/Portfolio/PortfolioViewModel.swift` |
| `portfolio_list_created` | User created a new portfolio list | `financeplan/Features/Portfolio/PortfolioViewModel.swift` |
| `subscription_restored` | User successfully restored a previous Pro subscription | `financeplan/Features/UserProfile/BillingManager.swift` |

## Next steps

We've built some insights and a dashboard for you to keep an eye on user behavior, based on the events we just instrumented:

- **Dashboard — Analytics basics**: https://us.posthog.com/project/395712/dashboard/1539206
- **User activation funnel** (Signup → Onboarding → First position): https://us.posthog.com/project/395712/insights/J4XXh5wb
- **Subscription conversion funnel** (Paywall viewed → Purchased): https://us.posthog.com/project/395712/insights/0XoHxAvc
- **Daily active users**: https://us.posthog.com/project/395712/insights/4ivy8VlP
- **Portfolio engagement** (positions added vs sold vs watchlist additions): https://us.posthog.com/project/395712/insights/XBddpmyN
- **Churn signal** (weekly logout trend): https://us.posthog.com/project/395712/insights/ZUbNu5H3

### Xcode setup

The environment variables `PostHogProjectToken` and `PostHogHost` are read from Info.plist at runtime. Ensure these keys are populated for each build configuration (Debug, Release) in your Info.plist or via Xcode build settings.

### Agent skill

We've left an agent skill folder in your project at `.claude/skills/integration-swift/`. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.

</wizard-report>
