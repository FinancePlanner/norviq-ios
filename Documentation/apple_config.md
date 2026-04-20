# Apple App Store Deployment Configuration

Based on the repository scan of the iOS App and Backend configurations, the application is technically very sound. However, deploying to the App Store requires a specific set of administrative, privacy, and production assets beyond just hosting the API.

Here is the checklist of what is missing to successfully pass Apple App Store Review and configure production:

### 1. Privacy & Entitlements
* **App-Level Privacy Manifest (`PrivacyInfo.xcprivacy`)**: While third-party SDKs (like Sentry) include their own privacy manifests, Apple now strictly requires a top-level `PrivacyInfo.xcprivacy` file placed inside the `financeplan` target to declare the app's explicit data-handling categories (especially due to the usage of `UserDefaults`).
* **App Tracking Transparency (ATT)**: The app lacks the `NSUserTrackingUsageDescription` key in `Info.plist`. Because the app utilizes Sentry for crash/error tracking, Apple demands this string explaining to users what data might be collected. 

### 2. Assets & UI Polish
* **App Icon Validation**: The `AppIcon.appiconset` only contains two raw source images (`nordiq-dark-mode.png` and `nordiq-light-mode.png`). App Store Connect rejects binaries that lack a generated 1024x1024 App Store icon with absolutely **zero transparency/alpha channels**. Ensure these PNGs are properly compiled in Xcode's Asset Catalog and flattened.
* **App Store Screenshots**: You will need to stage data and generate screenshots for iPhone 6.5" and 5.5" displays (and optionally iPad) to upload to App Store Connect. 

### 3. Apple Developer/Cloud Configurations
* **Production APNs Setup**: The `.entitlements` file registers `aps-environment` locally, but a `.p8` Push Notification Key must be generated in the Apple Developer Portal and attached to the eventually hosted API (the backend currently drops a warning for APNS disabled). 
* **Sign In With Apple Configuration**: To utilize OAuth production keys, an explicitly defined Service ID and `Team ID` must be configured in the Apple Developer Portal so that logging in authenticates securely.
* **Applies Exception Domains**: In `Info.plist`, `NSExceptionAllowsInsecureHTTPLoads` is set to `true` for `api.norviqa.io`. Since you are preparing for production, this override must be removed—Apple automatically flags and rejects deployments that permit unencrypted HTTP loads on production APIs, requiring you to host the API on raw HTTPS.

### 4. App Store Connect Legalities
* **Privacy Policy URL**: Apple requires an active external URL hosting a compliant Data Privacy statement. 
* **Support Data URL**: Apple requires a linked webpage or email form to field active support requests.

Everything else (Launch Screens, UI paradigms, Face ID declarations, and internal state routing) is completely production-ready. Once the Developer Portal certificates are matched against a final Bundle Identifier and the API is hosted with SSL, the app will be cleared for TestFlight and public release!
