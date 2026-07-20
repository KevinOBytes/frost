#!/bin/bash
set -euo pipefail

# generate-icon.sh — Generate Frost app icon as .icns
# Uses sips and iconutil (built-in macOS tools, no dependencies)
# Output: build/Frost.iconset and build/Frost.icns

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$PROJECT_DIR/build}"

echo "=== Frost Icon Generator ==="

# Create iconset directory
ICONSET_DIR="$OUTPUT_DIR/Frost.iconset"
mkdir -p "$ICONSET_DIR"

# Generate the base icon at 1024x1024 using Swift
cat > /tmp/frost-icon-gen.swift << 'SWIFT'
import AppKit

let size = 1024
let nsSize = NSSize(width: size, height: size)
let image = NSImage(size: nsSize)
image.lockFocus()

// Background — rounded rect with gradient blue
let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let radius = CGFloat(size) * 0.22
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)

let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.35, green: 0.6, blue: 0.95, alpha: 1.0),
    NSColor(srgbRed: 0.15, green: 0.35, blue: 0.8, alpha: 1.0)
])
gradient?.draw(in: bgPath, angle: -90)

// Draw snowflake in white
let center = NSPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
let armLength = CGFloat(size) * 0.3
let path = NSBezierPath()
path.lineWidth = CGFloat(size) * 0.04

for i in 0..<6 {
    let angle = CGFloat(i) * .pi / 3.0
    let endX = center.x + cos(angle) * armLength
    let endY = center.y + sin(angle) * armLength
    path.move(to: center)
    path.line(to: NSPoint(x: endX, y: endY))

    let branchDist = armLength * 0.55
    let branchStart = NSPoint(x: center.x + cos(angle) * branchDist, y: center.y + sin(angle) * branchDist)
    let branchLen = armLength * 0.3
    let ba1 = angle + .pi / 6
    let ba2 = angle - .pi / 6
    path.move(to: branchStart)
    path.line(to: NSPoint(x: branchStart.x + cos(ba1) * branchLen, y: branchStart.y + sin(ba1) * branchLen))
    path.move(to: branchStart)
    path.line(to: NSPoint(x: branchStart.x + cos(ba2) * branchLen, y: branchStart.y + sin(ba2) * branchLen))
}

NSColor.white.setStroke()
path.stroke()

image.unlockFocus()

// Save as PNG
let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: "/tmp/frost-icon-1024.png"))
print("Generated /tmp/frost-icon-1024.png")
SWIFT

echo "[1/3] Generating base icon..."
swift /tmp/frost-icon-gen.swift 2>&1

# Use sips to create all required sizes
echo "[2/3] Creating iconset variants..."
SIPS="sips -s format png"
BASE="/tmp/frost-icon-1024.png"

$SIPS -z 16 16     "$BASE" --out "$ICONSET_DIR/icon_16x16.png"     >/dev/null 2>&1
$SIPS -z 32 32     "$BASE" --out "$ICONSET_DIR/icon_16x16@2x.png"  >/dev/null 2>&1
$SIPS -z 32 32     "$BASE" --out "$ICONSET_DIR/icon_32x32.png"     >/dev/null 2>&1
$SIPS -z 64 64     "$BASE" --out "$ICONSET_DIR/icon_32x32@2x.png"  >/dev/null 2>&1
$SIPS -z 128 128   "$BASE" --out "$ICONSET_DIR/icon_128x128.png"   >/dev/null 2>&1
$SIPS -z 256 256   "$BASE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1
$SIPS -z 256 256   "$BASE" --out "$ICONSET_DIR/icon_256x256.png"   >/dev/null 2>&1
$SIPS -z 512 512   "$BASE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1
$SIPS -z 512 512   "$BASE" --out "$ICONSET_DIR/icon_512x512.png"   >/dev/null 2>&1
cp "$BASE"          "$ICONSET_DIR/icon_512x512@2x.png"

# Convert to .icns
echo "[3/3] Converting to .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_DIR/Frost.icns" 2>&1

# Cleanup
rm -f /tmp/frost-icon-gen.swift /tmp/frost-icon-1024.png

echo ""
echo "Icon generated: $OUTPUT_DIR/Frost.icns"
echo "Iconset: $ICONSET_DIR"