import 'dart:io';

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

/// Sets up Linux hardware volume button capture.
///
/// Many 2-in-1 tablets (for example the HP Elite x2 1012 G2) route their side
/// volume buttons through the `intel-hid` 5-button array. The kernel only
/// enables that array for a DMI allowlist of known models, and on Wayland the
/// compositor handles the keys before an application can see them.
///
/// [setUp] performs both changes:
///
/// * writes a modprobe option enabling the `intel-hid` 5-button array, and
/// * installs a udev rule granting the active session access to non-keyboard
///   key devices, so the plugin can grab the dedicated volume device
///   exclusively (which suppresses the system volume change).
///
/// It requires administrator rights, so it triggers a single polkit
/// authentication prompt via `pkexec`. Call it only in response to an explicit
/// user action.
class LinuxVolumeButtonSetup {
  static const String _parameterPath =
      '/sys/module/intel_hid/parameters/enable_5_button_array';
  static const String _inputDevicesPath = '/proc/bus/input/devices';
  static const String _arrayDeviceName = 'Intel HID 5 button array';
  static const String _udevRulePath =
      '/etc/udev/rules.d/60-volume-button-listener.rules';

  /// Inspects the current system to decide whether [setUp] is needed.
  static LinuxVolumeButtonSetupStatus status() {
    if (!Platform.isLinux) {
      return LinuxVolumeButtonSetupStatus.notApplicable;
    }

    final hasCaptureRule = File(_udevRulePath).existsSync();

    final parameter = File(_parameterPath);
    if (parameter.existsSync()) {
      if (!hasCaptureRule) {
        return LinuxVolumeButtonSetupStatus.needsSetup;
      }
      final enabled = parameter.readAsStringSync().trim();
      if (enabled != 'Y' && enabled != '1') {
        return LinuxVolumeButtonSetupStatus.needsSetup;
      }
      final devices = File(_inputDevicesPath);
      if (!devices.existsSync() ||
          !devices.readAsStringSync().contains(_arrayDeviceName)) {
        return LinuxVolumeButtonSetupStatus.needsSetup;
      }
      return LinuxVolumeButtonSetupStatus.ready;
    }

    return hasCaptureRule
        ? LinuxVolumeButtonSetupStatus.ready
        : LinuxVolumeButtonSetupStatus.notApplicable;
  }

  /// Applies the `intel-hid` 5-button array option and the input device access
  /// rule using `pkexec` for the required privileges.
  ///
  /// This is a one-time setup: if [status] reports
  /// [LinuxVolumeButtonSetupStatus.ready] it returns `true` immediately
  /// without prompting, so it is safe to call on every launch.
  ///
  /// Returns `true` if capture is available. Returns `false` if the user
  /// cancelled the authentication prompt or the change failed.
  static Future<bool> setUp() async {
    if (!Platform.isLinux) return false;

    final current = status();
    if (current == LinuxVolumeButtonSetupStatus.ready) return true;
    if (current == LinuxVolumeButtonSetupStatus.notApplicable) return false;

    const command =
        r'''printf '%s\n' 'options intel_hid enable_5_button_array=1' > /etc/modprobe.d/intel-hid.conf;
printf '%s\n' 'SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEY}=="1", ENV{ID_INPUT_KEYBOARD}!="1", TAG+="uaccess"' > /etc/udev/rules.d/60-volume-button-listener.rules;
modprobe -r intel_hid 2>/dev/null;
modprobe intel_hid 2>/dev/null;
udevadm control --reload-rules && udevadm trigger --subsystem-match=input''';

    final ProcessResult result;
    try {
      result = await Process.run('pkexec', <String>['/bin/sh', '-c', command]);
    } on ProcessException {
      return false;
    }
    if (result.exitCode != 0) return false;

    // Give the kernel and udev a moment to apply the changes.
    for (var attempt = 0; attempt < 10; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (status() == LinuxVolumeButtonSetupStatus.ready) return true;
    }
    return false;
  }
}
