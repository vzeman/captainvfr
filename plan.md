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

- [x] download links are not working properly for MAC OS app - review why https://captainvfr.com/downloads/CaptainVFR.dmg returns small file and not the full app dmg file
  - Found that CaptainVFR.dmg was only 63MB (zlib compressed data) instead of proper 131MB DMG file
  - Replaced with proper DMG file from rw.3218.CaptainVFR.dmg
  - Ensured file is tracked by Git LFS
  - Cleaned up temporary files
  - Hugo build successful with proper DMG file