#!/bin/bash

# Auto-update script for aviation data
# This script is designed to be run periodically (e.g., via cron) to keep data fresh
# It runs quietly unless there are errors or updates
#
# Usage: ./scripts/auto_update_data.sh [--verbose]
# 
# Example cron entry (daily at 3 AM):
# 0 3 * * * cd /path/to/captainvfr && ./scripts/auto_update_data.sh >> logs/data_update.log 2>&1

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to project root
cd "$PROJECT_ROOT"

# Check for verbose flag
VERBOSE=false
if [ "$1" = "--verbose" ]; then
    VERBOSE=true
fi

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Only log if verbose or error
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        log "$1"
    fi
}

# Start update
log_verbose "Starting automatic data update check..."

# Run the download script (it will only download if needed)
OUTPUT=$(./scripts/download_all_data.sh 2>&1)
EXIT_CODE=$?

# Check if any updates were made
if echo "$OUTPUT" | grep -q "Data updates completed!"; then
    log "✅ Data was updated successfully"
    if [ "$VERBOSE" = true ]; then
        echo "$OUTPUT"
    else
        # Just show what was updated
        echo "$OUTPUT" | grep -E "(Updated|Compressed:)"
    fi
elif echo "$OUTPUT" | grep -q "All data is fresh!"; then
    log_verbose "✨ All data is fresh, no updates needed"
else
    # There was an error
    log "❌ Error during data update (exit code: $EXIT_CODE)"
    echo "$OUTPUT"
    exit $EXIT_CODE
fi

log_verbose "Auto-update check completed"