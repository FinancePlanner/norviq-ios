<wizard-report>
# PostHog post-wizard report

The wizard has completed a deep integration of PostHog analytics into the Norviqa iOS app (financeplan). The PostHog iOS SDK (v3.40.0) was added via Swift Package Manager, initialized in the app entry point alongside existing Sentry and Amplitude integrations, and event tracking was added across all major user journeys: authentication, portfolio management, stock research, broker connectivity, and subscription conversion.

Key integration points:
- **PostHog initialization** in `NorviqaApp.init()` with `captureApplicationLifecycleEvents` enabled, reading credentials from Xcode scheme environment variables via a `PostHogEnv` enum
- **User identification** via `PostHogSDK.shared.identify()` on every login, and `PostHogSDK.shared.reset()` on logout
- **AnalyticsService** (`financeplan/Features/Analytics/AnalyticsService.swift`) forwards all Amplitude events to PostHog in parallel
- **15 business events** instrumented across 5 files covering authentication, portfolio actions, stock engagement, broker connectivity, and Pro subscription conversion

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
| `portfolio_csv_imported` | CSV portfolio import completed successfully | `financeplan/Features/Portfolio/PortfolioCSVImportSheet.swift` |
| `broker_connected` | IBKR broker account successfully connected | `financeplan/Features/Portfolio/PortfolioCSVImportSheet.swift` |
| `broker_synced` | IBKR broker portfolio data synced | `financeplan/Features/Portfolio/PortfolioCSVImportSheet.swift` |
| `broker_disconnected` | IBKR broker account disconnected | `financeplan/Features/Portfolio/PortfolioCSVImportSheet.swift` |
| `stock_detail_viewed` | User opened a stock detail screen | `financeplan/Features/Stocks/StockDetailsScreen.swift` |
| `position_sold` | User sold shares of a stock position | `financeplan/Features/Stocks/StockDetailsScreen.swift` |

## Next steps

We've built some insights and a dashboard for you to keep an eye on user behavior, based on the events instrumented:

- **Dashboard — Analytics basics**: https://us.posthog.com/project/395712/dashboard/1506437
- **Sign-up to Login Funnel**: https://us.posthog.com/project/395712/insights/CSHbrMyI
- **Daily Active Users**: https://us.posthog.com/project/395712/insights/v8XAnWIn
- **Portfolio Activity Breakdown**: https://us.posthog.com/project/395712/insights/373JMJxU
- **Paywall to Upgrade Funnel**: https://us.posthog.com/project/395712/insights/p0YY04Lu
- **Churn Signal — Logout Trend**: https://us.posthog.com/project/395712/insights/M9SPlPkj

### Xcode setup

The environment variables `POSTHOG_PROJECT_TOKEN` and `POSTHOG_HOST` are already set in the **financeplan** scheme's Run action. If you use additional schemes (e.g. a dev/staging scheme), add those same variables there too.

### Agent skill

We've left an agent skill folder in your project at `.claude/skills/integration-swift/`. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.

</wizard-report>
