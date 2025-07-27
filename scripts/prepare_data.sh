#!/bin/bash

# Script to prepare all aviation data for the app
# This downloads, converts, splits, and compresses all data

set -e  # Exit on error

echo "🚀 Captain VFR Data Preparation Script"
echo "====================================="
echo ""

# Check if .env exists and load it
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "✅ Loaded environment variables from .env"
else
    echo "⚠️  No .env file found"
fi

# Check if API key is provided
if [ -z "$OPENAIP_API_KEY" ] && [ -z "$1" ]; then
    echo "❌ Error: OpenAIP API key is required!"
    echo ""
    echo "Usage:"
    echo "  ./scripts/prepare_data.sh YOUR_API_KEY"
    echo "  or"
    echo "  Set OPENAIP_API_KEY in .env file"
    exit 1
fi

# Use provided API key or environment variable
API_KEY="${1:-$OPENAIP_API_KEY}"

echo "📍 Using API key: ${API_KEY:0:4}... (${#API_KEY} chars)"
echo ""

# Run the OpenAIP data preparation script
echo "🔄 Starting OpenAIP data preparation..."
echo "ℹ️  Using updated script with altitude data fix..."
dart scripts/prepare_all_data.dart --api-key "$API_KEY"

echo ""
echo "🔄 Starting OurAirports data preparation..."
# OurAirports data doesn't require an API key
dart scripts/prepare_ourairports_data.dart

echo ""
echo "✅ All data preparation complete!"
echo ""
echo "📁 Data is ready in: assets/data/tiles/"
echo "   - OpenAIP data: airports, airspaces, navaids, reporting points, obstacles, hotspots"
echo "   - OurAirports data: runways, frequencies"