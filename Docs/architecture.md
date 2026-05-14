# iOS Architecture Documentation

## Overview
The StockPlan iOS application follows a **Modern Layered MVVM** architecture. It leverages SwiftUI for the UI layer, Combine for reactive updates, and Swift's modern `async/await` concurrency for networking and business logic.

## 1. Architectural Layers

### View Layer (SwiftUI)
- **Role:** Declarative UI definition and user interaction handling.
- **Implementation:** Uses standard SwiftUI views. Views are kept "dumb" and react to state changes in their respective ViewModels.
- **State Observation:** Uses `@StateObject` or `@ObservedObject` to bind to ViewModels.

### ViewModel Layer
- **Role:** Owns UI state, handles business logic, and transforms domain models into display-ready data.
- **Implementation:** Defined as `@MainActor final class ...: ObservableObject`.
- **Properties:** Uses `@Published` for reactive UI updates.
- **Dependencies:** Injected via the `Factory` library, ensuring easy testability and decoupling from concrete implementations.

### Service Layer
- **Role:** Acts as an intermediary between ViewModels and the Networking layer. Handles orchestration, authentication logic, and error mapping.
- **Implementation:** Protocols (e.g., `StockServicing`, `MarketDataServicing`) with concrete HTTP implementations.
- **Auth Management:** Collaborates with `AuthSessionManager` to ensure requests are authenticated.

### Networking Layer (HTTP Clients)
- **Role:** Low-level `URLRequest` construction and execution.
- **Domain-Specific Clients:** Instead of a single generic client, the app uses specialized structs like `MarketDataHTTPClient` and `StockHTTPClient`.
- **Endpoint Pattern:** Uses a protocol-based approach (via `AnyAPI`) where each API call is defined as an `Endpoint` struct containing the path, method, and decoding logic.

### Earnings Transcripts
- **Endpoint:** `GetStockEarningsTranscriptEndpoint` calls `GET /v1/market/earnings/{symbol}/transcript?date=YYYY-MM-DD`.
- **Service Flow:** `MarketDataServicing.fetchStockEarningsTranscript(symbol:date:)` keeps transcript loading behind the existing authenticated market data service boundary.
- **UI Flow:** `StockDetailsScreenViewModel` owns transcript loading state. `StockEarningsTab` only enables transcript selection for events marked with transcript availability and presents the result in a sheet.

## 2. Authentication & Retry Strategy

The application implements a robust **Automatic Recovery Flow** for expired sessions within the Service Layer:

1.  **Initial Attempt:** A service calls the HTTP client with the current access token.
2.  **Unauthorized Catch:** If the client returns a `401 Unauthorized` error, the Service layer intercepts it.
3.  **Token Refresh:** The service requests a new token from `AuthSessionManager.refreshAccessToken()`.
    -   *Deduplication:* `AuthSessionManager` uses an `NSLock` and a shared `Task` to ensure multiple concurrent `401` errors only trigger a single refresh request.
4.  **Single Retry:** The service recreates the client with the new token and retries the operation exactly once.
5.  **Invalidation:** If the retry also fails with a `401`, the session is invalidated, and the user is typically navigated to the login screen.

## 3. Caching Strategy

### In-Memory Caching
Currently, the application primarily relies on in-memory storage within Services and ViewModels for active session data (e.g., portfolio holdings, market snapshots).

### Persistent Storage
-   **Session Data:** `UserDefaultsAuthSessionStore` persists tokens, user IDs, and environment settings. It includes logic to fall back to Keychain/Secure storage where applicable.
-   **Future Growth:** The project includes `EntityStore` as a dependency, intended for a future local database/caching layer to support offline access and performance optimizations for large datasets (e.g., historical reports).

## 4. Dependency Injection
The app uses the **Factory** library for dependency management. 
-   **Containers:** Dependencies are registered in `Container` extensions (e.g., `Container+AppFactories.swift`).
-   **Scopes:** Supports `.singleton` for shared managers and default instances for standard services, allowing for easy mocking in unit tests.
