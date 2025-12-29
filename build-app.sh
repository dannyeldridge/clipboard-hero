#!/bin/bash

# Build the release binary
cd ClipboardHero
swift build -c release

# Create app bundle structure
APP_NAME="ClipboardHero"
APP_DIR="../${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Clean up any existing app bundle
rm -rf "${APP_DIR}"

# Create directories
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy the binary
cp ".build/release/ClipboardHero" "${MACOS_DIR}/"

# Copy Info.plist
cp "Resources/Info.plist" "${CONTENTS_DIR}/"

# Create a simple launch script to ensure proper execution
cat > "${MACOS_DIR}/ClipboardHero.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
./ClipboardHero
EOF

chmod +x "${MACOS_DIR}/ClipboardHero.sh"

echo "App bundle created at: ${APP_DIR}"
echo "You can now run the app by double-clicking ClipboardHero.app"