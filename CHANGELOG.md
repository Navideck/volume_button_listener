## 0.4.1
* Add Linux support for volume button press/release/long-press/multi-press events with no end-user setup:
  * Non-Wayland X11 sessions use a global key grab (consumes the key)
  * Wayland sessions with a dedicated volume-key device use an exclusive `EVIOCGRAB`, suppressing the system volume change and OSD
    * Auto-repeat reported as repeated press/release pairs (for example the Intel HID 5-button array) is coalesced so long press is detected
  * Other sessions (for example GNOME Wayland) fall back to observing system volume changes
* Add opt-in `LinuxVolumeButtonSetup` helper that enables the `intel-hid` 5-button array (side volume buttons on some detachable tablets) and installs the input-device access rule via a single `pkexec` authentication prompt

## 0.4.0
* Add double and triple press support via `addButtonMultiPressedListener`
* Add configurable `multiPressWindow` (default `300ms`)

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
