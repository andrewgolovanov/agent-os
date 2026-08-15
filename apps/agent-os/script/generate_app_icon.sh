#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SVG="$ROOT_DIR/Resources/AppIcon.svg"
OUTPUT_ICNS="$ROOT_DIR/Resources/AppIcon.icns"
TEMP_BASE="${TMPDIR:?TMPDIR is required}"
TEMP_DIR="$(mktemp -d "${TEMP_BASE%/}/agent-os-icon.XXXXXX")"

case "$TEMP_DIR" in
  "${TEMP_BASE%/}/agent-os-icon."*) ;;
  *) echo "refusing unexpected temporary icon path: $TEMP_DIR" >&2; exit 2 ;;
esac

cleanup() {
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" && ! -L "$TEMP_DIR" ]] || return
  /bin/rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

[[ -f "$SOURCE_SVG" && ! -L "$SOURCE_SVG" ]] || {
  echo "missing app icon source: $SOURCE_SVG" >&2
  exit 1
}

ICONSET_DIR="$TEMP_DIR/AppIcon.iconset"
SOURCE_PNG="$TEMP_DIR/AppIcon-source.png"
MASTER_PNG="$TEMP_DIR/AppIcon-1024.png"
mkdir -p "$ICONSET_DIR"

/usr/bin/sips -s format png "$SOURCE_SVG" --out "$SOURCE_PNG" >/dev/null
/usr/bin/sips -Z 1024 "$SOURCE_PNG" --out "$MASTER_PNG" >/dev/null
/usr/bin/sips --padColor 111111 --padToHeightWidth 1024 1024 "$MASTER_PNG" --out "$MASTER_PNG" >/dev/null

write_icon() {
  local size="$1"
  local filename="$2"
  /usr/bin/sips -z "$size" "$size" "$MASTER_PNG" --out "$ICONSET_DIR/$filename" >/dev/null
}

write_icon 16 icon_16x16.png
write_icon 32 icon_16x16@2x.png
write_icon 32 icon_32x32.png
write_icon 64 icon_32x32@2x.png
write_icon 128 icon_128x128.png
write_icon 256 icon_128x128@2x.png
write_icon 256 icon_256x256.png
write_icon 512 icon_256x256@2x.png
write_icon 512 icon_512x512.png
write_icon 1024 icon_512x512@2x.png

/usr/bin/iconutil --convert icns --output "$OUTPUT_ICNS" "$ICONSET_DIR"
echo "generated app icon: $OUTPUT_ICNS"
