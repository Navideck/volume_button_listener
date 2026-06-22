import 'package:volume_button_listener/src/volume_button_direction.dart';

typedef VolumeButtonListenerCallback =
    void Function(VolumeButtonDirection direction);

/// Notifies listeners when the volume button is pressed or released.
class VolumeButtonNotifier {
  final List<VolumeButtonListenerCallback> _listeners = [];

  bool get hasListeners => listenerCount > 0;

  int get listenerCount => _listeners.length;

  /// Adds the listener to the notifier.
  /// Returns true if the listener was added, false if it was already present.
  bool addListener(VolumeButtonListenerCallback listener) {
    if (hasListener(listener)) return false;
    _listeners.add(listener);
    return true;
  }

  /// Removes the listener from the notifier.
  /// Returns true if the listener was removed, false if it was not present.
  bool removeListener(VolumeButtonListenerCallback listener) =>
      _listeners.remove(listener);

  /// Returns true if the listener is present in the notifier.
  bool hasListener(VolumeButtonListenerCallback listener) =>
      _listeners.contains(listener);

  /// Notifies all listeners with the given direction.
  void notify(VolumeButtonDirection direction) {
    for (var listener in _listeners) {
      try {
        listener(direction);
      } catch (_) {}
    }
  }
}
