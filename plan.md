# Development plan
- [x] Develop flight planning feature
- [ ] Develop settings section where will be possible to define airplanes pilot is using with all possible parameters about specific airplane, in the flight plan will be possible to select airplane in use
- [ ] Every fligh will use airplane information, user will be able to track based on it number of flights in each airplane, if it is single engine, multiengine flight, etc.
- [ ] Weight and balance calculation based on the airplane parameters, user will be able to define weight of pilot, passengers, baggage, fuel, etc. in the flight plan
- [ ] Checklists definition for each airplane, user will be able to define checklists for each airplane, and use them when flight plan is loaded and airplane is selected or choose them directly from menu

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
- [ ] drag and drop editing of waypoints in the flight plan, so user will be able to change order of waypoints by dragging them
- [ ] for selected waypoint should be possible to define the elevation, when I add new waypoint, it should copy previouse elevation, but user should be able to change it
- [ ] if airplane is selected, we will be able to calculate fuel consumption for each segment and total fuel consumption for the flight plan
- [ ] if airplane is selected, we will be able to calculate estimated time of flight for each segment and total time of flight for the flight plan
- [ ] if airplane is selected, we will be able to calculate estimated distance for each segment and total distance for the flight plan
- [ ] if airplane is selected, we will be able to calculate altitude changes based on the max climb rate and max descent rate of the airplane
- [ ] if airplane is selected, we will be able to cap maximum altitude based on the maximum altitude of the airplane
- [ ] flight plan and flight recording should have option to select flight rules (VFR, IFR)



## Airplane settings
- [ ] part of airplane settings is list of manufacturers, user will be able to add new manufacturer, edit existing manufacturer, delete manufacturer
- [ ] User will be able to add new airplane, edit existing airplane, delete airplane
- [ ] Airplane will have name, type (single engine, multiengine), manufacturer, cruise speed, fuel consumption, maximum altitude, maximum climb rate, maximum descent rate, max takeoff weight, max landing weight, fuel capacity, and other parameters
- [ ] airplane will have data used for calculation of center of gravity (CG)

## Checklists
- [ ] User will be able to add new checklist, edit existing checklist, delete checklist
- [ ] Checklist will have name, description, and list of items
- [ ] Checklist items will have name, description, target value and status (done, not done)
- [ ] should be possible to search checklists by name, manufacturer, airplane type, etc.

ALWAYS UPDATE plan.md if any task is finished (this file)