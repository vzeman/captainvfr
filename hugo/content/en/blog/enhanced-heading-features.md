---
title: "Enhanced Heading & Navigation Features"
date: 2025-08-03T12:00:00Z
author: "CaptainVFR Team"
tags: ["updates", "features", "navigation", "compass"]
categories: ["App Updates"]
description: "Major improvements to heading display, compass functionality, and map rotation modes for better situational awareness during flight"
image: "/images/blog/compass-update.jpg"
draft: false
---

We're excited to announce significant enhancements to CaptainVFR's navigation and heading features, making your flight experience more intuitive and reliable than ever before.

## What's New

### 🧭 Always-On Compass Heading

The compass now works continuously, even when you're not actively tracking a flight. This means you can:
- Check your heading at any time
- Use the app as a backup compass
- Get immediate orientation information when planning flights

### 🗺️ Dual Map Rotation Modes

Choose how you want to view your flight path with two distinct modes:

**1. Map Rotates (North-Up)**
- Map stays oriented with North at the top
- Your aircraft icon rotates to show heading
- Perfect for maintaining geographic awareness

**2. Aircraft Icon Rotates (Track-Up)**
- Map rotates to match your heading
- Aircraft icon always points up
- Ideal for following your route intuitively

Access this setting in **Settings → Map Settings → Map Rotation Mode**.

### 📱 Improved iOS Compatibility

We've resolved several iOS-specific issues:
- **Fixed permission detection** - The app now correctly handles location permissions for compass access
- **Better permission prompts** - Non-intrusive notifications guide you through enabling required permissions
- **Automatic recovery** - If permissions are granted while the app is running, features activate immediately

### ⚡ Performance Enhancements

- **Smart retry mechanism** - Compass initialization uses exponential backoff to conserve battery
- **Optimized updates** - Heading updates are throttled to 2Hz for smooth display without draining resources
- **Cleaner codebase** - Removed unnecessary debug messages for better performance

## Technical Improvements

### Enhanced Flight Dashboard
The flight tracking panel now displays:
- Real-time heading even when not tracking
- Improved layout with better information density
- Responsive design that adapts to different screen sizes

### Robust Error Handling
- Graceful degradation when sensors are unavailable
- Clear user feedback for permission issues
- Automatic recovery from temporary failures

### Apple Watch Integration
For pilots with Apple Watch:
- Real-time flight telemetry on your wrist
- Start/stop tracking from your watch
- Monitor altitude, speed, and heading without reaching for your phone

## Known Issues & Workarounds

### iOS Simulator
The compass doesn't work in the iOS Simulator. Always test heading features on a real device.

### Permission Caching
On iOS, if you've previously denied location permission, you may need to:
1. Go to Settings → Privacy & Security → Location Services
2. Find CaptainVFR and set to "While Using App" or "Always"
3. Return to the app - heading should now work

## Coming Soon

We're continuously improving CaptainVFR based on your feedback. Upcoming features include:
- Compass calibration interface
- Magnetic variation corrections
- Enhanced track recording with heading data
- Wind calculation based on heading and GPS track

## Feedback

Your input helps us build better features. If you experience any issues with the new heading functionality or have suggestions for improvements, please [contact us](/contact) or report issues on our [GitHub repository](https://github.com/QualityUnit/captainvfr/issues).

Thank you for flying with CaptainVFR! ✈️

---

*This update is available now in version 1.5.0 on iOS and Android. Update your app to access these new features.*