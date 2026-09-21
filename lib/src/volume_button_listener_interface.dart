import 'package:flutter/foundation.dart';
import 'package:volume_button_listener/src/button_sequence_detector.dart';
import 'package:volume_button_listener/src/volume_button_notifier.dart';

/// The mechanism that is currently delivering volume button events.
enum VolumeButtonBackend {
  /// A native platform backend (Android, iOS, macOS, Windows).
  native,

  /// Linux X11 passive key grab. The key is consumed.
  x11,

  /// Linux exclusive evdev device grab. The key is consumed.
  evdev,

  /// Linux fallback that observes system volume changes. The system still
  /// handles the key, so the volume UI cannot be suppressed.
  volumeMonitor,

  /// No backend is active.
  none,
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

  late final ButtonSequenceDetector _sequence = ButtonSequenceDetector(
    onPressed: buttonPressedNotifier.notify,
    onReleased: buttonReleasedNotifier.notify,
    onLongPressed: buttonLongPressedNotifier.notify,
    onLongPressReleased: buttonLongPressReleasedNotifier.notify,
    onMultiPressed: buttonMultiPressedNotifier.notify,
    hasLongPressListeners: () => hasLongPressListeners,
    hasMultiPressListeners: () => hasMultiPressListeners,
    isIOS: () => defaultTargetPlatform == TargetPlatform.iOS,
    longPressDuration: () => longPressDuration,
    multiPressWindow: () => multiPressWindow,
    suppressRepeatedPressEvents: () => _suppressRepeatedPressEvents,
  );

  bool get hasLongPressListeners =>
      buttonLongPressedNotifier.hasListeners ||
      buttonLongPressReleasedNotifier.hasListeners;

  bool get hasMultiPressListeners => buttonMultiPressedNotifier.hasListeners;

  /// Whether any button listener is registered.
  bool get hasAnyListeners =>
      buttonPressedNotifier.hasListeners ||
      buttonReleasedNotifier.hasListeners ||
      hasLongPressListeners ||
      hasMultiPressListeners;

  Future<double> getVolume();

  Future<void> setVolume(double volume);

  /// Starts listening and returns the backend that is now active.
  Future<VolumeButtonBackend> startListener();

  Future<void> setShowVolumeUi(bool showVolumeUi);

  Future<void> stopListener();

  Future<bool> isListening();

  void setSuppressRepeatedPressEvents(bool suppressRepeatedPressEvents) {
    _suppressRepeatedPressEvents = suppressRepeatedPressEvents;
    if (!suppressRepeatedPressEvents) {
      _sequence.resetSuppression();
    }
  }

  void cancelLongPressTimers() => _sequence.cancelTimers();

  void notifyVolumeButtonPressed(bool isVolumeUp) =>
      _sequence.press(isVolumeUp);

  void notifyVolumeButtonReleased(bool isVolumeUp) =>
      _sequence.release(isVolumeUp);
}
