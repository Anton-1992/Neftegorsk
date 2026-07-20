#!/bin/bash
# Build script for Android APK

set -e

PROJECT_DIR="/home/user/Neftegorsk/project"
BUILD_DIR="/home/user/Neftegorsk/builds"
GODOT="/usr/bin/godot"  # Adjust path to your Godot 4 binary

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Neftegorsk Android Build ===${NC}"

# Check Godot
if [ ! -f "$GODOT" ]; then
    echo -e "${RED}Godot not found at $GODOT${NC}"
    echo "Please install Godot 4.2+ and update GODOT path in this script"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Generate debug keystore if not exists
KEYSTORE="$HOME/.local/share/godot/app_userdata/Neftegorsk/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
    echo -e "${YELLOW}Generating debug keystore...${NC}"
    mkdir -p "$(dirname "$KEYSTORE")"
    keytool -genkey -v \
        -keystore "$KEYSTORE" \
        -alias androiddebugkey \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass android \
        -keypass android \
        -dname "CN=Android Debug,O=Android,C=US" \
        2>/dev/null || echo "Keystore generation failed (may already exist)"
fi

# Export
echo -e "${GREEN}Exporting APK...${NC}"
cd "$PROJECT_DIR"
"$GODOT" --headless --export-release "Android" "$BUILD_DIR/Neftegorsk.apk"

if [ -f "$BUILD_DIR/Neftegorsk.apk" ]; then
    SIZE=$(du -h "$BUILD_DIR/Neftegorsk.apk" | cut -f1)
    echo -e "${GREEN}Build successful!${NC}"
    echo -e "APK: ${YELLOW}$BUILD_DIR/Neftegorsk.apk${NC} (${SIZE})"
    
    # Optionally install to connected device
    if command -v adb &> /dev/null; then
        echo -e "${YELLOW}Install to device? (y/N)${NC}"
        read -r -t 10 INSTALL || INSTALL="n"
        if [[ "$INSTALL" =~ ^[Yy]$ ]]; then
            adb install -r "$BUILD_DIR/Neftegorsk.apk"
        fi
    fi
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi