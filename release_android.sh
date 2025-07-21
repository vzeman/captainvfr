#!/bin/bash

# Android Release Build and Upload Script
# Builds AAB (Android App Bundle) and prepares for Google Play Console upload

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Set version (e.g., 1.0.1)"
    echo "  -b, --build BUILD        Set build number (e.g., 2)"
    echo "  -i, --increment          Auto-increment build number"
    echo "  -c, --clean              Clean build folders before building"
    echo "  -t, --test               Run tests before building"
    echo "  -a, --apk                Build APK in addition to AAB"
    echo "  -u, --upload             Upload to Google Play (requires setup)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       # Build AAB with current version"
    echo "  $0 -v 1.0.1 -b 2        # Set version to 1.0.1+2"
    echo "  $0 -i -a                # Increment build and create APK too"
    echo "  $0 -c -t                # Clean build and run tests"
    exit 1
}

# Parse command line arguments
CLEAN_BUILD=false
RUN_TESTS=false
INCREMENT_BUILD=false
BUILD_APK=false
UPLOAD_TO_PLAY=false
NEW_VERSION=""
NEW_BUILD=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            NEW_VERSION="$2"
            shift 2
            ;;
        -b|--build)
            NEW_BUILD="$2"
            shift 2
            ;;
        -i|--increment)
            INCREMENT_BUILD=true
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -t|--test)
            RUN_TESTS=true
            shift
            ;;
        -a|--apk)
            BUILD_APK=true
            shift
            ;;
        -u|--upload)
            UPLOAD_TO_PLAY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check for required files
if [ ! -f "android/key.properties" ]; then
    print_error "android/key.properties not found!"
    print_warning "Please ensure your signing configuration is set up."
    exit 1
fi

# Get current version and build number
CURRENT_VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //')
CURRENT_VERSION_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f1)
CURRENT_BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

print_info "Current version: $CURRENT_VERSION_NUMBER+$CURRENT_BUILD_NUMBER"

# Handle version updates
if [ -n "$NEW_VERSION" ]; then
    CURRENT_VERSION_NUMBER=$NEW_VERSION
fi

if [ -n "$NEW_BUILD" ]; then
    CURRENT_BUILD_NUMBER=$NEW_BUILD
elif [ "$INCREMENT_BUILD" = true ]; then
    CURRENT_BUILD_NUMBER=$((CURRENT_BUILD_NUMBER + 1))
fi

NEW_FULL_VERSION="$CURRENT_VERSION_NUMBER+$CURRENT_BUILD_NUMBER"

if [ "$NEW_FULL_VERSION" != "$CURRENT_VERSION" ]; then
    print_status "Updating version to: $NEW_FULL_VERSION"
    sed -i '' "s/version: .*/version: $NEW_FULL_VERSION/" pubspec.yaml
fi

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_status "Cleaning Flutter build..."
    flutter clean
fi

# Run tests if requested
if [ "$RUN_TESTS" = true ]; then
    print_status "Running tests..."
    flutter test
fi

# Get dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Build AAB (Android App Bundle)
print_status "Building Android App Bundle (AAB)..."
flutter build appbundle --release --build-number=$CURRENT_BUILD_NUMBER --build-name=$CURRENT_VERSION_NUMBER

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"

if [ ! -f "$AAB_PATH" ]; then
    print_error "AAB file not found at: $AAB_PATH"
    exit 1
fi

# Get AAB size
AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
print_info "AAB size: $AAB_SIZE"
print_status "AAB location: $AAB_PATH"

# Build APK if requested
if [ "$BUILD_APK" = true ]; then
    print_status "Building APK..."
    flutter build apk --release --build-number=$CURRENT_BUILD_NUMBER --build-name=$CURRENT_VERSION_NUMBER
    
    APK_PATH="build/app/outputs/apk/release/app-release.apk"
    if [ -f "$APK_PATH" ]; then
        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
        print_info "APK size: $APK_SIZE"
        print_status "APK location: $APK_PATH"
    else
        print_warning "APK build failed"
    fi
fi

# Don't copy AAB to release directory - it's too large for GitHub
# AAB files are available in build/app/outputs/bundle/release/
print_info "AAB file is available at: $AAB_PATH"
print_info "Note: AAB files are not stored in git due to size constraints"

# Upload to Google Play if requested
if [ "$UPLOAD_TO_PLAY" = true ]; then
    print_info "Checking for Google Play upload configuration..."
    
    # Check for service account JSON
    SERVICE_ACCOUNT_JSON=$(find . -name "*playstore*.json" -o -name "*service-account*.json" | head -1)
    
    if [ -z "$SERVICE_ACCOUNT_JSON" ]; then
        print_error "No Google Play service account JSON found!"
        print_warning "To enable automated uploads:"
        echo "1. Create a service account in Google Cloud Console"
        echo "2. Grant it access in Google Play Console"
        echo "3. Download the JSON key and place it in the project"
        echo "4. Run: $0 --upload"
    else
        print_status "Found service account: $SERVICE_ACCOUNT_JSON"
        print_warning "Automated upload requires additional setup with fastlane or Google Play API"
        print_info "For now, please upload manually via Google Play Console"
    fi
fi

print_status "Build Summary:"
echo "  Version: $NEW_FULL_VERSION"
echo "  AAB Path: $AAB_PATH"
echo "  AAB Size: $AAB_SIZE"

if [ "$BUILD_APK" = true ] && [ -f "$APK_PATH" ]; then
    echo "  APK Path: $APK_PATH"
    echo "  APK Size: $APK_SIZE"
fi

echo ""
print_status "Next steps:"
echo "1. Go to https://play.google.com/console"
echo "2. Select your app"
echo "3. Go to 'Production' or 'Testing' track"
echo "4. Click 'Create new release'"
echo "5. Upload the AAB file"
echo "6. Fill in release notes"
echo "7. Submit for review"

# Optionally commit version bump
if [ "$NEW_FULL_VERSION" != "$CURRENT_VERSION" ]; then
    echo ""
    print_info "Don't forget to commit the version bump:"
    echo "  git add pubspec.yaml"
    echo "  git commit -m \"Bump version to $NEW_FULL_VERSION\""
    echo "  git tag v$CURRENT_VERSION_NUMBER"
    echo "  git push && git push --tags"
fi