import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:volume_button_listener/src/android_listening_mode.dart';
import 'package:volume_button_listener/src/volume_button_listener.g.dart';
import 'package:volume_button_listener/src/volume_button_listener_interface.dart';

class VolumeButtonListenerNative extends VolumeButtonListenerCallbackChannel
    with VolumeButtonListenerInterface {
  static VolumeButtonListenerNative? _instance;
  static VolumeButtonListenerNative get instance =>
      _instance ??= VolumeButtonListenerNative._();

  final _channel = VolumeButtonListenerPlatformChannel();

  AndroidListeningMode _androidListeningMode = AndroidListeningMode.keyEvents;

  AndroidListeningMode get androidListeningMode => _androidListeningMode;

  set androidListeningMode(AndroidListeningMode mode) {
    if (_androidListeningMode == mode) return;
    _androidListeningMode = mode;
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        _channel.setAndroidListeningMode(
          mode == AndroidListeningMode.volumeEvents,
        ),
      );
    }
  }

  VolumeButtonListenerNative._() {
    VolumeButtonListenerCallbackChannel.setUp(this);
  }

  @override
  Future<VolumeButtonBackend> startListener() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _channel.setAndroidListeningMode(
        _androidListeningMode == AndroidListeningMode.volumeEvents,
      );
    }
    await _channel.startListener();
    if (defaultTargetPlatform == TargetPlatform.android &&
        _androidListeningMode == AndroidListeningMode.volumeEvents) {
      return VolumeButtonBackend.volumeMonitor;
    }
    return VolumeButtonBackend.native;
  }

  @override
  Future<void> setShowVolumeUi(bool showVolumeUi) =>
      _channel.setShowVolumeUi(showVolumeUi);

  @override
  Future<void> stopListener() => _channel.stopListener();

  @override
  Future<bool> isListening() => _channel.isListening();

  @override
  Future<double> getVolume() => _channel.getVolume();

  @override
  Future<void> setVolume(double volume) => _channel.setVolume(volume);

  @override
  void onVolumeButtonPressed(bool isVolumeUp) =>
      notifyVolumeButtonPressed(isVolumeUp);

  @override
  void onVolumeButtonReleased(bool isVolumeUp) =>
      notifyVolumeButtonReleased(isVolumeUp);
}
