## 0.4.2
* Add `AndroidListeningMode` (`keyEvents` and `volumeEvents`), allowing devices like Meta Quest (Horizon OS) to capture volume buttons via system volume events when key events are intercepted by the OS compositor.
* Automatically revert volume changes on Android in `volumeEvents` mode when `showVolumeUI = false` to prevent volume drift.
* Android: recover the volume-button listener when window focus returns after the
  host replaced the window callback, so 2D panels on Meta Quest (Horizon OS) and
  Android XR keep receiving button events when focus moves between spaces.
* Meta Quest (Horizon OS): document that the Android implementation is used in
  a 2D panel, that volume-button events are best-effort because the OS owns the
  buttons and its volume overlay, and which manifest entries a Quest build needs.
* Example: declare supported Meta Quest devices, default panel size, and add Android listening mode selector.

## 0.4.1
* Android: keep listening across activity recreation, and make `isListening`
  reflect whether the window still delegates to the plugin, so a replaced
  callback is re-installed instead of silently going dead.

## 0.4.0
* Double and triple press support via `addButtonMultiPressedListener`, with a
  configurable `multiPressWindow` (default `300ms`).
* Add Linux support for volume button events (press, release, long-press, multi-press) on X11 and Wayland.
* Add opt-in `LinuxVolumeButtonSetup` helper for tablet and detachable devices.
* Android: re-install the volume-button listener after the activity is recreated
  for a configuration change, so volume keys keep working.

## 0.3.2
* Fix iOS builds using Swift Package Manager

## 0.3.1
* Add macOS SPM support

## 0.3.0
* Add long press support

## 0.2.0
* Bump flutter_volume_controller to 2.0

## 0.1.1

* Update readme APIs
* Add macOS App Store review notes to README.

## 0.1.0

* Initial release.
