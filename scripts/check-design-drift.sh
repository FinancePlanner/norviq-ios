#!/usr/bin/env bash
# Fails if this repo's copies of the shared design files differ from the canonical files in
# norviq-web-v2/design/:
#   - the 3D Vig motion data (BRD-001) and its fixtures;
#   - tokens.json, the source of the Theme colour sets (DS 2.0).
#
#   ./scripts/check-design-drift.sh        (./scripts/check-vig-motion-drift.sh still works)
#
# Canonical source, in order:
#   1. $DESIGN_WEB_DIR or $VIG_WEB_DIR (a norviq-web-v2 checkout), or ../../norviq-web-v2 when that
#      exists (local runs);
#   2. otherwise norviq-web-v2 main through `gh api` (CI; needs GH_TOKEN = BRAND_GUARD_TOKEN).
# A missing iOS copy or a missing canonical file fails.
# Fix: cp <norviq-web-v2>/design/<file> <the copy below>, after the web change has merged.
set -euo pipefail

cd "$(dirname "$0")/.."

WEB_REPO="FinancePlanner/norviq-web-v2"
# canonical:copy
pairs=(
  "design/vig-motion.json:financeplan/Design/vig-motion.json"
  "design/vig-motion.fixtures.json:financeplanTests/vig-motion.fixtures.json"
  "design/tokens.json:financeplan/Design/tokens.json"
)

web_dir="${DESIGN_WEB_DIR:-${VIG_WEB_DIR:-}}"
if [ -z "$web_dir" ] && [ -d ../../norviq-web-v2/design ]; then
  web_dir="../../norviq-web-v2"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

status=0
for pair in "${pairs[@]}"; do
  IFS=: read -r canonical copy <<<"$pair"
  if [ ! -f "$copy" ]; then
    echo "::error::$copy is missing (copy of $WEB_REPO/$canonical)." >&2
    status=1
    continue
  fi
  missing=""
  if [ -n "$web_dir" ]; then
    source_file="$web_dir/$canonical"
    where="$web_dir/$canonical"
    [ -s "$source_file" ] || missing=1
  else
    if [ -z "${GH_TOKEN:-}" ]; then
      echo "::error::No norviq-web-v2 checkout and no GH_TOKEN; cannot check $copy." >&2
      exit 1
    fi
    source_file="$tmp/$(basename "$canonical")"
    where="$WEB_REPO@main:$canonical"
    if ! gh api "repos/$WEB_REPO/contents/$canonical?ref=main" -H "Accept: application/vnd.github.raw" \
      >"$source_file" 2>"$tmp/gh.err"; then
      if grep -q "HTTP 404" "$tmp/gh.err"; then
        missing=1
      else
        echo "::error::Could not fetch $where: $(cat "$tmp/gh.err")" >&2
        status=1
        continue
      fi
    fi
    [ -s "$source_file" ] || missing=1
  fi
  if [ -n "$missing" ]; then
    echo "::error::$where is missing or empty." >&2
    status=1
  elif ! cmp -s "$source_file" "$copy"; then
    echo "::error::$copy differs from $where. Copy the canonical file after the web change merges." >&2
    status=1
  else
    echo "ok: $copy == $where"
  fi
done
exit $status
