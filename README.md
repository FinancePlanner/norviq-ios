# FinancePlan iOS App

## Shared Models Dependency

This app consumes shared API DTOs from:
- `https://github.com/FinancePlanner/FinanceShared.git`
- Product: `StockPlanShared`
- Version requirement: `0.1.0` and above (`upToNextMajorVersion`)

The dependency is configured in:
- `financeplan.xcodeproj/project.pbxproj`

## Auth Model Usage Example

A minimal auth example using shared DTOs is in:
- `financeplan/Auth/AuthAPIExample.swift`

It demonstrates:
- `import StockPlanShared`
- encoding `AuthLoginRequest` to JSON request body
- decoding `AuthResponse` from response data

## If Xcode Cannot Resolve the Package

Make sure `FinanceShared` has a published semver tag:

```bash
git tag 0.1.0
git push origin 0.1.0
```

Then in Xcode:
1. `File > Packages > Reset Package Caches`
2. `File > Packages > Resolve Package Versions`
