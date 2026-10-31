#!/usr/bin/env bash
# Fails when Swift code paints with raw SwiftUI .green / .red.
#
# Green and red mean financial direction and nothing else
# (docs/precision-identity.md), and they must come from the theme so they adapt
# to light and dark: AppTheme.Colors.gain / .loss for direction,
# .success / .danger for status. A raw `.green` in a view is how the old P&L
# colours spread to ~180 call sites, so this guard keeps the count at zero.
#
# Enum cases that happen to be named green/red (BudgetDriftLevelWire) are
# matched as `case .green` / `== .red` and skipped.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

hits="$(
  grep -rnE '(^|[^A-Za-z0-9_])(Color)?\.(green|red)\b' "$ROOT/financeplan" --include='*.swift' \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' \
    | grep -vE 'case \.(green|red)|[=!]= \.(green|red)' \
    || true
)"

if [[ -n "$hits" ]]; then
  echo "Raw .green/.red colours found. Use AppTheme.Colors.gain/.loss (direction) or .success/.danger (status):" >&2
  echo "$hits" | sed "s|$ROOT/||" >&2
  exit 1
fi
echo "check-raw-pnl-colors: OK"
