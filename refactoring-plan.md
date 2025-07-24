# Map Screen Refactoring Plan

## Overview
Refactoring the map_screen.dart file (4132 lines) into smaller, maintainable components.

## Progress

### Completed ✅
1. **Identified large classes** requiring refactoring:
   - map_screen.dart - 4132 lines
   - openaip_service.dart - 1577 lines  
   - offline_data_screen.dart - 1443 lines
   - flight_service.dart - 1180 lines
   - flight_dashboard.dart - 1122 lines
   - cache_service.dart - 1015 lines

2. **Created directory structure** for map components:
   - lib/screens/map/components/
   - lib/screens/map/controllers/
   - lib/screens/map/utils/
   - lib/screens/map/constants/
   - lib/screens/map/services/

3. **Extracted components**:
   - ✅ MapConstants - All constants and configuration values
   - ✅ SegmentUtils - Utility functions for segment colors/icons
   - ✅ PositionTrackingButton - GPS tracking button widget
   - ✅ LayerToggleButton - Individual layer toggle button
   - ✅ MapControlsPanel - Main control panel with all layer toggles
   - ✅ MapStateController - State management for map features
   - ✅ MapUtils - Utility functions for map calculations
   - ✅ MapDialogs - Permission and error dialogs
   - ✅ MapLayersBuilder - Manages all map layers
   - ✅ MapDataLoader - Service for loading map data

### In Progress 🚧
- Refactoring main map_screen.dart to use extracted components
- Fixing import and dependency issues

### Planned 📋
1. **Complete map_screen.dart refactoring**:
   - Split remaining methods into appropriate components
   - Create separate files for:
     - Map event handlers (tap, drag, etc.)
     - Flight planning logic
     - Location management
     - Navigation drawer

2. **Extract additional widgets**:
   - CurrentPositionMarker
   - MapNavigationDrawer
   - FlightTrackingOverlay
   - WaypointDragHandler

3. **Create comprehensive tests** for all extracted components

4. **Update documentation** in hugo/content/en/ 

5. **Continue with other large files**:
   - openaip_service.dart
   - offline_data_screen.dart
   - flight_service.dart
   - flight_dashboard.dart
   - cache_service.dart

## Architecture Overview

### Map Screen Structure
```
map_screen.dart
├── MapStateController (state management)
├── MapDataLoader (data loading service)
├── MapLayersBuilder (UI layers)
├── MapControlsPanel (UI controls)
├── MapUtils (utilities)
└── MapConstants (configuration)
```

### Benefits
1. **Separation of Concerns**: Each component has a single responsibility
2. **Reusability**: Components can be used elsewhere
3. **Testability**: Smaller units are easier to test
4. **Maintainability**: Easier to understand and modify
5. **Performance**: Better code organization can lead to optimizations

## Challenges
1. **Complex dependencies**: The map screen has many interconnected services
2. **State management**: Need to carefully manage state across components
3. **Testing**: Need to ensure refactoring doesn't break functionality
4. **Migration**: Need to gradually migrate to new structure

## Next Steps
1. Fix current compilation errors in extracted components
2. Create a minimal working version of refactored map_screen
3. Gradually migrate functionality piece by piece
4. Run comprehensive tests after each migration step
5. Update documentation