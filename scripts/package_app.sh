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
DMG_BACKGROUND="$ROOT_DIR/Packaging/DMGBackground.png"
TEMP_DMG="$DIST_DIR/.MacPulse-temp.dmg"
DMG_WINDOW_BOUNDS="{120, 120, 840, 560}"

VERSION="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"
ZIP_NAME="MacPulse-${VERSION}.zip"
DMG_NAME="MacPulse-${VERSION}.dmg"
DMG_STAGING_DIR="$DIST_DIR/.dmg-staging"
DMG_VOLUME_NAME="Install MacPulse"
DMG_BACKGROUND_DIR="$DMG_STAGING_DIR/.background"
DMG_MOUNT_DIR="$DIST_DIR/.dmg-mount"

mkdir -p "$DIST_DIR"
if [[ -d "$DMG_MOUNT_DIR" ]]; then
    hdiutil detach "$DMG_MOUNT_DIR" -force >/dev/null 2>&1 || true
fi
rm -rf "$APP_DIR" "$DIST_DIR/$ZIP_NAME" "$DIST_DIR/$DMG_NAME" "$DMG_STAGING_DIR" "$TEMP_DMG" "$DMG_MOUNT_DIR"

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

if [[ ! -f "$DMG_BACKGROUND" ]]; then
    echo "Generating DMG background..."
    swift "$ROOT_DIR/scripts/generate_dmg_background.swift"
fi

mkdir -p "$DMG_STAGING_DIR" "$DMG_BACKGROUND_DIR"
ditto "$APP_DIR" "$DMG_STAGING_DIR/$APP_NAME"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
cp "$DMG_BACKGROUND" "$DMG_BACKGROUND_DIR/DMGBackground.png"

hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDRW \
    "$TEMP_DMG" >/dev/null

mkdir -p "$DMG_MOUNT_DIR"
ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$DMG_MOUNT_DIR" "$TEMP_DMG")"
DEVICE="$(echo "$ATTACH_OUTPUT" | awk '/^\/dev\// {print $1; exit}')"
MOUNT_POINT="$DMG_MOUNT_DIR"

osascript <<EOF >/dev/null
tell application "Finder"
    set dmgAlias to (POSIX file "$MOUNT_POINT") as alias
    open dmgAlias
    delay 1
    set dmgDisk to disk of dmgAlias
    tell dmgDisk
        open
        delay 1
        tell container window
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set bounds to $DMG_WINDOW_BOUNDS
        end tell
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 112
        set text size of theViewOptions to 14
        set background picture of theViewOptions to (POSIX file "$MOUNT_POINT/.background/DMGBackground.png" as alias)
        set position of item "$APP_NAME" to {165, 210}
        set position of item "Applications" to {515, 210}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

sync
hdiutil detach "$DEVICE" >/dev/null
hdiutil convert "$TEMP_DMG" -ov -format UDZO -imagekey zlib-level=9 -o "$DIST_DIR/$DMG_NAME" >/dev/null
rm -f "$TEMP_DMG"

rm -rf "$DMG_STAGING_DIR" "$DMG_MOUNT_DIR"

echo
echo "Done."
echo "App bundle: $APP_DIR"
echo "ZIP archive: $DIST_DIR/$ZIP_NAME"
echo "DMG archive: $DIST_DIR/$DMG_NAME"
echo
echo "If your friend downloads it from the internet, macOS may still warn because the app is not notarized."
echo "Best sharing options: DMG for drag-and-drop install, AirDrop, or ZIP with Right Click -> Open the first time."
