/// Whether Linux volume button capture is set up on this system.
enum LinuxVolumeButtonSetupStatus {
  /// This system is not Linux, or does not need any setup.
  notApplicable,

  /// Setup is required before the hardware volume buttons can be captured and
  /// the system volume change suppressed.
  needsSetup,

  /// Everything is already set up.
  ready,
}

/// Stub used when `dart:io` is unavailable (for example on web).
class LinuxVolumeButtonSetup {
  static LinuxVolumeButtonSetupStatus status() =>
      LinuxVolumeButtonSetupStatus.notApplicable;

  static Future<bool> setUp() async => false;
}
