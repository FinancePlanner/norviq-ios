<claude-mem-context>
# Memory Context

# [financeplan] recent context, 2026-06-05 9:48pm GMT+1

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (16,719t read) | 329,003t work | 95% savings

### May 6, 2026
S29 SwiftUI view refactor — user invoked skill to refactor a SwiftUI view, session is in early clarification stage (May 6 at 5:18 PM)
S30 SwiftUI Pro code review of the Norviqa iOS app (financeplan) — full audit against swiftui-pro plugin rules and delivery of prioritized remediation report (May 6 at 6:16 PM)
S31 Scan financeplan iOS codebase for SwiftUI refactor candidates, ranked by complexity (May 6 at 6:18 PM)
S32 Fix onboarding card deck text bleed-through caused by iOS 26 liquid glass transparency (May 6 at 10:15 PM)
S33 Execute SwiftUI refactoring plan — split 6 monolithic view files (1k–3.8k lines each) into focused single-responsibility files (May 6 at 10:17 PM)
S34 Execute SwiftUI refactoring plan — split 6 monolithic iOS view files into focused single-responsibility files across subdirectories (May 6 at 10:21 PM)
S37 SwiftUI view refactor (/swiftui-view-refactor) — split 6 large SwiftUI files into focused sub-view files across StockPlanIOSApp (May 6 at 10:23 PM)
### May 8, 2026
262 7:33a 🔄 GasTrackerCard and MarketDominanceCard Extracted to Cards/
263 " 🔄 MarketQuickStatsCard + QuickStatColumn Co-located in Cards/
264 " 🔄 CryptoOverviewSkeleton Extracted to Cards/
265 7:34a 🔄 CryptoHoldingRow, HoldingCircle, and SparklineShapes Extracted to Components/
266 " 🔄 CryptoNewsRow and CryptoNewsCard Extracted to Components/
270 12:22p 🔵 Portfolio Feature Directory State and Recent Refactor Context
273 " 🔵 PortfolioScreen.swift Contains 12 Embedded Private Structs Still Pending Extraction
274 12:23p 🔵 Duplicate Type Definitions Found: Private Structs in PortfolioScreen.swift Match Already-Extracted Standalone Files
275 12:24p 🔄 PortfolioScreen.swift Truncated to Remove All Extracted Private Structs
276 " 🔴 Build Failure: CardButtonStyle Redeclaration Conflict Between Portfolio and Expenses Features
277 " 🔵 CardButtonStyle Duplicate Confirmed Identical — Safe to Delete from ExpensesPlannerScreen
278 " 🔴 Removed Duplicate CardButtonStyle from ExpensesPlannerScreen.swift to Fix Build
279 12:25p 🟣 Portfolio Component Extraction Refactor Complete — Build Succeeded
280 " ✅ Committed Portfolio Refactor as "refactor: split PortfolioScreen into focused sub-views and extract async methods"
281 " 🔵 UserProfileView.swift Identified as Next Refactor Target — 1014 Lines with 4 Embedded Private Structs
282 12:26p ⚖️ UserProfileView Extraction Uses ProfileViews Subdirectory Instead of Flat Feature Folder
283 " 🔄 UserProfileView Extraction Started: AIInfoView.swift and ConnectView.swift Created in ProfileViews/
284 " 🔄 DataAvailabilityView Extracted to ProfileViews/DataAvailabilityView.swift
285 12:27p 🔄 SecurityCodeView Extracted to ProfileViews/ with @Binding Interface Preserved
286 12:28p 🔄 UserProfileView.swift Cleaned Up: Private Structs Removed and Inline Task Closures Extracted to Named Methods
287 " 🔄 UserProfileView Component Extraction Build Confirmed Green
288 12:39p 🔄 UserProfileView.swift split into focused sub-view files
289 12:40p 🔵 Post-refactor line count audit reveals remaining large files in StockPlanIOSApp
S38 Confirmation that all 6 refactoring tasks are done — user asked "All are done then?" (May 8 at 12:40 PM)
S236 Rebase fcorreia/hotfix-google-oauth-ios onto main and force-push (May 8 at 12:44 PM)
### May 14, 2026
2628 6:46p ✅ Rebased hotfix-google-oauth-ios branch onto main and force-pushed
### May 28, 2026
8069 9:52a 🔵 App Store Rejection: Guideline 2.1(a) – "Coming Soon" Section Found
8071 " ⚖️ Remediation Plan: 4 Placeholder Surfaces + 2 Dead Code Sites Identified for App Store Resubmission
8072 " 🔵 EarningsCalendarScreen: transcriptsSection Defined at Line 148, Called at Line 90
8073 " 🔴 Removed "Coming in Future Updates" transcriptsSection from EarningsCalendarScreen
8075 9:53a 🔴 Removed Disabled "Crypto Assets" Button with "Soon" Badge from Onboarding Main Menu
8077 " 🔄 Removed showSoonBadge Parameter and "Soon" Capsule UI from OnboardingMenuButton Component
8078 " 🔵 StockImportMethod Enum Structure Confirmed: .api Case Has isDisabled and badge: "Soon"
8080 " 🔵 isDisabled and badge Properties Consumed in 5 Places Across ImportMethodCard View
8082 " 🔴 Removed .api Case and isDisabled/badge Properties from StockImportMethod Enum
8084 " 🔴 Removed isDisabled Guard and .disabled() Modifier from methodSelectionButton
8086 9:54a 🔴 Removed All isDisabled and badge Consumers from ImportMethodCard View
8088 " 🔴 Replaced "Endpoint Pending" Placeholder Text in StockBasicFinancialsPlaceholderCard
8089 " 🔵 DashboardActionButton Struct Confirmed at Lines 714-757 with "Soon" Capsule Dead Code
8090 " 🔴 Deleted Dead DashboardActionButton Struct Containing "Soon" Badge from DashboardRoot.swift
8093 " 🔴 Deleted Commented-Out "Integrations (Coming Soon)" Block from UserProfileView
8095 9:55a 🔵 Residual Dead State: isAIInfoPresented and AIModelIntegrationsInfoSheet Still Present in UserProfileView
8096 " 🔵 AIModelIntegrationsInfoSheet Has One Call Site and Contains No "Soon" Content
8098 " 🔵 5 Orphaned Localization Keys Found in Localizable.xcstrings After Swift Edits
8099 " 🔵 StockConsensusPlaceholderCard Contains Missed "Wrapped Endpoint" Placeholder Text
8101 " 🔴 Replaced "Wrapped Endpoint Pending" Text in StockConsensusPlaceholderCard
8103 9:56a 🔵 Final Placeholder Sweep: Zero App-Code Hits — All Remaining Results Are Third-Party Dependencies
8104 " 🔵 App Source Code Verified Clean: Zero "Soon/TBD/Coming/WIP" Text Literals Remain
8127 10:07a 🔵 App Store Rejection: Guideline 2.1(a) - Incomplete Content
8128 10:08a 🔴 Removed APIKeyImportScreen (Broker API Feature) from Onboarding Flow
8129 " ✅ Build Succeeds After APIKeyImportScreen Removal
8130 " 🔵 No Remaining "Coming Soon" Placeholder Strings Found
S616 App Store Rejection Fix — Guideline 2.1(a) App Completeness: Remove all "coming soon" / placeholder content from financeplan iOS app before resubmission (May 28 at 10:08 AM)
**Investigated**: All Swift source files and Localizable.xcstrings were audited for placeholder strings ("coming soon", "coming in future", "wrapped endpoint", disabled/badge UI patterns). The Xcode project was confirmed to use PBXFileSystemSynchronizedRootGroup, meaning file deletions from disk are automatically reflected in the build without manual pbxproj edits.

**Learned**: The app had placeholder content spread across multiple unrelated features: an entire broker API key import flow in onboarding (disabled with "Soon" badge), a "Coming in Future Updates" transcripts card in Earnings, a disabled Crypto Assets button in onboarding main menu, a dead DashboardActionButton struct with "Soon" capsule in the home dashboard, a commented-out "Integrations (Coming Soon)" block in user profile, and two neutral-but-revealing placeholder strings in StockInsightsViews. The Xcode project's filesystem-synchronized groups made file deletion safe without touching pbxproj manually.

**Completed**: - Deleted `APIKeyImportScreen.swift` (broker API import — entire file removed)
    - Removed `.api` step from `OnboardingImportViewModel`, `OnboardingImportFlow`, and `InitialStockImportScreen` (enum case, switch arms, isDisabled/badge props, 5 consumer sites)
    - Removed Crypto Assets disabled button and "Soon" capsule from `OnboardingMainMenu.swift`
    - Deleted `transcriptsSection` ("Coming in Future Updates" card) from `EarningsCalendarScreen.swift`
    - Replaced 2 placeholder texts in `StockInsightsViews.swift` with neutral unavailable copy
    - Deleted dead `DashboardActionButton` struct from `DashboardRoot.swift`
    - Deleted commented "Integrations (Coming Soon)" block from `UserProfileView.swift`
    - Pruned 3 orphan localization keys from `Localizable.xcstrings`
    - Build confirmed: BUILD SUCCEEDED with no errors on iPad Pro 13-inch (M5) simulator
    - Final string audit confirmed zero remaining "coming soon" / placeholder strings in Swift source or localization files

**Next Steps**: Bump build number from 1.0 (14) to 1.0 (15), archive the app, and resubmit to App Store with a reviewer note explaining the removal of all incomplete/placeholder content per Guideline 2.1(a) remediation.


Access 329k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>