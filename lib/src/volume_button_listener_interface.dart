import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:volume_button_listener/src/volume_button_notifier.dart';
import 'package:volume_button_listener/volume_button_listener.dart';

class _ButtonState {
  Timer? timer;
  int pressCount = 0;
  bool isLongPressActive = false;

  void reset() {
    timer?.cancel();
    timer = null;
    pressCount = 0;
    isLongPressActive = false;
  }
}

mixin VolumeButtonListenerInterface {
  final VolumeButtonNotifier buttonPressedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonReleasedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonLongPressedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonLongPressReleasedNotifier =
      VolumeButtonNotifier();

  Duration longPressDuration = const Duration(milliseconds: 500);

  bool _suppressRepeatedPressEvents = true;
  (bool isVolumeUp, bool isPressed)? _previousEvent;

  final _ButtonState _upState = _ButtonState();
  final _ButtonState _downState = _ButtonState();

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
    _upState.reset();
    _downState.reset();
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

    final state = isVolumeUp ? _upState : _downState;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      state.pressCount++;
      if (state.pressCount > 1) {
        if (state.pressCount >= 3 && state.timer == null) {
          _activateLongPress(state, direction);
        }
        return;
      }
    } else if (shouldSuppress) {
      return;
    }

    state.timer?.cancel();
    state.isLongPressActive = false;
    state.timer = Timer(longPressDuration, () {
      if (state.pressCount < 3 && defaultTargetPlatform == TargetPlatform.iOS) {
        state.timer = null;
        return;
      }
      state.timer = null;
      _activateLongPress(state, direction);
    });
  }

  void notifyVolumeButtonReleased(bool isVolumeUp) {
    debugPrint('VBL raw ${isVolumeUp ? 'up' : 'down'} release ${DateTime.now().millisecondsSinceEpoch}');
    if (_shouldSuppressEvent(isVolumeUp, isPressed: false)) return;
    final direction = _directionFromBool(isVolumeUp);
    final state = isVolumeUp ? _upState : _downState;

    state.pressCount = 0;
    state.timer?.cancel();
    state.timer = null;

    if (state.isLongPressActive) {
      state.isLongPressActive = false;
      buttonLongPressReleasedNotifier.notify(direction);
    } else {
      if (hasLongPressListeners) {
        buttonPressedNotifier.notify(direction);
      }
      buttonReleasedNotifier.notify(direction);
    }
  }

  void _activateLongPress(
    _ButtonState state,
    VolumeButtonDirection direction,
  ) {
    if (state.isLongPressActive) return;
    state.isLongPressActive = true;
    debugPrint('VBL classified ${direction == VolumeButtonDirection.up ? 'up' : 'down'} long press ${DateTime.now().millisecondsSinceEpoch}');
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
