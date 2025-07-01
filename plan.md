# Development plan
- [x] Develop flight planning feature
- [ ] Develop settings section where will be possible to define airplanes pilot is using with all possible parameters about specific airplane, in the flight plan will be possible to select airplane in use
- [ ] Every fligh will use airplane information, user will be able to track based on it number of flights in each airplane, if it is single engine, multiengine flight, etc.


## Flight planning feature
- [x] User will be able to select on the map points where he wants to fly, these points will form segments of flight stored in the flight plan 
- [x] it will be possible to select points by clicking on the map and define altitude pilot wants to fly at specific point, 
- [x] it should be possible to delete points by clicking on them and confirming deletition
- [x] if airplane is selected, we will know average speed of airplane, so we will be able to calculate time of flight
- [x] during planning, we should show on the map estimated time of flight for segment, distance of each segment, heading of the segment, and total time and distance of flight
- [x] under the map should be visible panel with the altitude and changes of altitude during whole flight, it should be possible to change altitude of each point by clicking on it and changing altitude in the panel
- [x] there should be button to start new flight plan
- [x] in main menu should be option to see list of all flight plans
- [x] user should be able to store fligh plan to the list of flight plans, delete flight plan from the list, edit flight plan, duplicate flight plan, and load flight to the map
- [x] flight plan should have name, contiains information about airplane, which will be used in the flight.

### Implementation Details Completed:
- **FlightPlanService**: Enhanced with Hive storage for persistent flight plans
- **FlightPlansScreen**: Complete flight plan management interface
- **Map Integration**: Click to add waypoints, visual overlays with route lines and markers
- **Flight Plan Panel**: Save/load/clear functionality with confirmation dialogs
- **Altitude Profile Panel**: Visual representation of altitude changes (existing)
- **Waypoint Management**: Add, delete, reorder waypoints with distance/time calculations
- **Navigation**: Flight Plans accessible from main menu

ALWAYS UPDATE plan.md if any task is finished (this file)