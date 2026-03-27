# MVP Features Roadmap

## Next Recommended Order

1. Work on Expenses API
2. Work on Reports API
3. Wrap the Portfolio view
4. Work on CSV Stock import
5. Work on API Stock import

## Why This Order

### 1. Expenses API

This should be the next priority because the Expenses planner UI is already built, but it is still backed by local in-memory state. Persisting salary, monthly plans, planned items, and recorded expenses is the biggest gap between the current app and a usable product.

### 2. Reports API

Reports should come right after Expenses because the Reports screen is derived from the same budget and expense data model. Once the canonical expense and salary endpoints are stable, report aggregation becomes much easier and more consistent.

### 3. Wrap the Portfolio view

Portfolio is already farther along on the app side than Expenses and Reports. It has its own feature folder and view model, so it is lower priority than making the budgeting and reporting flows real.

### 4. CSV Stock import

CSV import is useful for onboarding and bulk setup, but it is not as critical as turning the core budgeting and reporting flows into persistent backend-driven features.

### 5. API Stock import

API-based stock import should come after CSV import. CSV is usually the simpler and lower-risk import path, while API import tends to require more external integration work and validation.

## Short Version

If you want the shortest execution path:

1. Build the Expenses API
2. Build the Reports API

After that, continue with Portfolio polish and stock import flows.
