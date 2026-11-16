import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:volume_button_listener/src/volume_button_direction.dart';

/// Observes system volume changes and infers volume button presses from the
/// direction of each change. Used for platforms and devices (such as Linux
/// Wayland or Meta Quest) where hardware key events are consumed by the OS.
class VolumeChangeMonitor {
  VolumeChangeMonitor({
    required this.onPressed,
    required this.onReleased,
    this.releaseDelay = const Duration(milliseconds: 100),
    this.changeThreshold = 0.005,
  });

  final void Function(bool isVolumeUp) onPressed;
  final void Function(bool isVolumeUp) onReleased;
  final Duration releaseDelay;
  final double changeThreshold;

  StreamSubscription<double>? _subscription;
  double? _lastVolume;
  VolumeButtonDirection? _pendingDirection;
  Timer? _releaseTimer;
  bool _ignoreChanges = false;
  Timer? _ignoreTimer;

  void start() {
    if (_subscription != null) return;
    _lastVolume = null;
    _subscription = FlutterVolumeController.addListener(
      onVolumeChanged,
      emitOnStart: true,
    );
  }

  void stop() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
    _ignoreTimer?.cancel();
    _ignoreTimer = null;
    _ignoreChanges = false;
    _pendingDirection = null;
    _lastVolume = null;
    _subscription?.cancel();
    _subscription = null;
  }

  void ignoreChangesFor(Duration duration) {
    _ignoreChanges = true;
    _ignoreTimer?.cancel();
    _ignoreTimer = Timer(duration, () => _ignoreChanges = false);
  }

  @visibleForTesting
  void onVolumeChanged(double volume) {
    final previous = _lastVolume;
    _lastVolume = volume;
    if (previous == null || _ignoreChanges) return;
    if ((volume - previous).abs() < changeThreshold) return;

    final direction = volume > previous
        ? VolumeButtonDirection.up
        : VolumeButtonDirection.down;

    if (_pendingDirection != direction) {
      final pending = _pendingDirection;
      if (pending != null) onReleased(pending == VolumeButtonDirection.up);
      _pendingDirection = direction;
      onPressed(direction == VolumeButtonDirection.up);
    }

    _releaseTimer?.cancel();
    _releaseTimer = Timer(releaseDelay, () {
      final pending = _pendingDirection;
      _pendingDirection = null;
      if (pending != null) onReleased(pending == VolumeButtonDirection.up);
    });
  }
}
