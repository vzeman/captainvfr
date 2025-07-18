#!/bin/bash

# Build Flutter web app and commit to repository

echo "🌐 Building Flutter Web App for Hugo"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 successful${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

# Build Flutter web app
echo -e "${YELLOW}Building Flutter web app...${NC}"
flutter build web --release --base-href /app/
check_status "Flutter web build"

# Remove old web app from hugo/static/app
echo -e "${YELLOW}Removing old web app...${NC}"
rm -rf hugo/static/app
mkdir -p hugo/static/app

# Copy new build to hugo/static/app
echo -e "${YELLOW}Copying web build to hugo/static/app...${NC}"
cp -r build/web/* hugo/static/app/
check_status "Web app copy"

# Show what's being added
echo -e "${YELLOW}Files to be committed:${NC}"
git status hugo/static/app/

echo ""
echo -e "${GREEN}✓ Web app built and copied to hugo/static/app/${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the web app locally: cd hugo && npm run dev"
echo "2. Commit changes: git add hugo/static/app/ && git commit -m 'Update web app'"
echo "3. Push to trigger Amplify build: git push"