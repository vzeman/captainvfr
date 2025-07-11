# Development tasks for the project

## Application startup
- [x] application should start even without internet connection, it should not wait for syncing data from the servers, if there is not internet, app should use just the data already stored in caches


## Flight planning
- [x] waypoint values in the table of waypoints shuld user units defined in Settings (Metric or Imperial) based on the user's settings
- [x] waypoints table row should be formatted in 2 rows, first row should contain the waypoint name and altitude, second row should contain all computed values (distance, speed, time, fuel) in the same row (if fuel or speed is not possible to compute, simply don't show anything)
- [x] label of the segment rendered on the map should be smaller, it should change the size of the label based on the text in the label - there should be no empty lines as it is now (render just value distance, heading and time if available aircraft settings)

## NOTAMs
- [x] as I move on the map, a lot of requests are mode to NOTAM service, this is not good, we should limit the number of requests to the NOTAM service, we should request all notams at once for area we need (if it is possible) - analyze first if notam service supports this before you start implementation
