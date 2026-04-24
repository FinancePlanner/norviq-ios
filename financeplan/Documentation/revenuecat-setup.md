# RevenueCat Setup — iOS Client

## What's already implemented

- RevenueCat SDK installed via SPM
- `BillingManager` handles configure, login, purchase, restore
- `PaywallView` shows annual/monthly plans with purchase and restore buttons
- `Info.plist` has a `RevenueCatAPIKey` entry read at runtime
- After purchase/restore, the app calls `POST /billing/restore` to sync entitlements with the backend

---

## What's missing

### 1. Verify the RevenueCat API key

`Info.plist` currently has:

```xml
<key>RevenueCatAPIKey</key>
<string>test_rMSfBBsOXDbWTOdVGdvMGLWvaiv</string>
```

This is a placeholder. Replace it with the real key from:

> RevenueCat Dashboard → Project → Apps → your iOS app → API Keys

The key must start with `appl_`. Without the correct key, `Purchases.configure` will fail silently and `loadOfferings()` will return empty packages.

---

### 2. Create products in App Store Connect

`BillingManager` looks for these exact product identifiers:

```swift
static let annualProductID = "pro_annual"
static let monthlyProductID = "pro_monthly"
```

Go to [App Store Connect](https://appstoreconnect.apple.com) → your app → In-App Purchases and create:

| Product ID | Type | Price |
|------------|------|-------|
| `pro_annual` | Auto-Renewable Subscription | e.g. $59.99/yr |
| `pro_monthly` | Auto-Renewable Subscription | e.g. $5.99/mo |

Both must be in the same subscription group.

---

### 3. Add a StoreKit Configuration File for simulator testing

Without this, the simulator cannot load offerings and the paywall shows hardcoded fallback prices.

**Steps:**

1. In Xcode: **File → New → File → StoreKit Configuration File** → name it `StoreKit.storekit`
2. Add two Auto-Renewable Subscription products:
   - Product ID: `pro_annual`, price: $59.99
   - Product ID: `pro_monthly`, price: $5.99
3. Attach it to your scheme: **Edit Scheme → Run → Options → StoreKit Configuration → select `StoreKit.storekit`**
4. In RevenueCat dashboard, enable **StoreKit Testing** for your iOS app (Project Settings → Apps → your app)

---

### 4. Verify the `pro` entitlement in RevenueCat

Go to RevenueCat Dashboard → Entitlements and confirm:

- An entitlement named exactly `pro` exists
- Both `pro_annual` and `pro_monthly` products are attached to it

`BillingManager` checks for `entitlementID = "pro"` — if the entitlement has a different name, purchases will appear to succeed but `isPro` will stay `false`.

---

## Checklist

- [ ] `RevenueCatAPIKey` in `Info.plist` replaced with real `appl_...` key
- [ ] `pro_annual` product created in App Store Connect
- [ ] `pro_monthly` product created in App Store Connect
- [ ] `StoreKit.storekit` config file added to project
- [ ] Scheme configured to use `StoreKit.storekit` for Run
- [ ] RevenueCat StoreKit Testing enabled for the iOS app
- [ ] `pro` entitlement exists in RevenueCat and has both products attached
