import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:volume_button_listener/src/volume_button_listener_interface.dart';
import 'package:volume_button_listener/src/volume_change_monitor.dart';

/// Linux implementation of [VolumeButtonListenerInterface].
///
/// The native plugin owns the capture backends. This class bridges to it and
/// falls back to observing system volume changes when no capture backend is
/// available (for example GNOME Wayland without a dedicated volume device).
class VolumeButtonListenerLinux with VolumeButtonListenerInterface {
  VolumeButtonListenerLinux._() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  static VolumeButtonListenerLinux? _instance;
  static VolumeButtonListenerLinux get instance =>
      _instance ??= VolumeButtonListenerLinux._();

  // Linux uses a plain MethodChannel rather than the Pigeon-generated channels
  // used by the other platforms: Flutter's Linux embedder exposes only the C
  // API (not the C++ `flutter::` wrapper that Pigeon's C++ output targets), so
  // the Pigeon protocol would have to be reimplemented by hand in C anyway.
  static const MethodChannel _channel = MethodChannel('volume_button_listener');

  // Matches the default step used by flutter_volume_controller on Linux.
  static const double _systemVolumeStep = 0.15;

  late final VolumeChangeMonitor _monitor = VolumeChangeMonitor(
    onPressed: notifyVolumeButtonPressed,
    onReleased: notifyVolumeButtonReleased,
    releaseDelay: const Duration(milliseconds: 80),
  );

  VolumeButtonBackend _backend = VolumeButtonBackend.none;
  bool _showVolumeUi = false;

  /// Whether the active backend consumes the key (so the system does not
  /// perform the volume change itself).
  bool get _backendConsumesKeys =>
      _backend == VolumeButtonBackend.x11 ||
      _backend == VolumeButtonBackend.evdev;

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onVolumeButtonPressed') {
      final isVolumeUp = call.arguments as bool? ?? false;
      // When the backend consumes the key but the caller asked for the volume
      // UI, emulate the volume change ourselves.
      if (_showVolumeUi && _backendConsumesKeys) {
        unawaited(
          isVolumeUp
              ? FlutterVolumeController.raiseVolume(_systemVolumeStep)
              : FlutterVolumeController.lowerVolume(_systemVolumeStep),
        );
      }
      notifyVolumeButtonPressed(isVolumeUp);
      return;
    }
    if (call.method == 'onVolumeButtonReleased') {
      notifyVolumeButtonReleased(call.arguments as bool? ?? false);
    }
  }

  @override
  Future<VolumeButtonBackend> startListener() async {
    if (_backend != VolumeButtonBackend.none) return _backend;

    try {
      final backend = await _channel.invokeMethod<String>('startListener');
      _backend = switch (backend) {
        'x11' => VolumeButtonBackend.x11,
        'evdev' => VolumeButtonBackend.evdev,
        _ => VolumeButtonBackend.none,
      };
      if (_backend != VolumeButtonBackend.none) return _backend;
    } on PlatformException {
      // No native capture backend (for example GNOME Wayland).
    } on MissingPluginException {
      // No native Linux implementation is available.
    }

    _monitor.start();
    _backend = VolumeButtonBackend.volumeMonitor;
    return _backend;
  }

  @override
  Future<void> stopListener() async {
    _monitor.stop();
    final wasNative = _backendConsumesKeys;
    _backend = VolumeButtonBackend.none;
    if (!wasNative) return;
    try {
      await _channel.invokeMethod<void>('stopListener');
    } on PlatformException {
      // Ignore.
    } on MissingPluginException {
      // Ignore.
    }
  }

  @override
  Future<void> setShowVolumeUi(bool showVolumeUi) async {
    // Purely local: whether the plugin emulates the volume change when it
    // consumes the key.
    _showVolumeUi = showVolumeUi;
  }

  @override
  Future<bool> isListening() async => _backend != VolumeButtonBackend.none;

  @override
  Future<double> getVolume() async {
    return await FlutterVolumeController.getVolume() ?? 0.0;
  }

  @override
  Future<void> setVolume(double volume) async {
    // Ignore the volume change this call produces so it is not mistaken for a
    // button press while observing system volume changes.
    _monitor.ignoreChangesFor(const Duration(milliseconds: 250));
    await FlutterVolumeController.setVolume(volume);
  }
}
