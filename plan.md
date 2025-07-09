# Development tasks for the project

## Current airspace panel
- [x] Add a button to close airspace panel in the riht top corner
- [x] add option to drag and drop the airspace panel to other position
- [x] add toggle button to show/hide the current airspace panel under airspaces toggle button
- [x] current airspace panel should show also distance and time to the end of airspace if there is no next airspace defined for current flight path

## internet connection
- [x] add a button to close notifications about internet connection in the right top corner
- [x] remove button TAP FOR INFO from the notification about internet connection, also remove the dialog which was shown after tapping the button
- [x] adjust the font size of the message based on the screen size

## Flight data panel
- [x] in the iphone make the flight data panel wider to use the full width of the screen - add just few pixels of padding, on bigger screens you can define maximum width how the panel will groiw
- [x] on bigger screens like ipad or any desktop, it should be possible to drag and drop the panel not just vertically but also horizontally
- [x] dynamically increase the size of fonts based on the size of the panel (defined by available space on the screen)

## Flight tracking
- [x] even I see in the flight data panel correct values of Gs, in the flight log detail I see just zeros in the tab with turbulence chart
- [x] during tracking record also vertical speed and show it in the same chart as the altitude tab in flight detail
- [x] during the tracking I don't see on the map line of the flight path, improve design of the flight path line on the map - make it a bit more wider, and better color
- [x] the speed in the flight detail is not correct - it is jumping often to zero even if my speed was constant ... speed shown in the flight data panel seems to be correct, just recorded speed in the flight log detail seems to be incorrect
- [x] altitude seems to be incorrect during tracking - it should show altitude abouve the sea level, not above the ground ... sometimes it shows even negative valus, what should not be possible
- [x] recorded altitude in flight log detail looks like sinusoid what is for sure not correct - review what could be wrong with the altitude recording
