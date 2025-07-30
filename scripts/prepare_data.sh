#!/bin/bash

# Script to prepare all aviation data for the app
# This downloads, converts, splits, and compresses all data

set -e  # Exit on error

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}🚀 Captain VFR Data Preparation Script${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""

# Check if .env exists and load it
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo -e "${GREEN}✅ Loaded environment variables from .env${NC}"
else
    echo -e "${YELLOW}⚠️  No .env file found${NC}"
fi

# Check if API key is provided
if [ -z "$OPENAIP_API_KEY" ] && [ -z "$1" ]; then
    echo -e "${RED}❌ Error: OpenAIP API key is required!${NC}"
    echo ""
    echo "Usage:"
    echo "  ./scripts/prepare_data.sh YOUR_API_KEY"
    echo "  or"
    echo "  Set OPENAIP_API_KEY in .env file"
    exit 1
fi

# Use provided API key or environment variable
API_KEY="${1:-$OPENAIP_API_KEY}"

echo -e "${BLUE}📍 Using API key: ${API_KEY:0:4}... (${#API_KEY} chars)${NC}"
echo ""

# Function to update all data
update_all() {
    echo -e "\n${CYAN}🔄 Updating all data...${NC}\n"
    
    echo -e "${BLUE}🔄 Starting OpenAIP data preparation...${NC}"
    echo -e "${BLUE}   This includes: airports, airspaces, navaids, reporting points, obstacles, hotspots${NC}"
    dart scripts/prepare_all_data.dart --api-key "$API_KEY"
    
    echo -e "\n${BLUE}🔄 Starting OurAirports data preparation...${NC}"
    echo -e "${BLUE}   This includes: runways, frequencies${NC}"
    dart scripts/prepare_ourairports_data.dart
    
    # Check if the new OpenAIP scripts exist and run them
    if [ -f "scripts/generate_openaip_runway_tiles_v3.dart" ]; then
        echo -e "\n${BLUE}🔄 Starting OpenAIP runway data preparation...${NC}"
        OPENAIP_API_KEY="$API_KEY" dart scripts/generate_openaip_runway_tiles_v3.dart --api-key "$API_KEY"
    elif [ -f "scripts/generate_openaip_runway_tiles_v2.dart" ]; then
        echo -e "\n${BLUE}🔄 Starting OpenAIP runway data preparation...${NC}"
        OPENAIP_API_KEY="$API_KEY" dart scripts/generate_openaip_runway_tiles_v2.dart --api-key "$API_KEY"
    fi
    
    if [ -f "scripts/generate_openaip_frequency_tiles.dart" ]; then
        echo -e "\n${BLUE}🔄 Starting OpenAIP frequency data preparation...${NC}"
        dart scripts/generate_openaip_frequency_tiles.dart
    fi
}

# Function to update OpenAIP data
update_openaip() {
    echo -e "\n${CYAN}🔄 Updating all OpenAIP data...${NC}\n"
    echo -e "${BLUE}   This includes: airports, airspaces, navaids, reporting points, obstacles, hotspots${NC}"
    dart scripts/prepare_all_data.dart --api-key "$API_KEY"
    
    # Check if the new OpenAIP scripts exist and run them
    if [ -f "scripts/generate_openaip_runway_tiles_v3.dart" ]; then
        echo -e "\n${BLUE}🔄 Also updating OpenAIP runway data...${NC}"
        OPENAIP_API_KEY="$API_KEY" dart scripts/generate_openaip_runway_tiles_v3.dart --api-key "$API_KEY"
    elif [ -f "scripts/generate_openaip_runway_tiles_v2.dart" ]; then
        echo -e "\n${BLUE}🔄 Also updating OpenAIP runway data...${NC}"
        OPENAIP_API_KEY="$API_KEY" dart scripts/generate_openaip_runway_tiles_v2.dart --api-key "$API_KEY"
    fi
    
    if [ -f "scripts/generate_openaip_frequency_tiles.dart" ]; then
        echo -e "\n${BLUE}🔄 Also updating OpenAIP frequency data...${NC}"
        dart scripts/generate_openaip_frequency_tiles.dart
    fi
}

# Function to update OurAirports data
update_ourairports() {
    echo -e "\n${CYAN}🔄 Updating all OurAirports data...${NC}\n"
    echo -e "${BLUE}   This includes: runways, frequencies${NC}"
    dart scripts/prepare_ourairports_data.dart
}

# Function to update OpenAIP runway data only
update_openaip_runways() {
    if [ -f "scripts/generate_openaip_runway_tiles_v3.dart" ]; then
        echo -e "\n${CYAN}🔄 Updating OpenAIP runway data...${NC}\n"
        OPENAIP_API_KEY="$API_KEY" dart scripts/generate_openaip_runway_tiles_v3.dart --api-key "$API_KEY"
    elif [ -f "scripts/generate_openaip_runway_tiles_v2.dart" ]; then
        echo -e "\n${CYAN}🔄 Updating OpenAIP runway data...${NC}\n"
        OPENAIP_API_KEY="$API_KEY" dart scripts/generate_openaip_runway_tiles_v2.dart --api-key "$API_KEY"
    else
        echo -e "\n${RED}❌ OpenAIP runway script not found${NC}"
        echo -e "${YELLOW}   OpenAIP runways are included in the general OpenAIP update${NC}"
    fi
}

# Function to update OpenAIP frequency data only
update_openaip_frequencies() {
    if [ -f "scripts/generate_openaip_frequency_tiles.dart" ]; then
        echo -e "\n${CYAN}🔄 Updating OpenAIP frequency data...${NC}\n"
        dart scripts/generate_openaip_frequency_tiles.dart
    else
        echo -e "\n${RED}❌ OpenAIP frequency script not found${NC}"
        echo -e "${YELLOW}   OpenAIP frequencies are included in the general OpenAIP update${NC}"
    fi
}

# Simple menu without arrow key navigation
echo -e "${BOLD}Select data to update:${NC}"
echo ""
echo -e "${YELLOW}ℹ️  Note:${NC}"
echo -e "   - OpenAIP data includes: airports, airspaces, navaids, reporting points, obstacles, hotspots"
echo -e "   - OurAirports data includes: runways, frequencies"
echo -e "   - Some data types may be available from both sources"
echo ""
echo -e "${GREEN}[1]${NC} Update All Data (OpenAIP + OurAirports)"
echo -e "${GREEN}[2]${NC} Update All OpenAIP Data"
echo -e "${GREEN}[3]${NC} Update All OurAirports Data"
echo -e "${GREEN}[4]${NC} Update OpenAIP Runways Only"
echo -e "${GREEN}[5]${NC} Update OpenAIP Frequencies Only"
echo -e "${GREEN}[6]${NC} Exit"
echo ""
echo -n -e "${YELLOW}Enter your choice (1-6): ${NC}"

read -r choice

case $choice in
    1)
        update_all
        ;;
    2)
        update_openaip
        ;;
    3)
        update_ourairports
        ;;
    4)
        update_openaip_runways
        ;;
    5)
        update_openaip_frequencies
        ;;
    6)
        echo -e "${YELLOW}👋 Exiting...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Please run the script again and select 1-6.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ Data preparation complete!${NC}"
echo ""
echo -e "${BLUE}📁 Data is ready in: assets/data/tiles/${NC}"

case $choice in
    1)
        echo "   - Updated all data from both OpenAIP and OurAirports"
        ;;
    2)
        echo "   - Updated all OpenAIP data"
        ;;
    3)
        echo "   - Updated all OurAirports data"
        ;;
    4)
        echo "   - Updated OpenAIP runway data"
        ;;
    5)
        echo "   - Updated OpenAIP frequency data"
        ;;
esac