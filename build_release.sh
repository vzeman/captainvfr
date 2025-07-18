#!/bin/bash

# Captain VFR Release Build Script

echo "🚀 Captain VFR Release Build"
echo "============================"

# Create downloads directory if it doesn't exist
DOWNLOADS_DIR="hugo/static/downloads"
mkdir -p "$DOWNLOADS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 successful${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

# Clean and get dependencies
echo -e "${YELLOW}Cleaning project...${NC}"
flutter clean
check_status "Clean"

echo -e "${YELLOW}Getting dependencies...${NC}"
flutter pub get
check_status "Pub get"

# Build for Android
echo -e "${YELLOW}Building Android release...${NC}"

# Build App Bundle for Play Store
echo -e "${YELLOW}Building Android App Bundle...${NC}"
# Build and check if AAB was created despite any warnings
flutter build appbundle --release || true
if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo -e "${GREEN}✓ AAB file created: build/app/outputs/bundle/release/app-release.aab${NC}"
    echo -e "${YELLOW}Note: Warning about debug symbols can be safely ignored${NC}"
else
    echo -e "${RED}✗ Android App Bundle build failed${NC}"
    echo -e "${YELLOW}Continuing with APK build only...${NC}"
fi

# Build APK for direct download
echo -e "${YELLOW}Building Android APK...${NC}"
flutter build apk --release
check_status "Android APK build"
echo -e "${GREEN}✓ APK file: build/app/outputs/flutter-apk/app-release.apk${NC}"

# Copy APK to downloads folder
cp build/app/outputs/flutter-apk/app-release.apk "$DOWNLOADS_DIR/CaptainVFR.apk"
echo -e "${GREEN}✓ APK copied to downloads folder${NC}"

# Build for iOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Building iOS release...${NC}"
    flutter build ios --release
    check_status "iOS build"
    echo -e "${GREEN}✓ iOS build complete. Now open Xcode to archive and upload.${NC}"
    echo "Next steps for iOS:"
    echo "1. Open ios/Runner.xcworkspace in Xcode"
    echo "2. Select 'Any iOS Device' as build target"
    echo "3. Product > Archive"
    echo "4. Distribute App > App Store Connect"
else
    echo -e "${YELLOW}Skipping iOS build (not on macOS)${NC}"
fi

# Build for macOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Building macOS release...${NC}"
    
    # Flutter doesn't support building universal binaries directly
    # Build for current architecture only
    flutter build macos --release
    check_status "macOS build"
    
    # Check the architecture of the built app
    echo -e "${YELLOW}Checking built architecture...${NC}"
    BINARY_NAME="captainvfr"
    BUILT_APP="build/macos/Build/Products/Release/captainvfr.app"
    lipo -info "$BUILT_APP/Contents/MacOS/$BINARY_NAME"
    
    # Create DMG
    echo -e "${YELLOW}Creating DMG installer...${NC}"
    
    # Install create-dmg if not available
    if ! command -v create-dmg &> /dev/null; then
        echo "Installing create-dmg..."
        brew install create-dmg
    fi
    
    # Create a temporary directory for DMG creation
    DMG_TEMP="build/dmg_temp"
    rm -rf "$DMG_TEMP"
    mkdir -p "$DMG_TEMP"
    
    # Copy the built app to temp directory
    cp -R "$BUILT_APP" "$DMG_TEMP/"
    
    # Create DMG without mounting (skip Finder customization)
    create-dmg \
        --volname "CaptainVFR" \
        --skip-jenkins \
        --no-internet-enable \
        "$DOWNLOADS_DIR/CaptainVFR.dmg" \
        "$DMG_TEMP" || {
            # Fallback: use hdiutil directly if create-dmg fails
            echo -e "${YELLOW}Using hdiutil as fallback...${NC}"
            hdiutil create -volname "CaptainVFR" \
                -srcfolder "$DMG_TEMP" \
                -ov \
                -format UDZO \
                "$DOWNLOADS_DIR/CaptainVFR.dmg"
        }
    
    check_status "DMG creation"
    echo -e "${GREEN}✓ DMG file: $DOWNLOADS_DIR/CaptainVFR.dmg${NC}"
    
    # Clean up
    rm -rf "$DMG_TEMP"
else
    echo -e "${YELLOW}Skipping macOS build (not on macOS)${NC}"
fi

# Build for Web
echo -e "${YELLOW}Building Web release...${NC}"
flutter build web --release --base-href /app/
check_status "Web build"

# Copy web build to hugo/static/app
echo -e "${YELLOW}Copying web build to hugo/static/app...${NC}"
mkdir -p hugo/static/app
rm -rf hugo/static/app/*
cp -r build/web/* hugo/static/app/
check_status "Web build copy to hugo/static/app"
echo -e "${GREEN}✓ Web build copied to hugo/static/app${NC}"

# Summary
echo ""
echo -e "${GREEN}=== Build Summary ===${NC}"
echo "Build artifacts:"
if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "✓ Android AAB: build/app/outputs/bundle/release/app-release.aab"
fi
if [ -f "$DOWNLOADS_DIR/CaptainVFR.apk" ]; then
    echo "✓ Android APK: $DOWNLOADS_DIR/CaptainVFR.apk"
fi
if [ -f "$DOWNLOADS_DIR/CaptainVFR.dmg" ]; then
    echo "✓ macOS DMG: $DOWNLOADS_DIR/CaptainVFR.dmg"
fi
if [ -d "hugo/static/app" ]; then
    echo "✓ Web Build: hugo/static/app/"
fi

echo ""
echo -e "${GREEN}Downloads available at:${NC}"
ls -la "$DOWNLOADS_DIR/"

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test the release builds on real devices"
echo "2. Upload to respective stores"
echo "3. Build and deploy Hugo website to make downloads available"
echo "4. Complete store listings and submit for review"