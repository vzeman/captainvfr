# Development plan - next tasks for CaptainVFR mobile app

## Airspaces ✅ COMPLETED
- [x] there is service available defined by https://api.core.openaip.net/api/system/specs/v1/schema.json, implement it as source of the airspaces, cache information in the app as we cache other services (use just /airspaces api call)
- [x] show airspaces cache information in offline data form
- [x] airspaces should be visualized as next layer on the map, with ability to toggle it on/off
- [x] when airspace is selected in the map, show its name and type, and all other information available in the API
- [x] when tracking the flight, show the airspaces that are crossed by the flight path, show also airspace which is in the same altitude as we are flying close to the flight path (you know headings, and altitude, should be possible to predict what will be the next airspace crossed - compute time to next airspace and show it in the UI in flight data panel)
- [x] user should be able to enter his API key in offline data settings, so that the app can use it to fetch airspaces from the API
The API client has a unique API key that is required to authenticate your client application to OpenAIP. You can use a the API key on all public API endpoints. API keys don't expire unless they are deleted by the user. For your client to be recognized by the OpenAIP API, the API key must be sent with each request to the OpenAIP API either with the:
x-openaip-api-key header
- [x] download should start just if user entered the API key, otherwise it should not be downloaded, just inform user that he needs to enter the API key for airspaces to be downloaded (user can get his api key in https://www.openaip.net/)
- [x] in the flight data panel show current airspace and if I click on it, it will show me information about it (name, type, frequencies, etc.)
- [x] remove the airspace label from the map, it is overlapping the map and makes it very hard to read the map
- [x] if I click on the map, show me list of all airspaces that are in the clicked point, and show me their names, types, frequencies, etc. - it will show list of airspaces that are in the clicked point, and show me their names, types, frequencies, etc.
- [x] if I search and the position on the map is changed to the searched position, show me the airspaces that are in the searched position, airspaces are not updated, after I move the map, they are correctly visible. it should be updated also when I jump in the map to the new position with search
- [x] icao classes, type and activity in the detail of airspace are displayed as number, use the text instead of number, so that it is more readable for the user - search in the documentation of the api interpretation of the numbers
- [x] when I select point on the map and list of airspaces is displayed, sort them based on their altitude from the ground on top, highlight airspace where is my current altitude located


## Reporting points ✅ COMPLETED
- [x] there is service available defined by https://api.core.openaip.net/api/system/specs/v1/schema.json, implement it as source of the reporting points, cache information in the app as we cache other services (use just /reporting-points api call) - load all reporting points and cache foreever until user clicks refresh data in offline data form
- [x] show reporting points in the map, togle them on/off together with airspaces map layer
- [x] properly handle 429 errors and retry the request 1 minute later, try to load as much rows in the single request as possible if there is pagination
- [x] Error fetching reporting points from OpenAIP: type 'int' is not a subtype of type 'String?'
- [x] load much bigger area for reporting points, try to set the bounding box to the whole world, so that we have all reporting points available in the app
- [x] dont load reporting points if all reporting points for whole world are already loaded, just show them in the map from cache