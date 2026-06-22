import 'package:volume_button_listener/src/volume_button_listener.g.dart';
import 'package:volume_button_listener/src/volume_button_listener_interface.dart';

class VolumeButtonListenerNative extends VolumeButtonListenerCallbackChannel
    with VolumeButtonListenerInterface {
  static VolumeButtonListenerNative? _instance;
  static VolumeButtonListenerNative get instance =>
      _instance ??= VolumeButtonListenerNative._();

  final _channel = VolumeButtonListenerPlatformChannel();

  VolumeButtonListenerNative._() {
    VolumeButtonListenerCallbackChannel.setUp(this);
  }

  @override
  Future<void> startListener() => _channel.startListener();

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
