# Volume Button Listener

A Flutter plugin for hardware volume button events and system volume control on mobile and desktop.

Listen for volume **up** and **down** press and release events, optionally hide the native volume HUD, and read or set the current system volume level.

## Features

- Singleton API via `VolumeButtonListener.instance`
- Press and release callbacks for volume up and volume down
- Optional suppression of duplicate consecutive events
- Pause and resume listening without removing callbacks
- Control whether the native volume UI is shown
- Read and set system volume (`0.0`–`1.0`)

## Platform support

|                    | Android | iOS | macOS | Windows | Linux |
| :----------------- | :-----: | :-: | :---: | :-----: | :---: |
| volumeButtonEvents |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| getVolume          |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ✔️   |
| setVolume          |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ✔️   |

Use `VolumeButtonListener.supportsVolumeButtonListener` to check whether volume button events are available on the current platform (`false` on Linux and Web).

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
    // Volume up or down pressed
  }

  void onReleased(VolumeButtonDirection direction) {
    // Volume up or down released
  }

  await listener.addButtonPressedListener(onPressed);
  await listener.addButtonReleasedListener(onReleased);

  // Optional:
  await listener.pause();
  await listener.resume();
  final active = await listener.isListening;

  // Cleanup:
  await listener.removeButtonPressedListener(onPressed);
  await listener.removeButtonReleasedListener(onReleased);
}

// Available on all supported desktop/mobile platforms except Web:
final volume = await listener.getVolume();
await listener.setVolume(0.5);
```

## Lifecycle

1. No native button events are delivered until at least one callback is registered via `addButtonPressedListener` or `addButtonReleasedListener`.
2. Native listening starts automatically when the first callback is added.
3. `pause()` suspends forwarding; `resume()` re-enables it for already-registered callbacks.
4. Removing the last callback stops native listening and releases native resources.
5. On iOS, if volume is exactly `0.0` or `1.0` when listening starts, it is nudged slightly away from the bounds so subsequent button presses can be detected reliably.

## Platform notes

### iOS

No extra setup is required. The plugin works with both CocoaPods and Swift Package Manager.

### Linux

Volume button listening is not available. Use `getVolume()` and `setVolume()` for system volume control only. Guard listener registration with `VolumeButtonListener.supportsVolumeButtonListener`.

## Example

See the [example](example/) app for a runnable demo of listeners, volume read/write, and configuration options.
