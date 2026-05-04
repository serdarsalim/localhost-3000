#!/bin/bash
set -e

APP_NAME="OpenPort"
BUNDLE_ID="com.serdarsalim.openport"
EXECUTABLE="LocalhostApp"
VERSION=$(date +%Y.%m.%d)
BUILD=$(date +%Y%m%d%H%M%S)

echo "▸ Building $APP_NAME..."
swift build -c release 2>&1

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    BINARY=".build/arm64-apple-macosx/release/$EXECUTABLE"
else
    BINARY=".build/x86_64-apple-macosx/release/$EXECUTABLE"
fi

APP_DIR="dist/$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/$EXECUTABLE"
chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE"

# Generate icon if AppIcon.png exists
if [ -f "AppIcon.png" ]; then
    echo "▸ Generating icon..."
    ICONSET="dist/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" > /dev/null 2>&1
        double=$((size * 2))
        sips -z $double $double AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null 2>&1
    done
    iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
    ICON_KEY='    <key>CFBundleIconFile</key>
    <string>AppIcon</string>'
else
    ICON_KEY=""
fi

echo "▸ Writing Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
$ICON_KEY
</dict>
</plist>
EOF

echo "▸ Signing..."
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "▸ Packaging..."
cd dist
ZIP_NAME="openport-macos.zip"
rm -f "$ZIP_NAME"
ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_NAME"
cd ..

echo ""
echo "  App:  dist/$APP_NAME.app"
echo "  Zip:  dist/$ZIP_NAME"
echo ""
