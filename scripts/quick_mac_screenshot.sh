#!/bin/bash

# Quick Mac Screenshot for App Store
# Takes a screenshot and immediately converts it to all required sizes

SCREENSHOT_DIR="macos_screenshots"
mkdir -p "$SCREENSHOT_DIR"

echo "🎯 Quick Mac App Store Screenshot Tool"
echo ""
echo "Options:"
echo "1) Capture full screen"
echo "2) Capture specific window (click to select)"
echo "3) Capture selection area (drag to select)"
echo ""
read -p "Choose option (1-3): " option

# Generate timestamp for unique filename
timestamp=$(date +%Y%m%d_%H%M%S)
original_file="$SCREENSHOT_DIR/screenshot_${timestamp}.png"

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
echo "🔄 Converting to App Store sizes..."

# Apple Store sizes
sizes=("1280x800" "1440x900" "2560x1600" "2880x1800")

for size in "${sizes[@]}"; do
    width=$(echo $size | cut -d'x' -f1)
    height=$(echo $size | cut -d'x' -f2)
    
    # Create fitted version (maintains aspect ratio)
    output_fit="$SCREENSHOT_DIR/appstore_${size}_fit_${timestamp}.png"
    sips -z $height $width "$original_file" --out "$output_fit" >/dev/null 2>&1
    echo "✅ Created: $(basename "$output_fit")"
    
    # Create filled version (exact dimensions, may crop)
    output_fill="$SCREENSHOT_DIR/appstore_${size}_fill_${timestamp}.png"
    sips -z $height $width -c $height $width "$original_file" --out "$output_fill" >/dev/null 2>&1
    echo "✅ Created: $(basename "$output_fill")"
done

echo ""
echo "🎉 Done! Your screenshots are ready in: $SCREENSHOT_DIR"
echo ""
echo "📝 Notes:"
echo "- 'fit' versions show the entire app (may have letterboxing)"
echo "- 'fill' versions are exact dimensions (may crop edges)"
echo "- Choose the version that looks best for each screenshot"
echo ""
echo "📤 To upload to App Store Connect:"
echo "1. Go to your app in App Store Connect"
echo "2. Navigate to the macOS platform section"
echo "3. Upload the screenshots to the appropriate device sizes"

# Open the folder in Finder
open "$SCREENSHOT_DIR"