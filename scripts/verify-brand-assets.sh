#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/../../StockPlanAssets"
ASSETS="$ROOT/financeplan/Assets.xcassets"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing file: $path" >&2
    exit 1
  fi
}

image_width() {
  sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/ {print $2}'
}

image_height() {
  sips -g pixelHeight "$1" 2>/dev/null | awk '/pixelHeight/ {print $2}'
}

image_has_alpha() {
  sips -g hasAlpha "$1" 2>/dev/null | awk '/hasAlpha/ {print $2}'
}

file_size_bytes() {
  wc -c < "$1" | tr -d ' '
}

require_dims() {
  local path="$1"
  local want_width="$2"
  local want_height="$3"
  require_file "$path"

  local got_width
  local got_height
  got_width="$(image_width "$path")"
  got_height="$(image_height "$path")"

  if [[ "$got_width" != "$want_width" || "$got_height" != "$want_height" ]]; then
    echo "$path is ${got_width}x${got_height}; want ${want_width}x${want_height}" >&2
    exit 1
  fi
}

require_alpha() {
  local path="$1"
  require_file "$path"

  local has_alpha
  has_alpha="$(image_has_alpha "$path")"
  if [[ "$has_alpha" != "yes" ]]; then
    echo "$path hasAlpha=$has_alpha; want yes" >&2
    exit 1
  fi
}

require_transparent_corners() {
  local path="$1"
  require_file "$path"

  python3 - "$path" <<'PY'
import sys
from PIL import Image

path = sys.argv[1]
image = Image.open(path).convert("RGBA")
width, height = image.size
points = [
    (0, 0),
    (width - 1, 0),
    (0, height - 1),
    (width - 1, height - 1),
]
bad = [(x, y, image.getpixel((x, y))[3]) for x, y in points if image.getpixel((x, y))[3] > 8]
if bad:
    print(f"{path} has opaque corner pixels: {bad}", file=sys.stderr)
    sys.exit(1)
PY
}

require_max_bytes() {
  local path="$1"
  local max_bytes="$2"
  require_file "$path"

  local got_bytes
  got_bytes="$(file_size_bytes "$path")"
  if (( got_bytes > max_bytes )); then
    echo "$path is ${got_bytes} bytes; want <= ${max_bytes}" >&2
    exit 1
  fi
}

require_grep() {
  local path="$1"
  local pattern="$2"
  require_file "$path"
  if ! grep -Fq "$pattern" "$path"; then
    echo "$path missing expected text: $pattern" >&2
    exit 1
  fi
}

require_dims "$SRC/icon.png" 1254 1254
require_dims "$SRC/icon_dark.png" 1254 1254
require_dims "$SRC/full_logo.png" 2172 724
require_dims "$SRC/full_logo_dark.png" 2172 724

require_dims "$ASSETS/AppIcon.appiconset/nordiq-light-mode.png" 1024 1024
require_dims "$ASSETS/AppIcon.appiconset/nordiq-dark-mode.png" 1024 1024
require_grep "$ASSETS/AppIcon.appiconset/Contents.json" '"size" : "1024x1024"'
require_grep "$ASSETS/AppIcon.appiconset/Contents.json" '"value" : "dark"'
require_grep "$ASSETS/AppIcon.appiconset/Contents.json" '"value" : "tinted"'
require_max_bytes "$ASSETS/AppIcon.appiconset/nordiq-light-mode.png" 100000
require_max_bytes "$ASSETS/AppIcon.appiconset/nordiq-dark-mode.png" 100000

require_dims "$ASSETS/NorviqIcon.imageset/norviq-icon-light.png" 512 512
require_dims "$ASSETS/NorviqIcon.imageset/norviq-icon-dark.png" 512 512
require_grep "$ASSETS/NorviqIcon.imageset/Contents.json" '"value" : "dark"'
require_alpha "$ASSETS/NorviqIcon.imageset/norviq-icon-light.png"
require_alpha "$ASSETS/NorviqIcon.imageset/norviq-icon-dark.png"
require_transparent_corners "$ASSETS/NorviqIcon.imageset/norviq-icon-light.png"
require_transparent_corners "$ASSETS/NorviqIcon.imageset/norviq-icon-dark.png"
require_max_bytes "$ASSETS/NorviqIcon.imageset/norviq-icon-light.png" 180000
require_max_bytes "$ASSETS/NorviqIcon.imageset/norviq-icon-dark.png" 180000

require_dims "$ASSETS/NorviqFullLogo.imageset/norviq-full-logo-light.png" 1086 362
require_dims "$ASSETS/NorviqFullLogo.imageset/norviq-full-logo-dark.png" 1086 362
require_grep "$ASSETS/NorviqFullLogo.imageset/Contents.json" '"value" : "dark"'
require_alpha "$ASSETS/NorviqFullLogo.imageset/norviq-full-logo-light.png"
require_alpha "$ASSETS/NorviqFullLogo.imageset/norviq-full-logo-dark.png"
require_transparent_corners "$ASSETS/NorviqFullLogo.imageset/norviq-full-logo-light.png"
require_transparent_corners "$ASSETS/NorviqFullLogo.imageset/norviq-full-logo-dark.png"
require_max_bytes "$ASSETS/NorviqFullLogo.imageset/norviq-full-logo-light.png" 220000
require_max_bytes "$ASSETS/NorviqFullLogo.imageset/norviq-full-logo-dark.png" 220000

echo "iOS brand assets verified."
