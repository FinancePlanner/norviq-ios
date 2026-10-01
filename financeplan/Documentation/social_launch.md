# Launching social: runbook

This is everything needed to switch on friends, discovery and leaderboards in production, in order. The API itself is described in `social_api.md`.

## 1. Deploy the backend

- **Merge:** norviq-backend `main` must include the social, moderation and gamification PRs. Merging to `main` builds the image and the promote job deploys it; there is no VPS step any more.
  - Migrations run on boot and add these tables: `social_*`, `gamification_*`, and the moderation columns.
- **Check the build:** `GET /v1/social/config` with a signed-in token should answer `{"enabled": false, …}` before step 2.

## 2. Server settings (infra repo)

The API runs on the `maat` cluster from `LuminaVault/LuminaVaultInfra` (`~/Work/production/platform/infra`), and ArgoCD deploys whatever is merged to `main`. `/opt/stockplan/.env.production` no longer deploys anything; editing it changes nothing.

Do staging (`norviq-staging`) first, check it, then production (`norviq`).

**Plain settings.** Add them to the `env:` list in **both** `apps/norviq/api/values-staging.yaml` and `apps/norviq/api/values-production.yaml` (Helm replaces `env:` lists rather than merging them, so `values-common.yaml` doesn't reach the pod):

```yaml
  - name: SOCIAL_ENABLED
    value: "1"
  - name: SOCIAL_LEADERBOARDS_ENABLED
    value: "1"
  - name: SOCIAL_MODERATOR_EMAILS
    value: you@example.com,cofounder@example.com
  # - name: SOCIAL_X_IMPORT_ENABLED   # leave off until the X API plan allows follows.read
  #   value: "1"
```

**The pepper.** It's sealed into the existing `api-env` secret, once per namespace (see `secrets/norviq/README.md`):

```sh
kubeseal --fetch-cert --controller-name sealed-secrets-controller \
  --controller-namespace kube-system > /tmp/sealed-secrets.pem
printf '%s' "$(openssl rand -hex 32)" | kubeseal --raw --cert /tmp/sealed-secrets.pem \
  --namespace norviq-staging --name api-env   # then again with --namespace norviq
```

Paste each output under `encryptedData:` in `secrets/norviq/{staging,production}/api-env.yaml` as `SOCIAL_CONTACT_PEPPER: AgB…`.

- **Namespace:** seal for `norviq` / `norviq-staging`, never `production`. A blob sealed for the wrong namespace decrypts to nothing, with no error.
- **`printf`, not `echo`:** otherwise a trailing newline is sealed into the value.
- **Generate it once and keep it.**
  - **Changing it:** every contact hash goes stale until each user opens the app again.
  - **What it is:** it's sent to the app by design. It isn't a password, so it doesn't need to be kept secret from clients. It just shouldn't live in git in plain text.

**After the infra PR merges and Argo syncs:** `kubectl rollout restart deploy/api -n <namespace>` (env from the secret is only read at pod start), then check that `/v1/social/config` answers `enabled: true`, `contactsDiscovery: true` and `leaderboards: true`.

- **X import:** besides `SOCIAL_X_IMPORT_ENABLED`, the X app must allow `follows.read`, and `OAUTH_ALLOWED_REDIRECT_URIS` in `api-env` must contain each callback in use (the app uses `https://api.norviq.org/v1/auth/oauth/x/callback`).
- **Discord alerts:** `DISCORD_WEBHOOK_URL`, already set in production, now also receives a message for every report. Staging has none.

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
