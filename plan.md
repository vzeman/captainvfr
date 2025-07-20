# Development tasks for the project

## tasks

- [x] Airspaces at location popup panel 
    - change the design of the popup panel to match the design of current airspaces panel
    - highlight the airspace at the current altitude
    - make sure font size is correct for each size of display
- [x] Airspaces map layer
    - airspaces in other altitudes are not visible in the airspaces map layer properly - review if the transparency is set correctly ... borders of airspace should not be transparent (doesnt matter what altitude is current)
    - Fixed by removing altitude filtering in getAirspacesInBounds call
    - Borders are already fully opaque (alpha: 1.0) regardless of altitude
- [x] Fix focus loss in all text input forms
    - **ACTUAL ROOT CAUSE FOUND**: KeyboardListener in MapScreen was creating a FocusNode with `..requestFocus()` which was stealing focus from all text fields
    - Fixed by:
        - Removing the KeyboardListener that was stealing focus
        - Completely removed KeyboardListener since performance monitoring can be activated through settings
    - Cleaned up all debug logging and focus tracking code after fixing the issue
    - Removed all temporary fixes:
        - Deleted FocusManagerService
        - Deleted FocusAwareTextField widget
        - Deleted KeyboardAwareFocusField
        - Reverted all TextField/TextFormField widgets back to their original implementations
- [x] Fix barometer sensor exception
    - Added proper error handling for PlatformException with code 'UNAVAILABLE'
    - Falls back to simulated data when barometer sensor is not available on the device
