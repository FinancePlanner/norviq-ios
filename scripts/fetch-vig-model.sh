#!/usr/bin/env bash
# Puts the 3D Vig's model into the app bundle's source folder for Debug and Beta builds (BRD-001,
# norviq-web-v2/docs/vig-3d.md). The files are built output, so they stay out of git
# (.gitignore); this script fetches the pinned version and checks each file's SHA-256.
#
#   scripts/fetch-vig-model.sh            fetch from cdn.norviq.org
#   scripts/fetch-vig-model.sh --local    copy from ../../norviq-web-v2/scripts/brand/out/vig-3d
#                                         (or $VIG_WEB_DIR/scripts/brand/out/vig-3d), same pins
#
# vig-poster.png is the bust's still, shown until the first 3D frame.
# Release excludes these files (EXCLUDED_SOURCE_FILE_NAMES); scripts/verify-release-no-3d.sh
# proves it. Without them a Beta build still runs and shows the flat VigFull.
# A new model version: bump VERSION and every pin in the same PR.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=1
BASE="https://cdn.norviq.org/vig/v$VERSION"
DEST=financeplan/Design
PINS=(
  "Vig.usdz e6d1ac68101b9dd5b1bb8af4ada3b0d6d27b82ff2d7dacf183a6403fcb65af75"
  "vig-model.json d8d9e751831b97138cb15e470d31eb31844dfb1c3ded31aa1219db23b66b7e1f"
  "vig-poster.png a09289e5564f9f42e8cb3dcd68367870c114abecc5328d8762c8032b4f4c22f9"
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for pin in "${PINS[@]}"; do
  name="${pin%% *}"
  want="${pin##* }"
  if [[ "${1:-}" == "--local" ]]; then
    web="${VIG_WEB_DIR:-../../norviq-web-v2}"
    cp "$web/scripts/brand/out/vig-3d/$name" "$tmp/$name"
  else
    curl --fail --silent --show-error --location --proto '=https' --max-time 60 \
      -o "$tmp/$name" "$BASE/$name"
  fi
  got="$(shasum -a 256 "$tmp/$name" | cut -d' ' -f1)"
  if [[ "$got" != "$want" ]]; then
    echo "fetch-vig-model: $name sha256 $got, pinned $want" >&2
    exit 1
  fi
done

for pin in "${PINS[@]}"; do
  name="${pin%% *}"
  mv "$tmp/$name" "$DEST/$name"
done
echo "fetch-vig-model: v$VERSION in $DEST"
