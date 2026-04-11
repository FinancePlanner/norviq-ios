# Persistence Standards

## SwiftData Rules

- Use local persistence abstractions for synced entities instead of direct `ModelContext` writes in view models.
- Keep reconciliation deterministic and server-authoritative:
  - upsert remote records,
  - delete local records missing from remote,
  - refresh `lastSyncedAt` on upsert.
- Keep SwiftData writes on the main-actor model context used by the app container.
- Cross-task handoff must use stable IDs (`String`) rather than model-object references.

## Portfolio + Watchlist

- `PortfolioViewModel` writes only through `PortfolioLocalPersisting`.
- `WatchlistViewModel` writes only through `WatchlistLocalPersisting`.
- Local stores own fetch predicates and save boundaries.

## Error Handling

- Persisting failures should surface to callers so UI can present actionable errors.
- Avoid silent data divergence when sync or save fails.
