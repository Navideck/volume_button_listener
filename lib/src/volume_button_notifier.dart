import 'package:volume_button_listener/src/volume_button_direction.dart';

typedef VolumeButtonListenerCallback =
    void Function(VolumeButtonDirection direction);

/// Signature for callbacks notified when a volume button is pressed multiple
/// times in quick succession. [count] is `2` for a double press and `3` for a
/// triple press.
typedef VolumeButtonMultiPressCallback =
    void Function(VolumeButtonDirection direction, int count);

/// Stores listeners of type [T] and dispatches events to them.
///
/// This is not exported; consumers use [VolumeButtonNotifier] and
/// [VolumeButtonMultiPressNotifier].
class VolumeButtonNotifierBase<T> {
  final List<T> _listeners = [];

  bool get hasListeners => _listeners.isNotEmpty;

  int get listenerCount => _listeners.length;

  /// Adds the listener. Returns true if it was added, false if already present.
  bool addListener(T listener) {
    if (_listeners.contains(listener)) return false;
    _listeners.add(listener);
    return true;
  }

  /// Removes the listener. Returns true if it was removed.
  bool removeListener(T listener) => _listeners.remove(listener);

  bool hasListener(T listener) => _listeners.contains(listener);

  /// Calls [dispatch] for each listener, ignoring listener exceptions.
  void dispatch(void Function(T listener) dispatch) {
    for (final listener in List<T>.of(_listeners)) {
      try {
        dispatch(listener);
      } catch (_) {}
    }
  }
}

/// Notifies listeners when the volume button is pressed or released.
class VolumeButtonNotifier
    extends VolumeButtonNotifierBase<VolumeButtonListenerCallback> {
  /// Notifies all listeners with the given direction.
  void notify(VolumeButtonDirection direction) {
    dispatch((listener) => listener(direction));
  }
}

/// Notifies listeners when the volume button is pressed multiple times in
/// quick succession (double or triple press).
class VolumeButtonMultiPressNotifier
    extends VolumeButtonNotifierBase<VolumeButtonMultiPressCallback> {
  /// Notifies all listeners with the given direction and press count.
  void notify(VolumeButtonDirection direction, int count) {
    dispatch((listener) => listener(direction, count));
  }
}
