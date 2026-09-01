import 'dart:async';

import 'package:flutter/foundation.dart';
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
  int _upPressCount = 0;
  int _downPressCount = 0;
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
    _upPressCount = 0;
    _downPressCount = 0;
    _isUpLongPressActive = false;
    _isDownLongPressActive = false;
  }

  void notifyVolumeButtonPressed(bool isVolumeUp) {
    debugPrint('VBL raw ${isVolumeUp ? 'up' : 'down'} press ${DateTime.now().millisecondsSinceEpoch}');
    final shouldSuppress = _shouldSuppressEvent(isVolumeUp, isPressed: true);
    final direction = _directionFromBool(isVolumeUp);

    if (!hasLongPressListeners) {
      if (shouldSuppress) return;
      buttonPressedNotifier.notify(direction);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (isVolumeUp) {
        _upPressCount++;
        if (_upPressCount > 1) {
          if (_upPressCount >= 3 && _upTimer == null) {
            _activateLongPress(isVolumeUp: true, direction: direction);
          }
          return;
        }
      } else {
        _downPressCount++;
        if (_downPressCount > 1) {
          if (_downPressCount >= 3 && _downTimer == null) {
            _activateLongPress(isVolumeUp: false, direction: direction);
          }
          return;
        }
      }
    } else if (shouldSuppress) {
      return;
    }

    if (isVolumeUp) {
      _upTimer?.cancel();
      _isUpLongPressActive = false;
      _upTimer = Timer(longPressDuration, () {
        if (_upPressCount < 3 && defaultTargetPlatform == TargetPlatform.iOS) {
          _upTimer = null;
          return;
        }
        _upTimer = null;
        _activateLongPress(isVolumeUp: true, direction: direction);
      });
    } else {
      _downTimer?.cancel();
      _isDownLongPressActive = false;
      _downTimer = Timer(longPressDuration, () {
        if (_downPressCount < 3 &&
            defaultTargetPlatform == TargetPlatform.iOS) {
          _downTimer = null;
          return;
        }
        _downTimer = null;
        _activateLongPress(isVolumeUp: false, direction: direction);
      });
    }
  }

  void notifyVolumeButtonReleased(bool isVolumeUp) {
    debugPrint('VBL raw ${isVolumeUp ? 'up' : 'down'} release ${DateTime.now().millisecondsSinceEpoch}');
    if (_shouldSuppressEvent(isVolumeUp, isPressed: false)) return;
    final direction = _directionFromBool(isVolumeUp);

    if (isVolumeUp) {
      _upPressCount = 0;
    } else {
      _downPressCount = 0;
    }

    final timer = isVolumeUp ? _upTimer : _downTimer;
    final isLongPressActive = isVolumeUp
        ? _isUpLongPressActive
        : _isDownLongPressActive;

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
      if (hasLongPressListeners) {
        buttonPressedNotifier.notify(direction);
      }
      buttonReleasedNotifier.notify(direction);
    }
  }

  void _activateLongPress({
    required bool isVolumeUp,
    required VolumeButtonDirection direction,
  }) {
    if (isVolumeUp) {
      if (_isUpLongPressActive) return;
      _isUpLongPressActive = true;
    } else {
      if (_isDownLongPressActive) return;
      _isDownLongPressActive = true;
    }
    debugPrint('VBL classified ${isVolumeUp ? 'up' : 'down'} long press ${DateTime.now().millisecondsSinceEpoch}');
    buttonLongPressedNotifier.notify(direction);
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
