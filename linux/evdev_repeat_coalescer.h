#ifndef VOLUME_BUTTON_LISTENER_LINUX_EVDEV_REPEAT_COALESCER_H_
#define VOLUME_BUTTON_LISTENER_LINUX_EVDEV_REPEAT_COALESCER_H_

#include <cstdint>

namespace volume_button_listener {

// Some input devices (for example the Intel HID 5-button array) do not use
// EV_REP auto-repeat. While a button is held they emit a fresh press/release
// pair every ~150 ms, so a hold looks like a stream of taps. This coalescer
// turns that stream back into a single press followed by a single release.
//
// It is deliberately free of GLib and device I/O so it can be unit tested.
class EvdevRepeatCoalescer {
 public:
  // Maximum gap between presses of the same key that is still treated as part
  // of one continuous hold.
  //
  // The value is chosen between the device's auto-repeat interval (~150 ms on
  // the Intel HID 5-button array) and a deliberate multi-tap gap (~250 ms), so
  // holding coalesces while double/triple taps remain separate. It is
  // intentionally independent of the Dart `multiPressWindow`/`longPressDuration`
  // settings, which must stay larger than [kReleaseDelayUs] for multi-press to
  // work on Wayland.
  static constexpr int64_t kRepeatWindowUs = 200 * 1000;

  // Time without a new press after which a key is reported as released.
  static constexpr int64_t kReleaseDelayUs = kRepeatWindowUs;

  // Registers a press at [event_time_us]. Returns true when the press should
  // be reported to the caller, or false when it was coalesced into a hold.
  bool OnPress(bool is_volume_up, int64_t event_time_us);

  // Marks the key as released. Returns true when a release should be reported.
  bool TakeRelease(bool is_volume_up);

  bool is_active(bool is_volume_up) const;

  void Reset();

 private:
  struct KeyState {
    bool active = false;
    int64_t last_press_us = 0;
  };

  static int Index(bool is_volume_up) { return is_volume_up ? 1 : 0; }

  KeyState keys_[2];
};

}  // namespace volume_button_listener

#endif  // VOLUME_BUTTON_LISTENER_LINUX_EVDEV_REPEAT_COALESCER_H_
