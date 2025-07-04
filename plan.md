# Development plan - next tasks for CaptainVFR mobile app


## Android 12 - problems
- [ ] on the real android device was not loading the app map or any other data, it is working in emulator - review why on android device was not internet working for this app, other apps were able to connect to internet
- [ ] For debugging reasons we can show the status of cache - number of entries in each cache type, when was last time refreshed
- [ ] move the data about cache to menu "offline", it should replace the menu entry offline maps, all offline data will be managed in the same screen
- [ ] move the option to refresh data from menu into offline menu, so user will be able to refresh data from the offline menu
- [ ] vibrations were not measured on the real device
- [ ] if application starts, make checks if internet is working for the app, if not, show warning to user that internet is not working and some features will not work

## Small changes
- [ ] Rename menu "Offline maps" to "Offline data"
- [ ] move functionality of menu "Refresh Data" to "Offline data" screen
- [ ] Show all offline data in "Offline data" screen with some statistics about number of entries in each cache type, when was last time refreshed

## Pilot licences changes
- [ ] should be possible to define also date from the past, not only from the future (also for expiration date)
- [ ] add field license number
- [ ] add option to add images to the license (e.g. I will take a photo of my license and add it to the app)