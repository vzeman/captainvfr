#!/bin/bash

# Build script for CaptainVFR web deployment

echo "🚀 Building CaptainVFR for web..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web with base href
echo "🏗️ Building web app..."
flutter build web --release --base-href /app/

# Check if build was successful
if [ -d "build/web" ]; then
    echo "✅ Build successful!"
    
    # Create hugo/static/app directory if it doesn't exist
    echo "📁 Creating hugo/static/app directory..."
    mkdir -p hugo/static/app
    
    # Clean existing content in hugo/static/app
    echo "🧹 Cleaning hugo/static/app..."
    rm -rf hugo/static/app/*
    
    # Copy build output to hugo/static/app
    echo "📋 Copying build to hugo/static/app..."
    cp -r build/web/* hugo/static/app/
    
    echo "✅ Web app copied to hugo/static/app/"
    echo ""
    echo "🚀 The web app is now ready in hugo/static/app"
    echo "   Hugo will serve it at /app when built"
else
    echo "❌ Build failed!"
    exit 1
fi