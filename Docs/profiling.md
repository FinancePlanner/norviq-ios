# iOS Profiling Recipe

How to profile the Norviq app for the performance audit. Pair with
`StockPlanBackend/docs/audit/AUDIT-PLAYBOOK.md` §2 and record numbers in
`PERF-BASELINE.md`.

## 1. SwiftUI re-render diagnostics (cheapest first)

Add to a hot view's `body` in DEBUG to log what triggers re-renders:

```swift
var body: some View {
    let _ = Self._printChanges()   // DEBUG only — remove before release
    // ...
}
```

Run on device/sim, exercise the screen, watch the console. Each line names the
property that changed. Red flags:
- A view re-rendering when nothing it displays changed → unstable input (new closure
  or object reference passed inline each render).
- `@self changed` on scroll → identity churn in `ForEach` (missing/unstable `id`).

**Primary targets:** `Features/Home/DashboardRoot.swift` (12 `@State` vars,
computed `insightCards` recomputed every render), `Features/Home/UnifiedActivityFeed.swift`,
`Features/Crypto/Sections/CryptoMarketSection.swift`.

## 2. Instruments templates

Product → Profile (⌘I), Release config. Run these templates:

| Template | What to look for |
|----------|------------------|
| **SwiftUI** | "View Body" + "Core Animation Commits" tracks. Long/freq. body evaluations = re-render hotspots. Confirm `LazyVStack` for long lists. |
| **Time Profiler** | Heaviest stack traces. Anything on the main thread > a few ms during scroll/launch is a stall. |
| **Allocations** | Per-frame allocations during scroll (image decode, model mapping). Persistent growth = leak/retain. |
| **Network** | Request count + duration. Duplicate identical requests = missing dedup (only `CompanyProfileCache` exists today). Check `URLSession.shared` has sane timeouts. |

## 3. Signposts on the hot paths

Add `os_signpost` intervals so the audited paths show up as named regions in the
Instruments timeline:

```swift
import os.signpost

let perfLog = OSLog(subsystem: "io.norviq.app", category: "perf")

let id = OSSignpostID(log: perfLog)
os_signpost(.begin, log: perfLog, name: "DashboardLoad", signpostID: id)
defer { os_signpost(.end, log: perfLog, name: "DashboardLoad", signpostID: id) }
```

Instrument at least: Dashboard load (`DashboardRoot` `.task`), main-feed list
render, and JSON decode in `BaseHTTPClient.call()`.

## 4. Metrics to capture (→ PERF-BASELINE.md)

- Cold launch, warm launch (Time Profiler from process start to first frame)
- Dashboard time-to-interactive (DashboardLoad signpost duration)
- Scroll hitches on the main feed (Core Animation FPS / hitch rate)
- Largest main-thread stall during a typical session

## 5. Cross-check against confirmed-clean areas

Already verified during the audit — don't re-flag without new evidence:
- Auth tokens are in Keychain (`Features/Auth/AuthService.swift:225-243`), not UserDefaults.
- No hardcoded API keys; keys come from Info.plist build config.
