#!/bin/bash

echo "🚀 Building and installing CaptainVFR on all connected iOS devices..."

# First, let's see what devices are connected
echo "📱 Checking connected devices..."
flutter devices

# Build the app in release mode
echo "🔨 Building iOS app in release mode..."
flutter build ios --release

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"

# Get list of connected iOS devices
DEVICES=$(flutter devices | grep -E "iPhone|iPad" | awk '{print $3}')

if [ -z "$DEVICES" ]; then
    echo "❌ No iOS devices found. Please connect your iPhone and iPad."
    exit 1
fi

echo "📱 Found devices:"
echo "$DEVICES"

# Install on each device
for DEVICE in $DEVICES; do
    echo "📲 Installing on device: $DEVICE"
    flutter install -d $DEVICE
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully installed on $DEVICE"
    else
        echo "❌ Failed to install on $DEVICE"
    fi
done

echo "🎉 Installation complete!"
echo ""
echo "📝 Next steps:"
echo "1. On each device, go to Settings → General → Device Management"
echo "2. Trust your developer certificate"
echo "3. The app will work for 1 year with your paid developer account"