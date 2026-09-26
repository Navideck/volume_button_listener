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
