#!/bin/bash

# Mac App Store Screenshot Generator Script
# This script captures screenshots and resizes them to Apple Store required sizes

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Apple Store required sizes
SIZES=(
    "1280x800"
    "1440x900"
    "2560x1600"
    "2880x1800"
)

# Create screenshots directory
SCREENSHOT_DIR="macos_screenshots"
mkdir -p "$SCREENSHOT_DIR"

echo -e "${GREEN}=== Mac App Store Screenshot Generator ===${NC}"
echo ""

# Function to take a screenshot
take_screenshot() {
    local filename=$1
    echo -e "${YELLOW}Taking screenshot in 3 seconds...${NC}"
    echo "Position your app window as desired"
    sleep 3
    
    # Capture the entire screen
    screencapture -x "$filename"
    echo -e "${GREEN}✓ Screenshot captured: $filename${NC}"
}

# Function to resize image maintaining aspect ratio
resize_image() {
    local input=$1
    local width=$2
    local height=$3
    local output=$4
    
    # Use sips (built-in macOS tool) to resize
    # -Z fits image within specified dimensions maintaining aspect ratio
    sips -z $height $width "$input" --out "$output" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Created: $output (${width}x${height})${NC}"
    else
        echo -e "${RED}✗ Failed to create: $output${NC}"
    fi
}

# Function to get image dimensions
get_dimensions() {
    local file=$1
    sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel/{print $2}' | tr '\n' 'x' | sed 's/x$//'
}

# Main script
echo "This script will help you create Mac App Store screenshots"
echo ""
echo "Options:"
echo "1) Take new screenshots"
echo "2) Convert existing screenshots"
echo -n "Choose option (1 or 2): "
read option

case $option in
    1)
        # Take new screenshots
        echo ""
        echo "How many screenshots do you want to take?"
        echo -n "Number of screenshots: "
        read num_screenshots
        
        original_files=()
        
        for ((i=1; i<=num_screenshots; i++)); do
            echo ""
            echo -e "${YELLOW}Screenshot $i of $num_screenshots${NC}"
            filename="$SCREENSHOT_DIR/original_screenshot_$i.png"
            take_screenshot "$filename"
            original_files+=("$filename")
        done
        ;;
    2)
        # Convert existing screenshots
        echo ""
        echo "Place your screenshots in the '$SCREENSHOT_DIR' folder"
        echo "Press Enter when ready..."
        read
        
        # Find all image files
        original_files=($(find "$SCREENSHOT_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | grep -v "_resized_"))
        
        if [ ${#original_files[@]} -eq 0 ]; then
            echo -e "${RED}No image files found in $SCREENSHOT_DIR${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}Found ${#original_files[@]} image(s) to process${NC}"
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Process each original file
for original in "${original_files[@]}"; do
    echo ""
    echo -e "${YELLOW}Processing: $(basename "$original")${NC}"
    
    # Get original dimensions
    original_dims=$(get_dimensions "$original")
    echo "Original dimensions: $original_dims"
    
    # Get base filename without extension
    base_name=$(basename "$original" | sed 's/\.[^.]*$//')
    
    # Create resized versions for each required size
    for size in "${SIZES[@]}"; do
        width=$(echo $size | cut -d'x' -f1)
        height=$(echo $size | cut -d'x' -f2)
        output_file="$SCREENSHOT_DIR/${base_name}_${size}.png"
        
        resize_image "$original" "$width" "$height" "$output_file"
    done
done

# Create a "best fit" version that fills the entire dimensions
echo ""
echo -e "${YELLOW}Creating 'filled' versions (may crop)...${NC}"

for original in "${original_files[@]}"; do
    base_name=$(basename "$original" | sed 's/\.[^.]*$//')
    
    for size in "${SIZES[@]}"; do
        width=$(echo $size | cut -d'x' -f1)
        height=$(echo $size | cut -d'x' -f2)
        output_file="$SCREENSHOT_DIR/${base_name}_${size}_filled.png"
        
        # Use sips to crop and resize to exact dimensions
        sips -z $height $width "$original" -c $height $width --out "$output_file" >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Created filled: $output_file${NC}"
        fi
    done
done

echo ""
echo -e "${GREEN}=== Screenshot generation complete! ===${NC}"
echo ""
echo "Your screenshots are in: $SCREENSHOT_DIR"
echo ""
echo "Files created:"
ls -la "$SCREENSHOT_DIR"/*_resized_*.png 2>/dev/null || ls -la "$SCREENSHOT_DIR"/*.png | grep -E "(1280x800|1440x900|2560x1600|2880x1800)"
echo ""
echo -e "${YELLOW}Tips for App Store submission:${NC}"
echo "- Use the regular resized versions if you want to show the full app"
echo "- Use the 'filled' versions if you want exact dimensions (may crop edges)"
echo "- Upload the highest quality versions to App Store Connect"