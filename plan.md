# Development tasks for the project

## drag and drop
- [x] when I drag and drop airspaces panel, it is chaning the size of the panel - keep it the same during dragging, panel should not change because we are moving it to different position. The same problem have maybe all dragable panel, review them and fix this.
- [x] in airspace detail panel I want to see also frequency information if provided by the airspace


## planning the flight
- [x] add toggle button to top panel with toggle buttons to show/hide planning panel
- [x] planning panel should be collapsable to one line
- [x] planning panel should be possible to drag and drop to different position
- [x] if no flight plan is loaded, and plan panel was loaded, create new plan and give it generic name, e.g. "Flight plan 1" - user should be able to change it when he clicks on the name of the plan in the flight panel
- [x] also when I am creating the flight plan from the main menu inside form flight plan, there is popup with dialog, where I should set Plan Name - set there a default value "Flight plan [random nr]" and user should be able to change it (it should be selected by default when I see the New Flight Plan dialog)
- [x] in the flight plan panel remove button "Hide" - it is useless, because we have toggle button in the top panel with toggle buttons and also whole planning panel has close button in the rigth top corner
- [x] remove also save button, it is not needed in the flight plan - implement autosave of the flight plan
- [x] remove "Clear" button, it is not needed in the flight plan panel
- [x] cruise speed and selected aircraft elements should be in the same line, not in two lines
- [x] adding points to the flight plan should be possible only in edit mode!
- [x] when in edit mode, all markers on the map should not show any information in popup dialogs, but should be added to the flight plan when I click on them
- [x] remove Load button from Flight Plan panel - it is not needed
- [x] new waypoints should be possible to add in the flight plan ONLY in edit mode, not in view mode !!! In Edit mode all markers like Airpotrs, Navigation Items, etc. should be clickable and added to the flight plan, in View mode they should behave like before, i.e. when I click on them, they should show popup dialog with information about the marker
- [x] in the flight planning pannel fix the design of Waypoints table - it should have design as the flight panel (dark background)
- [ ] it is possible to change the order of waypoints in the waypoints table with drag and drop, but don't make the whole row draggable, just the icon in the right side of the row should drag the row - it is not possible to scroll the table if whole part of the row is draggable
- [ ] move the information about number of waypoints and distance to the top of the flight panel, it should be in the same line as the flight plan name, if there is no space, hide number of points information
- [ ] heading information is missing in the flight plan panel in the waypoints table - maybe it is there, but not computed yet correctly
- [ ] when I hide flight plan panel, it should close the flight plan panel and also hide layer of flight plan on the map, so it should not be visible on the map


## toggle buttons
- [x] change icon of toggle button, which shows current airspaces - choose any nice icon, which will express, that user will see layers of airspaces


## notams
- [x] review formatting of notam messages, it looks incorrectly formated
- [ ] cache notams for all airports in the flight plan or airports in the current view, so when I click on the airport, I can see notams for that airport even if I am offline (cache should be valid minimum 6 hours before it is loaded again, server all other requests from cache only - just reload notam if user clicks on refresh button in NOTAMs view)


## Application startup
- [ ] application should start even without internet connection, it should not wait for syncing data from the servers, if there is not internet, app should use just the data already stored in caches
