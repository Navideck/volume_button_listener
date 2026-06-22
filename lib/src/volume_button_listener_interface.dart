import 'package:volume_button_listener/src/volume_button_notifier.dart';
import 'package:volume_button_listener/volume_button_listener.dart';

mixin VolumeButtonListenerInterface {
  final VolumeButtonNotifier buttonPressedNotifier = VolumeButtonNotifier();
  final VolumeButtonNotifier buttonReleasedNotifier = VolumeButtonNotifier();
  bool _suppressRepeatedPressEvents = true;
  (bool isVolumeUp, bool isPressed)? _previousEvent;

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

  void notifyVolumeButtonPressed(bool isVolumeUp) {
    if (_shouldSuppressEvent(isVolumeUp, isPressed: true)) return;
    buttonPressedNotifier.notify(_directionFromBool(isVolumeUp));
  }

  void notifyVolumeButtonReleased(bool isVolumeUp) {
    if (_shouldSuppressEvent(isVolumeUp, isPressed: false)) return;
    buttonReleasedNotifier.notify(_directionFromBool(isVolumeUp));
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
