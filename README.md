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

|                                     | Android | iOS | macOS | Windows | Linux |
| :---------------------------------- | :-----: | :-: | :---: | :-----: | :---: |
| addButtonPressedListener            |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| addButtonReleasedListener           |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| addButtonLongPressedListener        |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| addButtonLongPressReleasedListener  |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| addButtonMultiPressedListener       |   ✔️    | ⚠️  |  ✔️   |   ✔️    |  ❌   |
| showVolumeUI                        |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ❌   |
| getVolume                           |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ✔️   |
| setVolume                           |   ✔️    | ✔️  |  ✔️   |   ✔️    |  ✔️   |

Use `VolumeButtonListener.supportsVolumeButtonListener` to check whether volume button press and release events are available on the current platform (`false` on Linux and Web).

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
