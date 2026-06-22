import 'package:pigeon/pigeon.dart';

// ./generate_pigeon.sh
/// Flutter -> Native
@HostApi()
abstract class VolumeButtonListenerPlatformChannel {
  void startListener();

  void setShowVolumeUi(bool showVolumeUi);

  void stopListener();

  bool isListening();

  double getVolume();

  void setVolume(double volume);
}

/// Native -> Flutter
@FlutterApi()
abstract class VolumeButtonListenerCallbackChannel {
  void onVolumeButtonPressed(bool isVolumeUp);

  void onVolumeButtonReleased(bool isVolumeUp);
}
