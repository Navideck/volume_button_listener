/// A Flutter plugin for listening to hardware volume button events
/// and controlling system volume across supported platforms.
library;

import 'dart:async';

import 'package:async_queue/async_queue.dart';
import 'package:flutter/foundation.dart';
import 'package:volume_button_listener/src/volume_button_listener.dart';
import 'package:volume_button_listener/src/volume_button_listener_interface.dart';
import 'package:volume_button_listener/src/volume_button_listener_vc.dart';
import 'package:volume_button_listener/src/volume_button_notifier.dart';

export 'package:volume_button_listener/src/volume_button_direction.dart';

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
  static bool supportsVolumeButtonListener =
      !kIsWeb && defaultTargetPlatform != TargetPlatform.linux;

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

  /// Gets the current system volume level between `0.0` and `1.0`.
  Future<double> getVolume() => _platform.getVolume();

  /// Sets the system volume level, clamped between `0.0` and `1.0`.
  Future<void> setVolume(double volume) => _platform.setVolume(volume);

  /// Adds a [callback] that is invoked when a volume button is pressed down.
  Future<void> addButtonPressedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonPressedNotifier.addListener(callback)) return;
    await _syncNativeListenerState();
  }

  /// Removes a previously registered button-pressed [callback].
  Future<void> removeButtonPressedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonPressedNotifier.removeListener(callback)) return;
    await _syncNativeListenerState();
  }

  /// Adds a [callback] that is invoked when a volume button is released.
  Future<void> addButtonReleasedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonReleasedNotifier.addListener(callback)) return;
    await _syncNativeListenerState();
  }

  /// Removes a previously registered button-released [callback].
  Future<void> removeButtonReleasedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonReleasedNotifier.removeListener(callback)) return;
    await _syncNativeListenerState();
  }

  /// Adds a [callback] that is invoked when a volume button is held down for [longPressDuration].
  Future<void> addButtonLongPressedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonLongPressedNotifier.addListener(callback)) return;
    await _syncNativeListenerState();
  }

  /// Removes a previously registered button long-pressed [callback].
  Future<void> removeButtonLongPressedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonLongPressedNotifier.removeListener(callback)) return;
    await _syncNativeListenerState();
  }

  /// Adds a [callback] that is invoked when a volume button is released after a long-press event.
  Future<void> addButtonLongPressReleasedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonLongPressReleasedNotifier.addListener(callback)) {
      return;
    }
    await _syncNativeListenerState();
  }

  /// Removes a previously registered button long-press released [callback].
  Future<void> removeButtonLongPressReleasedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonLongPressReleasedNotifier.removeListener(callback)) {
      return;
    }
    await _syncNativeListenerState();
  }

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

  Future<void> _syncNativeListenerState() {
    return _syncQueue.addJob((_) async {
      final nativeListening = await isListening;
      bool hasListeners =
          _platform.buttonPressedNotifier.hasListeners ||
          _platform.buttonReleasedNotifier.hasListeners ||
          _platform.buttonLongPressedNotifier.hasListeners ||
          _platform.buttonLongPressReleasedNotifier.hasListeners;
      if (hasListeners && !_isPaused) {
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
      return VolumeButtonListenerVC.instance;
    }
    return VolumeButtonListenerNative.instance;
  }
}
