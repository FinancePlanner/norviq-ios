#!/usr/bin/env bash
# Proves the 3D Vig (BRD-001) never ships in the App Store build: builds the app and checks the
# bundle for the model, its JSON and the 3D code's symbols.
#
#   scripts/verify-release-no-3d.sh            Release: none may be present
#   scripts/verify-release-no-3d.sh Beta       Beta: all must be present (the check can see them);
#                                              run scripts/fetch-vig-model.sh first
#
# Builds for the simulator without signing, into its own DerivedData ($VERIFY_DERIVED_DATA, or a
# temp dir).
set -euo pipefail
cd "$(dirname "$0")/.."

config="${1:-Release}"
case "$config" in Release | Beta) ;; *) echo "usage: $0 [Release|Beta]" >&2; exit 2 ;; esac

dd="${VERIFY_DERIVED_DATA:-$(mktemp -d)}"
xcodebuild -project financeplan.xcodeproj -scheme financeplan -configuration "$config" \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$dd" CODE_SIGNING_ALLOWED=NO build -quiet

app="$(find "$dd/Build/Products/$config-iphonesimulator" -maxdepth 1 -name '*.app' | head -1)"
[[ -n "$app" ]] || { echo "verify-no-3d: no .app under $dd" >&2; exit 1; }
binary="$app/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist")"

files="$(find "$app" \( -iname '*.usdz' -o -name 'vig-motion.json' -o -name 'vig-model.json' -o -name 'vig-poster.png' \) | sed "s|$app/||")"
# The debug dylib holds the code in Debug-like builds; check every Mach-O in the bundle root.
symbols="$(for f in "$binary" "$app"/*.debug.dylib; do [[ -f "$f" ]] && strings -a "$f"; done \
  | grep -E 'Vig3DView|VigStage|VigMotion' | sort -u | head -5 || true)"

echo "verify-no-3d: $config app $(basename "$app")"
echo "  model files: ${files:-none}"
echo "  3D symbols:  ${symbols:-none}"

if [[ "$config" == Release ]]; then
  if [[ -n "$files" || -n "$symbols" ]]; then
    echo "verify-no-3d: FAIL: the Release app carries the 3D Vig" >&2
    exit 1
  fi
else
  for want in Vig.usdz vig-motion.json vig-model.json vig-poster.png; do
    grep -qx "$want" <<<"$files" || { echo "verify-no-3d: FAIL: Beta app lacks $want" >&2; exit 1; }
  done
  [[ -n "$symbols" ]] || { echo "verify-no-3d: FAIL: Beta app lacks the 3D code" >&2; exit 1; }
fi
echo "verify-no-3d: OK"
