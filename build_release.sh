#!/bin/bash

# Captain VFR Release Build Script

echo "🚀 Captain VFR Release Build"
echo "============================"

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
echo "Choose build type:"
echo "1) App Bundle (recommended for Play Store)"
echo "2) APK"
read -p "Enter choice (1 or 2): " android_choice

if [ "$android_choice" == "1" ]; then
    flutter build appbundle --release
    check_status "Android App Bundle build"
    echo -e "${GREEN}✓ AAB file: build/app/outputs/bundle/release/app-release.aab${NC}"
else
    flutter build apk --release
    check_status "Android APK build"
    echo -e "${GREEN}✓ APK file: build/app/outputs/flutter-apk/app-release.apk${NC}"
fi

# Build for iOS
echo -e "${YELLOW}Building iOS release...${NC}"
echo "Do you want to build for iOS? (requires macOS with Xcode)"
read -p "Build for iOS? (y/n): " ios_choice

if [ "$ios_choice" == "y" ] || [ "$ios_choice" == "Y" ]; then
    flutter build ios --release
    check_status "iOS build"
    echo -e "${GREEN}✓ iOS build complete. Now open Xcode to archive and upload.${NC}"
    echo "Next steps for iOS:"
    echo "1. Open ios/Runner.xcworkspace in Xcode"
    echo "2. Select 'Any iOS Device' as build target"
    echo "3. Product > Archive"
    echo "4. Distribute App > App Store Connect"
fi

# Summary
echo ""
echo -e "${GREEN}=== Build Summary ===${NC}"
echo "Android AAB: build/app/outputs/bundle/release/app-release.aab"
echo "Android APK: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test the release builds on real devices"
echo "2. Upload to respective stores"
echo "3. Complete store listings"
echo "4. Submit for review"