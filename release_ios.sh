#!/bin/bash

# iOS Release Build and Upload Script
# Builds, archives, exports, and uploads the iOS app to App Store Connect

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

# Function to increment version number
increment_version() {
    local version=$1
    local major=$(echo $version | cut -d'.' -f1)
    local minor=$(echo $version | cut -d'.' -f2)
    local patch=$(echo $version | cut -d'.' -f3)
    
    # Increment patch version
    patch=$((patch + 1))
    
    echo "$major.$minor.$patch"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Set version (e.g., 1.0.1)"
    echo "  -b, --build BUILD        Set build number (e.g., 2)"
    echo "  -i, --increment          Auto-increment build number"
    echo "  -I, --increment-version  Auto-increment version number (patch)"
    echo "  -c, --clean              Clean build folders before building"
    echo "  -t, --test               Run tests before building"
    echo "  -f, --fix-warnings       Apply iOS warning fixes before building"
    echo "  -q, --quiet              Suppress verbose output from build commands"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       # Build and upload with current version"
    echo "  $0 -v 1.0.1 -b 2        # Set version to 1.0.1+2"
    echo "  $0 -i                    # Auto-increment build number"
    echo "  $0 -I                    # Auto-increment version number"
    echo "  $0 -c -t                # Clean build and run tests"
    echo "  $0 -f -i                # Fix warnings and increment build"
    exit 1
}

# Parse command line arguments
CLEAN_BUILD=false
RUN_TESTS=false
INCREMENT_BUILD=false
INCREMENT_VERSION=false
FIX_WARNINGS=false
QUIET_MODE=false
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
        -I|--increment-version)
            INCREMENT_VERSION=true
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
        -f|--fix-warnings)
            FIX_WARNINGS=true
            shift
            ;;
        -q|--quiet)
            QUIET_MODE=true
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

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -E '^(APPLE_USERNAME|APPLE_APP_PASSWORD)=' | xargs)
else
    print_error ".env file not found!"
    exit 1
fi

# Check required environment variables
if [ -z "$APPLE_USERNAME" ] || [ -z "$APPLE_APP_PASSWORD" ]; then
    print_error "Missing required environment variables: APPLE_USERNAME or APPLE_APP_PASSWORD"
    print_warning "Please add these to your .env file:"
    echo "APPLE_USERNAME=your.email@example.com"
    echo "APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx"
    exit 1
fi

# Configuration
WORKSPACE_PATH="ios/Runner.xcworkspace"
SCHEME="Runner"
ARCHIVE_PATH="ios/build/Runner.xcarchive"
EXPORT_PATH="ios/build/IPA"
EXPORT_OPTIONS="ios/ExportOptions.plist"
IPA_NAME="captainvfr.ipa"

# Set quiet flags if requested
XCODE_QUIET=""
if [ "$QUIET_MODE" = true ]; then
    XCODE_QUIET="-quiet"
fi

# Get current version and build number
CURRENT_VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //')
CURRENT_VERSION_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f1)
CURRENT_BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

print_info "Current version: $CURRENT_VERSION_NUMBER+$CURRENT_BUILD_NUMBER"

# Check if version needs to be incremented based on common scenarios
if [ "$CURRENT_VERSION_NUMBER" = "1.0.0" ] && [ "$INCREMENT_VERSION" = false ] && [ -z "$NEW_VERSION" ]; then
    print_warning "Version 1.0.0 is commonly closed for new submissions after initial release."
    print_warning "Consider using -I flag to auto-increment to 1.0.1"
    echo ""
fi

# Handle version updates
if [ -n "$NEW_VERSION" ]; then
    CURRENT_VERSION_NUMBER=$NEW_VERSION
elif [ "$INCREMENT_VERSION" = true ]; then
    CURRENT_VERSION_NUMBER=$(increment_version $CURRENT_VERSION_NUMBER)
    print_status "Auto-incrementing version to: $CURRENT_VERSION_NUMBER"
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

# Apply iOS warning fixes if requested
if [ "$FIX_WARNINGS" = true ]; then
    print_status "Applying iOS warning fixes..."
    cd ios
    rm -rf Pods
    rm -rf .symlinks
    rm -f Podfile.lock
    pod cache clean --all
    pod install --repo-update
    cd ..
fi

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_status "Cleaning Flutter build..."
    flutter clean
    cd ios
    if [ ! -d "Pods" ]; then
        pod install
    fi
    cd ..
fi

# Run tests if requested
if [ "$RUN_TESTS" = true ]; then
    print_status "Running tests..."
    flutter test
fi

# Clean previous builds
print_status "Cleaning previous builds..."
rm -rf "$ARCHIVE_PATH"
rm -rf "$EXPORT_PATH"

# Step 1: Update pods if needed
if [ ! -d "ios/Pods" ] || [ "$FIX_WARNINGS" = false ]; then
    print_status "Updating CocoaPods dependencies..."
    cd ios
    pod install --repo-update
    cd ..
fi

# Step 2: Build Flutter iOS release
print_status "Building Flutter iOS release (version $NEW_FULL_VERSION)..."
flutter build ios --release --build-number=$CURRENT_BUILD_NUMBER --build-name=$CURRENT_VERSION_NUMBER

# Step 3: Check and fix app icon transparency
print_status "Checking app icon for transparency..."
ICON_PATH="ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
if sips -g hasAlpha "$ICON_PATH" | grep -q "yes"; then
    print_warning "App icon has alpha channel. Removing..."
    # Remove alpha channel by converting to JPEG and back to PNG
    sips -s format jpeg "$ICON_PATH" --out "${ICON_PATH}.temp.jpg"
    sips -s format png "${ICON_PATH}.temp.jpg" --out "$ICON_PATH"
    rm "${ICON_PATH}.temp.jpg"
    print_status "Alpha channel removed from app icon"
fi

# Step 4: Archive the app
print_status "Creating archive..."
cd ios
xcodebuild -workspace Runner.xcworkspace \
    -scheme "$SCHEME" \
    -sdk iphoneos \
    -configuration Release \
    -archivePath "build/Runner.xcarchive" \
    archive \
    $XCODE_QUIET

# Step 5: Export the archive
print_status "Exporting IPA..."
xcodebuild -exportArchive \
    -archivePath "build/Runner.xcarchive" \
    -exportPath "build/IPA" \
    -exportOptionsPlist "ExportOptions.plist" \
    -allowProvisioningUpdates \
    $XCODE_QUIET

cd ..

# Step 6: Upload to App Store Connect
print_status "Uploading to App Store Connect..."
IPA_PATH="$EXPORT_PATH/$IPA_NAME"

if [ ! -f "$IPA_PATH" ]; then
    print_error "IPA file not found at: $IPA_PATH"
    exit 1
fi

# Get IPA size
IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
print_info "IPA size: $IPA_SIZE"

# Upload - capture output for error analysis
UPLOAD_OUTPUT=$(xcrun altool --upload-app \
    -f "$IPA_PATH" \
    -t ios \
    -u "$APPLE_USERNAME" \
    -p "$APPLE_APP_PASSWORD" 2>&1)

UPLOAD_RESULT=$?

if [ $UPLOAD_RESULT -eq 0 ]; then
    print_status "Upload successful!"
    echo ""
    print_status "Build Summary:"
    echo "  Version: $NEW_FULL_VERSION"
    echo "  IPA Size: $IPA_SIZE"
    echo "  IPA Path: $IPA_PATH"
    echo ""
    print_status "Next steps:"
    echo "1. Go to https://appstoreconnect.apple.com"
    echo "2. Wait for processing (5-30 minutes)"
    echo "3. Submit for review in App Store Connect"
    echo ""
    
    # Optionally commit version bump
    if [ "$NEW_FULL_VERSION" != "$CURRENT_VERSION" ]; then
        print_info "Don't forget to commit the version bump:"
        echo "  git add pubspec.yaml"
        echo "  git commit -m \"Bump version to $NEW_FULL_VERSION\""
        echo "  git tag v$CURRENT_VERSION_NUMBER"
        echo "  git push && git push --tags"
    fi
else
    print_error "Upload failed!"
    
    # Check for specific error messages
    if echo "$UPLOAD_OUTPUT" | grep -q "closed for new build submissions"; then
        print_error "Version $CURRENT_VERSION_NUMBER is closed for new submissions!"
        print_warning "You need to increment the version number."
        echo ""
        print_info "Suggested fix - run one of these commands:"
        echo "  $0 -I    # Auto-increment to $(increment_version $CURRENT_VERSION_NUMBER)"
        echo "  $0 -v $(increment_version $CURRENT_VERSION_NUMBER)    # Manually set version"
        echo ""
    elif echo "$UPLOAD_OUTPUT" | grep -q "must contain a higher version"; then
        print_error "Version $CURRENT_VERSION_NUMBER has already been submitted!"
        print_warning "You need to increment the version number."
        echo ""
        print_info "Suggested fix - run one of these commands:"
        echo "  $0 -I    # Auto-increment to $(increment_version $CURRENT_VERSION_NUMBER)"
        echo "  $0 -v $(increment_version $CURRENT_VERSION_NUMBER)    # Manually set version"
        echo ""
    fi
    
    # Show the full error output
    echo "$UPLOAD_OUTPUT"
    exit 1
fi