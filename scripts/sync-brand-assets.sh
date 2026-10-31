#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/../../StockPlanAssets"
ASSETS="$ROOT/financeplan/Assets.xcassets"
APPICON="$ASSETS/AppIcon.appiconset"
ICON_SET="$ASSETS/NorviqIcon.imageset"
FULL_LOGO_SET="$ASSETS/NorviqFullLogo.imageset"
PRECISION="$SRC/precision/derived"
OPTIMIZE_OPAQUE="$ROOT/scripts/optimize-opaque-png.py"

# The AppIcon stays on the old N until the Precision vector master exists
# (docs/precision-identity.md, outstanding assets), so it still reads icon*.png.
for file in icon.png icon_dark.png; do
  if [[ ! -f "$SRC/$file" ]]; then
    echo "missing canonical asset: $SRC/$file" >&2
    exit 1
  fi
done

# The in-app symbol and lockup are the Precision raster crops, produced by
# norviq-web-v2/scripts/brand/derive-precision-assets.py. They are copied at
# native size: resizing would upscale a raster that has no vector master.
for file in logo-symbol-light.png logo-symbol-dark.png logo-lockup-horizontal-light.png logo-lockup-horizontal-dark.png; do
  if [[ ! -f "$PRECISION/$file" ]]; then
    echo "missing Precision asset: $PRECISION/$file (run derive-precision-assets.py)" >&2
    exit 1
  fi
done

if [[ ! -f "$OPTIMIZE_OPAQUE" ]]; then
  echo "missing opaque PNG optimizer: $OPTIMIZE_OPAQUE" >&2
  exit 1
fi

mkdir -p "$APPICON" "$ICON_SET" "$FULL_LOGO_SET"

resize_png() {
  local source="$1"
  local height="$2"
  local width="$3"
  local output="$4"
  sips -s format png -z "$height" "$width" "$source" --out "$output" >/dev/null
}

resize_platform_png() {
  local source="$1"
  local height="$2"
  local width="$3"
  local output="$4"
  resize_png "$source" "$height" "$width" "$output"
  python3 "$OPTIMIZE_OPAQUE" "$output"
}

resize_platform_png "$SRC/icon.png" 1024 1024 "$APPICON/nordiq-light-mode.png"
resize_platform_png "$SRC/icon_dark.png" 1024 1024 "$APPICON/nordiq-dark-mode.png"

cp "$PRECISION/logo-symbol-light.png" "$ICON_SET/norviq-icon-light.png"
cp "$PRECISION/logo-symbol-dark.png" "$ICON_SET/norviq-icon-dark.png"

cp "$PRECISION/logo-lockup-horizontal-light.png" "$FULL_LOGO_SET/norviq-full-logo-light.png"
cp "$PRECISION/logo-lockup-horizontal-dark.png" "$FULL_LOGO_SET/norviq-full-logo-dark.png"

cat >"$APPICON/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "nordiq-light-mode.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "nordiq-dark-mode.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "nordiq-light-mode.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

cat >"$ICON_SET/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "norviq-icon-light.png",
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "norviq-icon-dark.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

cat >"$FULL_LOGO_SET/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "norviq-full-logo-light.png",
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "norviq-full-logo-dark.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Synced iOS brand assets from $SRC"
