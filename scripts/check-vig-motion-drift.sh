#!/usr/bin/env bash
# Kept for old call sites: the drift check now covers every shared design file.
# See scripts/check-design-drift.sh.
exec "$(dirname "$0")/check-design-drift.sh" "$@"
