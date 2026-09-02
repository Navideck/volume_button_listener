# Volume Button Listener

A Flutter plugin for hardware volume button events and system volume control on mobile and desktop.

Listen for volume **up** and **down** press and release events, optionally hide the native volume HUD, and read or set the current system volume level.

## Features

- Singleton API via `VolumeButtonListener.instance`
- Press, release, long press, and long press release callbacks for volume up and volume down
- Configurable global `longPressDuration` (default `500ms`) with smart short-press deferral
- Optional suppression of duplicate consecutive events
- Pause and resume listening without removing callbacks
- Control whether the native volume UI is shown
- Read and set system volume (`0.0`–`1.0`)

## Platform support

|                                     | Android | iOS | macOS | Windows | Linux |
| :---------------------------------- | :-----: | :-: | :---: | :-----: | :---: |
| addButtonPressedListener            |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| addButtonReleasedListener           |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| addButtonLongPressedListener        |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| addButtonLongPressReleasedListener  |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| showVolumeUI                        |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| getVolume                           |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ✔️   |
| setVolume                           |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ✔️   |

Use `VolumeButtonListener.supportsVolumeButtonListener` to check whether volume button press and release events are available on the current platform (`false` on Linux and Web).

### macOS App Store review

On macOS, button listening uses a Core Graphics event tap and requires Input Monitoring/Accessibility access. Apple may reject Mac App Store apps that use this access for non-accessibility features under App Review Guideline 2.4.5. Mac App Store apps should keep volume-button listening disabled by default and let users explicitly enable it, or omit the feature on macOS. Reading and setting system volume does not start the event tap.

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

  // Set long press threshold (defaults to 500ms):
  listener.longPressDuration = const Duration(milliseconds: 600);

  await listener.addButtonPressedListener(onPressed);
  await listener.addButtonReleasedListener(onReleased);
  await listener.addButtonLongPressedListener(onLongPressed);
  await listener.addButtonLongPressReleasedListener(onLongPressReleased);

  // Optional:
  await listener.pause();
  await listener.resume();
  final active = await listener.isListening;

  // Cleanup:
  await listener.removeButtonPressedListener(onPressed);
  await listener.removeButtonReleasedListener(onReleased);
  await listener.removeButtonLongPressedListener(onLongPressed);
  await listener.removeButtonLongPressReleasedListener(onLongPressReleased);
}

// Available on all supported desktop/mobile platforms except Web:
final volume = await listener.getVolume();
await listener.setVolume(0.5);
```

## Lifecycle

1. No native button events are delivered until at least one callback is registered via `addButtonPressedListener`, `addButtonReleasedListener`, `addButtonLongPressedListener`, or `addButtonLongPressReleasedListener`.
2. Native listening starts automatically when the first callback is added.
3. `pause()` suspends forwarding and cancels active timers; `resume()` re-enables it for already-registered callbacks.
4. Removing the last callback stops native listening and releases native resources.
5. On iOS, if volume is exactly `0.0` or `1.0` when listening starts, it is nudged slightly away from the bounds so subsequent button presses can be detected reliably.

## Example

See the [example](example/) app for a runnable demo of listeners, volume read/write, and configuration options.
