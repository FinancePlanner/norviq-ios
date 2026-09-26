# Social API contract

This is the contract for Norviq's social layer: friends, discovery, XP and leaderboards, and DMs. The iOS app implements the client side, and the backend implements this document.

**Status:**
- Phase 1 (friends, invites, privacy, block/report) is built in the app, behind `GET /v1/social/config`.
- Phases 2–4 are specified here and not built yet.

**Conventions:**
- Every path is under `/v1` and requires `Authorization: Bearer <access token>`.
- JSON keys are camelCase. Dates are ISO 8601, which `.stockPlanShared` decodes.
- Lists are cursor-paginated: `?cursor=&limit=` in, `nextCursor` out (null on the last page).
- Errors use the existing `APIEnvelope` shape with a `message`.
- **Blocking is invisible.** When either user has blocked the other, every endpoint that names the other user returns `404`, never `403`, so nobody can detect a block.
- **Money never appears in social payloads.** Only percentages, counts and levels do. The server must reject any payload that carries amounts.

The Swift types live in `financeplan/API/Social/SocialDTOs.swift`. They move to `norviq-shared` unchanged once the backend ships them.

## Rollout switch

`GET /social/config` returns `SocialConfig`:

```json
{ "enabled": true, "contactsDiscovery": false, "xImport": false, "leaderboards": false, "messaging": false }
```

- When the call fails or `enabled` is false, the app hides the Friends tab and the Friends settings.
- Turn a flag on only once its endpoints are live in production. App Review rejects features that are visibly incomplete.

## Phase 1: friends, invites, privacy, safety

| Method | Path | Body | Response | Notes |
|---|---|---|---|---|
| GET | `/social/users/search?q=` | — | `UserSearchResponse` | Case-insensitive username prefix match, min 2 chars. Respect `searchVisibility`. Exclude blocked users both ways. Rate-limit per user. |
| GET | `/social/users/{id}` | — | `SocialProfile` | Omit stats the owner's privacy settings hide. |
| GET | `/social/friends` | — | `FriendsListResponse` | |
| DELETE | `/social/friends/{userId}` | — | 204 | Unfriend. Ends DM access (Phase 4). |
| GET | `/social/friend-requests` | — | `FriendRequestsResponse` | `incoming` and `outgoing`, both pending only. |
| POST | `/social/friend-requests` | `{ "userId" }` | `FriendRequest` | Idempotent. If the target already has a pending request to the caller, accept it instead and return it. Push `friend_request` to the target. |
| POST | `/social/friend-requests/{id}/accept` | — | 204 | Push `friend_accepted` to the requester. |
| POST | `/social/friend-requests/{id}/decline` | — | 204 | No push. The requester isn't told. |
| DELETE | `/social/friend-requests/{id}` | — | 204 | The sender cancels. |
| POST | `/social/invites` | — | `InviteLink` | One reusable code per user; the same code comes back each time. `url` = `https://norviq.org/i/{code}`. Codes are 4–64 chars of `[A-Za-z0-9_-]`. |
| GET | `/social/invites/{code}` | — | `SocialUserSummary` | The inviter, for the preview sheet. 404 when the code is unknown or its owner has blocked the caller. |
| POST | `/social/invites/{code}/redeem` | — | `InviteRedeemResponse` | Sends a friend request from the redeemer to the inviter, which auto-accepts because the inviter asked. |
| GET / PUT | `/social/privacy` | `SocialPrivacySettings` | `SocialPrivacySettings` | The defaults are `SocialPrivacySettings.default` in the DTO file. `showReturnPercent` defaults to **false**. |
| GET | `/social/blocks` | — | `BlockedUsersResponse` | |
| POST / DELETE | `/social/blocks/{userId}` | — | 204 | Blocking removes the friendship and pending requests both ways, and hides DMs. |
| POST | `/social/reports` | `ReportRequest` | 202 | `targetType` is `user` or `message`. Queue for human review within 24 h (App Review Guideline 1.2). |

**`FriendshipStatus` values:**
- `none`, `outgoing_pending`, `incoming_pending`, `friends`, `blocked`.
- The app decodes unknown values as `none`.

**Content filtering:**
- Filter usernames and display names server-side at write time, against a profanity and slur list.
- Offending values get a 422 with a readable `message`.

**Push payloads:**
- Friend request: `{ "type": "friend_request" }`
- Request accepted: `{ "type": "friend_accepted" }`
- The app routes both to the Friends tab.

**Universal links:**
- The app claims `applinks:norviq.org` and `applinks:www.norviq.org`.
- Serve `/.well-known/apple-app-site-association` on both hosts. Include the `/i/*` component for the production and beta app IDs.
- `https://norviq.org/i/{code}` should also render a web page with the inviter's name, the code, and an App Store link. The app can't read the code after a fresh install, so the page must show it.

**Account deletion:** the existing delete-account endpoint must also delete friendships, requests, blocks, reports filed by the user, and invite codes.

## Phase 2: discovery (specified, not built)

**`POST /social/discovery/contacts/match`**
- **Body:** `{ "hashVersion": 1, "items": [{ "hash", "kind": "phone" | "email" }] }`, up to 1,000 items per call.
- **How the client hashes:** it normalizes each value, then applies HMAC-SHA256 with the `contactPepper` from `SocialConfig`.
  - Emails are trimmed and lowercased.
  - Phones are converted to E.164, with the device region as the default.
- **Response:** `{ "matches": [{ "hash", "user": SocialUserSummary }] }`.
- **Rules:**
  - Match only users with `discoverableByContacts = true`.
  - Store neither the hashes nor the non-matches.
  - Apply strict per-user rate limits.

**`POST /social/discovery/x/start`** and **`POST /social/discovery/x/exchange`**
- Server-side OAuth 2.0 PKCE with the scopes `follows.read users.read`. This needs X API Basic tier.
- `exchange` returns `{ "matches": [{ "xHandle", "user" }], "totalFollowingScanned" }`.
- Keep only the matched ids, and discard the X token.
- Match only users with `discoverableByX = true`.

**Not supported:**
- Instagram has no friends API, so it is invite-link only.
- Facebook friend matching is deferred.

## Phase 3: XP, streaks, leaderboards (specified, not built)

**XP and streaks:**

| Method | Path | Notes |
|---|---|---|
| GET | `/gamification/xp` | Returns `{ total, level, levelProgress, weekXP }`. |
| GET | `/gamification/xp/events` | Paginated `{ id, type, points, createdAt }`. `type` is one of `check_in`, `streak_milestone`, `badge_earned`, `expense_logged`, `budget_streak_month`. |
| GET | `/gamification/streaks` | Returns `{ checkInCurrent, checkInLongest, budgetMonths, lastCheckInDate }`. |
| POST | `/gamification/check-in` | Idempotent per local day, using the `X-Timezone` header. Returns `{ streak, xpAwarded, alreadyCheckedIn }`. |
| POST | `/gamification/streaks/budget` | `{ months }`. The server validates it against expense data. |

- The server awards XP. The client reports only facts, never XP amounts.

**`GET /social/leaderboards?metric=&period=`**
- `metric` is one of `return_percent`, `xp`, `check_in_streak`, `budget_streak`.
- `period` is `week` or `month`.
- **Who is ranked:** the caller and their friends. Only users with `leaderboardOptIn` appear.
- **Return % leaderboards** also require `showReturnPercent`. Return % is time-weighted and computed server-side.
- **Entry shape:** `{ rank, user, value, isMe }`. `value` is a percent or an integer, never money.

## Phase 4: DMs and realtime (specified, not built)

**REST endpoints:**

| Method | Path | Notes |
|---|---|---|
| GET | `/messaging/conversations` | |
| POST | `/messaging/conversations` | `{ peerId }`. Get-or-create. 404 unless the two are mutual friends and neither has blocked the other. |
| GET | `/messaging/conversations/{id}/messages?before=` | Newest first. |
| POST | `/messaging/conversations/{id}/messages` | Body `{ clientMessageId, content }`, deduplicated by `clientMessageId`. |
| DELETE | `/messaging/messages/{id}` | Sender only. Leaves a tombstone. |
| POST | `/messaging/conversations/{id}/read` | `{ upToMessageId }`. |
| POST / DELETE | `/messaging/conversations/{id}/mute` | |
| GET | `/messaging/unread-count` | `{ total, requests }` |

**Message content:**
- `content` is a tagged union: `text`, `portfolio_snapshot`, `ticker`, `badge`, `leaderboard_rank`.
- **Portfolio snapshots** carry only `{ symbol, name, weightPercent }` rows plus `returnPercent`/`dayChangePercent`. The server rejects any amount field.
- **Filtering:** the server filters text, and rejected text gets 422 `content_rejected`.
- **Reports:** messages can be reported through `/social/reports` with `targetType: "message"`.

**Realtime:**
- **Connection:** `wss://api.norviq.org/ws`, bearer auth on upgrade, `?resume=<lastSeq>`.
- **Server → client:** events `{ type, seq, ts, payload }`. `type` is one of `message.new`, `message.deleted`, `message.read`, `typing`, `friend.request`, `friend.accepted`, `block.applied`, `resync_required`.
- **Heartbeat:** the server pings every 25 s.
- **Replay:** it replays up to 500 missed events. Beyond that it sends `resync_required`, and the client refetches over REST.

**Push:**
- Payload is `{ "type": "chat_message", "conversationId" }` with `thread-id` = conversationId.
- Muted conversations get no push.

## App Store checklist before each launch

- **Guideline 1.2:**
  - Report and block are reachable from every profile. From every chat once DMs ship.
  - Reports are reviewed within 24 h.
  - The terms/EULA forbid objectionable content.
  - The support contact is published.
- **Demo account:** the reviewer demo account has one pre-added friend, so reviewers can reach these screens.
- **Contacts (Phase 2):** add `NSContactsUsageDescription`, update `PrivacyInfo.xcprivacy` and the App Store privacy label.
- **Metadata:** change App Store metadata and onboarding copy to the social positioning only in the release that turns `enabled` on. Metadata must describe what the build does (Guideline 2.3.1).
