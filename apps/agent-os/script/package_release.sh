#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="AgentOS"
APP_DISPLAY_NAME="Agent OS"
BUNDLE_ID="com.andrewgolovanov.AgentOS"
MIN_SYSTEM_VERSION="14.0"
VERSION="0.1.0"
PRIVATE_KEY_FILE=""

usage() {
  cat <<'USAGE'
usage: package_release.sh [--version VERSION] [--ed-key-file PATH]

Creates an ad-hoc signed app, zip, SHA-256 checksum, and Sparkle appcast. The
archive is signed with the Agent OS Ed25519 update key. The app has no Developer
ID and is not notarized, so macOS requires explicit user approval.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      VERSION="$2"
      shift 2
      ;;
    --ed-key-file)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      PRIVATE_KEY_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "version must contain one to three numeric components" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/update_config.sh"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$RELEASE_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PRODUCT_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
RUNTIME_SOURCE="$ROOT_DIR/../../plugins/agent-os/runtime"
RUNTIME_DESTINATION="$APP_RESOURCES/AgentOSRuntime"
ZIP_PATH="$RELEASE_DIR/$PRODUCT_NAME-$VERSION-macOS.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"
APPCAST_PATH="$RELEASE_DIR/appcast.xml"

case "$APP_BUNDLE" in
  "$ROOT_DIR/dist/release/Agent OS.app") ;;
  *) echo "refusing unexpected app path: $APP_BUNDLE" >&2; exit 2 ;;
esac
case "$ZIP_PATH" in
  "$ROOT_DIR/dist/release/AgentOS-"*"-macOS.zip") ;;
  *) echo "refusing unexpected archive path: $ZIP_PATH" >&2; exit 2 ;;
esac

if [[ -L "$ROOT_DIR/dist" || -L "$RELEASE_DIR" || -L "$APP_BUNDLE" || -L "$ZIP_PATH" || -L "$CHECKSUM_PATH" || -L "$APPCAST_PATH" ]]; then
  echo "refusing to replace a symlinked release artifact" >&2
  exit 2
fi

swift build -c release --package-path "$ROOT_DIR"
BUILD_DIR="$(swift build -c release --package-path "$ROOT_DIR" --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$PRODUCT_NAME"
BUILD_FRAMEWORK="$BUILD_DIR/Sparkle.framework"
[[ -x "$BUILD_BINARY" ]] || { echo "missing release binary: $BUILD_BINARY" >&2; exit 1; }
[[ -d "$BUILD_FRAMEWORK" ]] || { echo "missing Sparkle framework: $BUILD_FRAMEWORK" >&2; exit 1; }
[[ -f "$APP_ICON" && ! -L "$APP_ICON" ]] || { echo "missing app icon: $APP_ICON" >&2; exit 1; }
[[ -f "$RUNTIME_SOURCE/.agent-os-runtime.json" && -x "$RUNTIME_SOURCE/tools/task-board" ]] || {
  echo "missing synchronized Agent OS runtime: $RUNTIME_SOURCE" >&2
  exit 1
}

GENERATE_APPCAST="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
[[ -x "$GENERATE_APPCAST" ]] || { echo "missing Sparkle generate_appcast tool: $GENERATE_APPCAST" >&2; exit 1; }
if [[ -n "$PRIVATE_KEY_FILE" ]]; then
  [[ "$PRIVATE_KEY_FILE" = /* ]] || { echo "Ed25519 key file path must be absolute" >&2; exit 2; }
  [[ -f "$PRIVATE_KEY_FILE" && ! -L "$PRIVATE_KEY_FILE" ]] || { echo "invalid Ed25519 key file: $PRIVATE_KEY_FILE" >&2; exit 2; }
fi

mkdir -p "$RELEASE_DIR"
/bin/rm -rf -- "$APP_BUNDLE"
/bin/rm -f -- "$ZIP_PATH"
/bin/rm -f -- "$CHECKSUM_PATH"
mkdir -p "$APP_MACOS" "$APP_FRAMEWORKS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
chmod +x "$APP_BINARY"
/usr/bin/ditto "$BUILD_FRAMEWORK" "$APP_FRAMEWORKS/Sparkle.framework"
/usr/bin/ditto "$RUNTIME_SOURCE" "$RUNTIME_DESTINATION"
/usr/bin/install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY"

/usr/bin/plutil -create xml1 "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleExecutable -string "$PRODUCT_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleName -string "$APP_DISPLAY_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleDisplayName -string "$APP_DISPLAY_NAME" "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleIconFile -string AppIcon "$INFO_PLIST"
/usr/bin/plutil -insert CFBundlePackageType -string APPL "$INFO_PLIST"
/usr/bin/plutil -insert CFBundleURLTypes -json '[{"CFBundleURLName":"com.andrewgolovanov.AgentOS","CFBundleURLSchemes":["agent-os"]}]' "$INFO_PLIST"
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

/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
(
  cd "$RELEASE_DIR"
  /usr/bin/shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

APPCAST_ARGUMENTS=(
  --account "$SPARKLE_KEY_ACCOUNT"
  --download-url-prefix "$SPARKLE_DOWNLOAD_URL_ROOT/v$VERSION/"
  --link "https://github.com/andrewgolovanov/agent-os"
  --versions "$VERSION"
  --maximum-versions 3
  --maximum-deltas 0
  -o "$APPCAST_PATH"
)
if [[ -n "$PRIVATE_KEY_FILE" ]]; then
  APPCAST_ARGUMENTS+=(--ed-key-file "$PRIVATE_KEY_FILE")
fi
"$GENERATE_APPCAST" "${APPCAST_ARGUMENTS[@]}" "$RELEASE_DIR"

ARCHIVE_SIGNATURE="$(/usr/bin/ruby -rrexml/document -e '
  document = REXML::Document.new(File.read(ARGV.fetch(0)))
  enclosure = REXML::XPath.first(document, "//enclosure")
  abort "missing Sparkle enclosure" unless enclosure
  signature = enclosure.attributes["sparkle:edSignature"].to_s
  abort "missing Sparkle Ed25519 signature" if signature.empty?
  print signature
' "$APPCAST_PATH")"
[[ -n "$ARCHIVE_SIGNATURE" ]] || { echo "missing archive signature" >&2; exit 1; }
/usr/bin/swift "$ROOT_DIR/script/verify_update_signature.swift" "$ZIP_PATH" "$SPARKLE_PUBLIC_KEY" "$ARCHIVE_SIGNATURE"

echo "ad-hoc signed release: $ZIP_PATH"
echo "checksum: $CHECKSUM_PATH"
echo "Sparkle appcast: $APPCAST_PATH"
echo "macOS will require explicit user approval because the app has no Developer ID and is not notarized."
