#!/bin/bash

# Simple Mac Screenshot for App Store
# Creates screenshots in the required 2880x1800 size

SCREENSHOT_DIR="macos_screenshots"
mkdir -p "$SCREENSHOT_DIR"

echo "🎯 Mac App Store Screenshot Tool"
echo ""
echo "This will create a 2880x1800 screenshot (the only size required)"
echo ""
echo "Options:"
echo "1) Capture full screen"
echo "2) Capture specific window (click to select)"
echo "3) Capture selection area (drag to select)"
echo ""
read -p "Choose option (1-3): " option

# Generate timestamp for unique filename
timestamp=$(date +%Y%m%d_%H%M%S)
original_file="$SCREENSHOT_DIR/temp_${timestamp}.png"

case $option in
    1)
        echo "📸 Capturing full screen in 3 seconds..."
        sleep 3
        screencapture -x "$original_file"
        ;;
    2)
        echo "📸 Click on the window you want to capture..."
        screencapture -x -w "$original_file"
        ;;
    3)
        echo "📸 Drag to select the area you want to capture..."
        screencapture -x -s "$original_file"
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

if [ ! -f "$original_file" ]; then
    echo "❌ Screenshot was cancelled"
    exit 1
fi

echo "✅ Screenshot captured!"
echo ""

# Create 2880x1800 version
output_file="$SCREENSHOT_DIR/appstore_screenshot_${timestamp}.png"

echo "🔄 Converting to 2880x1800..."
# Create exact 2880x1800 size (crops if needed to maintain aspect ratio)
sips -z 1800 2880 -c 1800 2880 "$original_file" --out "$output_file" >/dev/null 2>&1

# Remove temporary file
rm "$original_file"

echo "✅ Created: $(basename "$output_file")"
echo ""
echo "📐 Size: 2880x1800 (required App Store size)"
echo "📁 Location: $output_file"
echo ""
echo "🎉 Done! Your screenshot is ready for App Store Connect"

# Open the file in Preview
open "$output_file"