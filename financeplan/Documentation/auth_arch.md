# Auth Architecture

## Goal
Document how authentication is implemented in this app today, including request flow, layering, error behavior, and how it compares to a generic `APIClient` design.

## High-Level Summary
The current auth stack is already close to the pattern you shared:

- `Endpoint`-driven requests (method + path + parameters)
- a dedicated HTTP client
- typed `Decodable` responses
- domain-level service interface used by the view model

Main difference: auth uses an auth-specific client (`AuthHTTPClient`) instead of one shared generic `APIClient` class for all features.

## Files and Responsibilities

### API layer
- `financeplan/API/Auth/AuthEndpoints.swift`
  - Defines endpoint contracts for auth:
    - `LoginEndpoint` (`POST /auth/login`)
    - `SignupEndpoint` (`POST /auth/register`)
    - `ForgotPasswordEndpoint` (`POST /auth/forgot-password`)
  - Each endpoint implements `asParameters()` using AnyAPI `Endpoint`.

- `financeplan/API/Auth/AuthHTTPClient.swift`
  - Transport client for auth operations.
  - Public methods:
    - `login(_:)`
    - `register(_:)`
    - `forgotPassword(_:)`
    - `logout(_:)`
  - Shared request execution path:
    - builds `URLRequest` from endpoint
    - executes with `URLSession` abstraction
    - validates status code
    - decodes success response via `endpoint.decode(data)`
  - Error mapping:
    - `.invalidResponse`
    - `.invalidStatus(Int)`
    - `.api(String)` when response body contains server-provided error text (supports multiple payload shapes, including StockPlanShared envelopes)

### Domain/service layer
- `financeplan/Features/Auth/AuthService.swift`
  - Defines `AuthServicing` protocol used by UI/view model.
  - Converts call-site primitives into shared DTOs from `StockPlanShared`.
  - Creates `AuthHTTPClient` with active environment base URL.
  - Calls server logout endpoint with refresh token before local session cleanup.

- `financeplan/Features/Auth/AuthService.swift` (`UserDefaultsAuthSessionStore`)
  - Stores:
    - `authToken`
    - `refreshToken`
    - persisted UI mode flag `loginIsSignup`
    - `currentUserID`
    - per-user mandatory import completion set (`initial_stock_import_user_ids`)

### Presentation layer
- `financeplan/Features/Auth/LoginViewModel.swift`
  - Handles validation and submission state.
  - Calls `AuthServicing` for network actions.
  - Persists token/refresh token on success.
  - Maps `AuthHTTPClient.Error` into user-facing messages.

- `financeplan/Features/Auth/LoginScreen.swift`
  - UI bindings and async actions for login/signup/forgot-password.

- `financeplan/Features/Onboarding/InitialStockImportScreen.swift`
  - Mandatory post-login screen shown until a stock import method is selected once.

### Dependency wiring
- `financeplan/Container+AppFactories.swift`
  - Registers singletons for:
    - `AuthServicing` -> `AuthService`
    - `AuthSessionStoring` -> `UserDefaultsAuthSessionStore`

## Request Lifecycle

### Login flow
1. `LoginScreen` triggers `await viewModel.submit()`.
2. `LoginViewModel` validates fields and calls `authService.login(email:password:)`.
3. `AuthService` creates `AuthLoginRequest` and calls `AuthHTTPClient.login(_:)`.
4. `AuthHTTPClient` creates `LoginEndpoint` and executes `call(endpoint)`.
5. On `2xx`, response is decoded into `AuthResponse`.
6. `LoginViewModel` persists token + refresh token + `currentUserID`, then invokes `onAuthenticated()`.
7. `ContentView` checks onboarding by user id:
   - if `currentUserID` has not completed import -> routes to `InitialStockImportScreen` (cannot be skipped)
   - if completed -> routes to `HomeScreen`

Signup and forgot-password follow the same pipeline with their endpoint/DTO types.

### Signup flow
1. `LoginViewModel` calls `authService.signup(...)`.
2. `AuthHTTPClient` only requires `2xx` for signup success (response body is ignored).
3. On success, UI switches back to login mode and prompts user to sign in manually.

### Logout flow
1. Home logout triggers `authService.logout(refreshToken:)`.
2. Client calls `/v2/logout` and falls back to `/auth/logout` on `404`.
3. Local auth and refresh tokens are then cleared.

## Environment and Base URL
- Environments are defined in `financeplan/AppEnvironment.swift`.
- Active environment is resolved by `AppEnvironmentManager` (`financeplan/Constants.swift`).
- `AuthService` uses `environmentManager.current.apiBaseUrl` to build `AuthHTTPClient`.

## Test Coverage
- `financeplanTests/AuthHTTPClientTests.swift`
  - Verifies request method/path/body and response/error decoding for:
    - login success
    - register API error parsing
    - forgot-password non-JSON error status handling
    - forgot-password success decoding

- `financeplanTests/LoginViewModelTests.swift`
  - Verifies validation, service call routing, and token persistence behavior.

## Comparison to Generic `APIClient` Pattern

### What already matches
- endpoint-oriented design
- typed async request methods
- centralized status-code and decoding handling
- testable transport abstraction (`AuthURLSessionProtocol`)

### Differences
- Current design is auth-specific (`AuthHTTPClient`) rather than a reusable shared generic client.
- Request body is produced from `[String: Any]` (`Parameters` + `JSONSerialization`) instead of `Encodable` body generics.
- `URLSessionConfiguration` customization (`waitsForConnectivity`, cache policy) is not currently applied in auth client init.
- Error extraction currently supports a single shape (`{ "error": String }`) before falling back to status-only errors.

## Practical Takeaway
Auth is already implemented in the same architectural direction as your sample.  
If needed, the next incremental step would be consolidating this into one reusable app-wide client while keeping these endpoint structs and service boundaries.
