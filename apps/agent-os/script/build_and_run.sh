#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="AgentOS"
APP_DISPLAY_NAME="Agent OS"
BUNDLE_ID="com.andrewgolovanov.AgentOS"
MIN_SYSTEM_VERSION="14.0"
VERSION="0.1.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/update_config.sh"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PRODUCT_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"

case "$APP_BUNDLE" in
  "$ROOT_DIR/dist/Agent OS.app") ;;
  *) echo "refusing unexpected bundle path: $APP_BUNDLE" >&2; exit 2 ;;
esac

if [[ -L "$DIST_DIR" || -L "$APP_BUNDLE" ]]; then
  echo "refusing a symlinked build destination" >&2
  exit 2
fi

pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true

swift build --package-path "$ROOT_DIR"
BUILD_DIR="$(swift build --package-path "$ROOT_DIR" --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$PRODUCT_NAME"
BUILD_FRAMEWORK="$BUILD_DIR/Sparkle.framework"
[[ -x "$BUILD_BINARY" ]] || { echo "missing app binary: $BUILD_BINARY" >&2; exit 1; }
[[ -d "$BUILD_FRAMEWORK" ]] || { echo "missing Sparkle framework: $BUILD_FRAMEWORK" >&2; exit 1; }
[[ -f "$APP_ICON" && ! -L "$APP_ICON" ]] || { echo "missing app icon: $APP_ICON" >&2; exit 1; }

/bin/rm -rf -- "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_FRAMEWORKS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
chmod +x "$APP_BINARY"
/usr/bin/ditto "$BUILD_FRAMEWORK" "$APP_FRAMEWORKS/Sparkle.framework"
/usr/bin/install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY"

/usr/bin/plutil -create xml1 "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleExecutable -string "$PRODUCT_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleName -string "$APP_DISPLAY_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleDisplayName -string "$APP_DISPLAY_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleIconFile -string AppIcon "$INFO_PLIST"
/usr/bin/plutil -insert CFBundlePackageType -string APPL "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleShortVersionString -string "$VERSION" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleVersion -string "$VERSION" "$INFO_PLIST"
/usr/bin/plutil -insert LSMinimumSystemVersion -string "$MIN_SYSTEM_VERSION" "$INFO_PLIST"
/usr/bin/plutil -insert NSPrincipalClass -string NSApplication "$INFO_PLIST"
/usr/bin/plutil -insert SUFeedURL -string "$SPARKLE_FEED_URL" "$INFO_PLIST"
/usr/bin/plutil -insert SUPublicEDKey -string "$SPARKLE_PUBLIC_KEY" "$INFO_PLIST"
/usr/bin/plutil -insert SUEnableAutomaticChecks -bool YES "$INFO_PLIST"
/usr/bin/plutil -insert SUAllowsAutomaticUpdates -bool YES "$INFO_PLIST"
/usr/bin/plutil -insert SUAutomaticallyUpdate -bool NO "$INFO_PLIST"
/usr/bin/plutil -insert SUVerifyUpdateBeforeExtraction -bool YES "$INFO_PLIST"
/usr/bin/plutil -insert SUScheduledCheckInterval -integer 86400 "$INFO_PLIST"

SPARKLE_VERSION="$APP_FRAMEWORKS/Sparkle.framework/Versions/B"
/usr/bin/codesign --force --sign - "$SPARKLE_VERSION/XPCServices/Installer.xpc"
/usr/bin/codesign --force --sign - --preserve-metadata=entitlements "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
/usr/bin/codesign --force --sign - "$SPARKLE_VERSION/Autoupdate"
/usr/bin/codesign --force --sign - "$SPARKLE_VERSION/Updater.app"
/usr/bin/codesign --force --sign - "$APP_FRAMEWORKS/Sparkle.framework"
/usr/bin/codesign --force --sign - "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PRODUCT_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$PRODUCT_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
