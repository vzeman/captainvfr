# Development tasks for the project

## Bugs
- [x] heading information is incorrect and is not reporting in the Flight data panel at all, use all sensors, which devices like iphone offer to track correct heading of airplain. If no sensor is available, use computed heading (averaged from previous positions)
- [x] when I click on the button to update my current position in the top menu panel, it takes very long time until the map is updated - review if there is any option to optimize the speed (e.g .dont wait for measurement of current GPS position, but use last known position and quickly update the map)
- [x] when I start tracking, there is duplicate Flioght data panel - starting of tracking should not show next same panel - Flight data panel is showed/hided by toggle button, it is correct solution, start tracking button should not show it again
- [x] during the flight tracking is not updated on the current position on the map - we should update the position as the airplain is moving
- [x] change icon of current position from blue dot to airplane icon
- [x] display should never switch off on the device when the tracking is active - if the tracking is not activated, display can be locked if device is set so.
- [x] tracking should continue properly also if the application is on the background - if the application is in the background, tracking should continue and update the position on the map
- [x] design of multiple forms is not nice, we should use same design for all popups and dialogs. Nice design has flight data panel, use the same design for all types of dialogs, popups and forms (dark background, rounded corners, white text, etc.)
- [x] when I load detail of flight log, map is not loaded properly, I need to move with map to see it properly - looks like map is not initialized properly when the flight log detail loaded, it refresh properly with first move of map
- [x] vertical speed in the flight data panel is not working properly, it is not showing correct values
- [x] show in the flight panel data also how many Gs are applied to the airplane, we should record in the flight log changes of Gs during the flight and visualize it in the same chart as Turbulences bar (rename vibrations to turbulences tab in flight log detail), we should use accelerometer data to calculate Gs
- [x] in the flight data panel show also barometric pressure, it should be updated during the flight tracking


## New features
- [x] Visualisation of heading in the flight data panel - create a small compass in the flight data panel, which will show the heading of the airplane (in the middle count be current heading as number, but same will be show as line in the compass circle), it should be updated during the flight tracking, if flight plan is activated, one more value of heading should be displayed for current segment of flight we are flying from flight plan


## Settings Dialog
- [x] add Settings dialog to the application, which will allow to set some options
- [x] add option if map during tracking should be turned to the North or Heading of the airplane, during flight tracking we should use Heading of the airplane, if not tracking, we can use North
- 