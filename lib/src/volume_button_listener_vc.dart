import 'dart:async';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:volume_button_listener/src/volume_button_listener_interface.dart';

class VolumeButtonListenerVC with VolumeButtonListenerInterface {
  VolumeButtonListenerVC._();
  static VolumeButtonListenerVC? _instance;
  static VolumeButtonListenerVC get instance =>
      _instance ??= VolumeButtonListenerVC._();

  @override
  Future<void> startListener() async {
    // TODO: Implement
    throw UnimplementedError();
  }

  @override
  Future<void> stopListener() async {
    // TODO: Implement
    throw UnimplementedError();
  }

  @override
  Future<void> setShowVolumeUi(bool showVolumeUi) async {
    // TODO: Implement
  }

  @override
  Future<bool> isListening() async {
    // TODO: Implement
    return false;
  }

  @override
  Future<double> getVolume() async {
    return await FlutterVolumeController.getVolume() ?? 0.0;
  }

  @override
  Future<void> setVolume(double volume) async {
    await FlutterVolumeController.setVolume(volume);
  }
}
