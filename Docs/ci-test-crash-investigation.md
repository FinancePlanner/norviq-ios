# CI test-bundle crash — investigation

**Status:** open
**Opened:** 2026-08-26
**Impact:** 487 unit tests exist; 3 test classes gate merges. The full bundle runs
`continue-on-error: true` in `.github/workflows/ci.yml`, so 484 tests protect nothing.

This document continues the notes at `.github/workflows/ci.yml:98-120`. Read those first.

## Symptom

```
Early unexpected exit, operation never finished bootstrapping.
(Underlying Error: The test runner crashed while preparing to run tests: financeplan at <some test>)
Test crashed with signal abrt.
```

The abort is in the **app under test**, and it kills the host, so a single crash reports
as a suite-wide failure.

## What is already established

| | |
|---|---|
| The crash point **moves** as classes are skipped | `AppEnvironmentManagerTests` → `BillingManagerTests` → the Keychain-backed `SecurityCodeManager` tests. Skipping classes is whack-a-mole |
| Does **not** reproduce locally | Full bundle passes on iPhone 16 and on iPhone 17 / iOS 26.4.1 |
| Ruled out — parallel simulator-clone capacity | `-parallel-testing-enabled NO` did not fix it |
| Ruled out — failable `UserDefaults(suiteName:)` force-unwrap | Hardened in #75; still crashes |
| Turning the full bundle on was already worth it | Surfaced five genuine failures sitting unnoticed on `main` (fixed in #73) |
| Runner image is unstable | The same image went from "iPhone 16, iOS 26.2" to no simulators at all within hours — which is what forced the dynamic UDID resolve step |

## Reading the evidence

**A moving crash point is the most informative fact here.** It rules out "one bad test"
and points at one of three things:

1. **Cross-test global state** — whichever test runs at position *N* aborts, because tests
   1…N-1 left the process in a state the app cannot start from.
2. **Cumulative resource exhaustion** — memory or file descriptors in a single host process
   running 487 tests, with the crash landing wherever the ceiling happens to fall.
3. **An environment-dependent abort** that any test can trip, and the ordering merely
   decides which one gets there first.

Note that all three named crash sites — `AppEnvironmentManagerTests`, `BillingManagerTests`,
`SecurityCodeManager` — touch **process-wide singletons or the Keychain**. That is not
a coincidence worth ignoring.

## Hypotheses, in priority order

### H1 — Keychain aborts on the CI simulator

`Features/Auth/SecureStringStore.swift` is Keychain-backed, and the Keychain behaves
differently on an unsigned CI simulator than on a local one. `SecItemAdd` /
`SecItemCopyMatching` can return `errSecMissingEntitlement (-34018)` or
`errSecNotAvailable (-25291)` where they succeed locally. If any path force-unwraps or
`fatalError`s on that, the host aborts.

**Test:** grep every Keychain call site for `try!`, `fatalError`, `precondition`, and
force-unwrapped `SecItem*` status handling. Then run *only* the Keychain-touching classes
on CI, in isolation, and see whether they abort alone.

**Cheap partial fix regardless of outcome:** every Keychain failure should be a thrown,
typed error. There is already a `SecureStoreError: LocalizedError, Equatable` — the
question is whether every path uses it.

### H2 — Shared SwiftData container constructed twice, or in an unwritable location

`Models/Local/SharedModelContainer.swift` builds a process-wide container.
`ModelContainer(for:)` throws, and a failure is commonly force-tried. In a CI sandbox the
Application Support directory may not exist, or a container built in an earlier test may
still hold the store file. Two containers over one on-disk store aborts.

**Test:** confirm whether the test target uses an in-memory
`ModelConfiguration(isStoredInMemoryOnly: true)`. If it does not, that is very likely the
bug and the fix is straightforward.

### H3 — Third-party SDK bootstrap at launch

Sentry, PostHog, Amplitude, Segment, and RevenueCat all initialise on app launch. On a
runner with restricted network egress or no Keychain, any of them can abort during
bootstrap — which matches "never finished bootstrapping" precisely.

**Test:** add a launch argument (`-uiTesting` / `-ciTesting`) that skips all analytics and
billing bootstrap, and set it for the test run. If the bundle goes green, the culprit is
in that list and can be isolated one SDK at a time.

### H4 — Cumulative memory pressure in the host process

487 tests, SwiftData, five analytics SDKs, and a 92k-LOC app in one process. If the
simulator OOMs, the crash lands wherever the ceiling falls — which is exactly the "moves
as classes are skipped" signature.

**Test:** run the bundle in halves (`-only-testing` by class, first half / second half).
If **each half passes alone but the whole fails**, it is H4 and not H1–H3.
This single experiment separates resource exhaustion from state contamination, so it is
worth running early.

### H5 — Runner simulator image instability (the current suspicion)

Plausible, and the image really is unstable. But it is the hypothesis that produces no
fix, so it should be the *last* one standing, not the first. H1–H4 are all cheaper to
falsify.

## Do this first — get the actual crash report

Right now the failure list is being read as evidence. **The failure list is a symptom; the
`abrt` is the thing.** Before testing any hypothesis:

1. Add `-resultBundlePath TestResults.xcresult` to the full-bundle step.
2. Upload it with `actions/upload-artifact`, along with the simulator's crash logs:
   `~/Library/Logs/DiagnosticReports/` and
   `xcrun simctl spawn booted log collect --output sim.logarchive`.
3. Read the crash with `xcrun xcresulttool get --path TestResults.xcresult --format json`,
   and open the `.ips` report for the aborting process.

A `SIGABRT` report names the aborting call. That one artifact probably collapses H1–H4
to a single line, and every experiment below becomes unnecessary.

## Experiment order

| # | Experiment | Separates |
|---|---|---|
| 0 | Upload `.xcresult` + `DiagnosticReports` and read the abort | Likely answers it outright |
| 1 | Run the bundle in halves | H4 (resource) vs H1–H3 (state) |
| 2 | Run Keychain-touching classes alone | H1 |
| 3 | Confirm the test target uses an in-memory `ModelConfiguration` | H2 |
| 4 | Add a `-ciTesting` launch argument that skips analytics/billing bootstrap | H3 |
| 5 | Re-run on a different runner image (`macos-15` vs `macos-26`) | H5 |

## Definition of done

- The abort has a named cause, not a suspicion
- The full bundle runs clean on CI
- The `Run Unit Tests (full bundle, informational)` step becomes gating, and the
  `-only-testing` subset above it is deleted
- The investigation is written up — this is a genuinely good debugging story and it is
  worth publishing

## Log

### 2026-08-26 — opened
Carried the `ci.yml:98-120` notes into hypotheses. Nothing run yet.
Next: experiment 0 — get the crash report out of the runner.
