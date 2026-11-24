/// The mechanism used on Android to capture hardware volume button events.
enum AndroidListeningMode {
  /// Uses Android window `KeyEvent` interception (default).
  ///
  /// Captures `ACTION_DOWN` and `ACTION_UP` directly from hardware buttons.
  /// Requires a focused Android window/activity. Does not work on platforms
  /// or devices where the OS compositor intercepts volume buttons (such as
  /// Meta Quest / Horizon OS).
  keyEvents,

  /// Observes system volume change events using `flutter_volume_controller`.
  ///
  /// Recommended for devices like Meta Quest (Horizon OS) where hardware
  /// volume key events are intercepted and consumed by the OS compositor.
  volumeEvents,
}

