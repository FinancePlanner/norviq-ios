# Achievements — iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring achievements to the iOS app: an Achievements screen (replacing Badges when on), an unlock celebration sheet, push handling + the `achievements_v1` capability, the friends activity feed with 🎉 congrats, friend-profile showcase, and the "Show achievements to friends" privacy toggle — gated on the backend config flags.

**Architecture:** New `API/Achievements` domain following the existing `{Endpoints,HTTPClient,DTOs,Container+Factories}` pattern; social additions in `API/Social`. `@MainActor @Observable` stores. An `AchievementUnlockCoordinator` runs on app-active, fetches unseen unlocks, marks them seen, and drives a celebration sheet. Accept-Language is sent from the in-app language so server-provided titles are localized.

**Tech Stack:** Swift 6.1, SwiftUI (iOS 18), Factory DI, XCTest, String Catalog, SwiftLint 0.65.1 / SwiftFormat.

**Spec:** norviq-backend `docs/superpowers/specs/2026-10-21-achievements-design.md` (iOS section). Backend contract: norviq-backend `openapi.yaml` on `main` (Achievements + Social tags). Web reference: norviq-web PR #138.

## Global Constraints

- Worktree `norviq/.worktrees/norviq-ios-achievements`, branch `feat/achievements-ios` off `main` (`8cf689e`). New files need no `project.pbxproj` edits (synchronized groups).
- Gates: everything achievements-related appears only when `SocialConfig.achievements` is true; the feed, congrats and friend achievements list only when `SocialConfig.activityFeed` is true. Both decode with `decodeIfPresent ?? false`. With both off, the app behaves exactly as today (Badges screen, no feed, no new pushes handled differently).
- DTOs: app-local, `nonisolated struct … Codable, Sendable, Hashable`; decoder `.stockPlanShared`; optional fields `decodeIfPresent`. No norviq-shared change.
- Icons: server `iconKey` is an SF Symbol name; render with a fallback (`rosette`) when `UIImage(systemName:)` is nil.
- No money anywhere. Performance achievements never show progress.
- Motion: use `AppMotion` / `.appAnimation`; respect Reduce Motion (static presentation when on).
- Copy: every user-facing literal goes through the String Catalog with an `en` and a European Portuguese `pt-PT` translation (state `translated`). Server titles are not catalogued.
- Design: `AppTheme` tokens (colors, spacing, radius), `.typography(...)`, existing components (`GlassCard`, `ProgressBar`, `EmptyStateView`, `ErrorRetryView`, `SocialAvatar`).
- Tests: XCTest in `financeplanTests/`, mocks of service protocols (pattern `SocialStoreTests.swift`), raw-JSON decode tests (pattern `SocialFacebookImportTests.swift`). No network. Add new test classes to the CI gating `-only-testing` list in `.github/workflows/ci.yml`.
- Build/test: `xcodebuild build -project financeplan.xcodeproj -scheme financeplan -destination 'generic/platform=iOS Simulator'`; tests `xcodebuild test … -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/<Class> -parallel-testing-enabled NO`; lint `./scripts/format.sh --skip-install --lint-only`.

## Review Focus

1. Flags off (or config fetch fails → `.disabled`): Badges screen, Social tab and push routing unchanged — Tasks 2, 4, 5.
2. The celebration sheet shows each unlock once, never while another sheet (settings, paywall, capture, review prompt) is up, and never loops on failure — Task 3.
3. An old push payload of an unknown kind still routes as before; new kinds route to Achievements / feed — Task 4.
4. Congrats tapped twice sends one request and the count rises by one — Task 5.
5. Privacy save keeps `showAchievements` from the server value when the toggle isn't shown — Task 5.

---

### Task 1: API layer — achievements domain, social additions, language header

**Files:** create `financeplan/API/Achievements/{AchievementsEndpoints,AchievementsHTTPClient,AchievementsDTOs,Container+AchievementsFactories}.swift` and `financeplan/Features/Achievements/AchievementsService.swift` (`protocol AchievementsServicing { func list() async throws -> AchievementsResponse; func unseen() async throws -> [AchievementUnlock]; func markSeen(_ ids: [UUID]) async throws; func setShowcase(_ items: [AchievementShowcaseItem]) async throws -> AchievementsResponse }` + `DefaultAchievementsService`); modify `API/Social/SocialDTOs.swift` (`SocialConfig.achievements`, `.activityFeed`; `SocialProfile.showcase: [AchievementShowcaseEntry]?`; `SocialPrivacySettings.showAchievements` default true, `decodeIfPresent ?? true`; feed DTOs `SocialFeedResponse`, `SocialFeedItem`, `SocialFeedAchievement`), `API/Social/SocialEndpoints.swift` (`GetSocialFeedEndpoint(cursor:limit:)`, `CongratulateActivityEndpoint(activityId:)` → `EmptyAPIResponse`, `GetFriendAchievementsEndpoint(userId:)`), `Features/Social/SocialService.swift` (protocol + default: `feed(cursor:limit:)`, `congratulate(activityId:)`, `friendAchievements(userId:)`), test mocks; add an `Accept-Language` header (value from the in-app language, `AppLanguage`, e.g. `pt-PT` / `en`) via `extraHeadersProvider` on the Achievements and Social HTTP clients.

- [ ] Tests (`AchievementsDTOTests`, extend `SocialStoreTests`/`SocialFacebookImportTests` patterns): decode an achievements fixture (earned, in-progress, locked, hidden with `hidden.1` key and null thresholds, performance with null progress); config JSON without `achievements`/`activityFeed` → false; privacy JSON without `showAchievements` → true; profile with/without `showcase`; feed page with `nextCursor` null; endpoint paths/methods/bodies (`/v1/achievements/seen` body `{ids}`, showcase `{items:[{key,tier}]}`, feed query items `cursor`/`limit`); the language header provider returns `pt-PT` when the app language is Portuguese.
- [ ] RED → GREEN; lint; commit `feat(achievements): API layer and language header`.

---

### Task 2: Achievements screen (replaces Badges when on)

**Files:** create `Features/Achievements/{AchievementsStore.swift, AchievementsView.swift, AchievementCard.swift, AchievementSymbol.swift}`; modify `Features/UserProfile/UserProfileView.swift` (Achievements section row → `AchievementsView` when `socialStore.config.achievements`, else `BadgesView`; `UserProfileDestination` gains `.achievements`).

**Screen:** header with "Unlocked n of total" (+ "n hidden"); a Showcase row (pinned, ranked) when any; one section per category in API order; cards in an adaptive grid: SF symbol (fallback), title, description, tier pills (Bronze/Silver/Gold localized, or single), progress bar `current/target` for in-progress, muted locked, "???" + lock for hidden; earned (non-hidden, non-performance-safe) cards have a context menu / button "Pin"/"Unpin" (max 3; at 3, Pin disabled with explanation). Pin/unpin calls `setShowcase` with the full desired list and replaces the response; failure → toast error. Pull to refresh. Loading skeleton; `ErrorRetryView` on failure; `EmptyStateView` never needed (catalogue is non-empty).

**Store:** `@MainActor @Observable final class AchievementsStore { var state: LoadState<AchievementsResponse>; func load() async; func pin(_:) async; func unpin(_:) async }` with pure helpers `showcase(from:)`, `canPin(_:)`, `pinnedItems(after:)` unit-tested.

- [ ] Tests (`AchievementsStoreTests` with a mock `AchievementsServicing`): load success/failure; pin appends and sends full list; unpin removes; cannot pin hidden/unearned/4th; showcase ordering by rank. A small view test is optional.
- [ ] RED → GREEN; build; lint; commit `feat(achievements): achievements screen`.

---

### Task 3: Unlock celebration

**Files:** create `Features/Achievements/{AchievementUnlockCoordinator.swift, AchievementUnlockSheet.swift}`; modify `ContentView.swift` (scenePhase `.active` when authenticated → `coordinator.checkForUnlocks()`; also once after sign-in/launch) and `HomeScreen.swift` (present the sheet; suppress while other sheets are up, using the same conditions that gate `ReviewPromptPresenter`).

**Coordinator:** `@MainActor @Observable final class AchievementUnlockCoordinator { var pending: [AchievementUnlock]; func checkForUnlocks() async; func dismiss() }`. `checkForUnlocks`: skip if achievements off or a check is in flight or `pending` non-empty; fetch unseen; if empty → done; `markSeen(ids)` FIRST; on failure → drop (show nothing); else set `pending`. Port `BadgesViewModel.considerBadgeReview` → after the sheet is dismissed call `reviewPromptCoordinator().consider(.badgeTierEarned(badgeID: key, tier:), userID:)` for the first unlock.

**Sheet:** `GlassCard`-based, medium detent: large SF symbol, "Achievement unlocked" (or "<n> achievements unlocked"), title + tier, description, "+<xp> XP"; buttons "View all" (opens Achievements) and "Done". Entrance: scale+opacity spring via `AppMotion`; static under Reduce Motion; `.sensoryFeedback(.success, …)` on appear.

- [ ] Tests (`AchievementUnlockCoordinatorTests`): flag off → no fetch; empty → no pending; two unseen → markSeen called with both ids before pending is set; markSeen failure → no pending; second check while pending → no fetch; dismiss clears and triggers the review-prompt consideration once.
- [ ] RED → GREEN; build; lint; commit `feat(achievements): unlock celebration sheet`.

---

### Task 4: Push — capability, kinds, routing

**Files:** `Features/Notifications/PushNotificationsService.swift` (capabilities `["rebalance_drift_v1", "achievements_v1"]`), `Features/Notifications/PushNotificationsCoordinator.swift` (`Kind.achievementUnlocked = "achievement_unlocked"`, `.achievementCongrats = "achievement_congrats"`; parser accepts them without a symbol), `ContentView.swift` route switch (unlocked → post `.openAchievementsFromPushNotification`; congrats → post `.openSocialFromPushNotification` with `["section": "feed"]`), `Features/Social/SocialDeepLink.swift` (new notification name), `HomeScreen.swift` (`.onReceive` → open Profile → Achievements when achievements on; social tab + feed section when activityFeed on; otherwise ignore).

- [ ] Tests: parser returns the new kinds from `["type": "achievement_unlocked"]` / `achievement_congrats`; unknown kind still falls back as today; registration request includes `achievements_v1` (and keeps `rebalance_drift_v1`); routing posts the right notification.
- [ ] RED → GREEN; build; lint; commit `feat(achievements): push kinds, routing and capability`.

---

### Task 5: Social — feed, congrats, friend showcase, privacy toggle

**Files:** `Features/Social/SocialRoot.swift` (`SocialSection.feed` shown when `config.activityFeed`; Picker shown when leaderboards OR feed; deep-link to feed section), create `Features/Social/{SocialFeedStore.swift, SocialFeedView.swift, CongratsButton.swift, FriendAchievementsView.swift}`; modify `SocialProfileView.swift` (Progress section: badge count row stays; a Showcase row of up to 3 symbol+title chips when `profile.showcase` non-empty; "All achievements" NavigationLink → `FriendAchievementsView` when activityFeed on), `SocialPrivacySettingsView.swift` ("Show achievements to friends" toggle in "What friends see" only when `config.achievements`).

**Feed:** list rows (`SocialAvatar`, "<username> unlocked <title> (<Tier>)", relative date, `CongratsButton`); infinite scroll via `nextCursor` (load next when last row appears; no duplicate pages; stop at nil); pull to refresh; `EmptyStateView` "When friends unlock achievements, they show up here."; errors via `ErrorRetryView`. **CongratsButton:** optimistic: tap → mark congratulated, count+1, call `congratulate`; disabled while in flight and once congratulated; on failure revert (404 → remove row with toast "No longer available").

- [ ] Tests (`SocialFeedStoreTests`): first page + next page appended, no refetch after nil cursor, concurrent load-more ignored; congrats optimistic success, double tap → one call, failure reverts, 404 removes; privacy: toggle hidden when achievements off and the saved struct keeps the server `showAchievements`.
- [ ] RED → GREEN; build; lint; commit `feat(social): activity feed, congrats, friend showcase and privacy toggle`.

---

### Task 6: Localization, CI gating, full verification, PR

- [ ] Every new literal has `en` + `pt-PT` (translated) in `Localizable.xcstrings`; run `fix_xcstrings.py` if needed; add a test that loads the catalog and asserts the new keys have `pt-PT`.
- [ ] Add new test classes to the CI gating `-only-testing` list.
- [ ] `./scripts/format.sh --skip-install --lint-only`; `xcodebuild build …`; gating tests; full test bundle → green (report pre-existing failures with evidence from `main`).
- [ ] Push; open PR "Achievements on iOS (flags off)"; merge with the user's go-ahead → TestFlight via the release lane.
