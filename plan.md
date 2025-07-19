# Development tasks for the project

## Completed tasks (January 2025)

- [x] loading indicator of airports or other types of data is now on top of the app, move it to the bottom of the app, because now it is overlapping  the main menu
  - Moved LoadingProgressBar from top: 0 to bottom: 0 in map_screen.dart
  - Updated SafeArea from bottom: false to top: false in loading_progress_bar.dart
  - Adjusted shadow offset from (0, 2) to (0, -2) for proper bottom positioning

- [x] add to the app main menu link to the homepage of the project www.captainvfr.com (Visit www.captainvfr.com) ... it can be behind the Settings menu entry
  - Added url_launcher import to map_screen.dart
  - Added new PopupMenuItem with 'website' value after Settings menu
  - Added PopupMenuDivider before the website link for visual separation
  - Implemented launchUrl handler to open https://www.captainvfr.com
  - Updated download.md page with recent updates section