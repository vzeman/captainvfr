# Development tasks for the project

## tasks

- [ ] QNH setting in the flight tracking mode
    - [ ] Add a field in flight tracking popup to set QNH
    - [ ] Initialize the QNH value from the current barometric pressure when the tracking starts
    - [ ] Use the QNH value to calculate the altitude in the flight tracking popup
- [ ] ETA calculation if flight tracking is running and the flight plan is selected in flight tracking panel
  - Add a value in flight tracking popup to show ETA of whole flight and to next waypoint
  - Calculate ETA based on the current position and speed of the aircraft


## Bugs
- [ ] web app crashes during loading of data on mobile devices (e.g. iphone), than restarts and than crashes again and shows error. Desktop version of chrome doesn't crash, it is working fine in normal desktop chrome.
    - mobile version of browsers always crashes, but desktop version of chrome works fine
    - how to debug javascript in mobile browsers?