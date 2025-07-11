# Development tasks for the project

## Tracking
- [x] line, which prints the path of the tracked flight should be more visible. Now it is behind the airspaces layer on the map and it is very hard to see it. Move it to the top layer so it is better visible, change the color to red


## Flight planning
- [x] When I want to scroll the waipoints in flight plan, it is moving the position of the panel instead. Movement of the panel should be done just if I drag and drop outside of the table with waypoints. Inside the table should be just scrolling the table rows.
- [x] when I collapse table with waypoints, it should not be expanded during drag and drop of the flight plan panel, it should keep the table of waipoints collapsed


## Airspaces
- [x] when I click toggle button to show current airspace, it takes very long time until the popup is displayed. Maybe it is waiting for current gps position. Maybe it independent. popup should be displayed rigth after clicking the button, not after the gps position is received. After you get gps position, simply just update the content of current airspace popup. Also when the popup is opened, load immediatelly last known gps position, later when you get new one, just update the values.