import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:volume_button_listener/src/volume_button_notifier.dart';
import 'package:volume_button_listener/volume_button_listener.dart';

class _ButtonState {
  Timer? timer;
  Timer? multiPressTimer;
  int pressCount = 0;
  int multiPressCount = 0;
  bool isLongPressActive = false;
  bool isReleased = false;
  bool isWindowElapsed = false;

  void reset() {
    timer?.cancel();
    timer = null;
    multiPressTimer?.cancel();
    multiPressTimer = null;
    pressCount = 0;
    multiPressCount = 0;
    isLongPressActive = false;
    isReleased = false;
    isWindowElapsed = false;
  }

  void resetSequence() {
    multiPressTimer?.cancel();
    multiPressTimer = null;
    multiPressCount = 0;
    isReleased = false;
    isWindowElapsed = false;
  }
}

mixin VolumeButtonListenerInterface {
  final VolumeButtonNotifier buttonPressedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonReleasedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonLongPressedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonLongPressReleasedNotifier =
      VolumeButtonNotifier();
  final VolumeButtonMultiPressNotifier buttonMultiPressedNotifier =
      VolumeButtonMultiPressNotifier();

  Duration longPressDuration = const Duration(milliseconds: 500);

  /// The maximum gap between consecutive press-downs for them to be considered
  /// part of the same double or triple press.
  Duration multiPressWindow = const Duration(milliseconds: 300);

  bool _suppressRepeatedPressEvents = true;
  (bool isVolumeUp, bool isPressed)? _previousEvent;

  final _ButtonState _upState = _ButtonState();
  final _ButtonState _downState = _ButtonState();

  bool get hasLongPressListeners =>
      buttonLongPressedNotifier.hasListeners ||
      buttonLongPressReleasedNotifier.hasListeners;

  bool get hasMultiPressListeners => buttonMultiPressedNotifier.hasListeners;

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
    final shouldSuppress = _shouldSuppressEvent(isVolumeUp, isPressed: true);
    final direction = _directionFromBool(isVolumeUp);

    if (!hasLongPressListeners && !hasMultiPressListeners) {
      if (shouldSuppress) return;
      buttonPressedNotifier.notify(direction);
      return;
    }

    final state = isVolumeUp ? _upState : _downState;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (hasLongPressListeners && isIOS) {
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

    _handlePressDown(state, direction, isIOS: isIOS);
  }

  void notifyVolumeButtonReleased(bool isVolumeUp) {
    if (_shouldSuppressEvent(isVolumeUp, isPressed: false)) return;
    final direction = _directionFromBool(isVolumeUp);

    if (!hasLongPressListeners && !hasMultiPressListeners) {
      buttonReleasedNotifier.notify(direction);
      return;
    }

    final state = isVolumeUp ? _upState : _downState;

    state.pressCount = 0;
    state.timer?.cancel();
    state.timer = null;
    state.isReleased = true;

    if (state.isLongPressActive) {
      state.isLongPressActive = false;
      buttonLongPressReleasedNotifier.notify(direction);
      state.reset();
      return;
    }

    if (hasMultiPressListeners) {
      // Wait for the multi-press window to close so a following press can be
      // counted. If the window already elapsed while the button was held,
      // finalize now.
      if (state.isWindowElapsed) {
        _finalizeSequence(state, direction);
      }
      return;
    }

    // Long-press-only path (unchanged).
    buttonPressedNotifier.notify(direction);
    buttonReleasedNotifier.notify(direction);
  }

  void _handlePressDown(
    _ButtonState state,
    VolumeButtonDirection direction, {
    required bool isIOS,
  }) {
    if (hasMultiPressListeners && state.multiPressCount >= 3) {
      // Extra presses beyond a triple are ignored until the window resets.
      return;
    }

    if (hasMultiPressListeners) {
      state.multiPressCount++;
      state.isReleased = false;
      state.isWindowElapsed = false;
      state.multiPressTimer?.cancel();
      state.multiPressTimer = Timer(
        multiPressWindow,
        () => _onMultiPressWindowElapsed(state, direction),
      );
    }

    if (hasLongPressListeners) {
      state.timer?.cancel();
      state.isLongPressActive = false;
      state.timer = Timer(longPressDuration, () {
        if (state.pressCount < 3 && isIOS) {
          state.timer = null;
          return;
        }
        state.timer = null;
        _activateLongPress(state, direction);
      });
    }
  }

  void _onMultiPressWindowElapsed(
    _ButtonState state,
    VolumeButtonDirection direction,
  ) {
    state.multiPressTimer = null;
    state.isWindowElapsed = true;

    // A long press owns the interaction until the button is released.
    if (state.isLongPressActive) return;

    // Wait for the button to be released before finalizing.
    if (!state.isReleased) return;

    _finalizeSequence(state, direction);
  }

  void _finalizeSequence(
    _ButtonState state,
    VolumeButtonDirection direction,
  ) {
    if (state.isLongPressActive) return;

    if (state.multiPressCount >= 2) {
      buttonMultiPressedNotifier.notify(direction, state.multiPressCount);
    } else {
      buttonPressedNotifier.notify(direction);
      buttonReleasedNotifier.notify(direction);
    }
    state.resetSequence();
  }

  void _activateLongPress(
    _ButtonState state,
    VolumeButtonDirection direction,
  ) {
    if (state.isLongPressActive) return;
    state.isLongPressActive = true;
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
