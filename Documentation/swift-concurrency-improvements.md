# Swift Concurrency Improvements

This document records the improvements made to the project to resolve Swift 6 actor-isolation and concurrency-related errors.

## Refactored Components

### `UserDefaultsAuthSessionStore`
- **Before**: Implemented as an `actor`.
- **After**: Refactored to `final class UserDefaultsAuthSessionStore: AuthSessionStoring, @unchecked Sendable`.
- **Reason**: To simplify synchronous access to `UserDefaults` and keychain while maintaining thread safety through manual auditing.
- **Key Change**: Token migration call in `init` remains synchronous.

### `AuthSessionManager`
- **Before**: Implemented as an `actor`.
- **After**: Refactored to `final class AuthSessionManager: AuthSessionManaging, @unchecked Sendable`.
- **Reason**: To resolve complex isolation issues when interacting with various services and stores.
- **Key Change**: Notification names in `Notification.Name` extension are kept as `nonisolated static let`.

## Code Fixes

### `AuthSessionManager.swift`
- **`accessTokenExpiry(for:)`**: Refactored to avoid using `await` inside a `??` (nil-coalescing) autoclosure, ensuring clearer execution order and avoiding potential compiler confusion.

### `AuthService.swift`
- **`Keys` enum**: Removed unnecessary `nonisolated(unsafe)` from static string constants in the `Keys` enum, as immutable strings are naturally `Sendable`.

### Service Token Providers
The following services were updated to correctly use `await` when providing the auth token to their respective HTTP clients:
- `BadgesService.swift`
- `NewsService.swift`
- `ExpensesService.swift`
- `GoalsService.swift`
- `DashboardService.swift`

**Update**:
```swift
authTokenProvider: { await Container.shared.authSessionStore().authToken }
```
This ensures that the `authToken` is retrieved asynchronously from the `AuthSessionStoring` protocol, resolving "main actor-isolated property authToken" errors.
