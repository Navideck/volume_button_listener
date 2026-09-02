import 'dart:async';

import 'package:async_queue/async_queue.dart';
import 'package:flutter/foundation.dart';
import 'package:volume_button_listener/src/volume_button_listener.dart';
import 'package:volume_button_listener/src/volume_button_listener_interface.dart';
import 'package:volume_button_listener/src/volume_button_listener_vc.dart';
import 'package:volume_button_listener/src/volume_button_notifier.dart';

export 'package:volume_button_listener/src/volume_button_direction.dart';

class VolumeButtonListener {
  static VolumeButtonListener? _instance;
  static VolumeButtonListener get instance =>
      _instance ??= VolumeButtonListener._();
  VolumeButtonListener._();

  final VolumeButtonListenerInterface _platform = _getPlatform();

  static bool supportsVolumeButtonListener =
      !kIsWeb && defaultTargetPlatform != TargetPlatform.linux;

  bool _isPaused = false;
  final _syncQueue = AsyncQueue.autoStart(allowDuplicate: true);

  Future<bool> get isListening => _platform.isListening();

  set showVolumeUI(bool value) => unawaited(_platform.setShowVolumeUi(value));

  set suppressRepeatedPressEvents(bool value) =>
      _platform.setSuppressRepeatedPressEvents(value);

  Duration get longPressDuration => _platform.longPressDuration;
  set longPressDuration(Duration value) => _platform.longPressDuration = value;

  Future<double> getVolume() => _platform.getVolume();

  Future<void> setVolume(double volume) => _platform.setVolume(volume);

  Future<void> addButtonPressedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonPressedNotifier.addListener(callback)) return;
    await _syncNativeListenerState();
  }

  Future<void> removeButtonPressedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonPressedNotifier.removeListener(callback)) return;
    await _syncNativeListenerState();
  }

  Future<void> addButtonReleasedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonReleasedNotifier.addListener(callback)) return;
    await _syncNativeListenerState();
  }

  Future<void> removeButtonReleasedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonReleasedNotifier.removeListener(callback)) return;
    await _syncNativeListenerState();
  }

  Future<void> addButtonLongPressedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonLongPressedNotifier.addListener(callback)) return;
    await _syncNativeListenerState();
  }

  Future<void> removeButtonLongPressedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonLongPressedNotifier.removeListener(callback)) return;
    await _syncNativeListenerState();
  }

  Future<void> addButtonLongPressReleasedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonLongPressReleasedNotifier.addListener(callback)) {
      return;
    }
    await _syncNativeListenerState();
  }

  Future<void> removeButtonLongPressReleasedListener(
    VolumeButtonListenerCallback callback,
  ) async {
    if (!_platform.buttonLongPressReleasedNotifier.removeListener(callback)) {
      return;
    }
    await _syncNativeListenerState();
  }

  Future<void> pause() async {
    _isPaused = true;
    _platform.cancelLongPressTimers();
    await _syncNativeListenerState();
  }

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
