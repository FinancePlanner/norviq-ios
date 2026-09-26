# Launching social: runbook

This is everything needed to switch on friends, discovery and leaderboards in production, in order. The API itself is described in `social_api.md`.

## 1. Deploy the backend

- **Merge:** norviq-backend `main` must include the social, moderation and gamification PRs.
- **Redeploy:** use the usual VPS path, `/opt/stockplan`, `docker compose` with `.env.production`.
  - Migrations run on boot and add these tables: `social_*`, `gamification_*`, and the moderation columns.
- **Check the build:** `GET /v1/social/config` with a signed-in token should answer `{"enabled": false, …}` before step 2.

## 2. Server settings (`/opt/stockplan/.env.production`)

```
SOCIAL_ENABLED=1
SOCIAL_CONTACT_PEPPER=<paste the output of: openssl rand -hex 32>
SOCIAL_MODERATOR_EMAILS=you@example.com,cofounder@example.com
SOCIAL_LEADERBOARDS_ENABLED=1
# SOCIAL_X_IMPORT_ENABLED=1   # leave off until the X API plan allows follows.read
```

- **After editing:** restart the API container, then check that `/v1/social/config` answers `enabled: true` and `contactsDiscovery: true`.
- **The pepper:** generate it once and keep it.
  - **Changing it:** every contact hash goes stale until each user opens the app again.
  - **What it is:** it's sent to the app by design. It isn't a password, so it doesn't need to be kept secret from clients. It just shouldn't live in git.
- **Discord alerts:** `DISCORD_WEBHOOK_URL`, which is already set, now also receives a message for every report.

## 3. Invite links (norviq.org)

- **The association file:** `https://norviq.org/.well-known/apple-app-site-association` and the `www` host must both serve the AASA file as `application/json`, with no redirect. The norviq-web repo ships it.
- **Checking it:**
  - Apple's CDN caches the file, so allow up to a day after deploying.
  - Then run `curl -s https://app-site-association.cdn-apple.com/a/v1/norviq.org`.
- **The fallback page:** `https://norviq.org/i/<code>` opens the app when it's installed. When it isn't, the page shows the code and an App Store link.

## 4. Moderation (App Review Guideline 1.2)

Reports must be acted on within 24 hours. Each report posts to Discord. Work the queue with any moderator's token:

```sh
TOKEN=…  # sign in as a SOCIAL_MODERATOR_EMAILS account
# open reports, oldest first
curl -s -H "Authorization: Bearer $TOKEN" https://api.norviq.org/v1/admin/social/reports
# close one: nothing wrong
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"action":"dismiss","note":"not abusive"}' https://api.norviq.org/v1/admin/social/reports/<id>/resolve
# close one and remove the user from social
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"action":"suspend_user","note":"harassment"}' https://api.norviq.org/v1/admin/social/reports/<id>/resolve
# lift a suspension
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" https://api.norviq.org/v1/admin/social/users/<userId>/suspend
```

A suspended user:
- is hidden from everyone, the same way a block hides someone
- loses their friendships and pending requests
- gets 403 on every social route

## 5. App Store Connect

- **Terms / EULA:** the terms on norviq.org must include the user-content clause from the norviq-web PR:
  - zero tolerance for objectionable content or abusive users
  - how to report
  - action within 24 hours
- **Privacy label:** add **Contacts**, marked *not linked to the user*, for *App Functionality*. The app hashes addresses on the device and the server stores nothing it's sent. The privacy manifest already declares this.
- **When to switch on:** turn social on **before** you submit the build (steps 1–2). A feature that is switched on after review can be rejected under Guideline 2.3.1.
- **Review account:** it needs one friend already added, so the reviewer can reach every screen:
  1. Create a second test account, e.g. `norviq_review_friend`.
  2. Signed in as the review account, open Friends and tap Invite friends, then copy the link.
  3. Open the link on a device signed in as the second account, or call `POST /v1/social/invites/<code>/redeem` with that account's token. The two accounts are now friends.
  4. On the second account, do one daily check-in, so the leaderboard has two rows.

### Review notes (paste into App Store Connect)

> Norviq now has a Friends tab (bottom bar). The demo account already has one friend, "norviq_review_friend".
> • Friends: tap a friend to open their profile; the ••• menu has **Report** and **Block**. Blocked people are listed under Friends → ••• → Blocked people.
> • Leaderboard: Friends → Leaderboard compares friends by XP, check-in streak or return % (percentages only; return % is shown only for people who opt in under Friends → ••• → Privacy).
> • Invites: Friends → Invite friends shares a link and QR code.
> • Find friends from contacts is optional: email addresses are hashed on the device and matched against people who allow it; nothing is uploaded in the clear or stored.
> Reports reach our moderation queue immediately and are reviewed within 24 hours; abusive users are removed from social features.

## 6. After launch

- Watch the Discord channel for reports.
- Watch PostHog tab analytics, since Crypto moved from the tab bar into More.
- X import is ready behind `SOCIAL_X_IMPORT_ENABLED` whenever the X API plan allows it.
