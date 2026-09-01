import 'dart:async';

import 'package:volume_button_listener/src/volume_button_notifier.dart';
import 'package:volume_button_listener/volume_button_listener.dart';

mixin VolumeButtonListenerInterface {
  final VolumeButtonNotifier buttonPressedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonReleasedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonLongPressedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonLongPressReleasedNotifier =
      VolumeButtonNotifier();

  Duration longPressDuration = const Duration(milliseconds: 500);

  bool _suppressRepeatedPressEvents = true;
  (bool isVolumeUp, bool isPressed)? _previousEvent;

  Timer? _upTimer;
  Timer? _downTimer;
  bool _isUpLongPressActive = false;
  bool _isDownLongPressActive = false;

  bool get hasLongPressListeners =>
      buttonLongPressedNotifier.hasListeners ||
      buttonLongPressReleasedNotifier.hasListeners;

  Future<double> getVolume();

  Future<void> setVolume(double volume);

  Future<void> startListener();

  Future<void> setShowVolumeUi(bool showVolumeUi);

  Future<void> stopListener();

  Future<bool> isListening();

  void setSuppressRepeatedPressEvents(bool suppressRepeatedPressEvents) {
    _suppressRepeatedPressEvents = suppressRepeatedPressEvents;
    if (!suppressRepeatedPressEvents) {
      _previousEvent = null;
    }
  }

  void cancelLongPressTimers() {
    _upTimer?.cancel();
    _upTimer = null;
    _downTimer?.cancel();
    _downTimer = null;
    _isUpLongPressActive = false;
    _isDownLongPressActive = false;
  }

  void notifyVolumeButtonPressed(bool isVolumeUp) {
    if (_shouldSuppressEvent(isVolumeUp, isPressed: true)) return;
    final direction = _directionFromBool(isVolumeUp);

    if (!hasLongPressListeners) {
      buttonPressedNotifier.notify(direction);
      return;
    }

    if (isVolumeUp) {
      _upTimer?.cancel();
      _isUpLongPressActive = false;
      _upTimer = Timer(longPressDuration, () {
        _isUpLongPressActive = true;
        _upTimer = null;
        buttonLongPressedNotifier.notify(direction);
      });
    } else {
      _downTimer?.cancel();
      _isDownLongPressActive = false;
      _downTimer = Timer(longPressDuration, () {
        _isDownLongPressActive = true;
        _downTimer = null;
        buttonLongPressedNotifier.notify(direction);
      });
    }
  }

  void notifyVolumeButtonReleased(bool isVolumeUp) {
    if (_shouldSuppressEvent(isVolumeUp, isPressed: false)) return;
    final direction = _directionFromBool(isVolumeUp);

    final timer = isVolumeUp ? _upTimer : _downTimer;
    final isLongPressActive =
        isVolumeUp ? _isUpLongPressActive : _isDownLongPressActive;

    if (timer != null && timer.isActive) {
      timer.cancel();
      if (isVolumeUp) {
        _upTimer = null;
        _isUpLongPressActive = false;
      } else {
        _downTimer = null;
        _isDownLongPressActive = false;
      }
      buttonPressedNotifier.notify(direction);
      buttonReleasedNotifier.notify(direction);
    } else if (isLongPressActive) {
      if (isVolumeUp) {
        _isUpLongPressActive = false;
        _upTimer = null;
      } else {
        _isDownLongPressActive = false;
        _downTimer = null;
      }
      buttonLongPressReleasedNotifier.notify(direction);
    } else {
      buttonReleasedNotifier.notify(direction);
    }
  }

  bool _shouldSuppressEvent(bool isVolumeUp, {required bool isPressed}) {
    if (!_suppressRepeatedPressEvents) return false;
    if (_previousEvent?.$1 == isVolumeUp && _previousEvent?.$2 == isPressed) {
      return true;
    }
    _previousEvent = (isVolumeUp, isPressed);
    return false;
  }

  VolumeButtonDirection _directionFromBool(bool isVolumeUp) {
    return isVolumeUp ? VolumeButtonDirection.up : VolumeButtonDirection.down;
  }
}
