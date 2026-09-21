/// A Flutter plugin for listening to hardware volume button events
/// and controlling system volume across supported platforms.
library;

import 'dart:async';

import 'package:async_queue/async_queue.dart';
import 'package:flutter/foundation.dart';
import 'package:volume_button_listener/src/volume_button_listener.dart';
import 'package:volume_button_listener/src/volume_button_listener_interface.dart';
import 'package:volume_button_listener/src/volume_button_listener_linux.dart';
import 'package:volume_button_listener/src/volume_button_notifier.dart';
export 'package:volume_button_listener/src/linux_volume_button_setup_stub.dart'
    if (dart.library.io)
        'package:volume_button_listener/src/linux_volume_button_setup.dart';
export 'package:volume_button_listener/src/volume_button_direction.dart';
export 'package:volume_button_listener/src/volume_button_notifier.dart'
    show VolumeButtonListenerCallback, VolumeButtonMultiPressCallback;

/// A singleton manager for listening to hardware volume button events
/// and controlling system volume.
class VolumeButtonListener {
  static VolumeButtonListener? _instance;

  /// The singleton instance of [VolumeButtonListener].
  static VolumeButtonListener get instance =>
      _instance ??= VolumeButtonListener._();
  VolumeButtonListener._();

  final VolumeButtonListenerInterface _platform = _getPlatform();

  /// Whether hardware volume button listening is supported on the current platform.
  ///
  /// On Linux this is always `true`: X11 sessions use a global key grab,
  /// Wayland sessions grab a dedicated volume device (or fall back to observing
  /// system volume changes). None of these require extra permissions or setup.
  static bool supportsVolumeButtonListener = !kIsWeb;

  bool _isPaused = false;
  final _syncQueue = AsyncQueue.autoStart(allowDuplicate: true);

  /// Whether the native volume button listener is currently active.
  Future<bool> get isListening => _platform.isListening();

  /// Sets whether the system volume UI/HUD is displayed when volume buttons are pressed.
  set showVolumeUI(bool value) => unawaited(_platform.setShowVolumeUi(value));

  /// Sets whether repeated press events caused by holding a button down should be suppressed.
  set suppressRepeatedPressEvents(bool value) =>
      _platform.setSuppressRepeatedPressEvents(value);

  /// The minimum duration a volume button must be held down to trigger a long-press event.
  Duration get longPressDuration => _platform.longPressDuration;

  /// Sets the minimum duration a volume button must be held down to trigger a long-press event.
  set longPressDuration(Duration value) => _platform.longPressDuration = value;

  /// The maximum gap between consecutive press-downs for them to count as a
  /// single double or triple press.
  Duration get multiPressWindow => _platform.multiPressWindow;

  /// Sets the maximum gap between consecutive press-downs for them to count as
  /// a single double or triple press.
  set multiPressWindow(Duration value) => _platform.multiPressWindow = value;

  /// Gets the current system volume level between `0.0` and `1.0`.
  Future<double> getVolume() => _platform.getVolume();

  /// Sets the system volume level, clamped between `0.0` and `1.0`.
  Future<void> setVolume(double volume) => _platform.setVolume(volume);

  /// Adds a [callback] that is invoked when a volume button is pressed down.
  Future<void> addButtonPressedListener(
    VolumeButtonListenerCallback callback,
  ) => _addListener(_platform.buttonPressedNotifier, callback);

  /// Removes a previously registered button-pressed [callback].
  Future<void> removeButtonPressedListener(
    VolumeButtonListenerCallback callback,
  ) => _removeListener(_platform.buttonPressedNotifier, callback);

  /// Adds a [callback] that is invoked when a volume button is released.
  Future<void> addButtonReleasedListener(
    VolumeButtonListenerCallback callback,
  ) => _addListener(_platform.buttonReleasedNotifier, callback);

  /// Removes a previously registered button-released [callback].
  Future<void> removeButtonReleasedListener(
    VolumeButtonListenerCallback callback,
  ) => _removeListener(_platform.buttonReleasedNotifier, callback);

  /// Adds a [callback] that is invoked when a volume button is held down for [longPressDuration].
  Future<void> addButtonLongPressedListener(
    VolumeButtonListenerCallback callback,
  ) => _addListener(_platform.buttonLongPressedNotifier, callback);

  /// Removes a previously registered button long-pressed [callback].
  Future<void> removeButtonLongPressedListener(
    VolumeButtonListenerCallback callback,
  ) => _removeListener(_platform.buttonLongPressedNotifier, callback);

  /// Adds a [callback] that is invoked when a volume button is released after a long-press event.
  Future<void> addButtonLongPressReleasedListener(
    VolumeButtonListenerCallback callback,
  ) => _addListener(_platform.buttonLongPressReleasedNotifier, callback);

  /// Removes a previously registered button long-press released [callback].
  Future<void> removeButtonLongPressReleasedListener(
    VolumeButtonListenerCallback callback,
  ) => _removeListener(_platform.buttonLongPressReleasedNotifier, callback);

  /// Adds a [callback] that is invoked when a volume button is pressed twice or
  /// three times in quick succession. The callback receives the pressed
  /// direction and the number of presses (`2` or `3`).
  Future<void> addButtonMultiPressedListener(
    VolumeButtonMultiPressCallback callback,
  ) => _addListener(_platform.buttonMultiPressedNotifier, callback);

  /// Removes a previously registered multi-pressed [callback].
  Future<void> removeButtonMultiPressedListener(
    VolumeButtonMultiPressCallback callback,
  ) => _removeListener(_platform.buttonMultiPressedNotifier, callback);

  /// Temporarily pauses volume button listening and cancels active timers without removing listeners.
  Future<void> pause() async {
    _isPaused = true;
    _platform.cancelLongPressTimers();
    await _syncNativeListenerState();
  }

  /// Resumes volume button listening after being paused.
  Future<void> resume() async {
    _isPaused = false;
    await _syncNativeListenerState();
  }

  Future<void> _addListener<T>(
    VolumeButtonNotifierBase<T> notifier,
    T callback,
  ) async {
    if (!notifier.addListener(callback)) return;
    await _syncNativeListenerState();
  }

  Future<void> _removeListener<T>(
    VolumeButtonNotifierBase<T> notifier,
    T callback,
  ) async {
    if (!notifier.removeListener(callback)) return;
    await _syncNativeListenerState();
  }

  Future<void> _syncNativeListenerState() {
    return _syncQueue.addJob((_) async {
      final nativeListening = await isListening;
      if (_platform.hasAnyListeners && !_isPaused) {
        await _ensureVolumeAwayFromBoundsIfNeeded();
        if (!nativeListening) await _platform.startListener();
      } else if (nativeListening) {
        _platform.cancelLongPressTimers();
        await _platform.stopListener();
      }
    });
  }

  Future<void> _ensureVolumeAwayFromBoundsIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final volume = await getVolume();
      if (volume == 0) {
        await setVolume(0.1);
      } else if (volume == 1) {
        await setVolume(0.9);
      }
    } catch (e) {
      debugPrint("Error setting volume away from bounds: $e");
    }
  }

  static VolumeButtonListenerInterface _getPlatform() {
    if (kIsWeb) {
      throw UnsupportedError('Volume button listener is not supported on web');
    }
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return VolumeButtonListenerLinux.instance;
    }
    return VolumeButtonListenerNative.instance;
  }
}
