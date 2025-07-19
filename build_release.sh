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

# Build for Windows (if on Windows)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OS" == "Windows_NT" ]]; then
    echo -e "${YELLOW}Building Windows release...${NC}"
    
    # Build Windows executable
    flutter build windows --release
    check_status "Windows build"
    
    # Create installer or ZIP package
    echo -e "${YELLOW}Creating Windows installer...${NC}"
    
    # Create a ZIP file with the Windows build
    WINDOWS_BUILD_DIR="build/windows/x64/runner/Release"
    if [ -d "$WINDOWS_BUILD_DIR" ]; then
        cd "$WINDOWS_BUILD_DIR"
        # Use PowerShell to create ZIP on Windows
        powershell -Command "Compress-Archive -Path * -DestinationPath '../../../../../$DOWNLOADS_DIR/CaptainVFR-Windows.zip' -Force"
        cd -
        echo -e "${GREEN}✓ Windows ZIP: $DOWNLOADS_DIR/CaptainVFR-Windows.zip${NC}"
    else
        echo -e "${RED}Windows build directory not found${NC}"
    fi
else
    echo -e "${YELLOW}Skipping Windows build (not on Windows)${NC}"
    echo -e "${YELLOW}To build for Windows, run this script on a Windows machine with Flutter installed${NC}"
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

# Remove source map references from production build to avoid 404 errors
echo -e "${YELLOW}Removing source map references from production build...${NC}"
if [ -f "hugo/static/app/flutter.js" ]; then
    # Remove the sourceMappingURL comment from flutter.js
    sed -i '' '/\/\/# sourceMappingURL=flutter.js.map/d' hugo/static/app/flutter.js 2>/dev/null || \
    sed -i '/\/\/# sourceMappingURL=flutter.js.map/d' hugo/static/app/flutter.js
    echo -e "${GREEN}✓ Removed source map reference from flutter.js${NC}"
fi

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
if [ -f "$DOWNLOADS_DIR/CaptainVFR-Windows.zip" ]; then
    echo "✓ Windows ZIP: $DOWNLOADS_DIR/CaptainVFR-Windows.zip"
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

# Git operations
echo ""
echo -e "${YELLOW}=== Git Operations ===${NC}"

# Ensure Git LFS is initialized
if ! git lfs version &> /dev/null; then
    echo -e "${RED}Git LFS is not installed. Please install it first.${NC}"
    echo "Run: brew install git-lfs && git lfs install"
    exit 1
fi

# Track large files with Git LFS
echo -e "${YELLOW}Setting up Git LFS tracking for large files...${NC}"
git lfs track "hugo/static/downloads/*.apk"
git lfs track "hugo/static/downloads/*.dmg"
git lfs track "hugo/static/downloads/*.exe"
git lfs track "hugo/static/downloads/*.msi"
git lfs track "hugo/static/downloads/*.zip"
check_status "Git LFS tracking setup"

# Add .gitattributes if it was modified
if git diff --name-only | grep -q ".gitattributes"; then
    git add .gitattributes
    echo -e "${GREEN}✓ Added .gitattributes${NC}"
fi

# Add all build artifacts
echo -e "${YELLOW}Adding build artifacts to Git...${NC}"
git add hugo/static/downloads/CaptainVFR.apk
git add hugo/static/downloads/CaptainVFR.dmg
if [ -f "hugo/static/downloads/CaptainVFR-Windows.zip" ]; then
    git add hugo/static/downloads/CaptainVFR-Windows.zip
fi
git add hugo/static/app/
check_status "Git add"

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo -e "${YELLOW}No changes to commit${NC}"
else
    # Commit changes
    echo -e "${YELLOW}Committing changes...${NC}"
    BUILD_DATE=$(date +"%Y-%m-%d %H:%M")
    COMMIT_MESSAGE="Build release: Update APK, DMG, and web app ($BUILD_DATE)

- Updated Android APK
- Updated macOS DMG  
- Updated web application in /app/
- All large files tracked with Git LFS"

    git commit -m "$COMMIT_MESSAGE"
    check_status "Git commit"
    
    # Push to remote
    echo -e "${YELLOW}Pushing to remote repository...${NC}"
    git push
    check_status "Git push"
    
    echo -e "${GREEN}✓ All changes committed and pushed to repository${NC}"
fi

echo ""
echo -e "${GREEN}=== Build and Deploy Complete ===${NC}"