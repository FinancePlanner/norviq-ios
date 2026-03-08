# FinancePlan Auth

## Purpose
This document explains how authentication works in the iOS app today, how JWTs are used, and what changed to make authenticated stock requests work reliably during onboarding and after login.

## Backend Contract

The backend uses a two-token session model:

- Access token:
  - signed JWT
  - includes `userId` and `exp`
  - verified by the backend on every protected request
- Refresh token:
  - opaque random token
  - hashed and stored server-side
  - rotated on refresh

Default TTLs in the backend repo are:

- access token: `604800` seconds (`7` days)
- refresh token: `2592000` seconds (`30` days)

Relevant backend files:

- `StockPlanBackend/Sources/StockPlanBackend/Auth/SessionToken.swift`
- `StockPlanBackend/Sources/StockPlanBackend/Auth/AuthService.swift`
- `StockPlanBackend/Sources/StockPlanBackend/Auth/AuthController.swift`
- `StockPlanBackend/Sources/StockPlanBackend/configure.swift`

## iOS Auth Components

### API layer
- `financeplan/API/Auth/AuthEndpoints.swift`
  - defines `/v1/auth/login`
  - defines `/v1/auth/register`
  - defines `/v1/auth/forgot-password`
  - defines `/v1/auth/refresh`
  - defines logout endpoint handling

- `financeplan/API/Auth/AuthHTTPClient.swift`
  - executes auth requests
  - decodes typed DTOs from `StockPlanShared`
  - maps server errors into app-facing errors

### Session storage
- `financeplan/Features/Auth/AuthService.swift`
  - `UserDefaultsAuthSessionStore` stores:
    - access token
    - refresh token
    - access token expiry metadata
    - refresh token expiry metadata
    - current user id
    - current username
    - onboarding import completion state

- `financeplan/Features/Auth/SecureStringStore.swift`
  - provides `KeychainStringStore`
  - access and refresh tokens are stored in Keychain when available
  - if secure storage cannot read the value back, the app falls back to `UserDefaults` so the session is still usable

### JWT/session logic
- `financeplan/Features/Auth/JWTTokenInspector.swift`
  - decodes the JWT payload locally
  - reads `userId`
  - reads `exp`
  - does not verify the JWT signature on-device

- `financeplan/Features/Auth/AuthSessionManager.swift`
  - is the client-side source of truth for session state
  - restores a session on app launch
  - decides whether the current access token is still usable
  - refreshes the session when needed
  - clears session state and notifies the UI when the session is no longer valid

### App flow and feature services
- `financeplan/ContentView.swift`
  - restores auth state on launch through `AuthSessionManager`
  - no longer treats "non-empty token string" as sufficient proof of a valid session

- `financeplan/Features/Onboarding/StockService.swift`
  - attaches a bearer token to stock requests
  - refreshes once and retries once on unauthorized responses

- `financeplan/Features/UserProfile/UserProfileService.swift`
  - uses the same authenticated request pattern as stock requests

## How JWT Auth Works In This App

### 1. Login
1. `LoginScreen` calls `LoginViewModel.submit()`.
2. `LoginViewModel` calls `AuthService.login(...)`.
3. `AuthService` uses `AuthHTTPClient` to call `/v1/auth/login`.
4. Backend returns:
   - JWT access token
   - opaque refresh token
   - `expiresIn`
   - `refreshExpiresIn`
   - user identity fields
5. `LoginViewModel` persists the auth response through `sessionStore.store(authResponse:)`.

### 2. Local session persistence
When the app stores a successful auth response it:

- stores the access token
- stores the refresh token
- stores `currentUserID`
- stores display name fields
- derives access token expiry from JWT `exp` when available
- falls back to `expiresIn` when JWT claims cannot be read
- stores refresh token expiry from `refreshExpiresIn`

### 3. App launch / session restore
On launch, `ContentView` calls `authSessionManager.restoreSessionIfNeeded()`.

The session manager:

- returns the current access token if it is still valid
- refreshes shortly before expiry when a refresh token is still usable
- refreshes immediately if the access token is already expired
- clears the session if neither token is usable

### 4. Protected requests
Feature services do not read raw tokens directly from UI code.

Instead:

1. feature service asks `AuthSessionManager` for a usable access token
2. service builds its HTTP client with `Authorization: Bearer <token>`
3. backend validates the JWT
4. if the backend returns `401`, the service refreshes once and retries once
5. if the retry is also unauthorized, the app invalidates the session and returns the error to the UI

### 5. Logout
Logout sends the refresh token to the backend logout endpoint and then clears all local session state.

## JWT Awareness: What The App Does And Does Not Do

The app is JWT-aware in a pragmatic client sense:

- it reads `exp` to understand local access-token lifetime
- it reads `userId` to synchronize user session state
- it uses refresh tokens to recover from expired access tokens
- it retries once after refresh on `401`

The app does not treat itself as the authority for JWT validity:

- it does not verify JWT signatures locally
- it does not replace backend authorization checks
- backend `401` responses remain the source of truth

This is intentional. The mobile client uses the JWT for local session timing and UX, while the backend performs real authorization.

## Changes Made To Make Authenticated Stock Requests Work

The onboarding/manual-import issue was caused by the app failing locally before it made the protected stock request. The following changes were made.

### 1. Added explicit JWT/session handling
- introduced `JWTTokenInspector`
- introduced `AuthSessionManager`
- added `/v1/auth/refresh` support to the auth client and service

Result:
- the app now understands access-token expiry
- the app can refresh and restore sessions instead of relying on token presence only

### 2. Moved token usage behind the session manager
- `StockService` and `UserProfileHTTPService` now request a valid access token from `AuthSessionManager`
- they no longer rely on reading and sending whatever raw token string happens to exist

Result:
- all protected features use one consistent auth flow

### 3. Added refresh-and-retry behavior for protected calls
- stock requests now refresh once on unauthorized and retry once
- profile requests follow the same pattern

Result:
- short-lived client drift, stale tokens, or first-request expiry no longer immediately log the user out

### 4. Tightened the local refresh policy
The session manager now:

- treats a token as usable until it is actually expired
- only pre-refreshes in a small window before expiry
- falls back to the still-valid access token if refresh fails but the token has not yet expired

Result:
- the app is less aggressive about declaring the session expired
- near-expiry tokens do not cause unnecessary logout behavior

### 5. Hardened token persistence
Tokens are stored in Keychain, but the app now also handles environments where secure storage read-back is unreliable by falling back to `UserDefaults`.

Result:
- the user can still remain authenticated locally after login
- onboarding flows do not fail just because secure storage did not return the token immediately

### 6. Aligned stock routes with backend routes
Stock endpoints were aligned to the backend's versioned routes:

- `/v1/stocks`
- `/v1/stocks/bulk`
- `/v1/stocks/{id}`

Result:
- onboarding import and portfolio requests target the same protected routes the backend actually serves

## Tests

Auth-related coverage now includes:

- `financeplanTests/AuthHTTPClientTests.swift`
  - login and refresh request/response handling
- `financeplanTests/LoginViewModelTests.swift`
  - auth persistence after successful login
- `financeplanTests/JWTTokenInspectorTests.swift`
  - JWT payload parsing
- `financeplanTests/AuthSessionManagerTests.swift`
  - valid token usage
  - refresh flow
  - expired-session handling
  - near-expiry fallback behavior
- `financeplanTests/AuthSessionStoreTests.swift`
  - expiry persistence
  - secure-store fallback behavior
- `financeplanTests/StockServiceTests.swift`
  - bearer-token usage
  - unauthorized refresh-and-retry flow
  - versioned stock endpoint usage

## Practical Takeaway

FinancePlan uses JWT access tokens as bearer tokens plus opaque rotating refresh tokens.

On the client:

- login stores both tokens and expiry metadata
- app launch restores the session through `AuthSessionManager`
- protected features ask for a valid access token instead of reading raw storage
- `401` triggers one refresh attempt and one retry
- session state is cleared only when both local checks and backend responses indicate the session is no longer usable
