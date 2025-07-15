#!/bin/bash

# Script to download all OpenAIP data (airspaces and reporting points)
# Usage: ./scripts/download_all_data.sh [OPTIONS] [YOUR_API_KEY]
# Options:
#   --force     Force download even if files are fresh
#   --help      Show this help message
#
# If no API key is provided, uses the default key from the app

# Default values
FORCE_DOWNLOAD=false
API_KEY=""
MAX_AGE_HOURS=24

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_DOWNLOAD=true
            shift
            ;;
        --help)
            echo "Usage: ./scripts/download_all_data.sh [OPTIONS] [YOUR_API_KEY]"
            echo ""
            echo "Options:"
            echo "  --force     Force download even if files are fresh (less than 24 hours old)"
            echo "  --help      Show this help message"
            echo ""
            echo "If no API key is provided, uses the default key from the app"
            echo ""
            echo "This script downloads:"
            echo "  - Airports (from OpenAIP)"
            echo "  - Airspaces (from OpenAIP)"
            echo "  - Reporting points (from OpenAIP)"
            echo "  - Frequencies (from OurAirports)"
            echo "  - Navaids (from OurAirports)"
            echo ""
            echo "Files are only downloaded if they don't exist or are older than 24 hours."
            echo "Use --force to download regardless of file age."
            exit 0
            ;;
        --*)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            # Assume it's the API key
            API_KEY="--api-key $1"
            shift
            ;;
    esac
done

if [ -z "$API_KEY" ]; then
    echo "📍 No API key provided, using default API key"
fi

echo "🚀 Starting data download..."
echo ""

if [ "$FORCE_DOWNLOAD" = true ]; then
    echo "⚡ Force download enabled - will download all data regardless of age"
else
    echo "🕐 Will only download data older than $MAX_AGE_HOURS hours"
fi
echo ""

# Make scripts directory if it doesn't exist
mkdir -p scripts

# Make assets/data directory if it doesn't exist
mkdir -p assets/data

# Track what was downloaded
AIRPORTS_DOWNLOADED=false
AIRSPACES_DOWNLOADED=false
REPORTING_POINTS_DOWNLOADED=false
FREQUENCIES_DOWNLOADED=false
NAVAIDS_DOWNLOADED=false
RUNWAYS_DOWNLOADED=false

# Function to check if download is needed
needs_download() {
    local file=$1
    local type=$2
    
    if [ "$FORCE_DOWNLOAD" = true ]; then
        echo "⚡ Force downloading $type"
        return 0
    fi
    
    # Check if file exists and age
    dart scripts/check_file_age.dart "$file" $MAX_AGE_HOURS
    local result=$?
    
    if [ $result -eq 0 ]; then
        if [ -f "$file" ]; then
            echo "🔄 $type data is older than $MAX_AGE_HOURS hours, updating..."
        else
            echo "📥 $type data not found, downloading..."
        fi
        return 0
    else
        echo "✓ $type data is fresh (less than $MAX_AGE_HOURS hours old), skipping..."
        return 1
    fi
}

# Download airports
if needs_download "assets/data/airports.json" "Airports"; then
    echo "📦 Downloading airports..."
    dart scripts/download_airports.dart $API_KEY
    
    if [ $? -ne 0 ]; then
        echo "❌ Airport download failed!"
        exit 1
    fi
    
    AIRPORTS_DOWNLOADED=true
    echo ""
    echo "✅ Airports downloaded successfully!"
fi
echo ""

# Download airspaces
if needs_download "assets/data/airspaces.json" "Airspaces"; then
    echo "📦 Downloading airspaces..."
    dart scripts/download_airspaces.dart $API_KEY
    
    if [ $? -ne 0 ]; then
        echo "❌ Airspace download failed!"
        exit 1
    fi
    
    AIRSPACES_DOWNLOADED=true
    echo ""
    echo "✅ Airspaces downloaded successfully!"
fi
echo ""

# Download reporting points
if needs_download "assets/data/reporting_points.json" "Reporting points"; then
    echo "📦 Downloading reporting points..."
    dart scripts/download_reporting_points.dart $API_KEY
    
    if [ $? -ne 0 ]; then
        echo "❌ Reporting points download failed!"
        exit 1
    fi
    
    REPORTING_POINTS_DOWNLOADED=true
    echo ""
    echo "✅ Reporting points downloaded successfully!"
fi
echo ""

# Download frequencies (no API key needed for OurAirports)
if needs_download "assets/data/frequencies.json" "Frequencies"; then
    echo "📦 Downloading frequencies..."
    dart scripts/download_frequencies.dart
    
    if [ $? -ne 0 ]; then
        echo "❌ Frequencies download failed!"
        exit 1
    fi
    
    FREQUENCIES_DOWNLOADED=true
    echo ""
    echo "✅ Frequencies downloaded successfully!"
fi
echo ""

# Download navaids (no API key needed for OurAirports)
if needs_download "assets/data/navaids.json" "Navaids"; then
    echo "📦 Downloading navaids..."
    dart scripts/download_navaids.dart
    
    if [ $? -ne 0 ]; then
        echo "❌ Navaids download failed!"
        exit 1
    fi
    
    NAVAIDS_DOWNLOADED=true
    echo ""
    echo "✅ Navaids downloaded successfully!"
fi
echo ""

# Download runways (no API key needed for OurAirports)
if needs_download "assets/data/runways.json" "Runways"; then
    echo "📦 Downloading runways..."
    dart scripts/download_runways.dart
    
    if [ $? -ne 0 ]; then
        echo "❌ Runways download failed!"
        exit 1
    fi
    
    RUNWAYS_DOWNLOADED=true
    echo ""
    echo "✅ Runways downloaded successfully!"
fi
echo ""

# Show summary
echo "📊 DOWNLOAD SUMMARY"
echo "=================="

# Show what was downloaded
if [ "$AIRPORTS_DOWNLOADED" = true ]; then
    echo "🔄 Airports: Updated"
else
    echo "✓ Airports: Already fresh"
fi

if [ "$AIRSPACES_DOWNLOADED" = true ]; then
    echo "🔄 Airspaces: Updated"
else
    echo "✓ Airspaces: Already fresh"
fi

if [ "$REPORTING_POINTS_DOWNLOADED" = true ]; then
    echo "🔄 Reporting Points: Updated"
else
    echo "✓ Reporting Points: Already fresh"
fi

if [ "$FREQUENCIES_DOWNLOADED" = true ]; then
    echo "🔄 Frequencies: Updated"
else
    echo "✓ Frequencies: Already fresh"
fi

if [ "$NAVAIDS_DOWNLOADED" = true ]; then
    echo "🔄 Navaids: Updated"
else
    echo "✓ Navaids: Already fresh"
fi

if [ "$RUNWAYS_DOWNLOADED" = true ]; then
    echo "🔄 Runways: Updated"
else
    echo "✓ Runways: Already fresh"
fi

echo ""

# Show file sizes
echo "📦 FILE SIZES"
echo "============="

if [ -f "assets/data/airports.json" ]; then
    AIRPORT_SIZE=$(du -h assets/data/airports.json | cut -f1)
    echo "✅ Airports: $AIRPORT_SIZE"
fi

if [ -f "assets/data/airports.json.gz" ]; then
    AIRPORT_GZ_SIZE=$(du -h assets/data/airports.json.gz | cut -f1)
    echo "   Compressed: $AIRPORT_GZ_SIZE"
fi

if [ -f "assets/data/airspaces.json" ]; then
    AIRSPACE_SIZE=$(du -h assets/data/airspaces.json | cut -f1)
    echo "✅ Airspaces: $AIRSPACE_SIZE"
fi

if [ -f "assets/data/airspaces.json.gz" ]; then
    AIRSPACE_GZ_SIZE=$(du -h assets/data/airspaces.json.gz | cut -f1)
    echo "   Compressed: $AIRSPACE_GZ_SIZE"
fi

if [ -f "assets/data/reporting_points.json" ]; then
    RP_SIZE=$(du -h assets/data/reporting_points.json | cut -f1)
    echo "✅ Reporting Points: $RP_SIZE"
fi

if [ -f "assets/data/reporting_points.json.gz" ]; then
    RP_GZ_SIZE=$(du -h assets/data/reporting_points.json.gz | cut -f1)
    echo "   Compressed: $RP_GZ_SIZE"
fi

if [ -f "assets/data/frequencies.json" ]; then
    FREQ_SIZE=$(du -h assets/data/frequencies.json | cut -f1)
    echo "✅ Frequencies: $FREQ_SIZE"
fi

if [ -f "assets/data/frequencies.json.gz" ]; then
    FREQ_GZ_SIZE=$(du -h assets/data/frequencies.json.gz | cut -f1)
    echo "   Compressed: $FREQ_GZ_SIZE"
fi

if [ -f "assets/data/navaids.json" ]; then
    NAVAID_SIZE=$(du -h assets/data/navaids.json | cut -f1)
    echo "✅ Navaids: $NAVAID_SIZE"
fi

if [ -f "assets/data/navaids.json.gz" ]; then
    NAVAID_GZ_SIZE=$(du -h assets/data/navaids.json.gz | cut -f1)
    echo "   Compressed: $NAVAID_GZ_SIZE"
fi

if [ -f "assets/data/runways.json" ]; then
    RUNWAY_SIZE=$(du -h assets/data/runways.json | cut -f1)
    echo "✅ Runways: $RUNWAY_SIZE"
fi

if [ -f "assets/data/runways.json.gz" ]; then
    RUNWAY_GZ_SIZE=$(du -h assets/data/runways.json.gz | cut -f1)
    echo "   Compressed: $RUNWAY_GZ_SIZE"
fi

echo ""

# Check if any data was downloaded
ANY_DOWNLOADED=false
if [ "$AIRPORTS_DOWNLOADED" = true ] || [ "$AIRSPACES_DOWNLOADED" = true ] || [ "$REPORTING_POINTS_DOWNLOADED" = true ] || [ "$FREQUENCIES_DOWNLOADED" = true ] || [ "$NAVAIDS_DOWNLOADED" = true ] || [ "$RUNWAYS_DOWNLOADED" = true ]; then
    ANY_DOWNLOADED=true
fi

if [ "$ANY_DOWNLOADED" = true ]; then
    echo "🎉 Data updates completed!"
    echo ""
    
    # Automatically compress the data
    echo "🗜️  Compressing data for distribution..."
    dart scripts/prepare_compressed_data.dart
    
    if [ $? -ne 0 ]; then
        echo "❌ Data compression failed!"
        exit 1
    fi
    
    echo ""
    echo "✅ Data compression complete!"
    echo ""
    
    # Show final sizes
    echo "📊 FINAL COMPRESSED SIZES"
    echo "========================"
    if [ -f "assets/data/airports_min.json.gz" ]; then
        AIRPORT_MIN_SIZE=$(du -h assets/data/airports_min.json.gz | cut -f1)
        echo "✅ Airports (compressed): $AIRPORT_MIN_SIZE"
    fi
    
    if [ -f "assets/data/airspaces_min.json.gz" ]; then
        AIRSPACE_MIN_SIZE=$(du -h assets/data/airspaces_min.json.gz | cut -f1)
        echo "✅ Airspaces (compressed): $AIRSPACE_MIN_SIZE"
    fi
    
    if [ -f "assets/data/reporting_points_min.json.gz" ]; then
        RP_MIN_SIZE=$(du -h assets/data/reporting_points_min.json.gz | cut -f1)
        echo "✅ Reporting Points (compressed): $RP_MIN_SIZE"
    fi
    
    if [ -f "assets/data/frequencies_min.json.gz" ]; then
        FREQ_MIN_SIZE=$(du -h assets/data/frequencies_min.json.gz | cut -f1)
        echo "✅ Frequencies (compressed): $FREQ_MIN_SIZE"
    fi
    
    if [ -f "assets/data/navaids_min.json.gz" ]; then
        NAVAID_MIN_SIZE=$(du -h assets/data/navaids_min.json.gz | cut -f1)
        echo "✅ Navaids (compressed): $NAVAID_MIN_SIZE"
    fi
    
    if [ -f "assets/data/runways_min.json.gz" ]; then
        RUNWAY_MIN_SIZE=$(du -h assets/data/runways_min.json.gz | cut -f1)
        echo "✅ Runways (compressed): $RUNWAY_MIN_SIZE"
    fi
else
    echo "✨ All data is fresh! No updates needed."
fi

echo ""
echo "📝 Next steps:"
echo "1. The compressed files are ready in assets/data/"
echo "2. They are already configured in pubspec.yaml"
echo "3. Build and test the app"