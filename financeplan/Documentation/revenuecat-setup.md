# RevenueCat Setup — iOS Client

## What's already implemented

- RevenueCat SDK installed via SPM
- `BillingManager` handles configure, login, purchase, restore, optimistic Pro unlock, and backend sync with retries
- Paywall screens show weekly / monthly / annual plans with plan-aware CTA and subscription disclosure
- `Info.plist` has production `RevenueCatAPIKey` (`appl_...`) read at runtime
- After purchase/restore, the app calls `POST /billing/restore` to sync entitlements with the backend
- Local StoreKit testing via `Products.storekit` (all three SKUs; 7-day trial on annual only)

See also: [`Documentation/revenuecat-apple-review-plan.md`](../../../../Documentation/revenuecat-apple-review-plan.md), [`Documentation/subscriptions-unavailable-app-review-fix.md`](../../../../Documentation/subscriptions-unavailable-app-review-fix.md), and backend [`StockPlanBackend/docs/revenuecat-setup.md`](../../../../StockPlanBackend/docs/revenuecat-setup.md).

---

## Product identifiers

`BillingManager` expects these exact App Store product IDs:

| Product ID | Plan |
|------------|------|
| `pro_weekly` | Weekly |
| `pro_monthly` | Monthly |
| `pro_annual` | Annual (7-day free trial intro offer) |

RevenueCat entitlement ID: **`pro_access`**

---

## App Store Connect checklist

- [ ] Create all three auto-renewable subscriptions in **one subscription group**
- [ ] Set 7-day free trial introductory offer on **`pro_annual` only**
- [ ] Add localizations and subscription review screenshot
- [ ] Paid Apps Agreement, banking, and tax complete
- [ ] Privacy Policy URL and Support URL on the app record

---

## RevenueCat dashboard checklist

- [ ] Entitlement `pro_access` with all three products attached
- [ ] Default offering includes weekly, monthly, and annual packages
- [ ] App Store Connect API / shared secret linked
- [ ] Webhook → `POST https://<prod-api>/webhooks/revenuecat` with Authorization = `REVENUECAT_WEBHOOK_SECRET`

---

## Local / simulator testing

1. Xcode → **Edit Scheme → Run → Options → StoreKit Configuration** → `Products.storekit`
2. Run on simulator; paywall should show live prices from StoreKit (not fallback placeholders)
3. Optional: enable StoreKit Testing in RevenueCat project settings

---

## Production backend (required for Pro on server)

- `REVENUECAT_API_KEY` — secret `sk_...` key (not the iOS `appl_` key)
- `REVENUECAT_WEBHOOK_SECRET` — same value as webhook Authorization header

Without these, purchases may succeed in the App Store but `GET /billing/me` stays on the free tier and Pro features (earnings transcripts + audio, advanced research, etc.) remain locked.

Earnings calendar list is available as a teaser to free users; transcripts and "Listen" (TTS) audio require the Pro entitlement (earningsText).

---

## iOS checklist

- [ ] `RevenueCatAPIKey` in `Info.plist` is the production `appl_...` key
- [ ] `pro_weekly`, `pro_monthly`, `pro_annual` exist in App Store Connect
- [ ] `Products.storekit` attached to Run scheme for local QA
- [ ] `pro_access` entitlement in RevenueCat with all three products
- [ ] Production webhook + API key deployed and verified
