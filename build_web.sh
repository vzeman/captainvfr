#!/bin/bash

# Build script for CaptainVFR web deployment

echo "🚀 Building CaptainVFR for web..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web
echo "🏗️ Building web app..."
flutter build web --release

# Check if build was successful
if [ -d "build/web" ]; then
    echo "✅ Build successful!"
    echo "📁 Build output is in: build/web/"
    echo ""
    echo "🚀 To deploy to AWS Amplify:"
    echo "1. Push this code to your Git repository"
    echo "2. Connect your repository to AWS Amplify Console"
    echo "3. Amplify will use amplify.yml to build and deploy"
else
    echo "❌ Build failed!"
    exit 1
fi