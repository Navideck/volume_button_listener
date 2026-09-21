# Volume Button Listener

A Flutter plugin for hardware volume button events and system volume control on mobile and desktop.

Listen for volume **up** and **down** press and release events, optionally hide the native volume HUD, and read or set the current system volume level.

## Features

- Singleton API via `VolumeButtonListener.instance`
- Press, release, long press, and long press release callbacks for volume up and volume down
- Double and triple press callbacks with a configurable global `multiPressWindow` (default `300ms`)
- Configurable global `longPressDuration` (default `500ms`) with smart short-press deferral
- Optional suppression of duplicate consecutive events
- Pause and resume listening without removing callbacks
- Control whether the native volume UI is shown
- Read and set system volume (`0.0`–`1.0`)

## Platform support

Legend: ✔️ supported · ⚠️ supported with caveats · ❌ not supported.

|                                     | Android | iOS | macOS | Windows |   Linux    | Web |
| :---------------------------------- | :-----: | :-: | :---: | :-----: | :--------: | :-: |
| addButtonPressedListener            |   ✔️    | ✔️  |  ✔️   |   ✔️    |     ⚠️     | ❌  |
| addButtonReleasedListener           |   ✔️    | ✔️  |  ✔️   |   ✔️    |     ⚠️     | ❌  |
| addButtonLongPressedListener        |   ✔️    | ✔️  |  ✔️   |   ✔️    |     ⚠️     | ❌  |
| addButtonLongPressReleasedListener  |   ✔️    | ✔️  |  ✔️   |   ✔️    |     ⚠️     | ❌  |
| addButtonMultiPressedListener       |   ✔️    | ⚠️  |  ✔️   |   ✔️    |     ⚠️     | ❌  |
| showVolumeUI                        |   ✔️    | ✔️  |  ✔️   |   ✔️    |     ⚠️     | ❌  |
| getVolume                           |   ✔️    | ✔️  |  ✔️   |   ✔️    |     ✔️     | ❌  |
| setVolume                           |   ✔️    | ✔️  |  ✔️   |   ✔️    |     ✔️     | ❌  |

- **Android** button events are only delivered while the app has a focused activity (the plugin throws if there is none), so listening does not work in the background.
- **iOS** multi-press is best-effort (see the iOS caveat below).
- **Linux** button capture depends on the session (see the Linux caveat below); `getVolume`/`setVolume` use ALSA through `flutter_volume_controller`.

Use `VolumeButtonListener.supportsVolumeButtonListener` to check whether volume button press and release events are available on the current platform (`false` on Web).

### Multi-press behavior

- `addButtonMultiPressedListener` receives `count == 2` for a double press and `count == 3` for a triple press. Consecutive presses must be the same direction; four or more rapid presses are ignored until the window resets.
- `multiPressWindow` is the maximum gap between consecutive press-downs that still counts as part of one sequence.
- When a multi-press is recognized, the individual `pressed`/`released` events for that sequence are suppressed and the callback fires once the window closes.
- When long-press listeners are also registered, a multi-press is finalized on the last short release. Holding the last press past `longPressDuration` triggers a long press instead.
- Registering a multi-press listener defers single-press events by up to `multiPressWindow` so a following press can be detected.

### iOS caveat

iOS is treated as a best-effort target for multi-press. The native layer reports presses through volume-change notifications rather than discrete key events, and the default `suppressRepeatedPressEvents = true` can hide the rapid repeats needed to detect a multi-press. If detection is unreliable on iOS, set `suppressRepeatedPressEvents = false`.

### macOS App Store review

On macOS, button listening uses a Core Graphics event tap and requires Input Monitoring/Accessibility access. Apple may reject Mac App Store apps that use this access for non-accessibility features under App Review Guideline 2.4.5. Mac App Store apps should keep volume-button listening disabled by default and let users explicitly enable it, or omit the feature on macOS. Reading and setting system volume does not start the event tap.

### Linux caveat

The plugin picks a backend automatically:

- **Non-Wayland X11**: captures the `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` media keys with a passive keyboard grab. No extra permissions are required, but the grabbed key is consumed, so it no longer changes the volume or shows the volume HUD. Set `showVolumeUI = true` to have the plugin emulate the volume change itself (the native HUD still cannot be shown); with the default `showVolumeUI = false`, call `setVolume` yourself if needed.
- **Wayland, with a dedicated volume-key device**: grabs that input device exclusively (`EVIOCGRAB`), so the compositor never sees the key and the system volume change (and its OSD) is suppressed. This yields true press/release events and works on any compositor. Some devices (for example the Intel HID 5-button array) report auto-repeat as fresh press/release pairs every ~150 ms instead of `value == 2`; these are coalesced so holding the key still produces a single long press. It requires the input device to be accessible to the session, which the setup helper below arranges with a narrowly scoped udev rule (non-keyboard key devices only).
- **Otherwise**: falls back to observing system volume changes. This is best-effort: the desktop handles the key as usual, so the volume UI cannot be suppressed, no event is produced when the volume is already at `0.0` or `1.0`, and long-press/multi-press are approximate. Only the change in volume is used, so a change made by another application is also reported.

Additional notes:

- **Build dependency.** Linking against X11 (`libx11-dev` on Debian/Ubuntu) is required.
- **Grab conflicts (X11).** If another application or the desktop environment already grabs the volume keys, the X11 grab fails and the plugin falls back to the exclusive device grab, then to observing volume changes.
- **Detachable tablets (for example the HP Elite x2 1012 G2).** On some 2-in-1 tablets the side volume buttons are handled by the `intel-hid` 5-button array, which the kernel only enables for a DMI allowlist of models. If the hardware buttons do nothing system-wide (no volume change and no OSD), the opt-in `LinuxVolumeButtonSetup` API sets this up for the user: it writes the `intel-hid` option and installs the input-device access rule, then reloads the module and udev. It requires administrator rights, so it shows a single polkit authentication prompt via `pkexec`. It is a one-time setup: `setUp()` returns immediately without prompting once the system is ready, so it is safe to call on every launch. Call it in response to an explicit user action the first time.

  ```dart
  if (LinuxVolumeButtonSetup.status() ==
      LinuxVolumeButtonSetupStatus.needsSetup) {
    final ready = await LinuxVolumeButtonSetup.setUp();
    if (ready) {
      // Restart listening so the exclusive-grab backend is picked up.
      await VolumeButtonListener.instance.pause();
      await VolumeButtonListener.instance.resume();
    }
  }
  ```

  Equivalently, from a terminal:

  ```sh
  echo "options intel_hid enable_5_button_array=1" | sudo tee /etc/modprobe.d/intel-hid.conf
  echo 'SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEY}=="1", ENV{ID_INPUT_KEYBOARD}!="1", TAG+="uaccess"' \
    | sudo tee /etc/udev/rules.d/60-volume-button-listener.rules
  sudo modprobe -r intel_hid && sudo modprobe intel_hid
  sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=input
  ```

  Please also report the model to `platform-driver-x86@vger.kernel.org` so it can be added to the allowlist. This is a kernel driver limitation, not a plugin one.

Reading and setting system volume uses ALSA through `flutter_volume_controller` and works on both X11 and Wayland.

## Installation

Add `volume_button_listener` to your `pubspec.yaml`:

```yaml
dependencies:
  volume_button_listener:
```

## Quick start

```dart
import 'package:volume_button_listener/volume_button_listener.dart';

final listener = VolumeButtonListener.instance;

if (VolumeButtonListener.supportsVolumeButtonListener) {
  listener.showVolumeUI = false;
  listener.suppressRepeatedPressEvents = true;

  void onPressed(VolumeButtonDirection direction) {
    // Volume up or down pressed (or short pressed if long press listeners are active)
  }

  void onReleased(VolumeButtonDirection direction) {
    // Volume up or down released
  }

  void onLongPressed(VolumeButtonDirection direction) {
    // Volume up or down long pressed
  }

  void onLongPressReleased(VolumeButtonDirection direction) {
    // Volume up or down released after a long press
  }

  void onMultiPressed(VolumeButtonDirection direction, int count) {
    // Volume up or down pressed twice (count == 2) or three times (count == 3)
    // in quick succession. Individual press/release events are suppressed for a
    // recognized multi-press.
  }

  // Set long press threshold (defaults to 500ms):
  listener.longPressDuration = const Duration(milliseconds: 600);

  // Set the maximum gap between presses that still counts as one multi-press
  // (defaults to 300ms):
  listener.multiPressWindow = const Duration(milliseconds: 250);

  await listener.addButtonPressedListener(onPressed);
  await listener.addButtonReleasedListener(onReleased);
  await listener.addButtonLongPressedListener(onLongPressed);
  await listener.addButtonLongPressReleasedListener(onLongPressReleased);
  await listener.addButtonMultiPressedListener(onMultiPressed);

  // Optional:
  await listener.pause();
  await listener.resume();
  final active = await listener.isListening;

  // Cleanup:
  await listener.removeButtonPressedListener(onPressed);
  await listener.removeButtonReleasedListener(onReleased);
  await listener.removeButtonLongPressedListener(onLongPressed);
  await listener.removeButtonLongPressReleasedListener(onLongPressReleased);
  await listener.removeButtonMultiPressedListener(onMultiPressed);
}

// Available on all supported desktop/mobile platforms except Web:
final volume = await listener.getVolume();
await listener.setVolume(0.5);
```

## Lifecycle

1. No native button events are delivered until at least one callback is registered via `addButtonPressedListener`, `addButtonReleasedListener`, `addButtonLongPressedListener`, `addButtonLongPressReleasedListener`, or `addButtonMultiPressedListener`.
2. Native listening starts automatically when the first callback is added.
3. `pause()` suspends forwarding and cancels active timers; `resume()` re-enables it for already-registered callbacks.
4. Removing the last callback stops native listening and releases native resources.
5. On iOS, if volume is exactly `0.0` or `1.0` when listening starts, it is nudged slightly away from the bounds so subsequent button presses can be detected reliably.

## Example

See the [example](example/) app for a runnable demo of listeners, volume read/write, and configuration options.
