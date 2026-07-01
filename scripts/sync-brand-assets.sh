#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_SRC="$ROOT/scripts/brand-source"
LEGACY_SRC="$ROOT/../../StockPlanAssets"
SRC="$LOCAL_SRC"
if [[ ! -d "$SRC" && -d "$LEGACY_SRC" ]]; then
  SRC="$LEGACY_SRC"
fi
ASSETS="$ROOT/financeplan/Assets.xcassets"
APPICON="$ASSETS/AppIcon.appiconset"
ICON_SET="$ASSETS/NorviqIcon.imageset"
FULL_LOGO_SET="$ASSETS/NorviqFullLogo.imageset"
DERIVE="$ROOT/scripts/derive-transparent-brand-asset.py"
OPTIMIZE_OPAQUE="$ROOT/scripts/optimize-opaque-png.py"

for file in icon.png icon_dark.png full_logo.png full_logo_dark.png; do
  if [[ ! -f "$SRC/$file" ]]; then
    echo "missing canonical asset: $SRC/$file" >&2
    exit 1
  fi
done

if [[ ! -f "$DERIVE" ]]; then
  echo "missing transparent asset helper: $DERIVE" >&2
  exit 1
fi

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

optional_source() {
  local preferred="$1"
  local fallback="$2"
  if [[ -f "$SRC/$preferred" ]]; then
    printf '%s/%s\n' "$SRC" "$preferred"
  else
    printf '%s/%s\n' "$SRC" "$fallback"
  fi
}

derive_asset() {
  local mode="$1"
  local theme="$2"
  local source="$3"
  local width="$4"
  local height="$5"
  local output="$6"
  python3 "$DERIVE" \
    --mode "$mode" \
    --theme "$theme" \
    --source "$source" \
    --width "$width" \
    --height "$height" \
    --output "$output"
}

resize_platform_png "$SRC/icon.png" 1024 1024 "$APPICON/nordiq-light-mode.png"
resize_platform_png "$SRC/icon_dark.png" 1024 1024 "$APPICON/nordiq-dark-mode.png"

derive_asset icon light "$(optional_source icon_transparent.png full_logo.png)" 512 512 "$ICON_SET/norviq-icon-light.png"
derive_asset icon dark "$(optional_source icon_dark_transparent.png full_logo_dark.png)" 512 512 "$ICON_SET/norviq-icon-dark.png"

derive_asset logo light "$(optional_source full_logo_transparent.png full_logo.png)" 1086 362 "$FULL_LOGO_SET/norviq-full-logo-light.png"
derive_asset logo dark "$(optional_source full_logo_dark_transparent.png full_logo_dark.png)" 1086 362 "$FULL_LOGO_SET/norviq-full-logo-dark.png"

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
