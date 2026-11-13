#!/usr/bin/env bash
# Fails if this repo's copies of the 3D Vig motion data (BRD-001) differ from the canonical files
# in norviq-web-v2/design/, or if either side is missing.
#
#   ./scripts/check-vig-motion-drift.sh
#
# Canonical source, in order:
#   1. $VIG_WEB_DIR (a norviq-web-v2 checkout), or ../../norviq-web-v2 when that exists (local runs);
#   2. otherwise norviq-web-v2 main through `gh api` (CI; needs GH_TOKEN = BRAND_GUARD_TOKEN).
# Fix: cp <norviq-web-v2>/design/<file> <the copy below>, after the web change has merged.
set -euo pipefail

cd "$(dirname "$0")/.."

WEB_REPO="FinancePlanner/norviq-web-v2"
pairs=(
  "design/vig-motion.json:financeplan/Design/vig-motion.json"
  "design/vig-motion.fixtures.json:financeplanTests/vig-motion.fixtures.json"
)

web_dir="${VIG_WEB_DIR:-}"
if [ -z "$web_dir" ] && [ -d ../../norviq-web-v2/design ]; then
  web_dir="../../norviq-web-v2"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

status=0
for pair in "${pairs[@]}"; do
  canonical="${pair%%:*}"
  copy="${pair##*:}"
  if [ ! -f "$copy" ]; then
    echo "::error::$copy is missing (copy of $WEB_REPO/$canonical)." >&2
    status=1
    continue
  fi
  if [ -n "$web_dir" ]; then
    source_file="$web_dir/$canonical"
    where="$web_dir/$canonical"
  else
    if [ -z "${GH_TOKEN:-}" ]; then
      echo "::error::No norviq-web-v2 checkout and no GH_TOKEN; cannot check $copy." >&2
      exit 1
    fi
    source_file="$tmp/$(basename "$canonical")"
    gh api "repos/$WEB_REPO/contents/$canonical?ref=main" -H "Accept: application/vnd.github.raw" > "$source_file"
    where="$WEB_REPO@main:$canonical"
  fi
  if [ ! -s "$source_file" ]; then
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
