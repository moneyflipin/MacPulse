#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="MacPulse.app"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_TEMPLATE="$ROOT_DIR/Packaging/Info.plist"
EXECUTABLE="$BUILD_DIR/arm64-apple-macosx/release/MacPulse"
APP_ICON="$ROOT_DIR/Packaging/AppIcon.icns"

VERSION="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"
ZIP_NAME="MacPulse-${VERSION}.zip"

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR" "$DIST_DIR/$ZIP_NAME"

echo "Building release..."
env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
    SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache \
    swift build -c release

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "Release executable not found at: $EXECUTABLE" >&2
    exit 1
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/MacPulse"
cp "$PLIST_TEMPLATE" "$CONTENTS_DIR/Info.plist"

if [[ -f "$APP_ICON" ]]; then
    cp "$APP_ICON" "$RESOURCES_DIR/AppIcon.icns"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"

chmod +x "$MACOS_DIR/MacPulse"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

ditto -c -k --keepParent "$APP_DIR" "$DIST_DIR/$ZIP_NAME"

echo
echo "Done."
echo "App bundle: $APP_DIR"
echo "ZIP archive: $DIST_DIR/$ZIP_NAME"
echo
echo "If your friend downloads it from the internet, macOS may still warn because the app is not notarized."
echo "Best sharing options: AirDrop, local transfer, or send the ZIP and tell them to use Right Click -> Open the first time."
