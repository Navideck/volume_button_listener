import 'dart:async';

import 'package:volume_button_listener/src/volume_button_direction.dart';

/// Per-direction sequencing state for [ButtonSequenceDetector].
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

/// Turns raw button press/release notifications into pressed, released,
/// long-press and multi-press events.
///
/// This is split out of `VolumeButtonListenerInterface` so the sequencing rules
/// are independent of notifiers, platform channels and Flutter bindings.
class ButtonSequenceDetector {
  ButtonSequenceDetector({
    required this.onPressed,
    required this.onReleased,
    required this.onLongPressed,
    required this.onLongPressReleased,
    required this.onMultiPressed,
    required this.hasLongPressListeners,
    required this.hasMultiPressListeners,
    required this.isIOS,
    required this.longPressDuration,
    required this.multiPressWindow,
    required this.suppressRepeatedPressEvents,
  });

  final void Function(VolumeButtonDirection direction) onPressed;
  final void Function(VolumeButtonDirection direction) onReleased;
  final void Function(VolumeButtonDirection direction) onLongPressed;
  final void Function(VolumeButtonDirection direction) onLongPressReleased;
  final void Function(VolumeButtonDirection direction, int count)
  onMultiPressed;

  final bool Function() hasLongPressListeners;
  final bool Function() hasMultiPressListeners;
  final bool Function() isIOS;
  final Duration Function() longPressDuration;
  final Duration Function() multiPressWindow;
  final bool Function() suppressRepeatedPressEvents;

  final _ButtonState _upState = _ButtonState();
  final _ButtonState _downState = _ButtonState();
  (bool isVolumeUp, bool isPressed)? _previousEvent;

  void press(bool isVolumeUp) {
    final shouldSuppress = _shouldSuppressEvent(isVolumeUp, isPressed: true);
    final direction = _directionFromBool(isVolumeUp);

    if (!hasLongPressListeners() && !hasMultiPressListeners()) {
      if (shouldSuppress) return;
      onPressed(direction);
      return;
    }

    final state = isVolumeUp ? _upState : _downState;
    final ios = isIOS();

    if (hasLongPressListeners() && ios) {
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

    _handlePressDown(state, direction, ios: ios);
  }

  void release(bool isVolumeUp) {
    if (_shouldSuppressEvent(isVolumeUp, isPressed: false)) return;
    final direction = _directionFromBool(isVolumeUp);

    if (!hasLongPressListeners() && !hasMultiPressListeners()) {
      onReleased(direction);
      return;
    }

    final state = isVolumeUp ? _upState : _downState;

    state.pressCount = 0;
    state.timer?.cancel();
    state.timer = null;
    state.isReleased = true;

    if (state.isLongPressActive) {
      state.isLongPressActive = false;
      onLongPressReleased(direction);
      state.reset();
      return;
    }

    if (hasMultiPressListeners()) {
      // Wait for the multi-press window to close so a following press can be
      // counted. If the window already elapsed while the button was held,
      // finalize now.
      if (state.isWindowElapsed) {
        _finalizeSequence(state, direction);
      }
      return;
    }

    // Long-press-only path.
    onPressed(direction);
    onReleased(direction);
  }

  void cancelTimers() {
    _upState.reset();
    _downState.reset();
  }

  /// Clears the duplicate-event suppression memory.
  void resetSuppression() {
    _previousEvent = null;
  }

  void _handlePressDown(
    _ButtonState state,
    VolumeButtonDirection direction, {
    required bool ios,
  }) {
    if (hasMultiPressListeners() && state.multiPressCount >= 3) {
      // Extra presses beyond a triple are ignored until the window resets.
      return;
    }

    if (hasMultiPressListeners()) {
      state.multiPressCount++;
      state.isReleased = false;
      state.isWindowElapsed = false;
      state.multiPressTimer?.cancel();
      state.multiPressTimer = Timer(
        multiPressWindow(),
        () => _onMultiPressWindowElapsed(state, direction),
      );
    }

    if (hasLongPressListeners()) {
      state.timer?.cancel();
      state.isLongPressActive = false;
      state.timer = Timer(longPressDuration(), () {
        if (state.pressCount < 3 && ios) {
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

  void _finalizeSequence(_ButtonState state, VolumeButtonDirection direction) {
    if (state.isLongPressActive) return;

    if (state.multiPressCount >= 2) {
      onMultiPressed(direction, state.multiPressCount);
    } else {
      onPressed(direction);
      onReleased(direction);
    }
    state.resetSequence();
  }

  void _activateLongPress(_ButtonState state, VolumeButtonDirection direction) {
    if (state.isLongPressActive) return;
    state.isLongPressActive = true;
    onLongPressed(direction);
  }

  bool _shouldSuppressEvent(bool isVolumeUp, {required bool isPressed}) {
    if (!suppressRepeatedPressEvents()) return false;
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
