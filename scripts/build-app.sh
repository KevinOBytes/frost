#!/bin/bash
set -euo pipefail

# build-app.sh — Build Frost as a .app bundle with icon
# Usage: ./scripts/build-app.sh [output_dir]
# Output: build/Frost.app (or specified dir)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_DIR/build}"
APP_NAME="Frost"
BUNDLE_ID="com.tkoresearch.frost"
BUNDLE_VERSION="1.1.0"
BUILD_DIR="$PROJECT_DIR/.build/release"
BINARY="$BUILD_DIR/Frost"

echo "=== Frost .app Bundle Builder v$BUNDLE_VERSION ==="
echo ""

# Step 1: Build release binary
echo "[1/6] Building release binary..."
cd "$PROJECT_DIR"
swift build -c release 2>&1
echo ""

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Build failed — binary not found at $BINARY"
    exit 1
fi

echo "[2/6] Binary built: $BINARY"
echo ""

# Step 2: Create .app bundle structure
echo "[3/6] Creating .app bundle..."
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "  Bundle: $APP_BUNDLE"
echo ""

# Step 3: Generate and copy icon
echo "[4/6] Generating app icon..."
bash "$SCRIPT_DIR/generate-icon.sh" "$OUTPUT_DIR" 2>&1 || echo "  WARNING: Icon generation failed, continuing without icon"
if [ -f "$OUTPUT_DIR/Frost.icns" ]; then
    cp "$OUTPUT_DIR/Frost.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "  Icon copied to bundle"
else
    echo "  No icon generated (non-fatal)"
fi
echo ""

# Step 4: Create Info.plist
echo "[5/6] Writing Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Frost</string>
    <key>CFBundleDisplayName</key>
    <string>Frost</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$BUNDLE_VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$BUNDLE_VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Frost needs Accessibility access to detect and manage menu bar items.</string>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "[6/6] Bundle created successfully!"
echo ""
echo "=== Result ==="
echo "  Path: $APP_BUNDLE"
echo "  Binary: $APP_BUNDLE/Contents/MacOS/$APP_NAME"
if [ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
    echo "  Icon: $APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
echo "  Version: $BUNDLE_VERSION"
echo ""
echo "To install: cp -R \"$APP_BUNDLE\" /Applications/"
echo "To run: open \"$APP_BUNDLE\""
echo ""
echo "NOTE: Grant Accessibility permission in System Settings > Privacy & Security"
echo ""