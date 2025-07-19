# Development tasks for the project

## Completed tasks

- [x] Make loading indicator non-blocking and smaller panel
  - Changed from full-width bar to max 400px wide centered panel
  - Added rounded corners and improved styling
  - Positioned above map controls (bottom: 60) to avoid blocking zoom buttons
  - Loading continues in background even when panel is dismissed
  - User can close the panel with X button while loading continues

# Active tasks

## Completed tasks (continued)

- [x] Add Windows build support to the Flutter app
  - Enabled Windows desktop support in Flutter config
  - Added Windows platform to the project using flutter create
  - Updated build_release.sh script to include Windows build steps
  - Windows build creates a ZIP package in downloads folder
  - Added Git LFS tracking for *.zip files
  - Note: Windows builds must be done on a Windows machine with Flutter

## Completed tasks (continued)

- [x] Fix heliports not showing when toggle button is clicked
  - Found that type 7 airports (7,794 entries) were incorrectly mapped to 'small_airport' instead of 'heliport'
  - Fixed the type mapping in airport_service.dart getAirportType() method
  - This will now correctly display ~7,794 heliports that were being misclassified
  - Heliports and balloon ports share the same toggle button as intended

## Completed tasks (continued)

- [x] Fix location service to handle delayed permission approval
  - Added retry mechanism that checks for location permission every 3 seconds
  - Added location stream subscription for continuous updates once permission is granted
  - Changed error message to "waiting for permission" to be more informative
  - Properly clean up timer and subscription in dispose method
  - Location will automatically start working when user grants permission in Safari

## Completed tasks (continued)

- [x] Fix flutter.js.map 404 error in web application
  - Identified that source map reference was causing 404 error
  - Updated build_release.sh to automatically remove source map references
  - Removed source map reference from current flutter.js file
  - This eliminates the harmless but annoying 404 error in browser console

## Completed tasks (continued)

- [x] Add Git operations to build_release.sh script
  - Added Git LFS check to ensure it's installed
  - Set up automatic LFS tracking for *.apk, *.dmg, *.exe, *.msi files
  - Added automatic git add for build artifacts
  - Added automatic commit with descriptive message including build date
  - Added automatic push to remote repository
  - Script now handles the complete build and deployment workflow

## Completed tasks (continued)

- [x] download links are not working properly for MAC OS app - review why https://captainvfr.com/downloads/CaptainVFR.dmg returns small file and not the full app dmg file
  - Found that CaptainVFR.dmg was only 63MB (zlib compressed data) instead of proper 131MB DMG file
  - Replaced with proper DMG file from rw.3218.CaptainVFR.dmg
  - Ensured file is tracked by Git LFS
  - Cleaned up temporary files
  - Hugo build successful with proper DMG file