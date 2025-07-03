# Development plan

## flight tracking tasks
- [x] before tracking will be started and no flight plan is loaded in the map, ask user about the aircraft he wants to use for the flight, if no aircraft is selected, tracking should work, we will just not know fuel consumption or similar values during the flight
- [x] if aircraft is selected from flight plan or manually before tracking started, we will be able to calculate total fuel consumption during current flight
- [x] lets integrate flight data panel with flight tracking, so user will be able to see the flight data panel during flight tracking, it will show current speed, altitude, distance from start point, estimated time of flight, fuel consumption, if flight plan was selected, it should show also distance and time to next waipoint
- [x] in flight data panel should be possible to start/pause/stop tracking, remove this button from top floating panel with action buttons
- [x] during flight tracking I should see my track on the map as the aircraft moves (history of path which was already flown), it should be possible to see the track on the map even if flight plan is not loaded, but in this case we will not know the distance and time to next waypoint
- [x] if flight plan is loaded, i want to see the current sugment we are flying selected, and also the next segment, so I will know where I am going to fly next - aircraft doesnt need to copy exactly the flight plan, but it should automatically detect segments based on the flight direction, so I will know where I am going to fly next

## aircraft settings
- [x] editing is accessible through main menu, there will be section "aircrafts" in the settings
- [x] part of aircraft settings is list of manufacturers and aircraft types, user will be able to add new manufacturer or aircraft type (if missing in the list of manufacturers or select existing), edit existing manufacturer, delete manufacturer, etc
- [x] aircraft type is assigned to the manufacturer, so user will be able to select manufacturer and then select aircraft type from the list of types for this manufacturer
- [x] User will be able to add new aircraft, edit existing aircraft, delete aircraft
- [x] aircraft will have name (can be call sign), type (single engine, multiengine), manufacturer, cruise speed, fuel consumption, maximum altitude, maximum climb rate, maximum descent rate, max takeoff weight, max landing weight, fuel capacity, and other parameters
- [x] in the detail of aircraft should be possible to see in "checklists" tab checklists assigned to this aircraft (manufacturer and type of aircraft will be used to filter checklists),
- [x] in the second tab should be possible to see all flights done in this aircraft
- [ ] user should be able to add photos to airplane, so he can see the photos in the detail of aircraft, it should be possible to add multiple photos, delete photos, etc
- [ ] user should be able to attach to aircraft documents and later view them in the aircraft detail, it should be possible to add multiple documents, delete documents, etc (example AFM of aircraft)

## Checklists Editing
- [x] User will be able to add new checklist, edit existing checklist, delete checklist
- [x] Checklist will have name, description, manufacturer (select from existing or add new) and type of aircraft (select from existing or add new), and list of items
- [x] Checklist items will have name, description (can contain images, text), target value, should be possible to add, remove, edit, move up and down in the list
- [x] table with checklists will have columns manufacturer, aircraft type, name of checklist, it should be possible to search checklists by name, manufacturer, aircraft type
- [x] in the table will be possible to start the checklist - view for checklist detail will be different as when editing checklist
- [ ] option to export and import checklists in JSON format, so user will be able to share checklists with other users and send it to other users, or import checklists from other users

## Checklist Usage
- [x] when checklist is opened, it should be in popup window, it should be possible to close it, percentage of done items should be visible (progressbar), name of checklist should be visible, name of aircraft should be visible, description of the checklist should be visible on top of the panel
- [ ] when flight plan is loaded and aircraft is selected, user will be able to select checklist for the aircraft
- [x] user can start checklist also from table of all checklists
- [x] first not done item in the checklist is opened (description of the item is visible, target value is visible, user can mark it as done)
- [x] user can mark item as done, it will be marked as done in the checklist, and next item will be opened
- [x] done item has green check mark, not done item has gray box (not checked yet)

## Flight planning feature
- [x] User will be able to select on the map points where he wants to fly, these points will form segments of flight stored in the flight plan 
- [x] it will be possible to select points by clicking on the map and define altitude pilot wants to fly at specific point, 
- [x] it should be possible to delete points by clicking on them and confirming deletition
- [x] if aircraft is selected, we will know average speed of aircraft, so we will be able to calculate time of flight
- [x] during planning, we should show on the map estimated time of flight for segment, distance of each segment, heading of the segment, and total time and distance of flight
- [x] under the map should be visible panel with the altitude and changes of altitude during whole flight, it should be possible to change altitude of each point by clicking on it and changing altitude in the panel
- [x] there should be button to start new flight plan
- [x] in main menu should be option to see list of all flight plans
- [x] user should be able to store fligh plan to the list of flight plans, delete flight plan from the list, edit flight plan, duplicate flight plan, and load flight to the map
- [x] flight plan should have name, contiains information about aircraft, which will be used in the flight.
- [ ] in the flight plan should be possible to choose aircraft, aircraft can be changed during flight tracking (before starting flight tracking, or during flight tracking), but this information will be used as default from flight plan in flight tracking panel
- [ ] flight plan panel should contain collapsable list of all waypoints in current flight plan as table, where I will be able to edit name of waypoint and altitude, there will be also computed information about the distance from prev. waypoint, time to this waypoint, fuel consumption (if aircraft selected), 
- [ ] flight plan panel should have option to hide/show the flight plan from the map
- [ ] if I select waypoint in the flight plan, it should be highlighted in the table of waypoints of the flight plan (if the table with waypoints is expanded)
- [ ] drag and drop editing of waypoints in the flight plan, so user will be able to change order of waypoints by dragging them
- [ ] for selected waypoint should be possible to define the elevation, when I add new waypoint, it should copy previouse elevation, but user should be able to change it
- [ ] if aircraft is selected, we will be able to calculate fuel consumption for each segment and total fuel consumption for the flight plan
- [ ] if aircraft is selected, we will be able to calculate estimated time of flight for each segment and total time of flight for the flight plan
- [ ] if aircraft is selected, we will be able to calculate estimated distance for each segment and total distance for the flight plan
- [ ] if aircraft is selected, we will be able to calculate altitude changes based on the max climb rate and max descent rate of the aircraft
- [ ] if aircraft is selected, we will be able to cap maximum altitude based on the maximum altitude of the aircraft
- [ ] flight plan and flight recording should have option to select flight rules (VFR, IFR)
- [ ] if I load plan, I should see the plan panel always, it should be collapsable, but it should be always available if flight plan is loaded in the map (even it is not in edit mode)
- [ ] label on the segment should be displayed just in case rendered size of the segment line is 2 times bigger as the label size, so it will not overlap with the segment line

## pilot licenses and expirations of endorsements
Each pilot has list of licenses, where are defined validity of the license and endorsements, so user will be able to track expirations of licenses and endorsements
- [ ] user will be able to add new license, edit existing license, delete license
- [ ] license will have name, description, date of issue, date of expiration
- [ ] pilot will see warning if any license is expired, or will be expired in next 30 days, warning will not be visible during the flight tracking, just if tracking is not running
- [ ] it will be accessible from the main menu, there will be section "Licenses" in the settings


# General rules
ALWAYS check if code has no ERRORS, WARNINGS or RECOMMENDATIONS during building to keep the code clean and without issues
ALWAYS UPDATE plan.md if any task is finished (in this file)
ALWAYS REFACTOR classes and methods to keep the code clean and readable without duplicated code, split too long classes (more than 800 lines) into smaller classes
ALWAYS keep the code clean without test or helper files you create during development, remove them after you finish the task
