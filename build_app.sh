#!/usr/bin/env bash
# Build Molly.app bundle from Swift Package
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Molly"
BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

echo "→ Building release binary…"
swift build -c release --package-path "$SCRIPT_DIR"

BINARY="$SCRIPT_DIR/.build/release/$APP_NAME"

echo "→ Creating bundle structure…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

echo "→ Copying binary…"
cp "$BINARY" "$BUNDLE/Contents/MacOS/$APP_NAME"

echo "→ Copying Info.plist…"
if [ -f "$SCRIPT_DIR/Sources/Molly/Resources/Info.plist" ]; then
    cp "$SCRIPT_DIR/Sources/Molly/Resources/Info.plist" "$BUNDLE/Contents/Info.plist"
elif [ -f "$SCRIPT_DIR/Info.plist" ]; then
    cp "$SCRIPT_DIR/Info.plist" "$BUNDLE/Contents/Info.plist"
else
    echo "Warning: Info.plist not found, app may not work correctly"
fi

echo "→ Creating PkgInfo…"
echo -n "APPL????" > "$BUNDLE/Contents/PkgInfo"

echo "✓ Done: $BUNDLE"
echo ""
echo "To run:  open $BUNDLE"
echo "To install: cp -r $BUNDLE /Applications/"
