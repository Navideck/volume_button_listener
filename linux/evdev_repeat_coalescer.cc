#include "evdev_repeat_coalescer.h"

namespace volume_button_listener {

bool EvdevRepeatCoalescer::OnPress(bool is_volume_up, int64_t event_time_us) {
  KeyState& state = keys_[Index(is_volume_up)];
  const bool is_repeat =
      state.active && event_time_us - state.last_press_us < kRepeatWindowUs;
  state.active = true;
  state.last_press_us = event_time_us;
  return !is_repeat;
}

bool EvdevRepeatCoalescer::TakeRelease(bool is_volume_up) {
  KeyState& state = keys_[Index(is_volume_up)];
  if (!state.active) {
    return false;
  }
  state.active = false;
  return true;
}

bool EvdevRepeatCoalescer::is_active(bool is_volume_up) const {
  return keys_[Index(is_volume_up)].active;
}

void EvdevRepeatCoalescer::Reset() {
  keys_[0] = KeyState();
  keys_[1] = KeyState();
}

}  // namespace volume_button_listener
