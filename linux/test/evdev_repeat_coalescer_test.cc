#include <gtest/gtest.h>

#include "evdev_repeat_coalescer.h"

namespace volume_button_listener {
namespace test {

namespace {
constexpr int64_t kMs = 1000;
}

TEST(EvdevRepeatCoalescer, SingleTapReportsOnePressAndRelease) {
  EvdevRepeatCoalescer coalescer;
  EXPECT_TRUE(coalescer.OnPress(true, 0));
  EXPECT_TRUE(coalescer.is_active(true));
  EXPECT_TRUE(coalescer.TakeRelease(true));
  EXPECT_FALSE(coalescer.is_active(true));
  EXPECT_FALSE(coalescer.TakeRelease(true));
}

TEST(EvdevRepeatCoalescer, HeldKeyIsCoalescedIntoASinglePress) {
  EvdevRepeatCoalescer coalescer;
  EXPECT_TRUE(coalescer.OnPress(true, 0));
  // Auto-repeat arrives every ~150ms while held; only the first is reported.
  for (int i = 1; i <= 20; ++i) {
    EXPECT_FALSE(coalescer.OnPress(true, i * 150 * kMs));
  }
  EXPECT_TRUE(coalescer.is_active(true));
  EXPECT_TRUE(coalescer.TakeRelease(true));
}

TEST(EvdevRepeatCoalescer, FastDoubleTapProducesTwoPresses) {
  EvdevRepeatCoalescer coalescer;
  EXPECT_TRUE(coalescer.OnPress(true, 0));
  EXPECT_TRUE(coalescer.TakeRelease(true));
  EXPECT_TRUE(coalescer.OnPress(true, 250 * kMs));
  EXPECT_TRUE(coalescer.TakeRelease(true));
}

TEST(EvdevRepeatCoalescer, PressAtExactlyTheWindowIsANewPress) {
  EvdevRepeatCoalescer coalescer;
  EXPECT_TRUE(coalescer.OnPress(true, 0));
  EXPECT_TRUE(coalescer.OnPress(true, EvdevRepeatCoalescer::kRepeatWindowUs));
}

TEST(EvdevRepeatCoalescer, WindowJitterIsHandled) {
  EvdevRepeatCoalescer coalescer;
  EXPECT_TRUE(coalescer.OnPress(true, 0));
  EXPECT_FALSE(coalescer.OnPress(true, 199 * kMs));
  EXPECT_FALSE(coalescer.OnPress(true, 398 * kMs));
  // A gap beyond the window starts a new press.
  EXPECT_TRUE(coalescer.OnPress(true, 599 * kMs));
}

TEST(EvdevRepeatCoalescer, KeysAreTrackedIndependently) {
  EvdevRepeatCoalescer coalescer;
  EXPECT_TRUE(coalescer.OnPress(true, 0));
  EXPECT_TRUE(coalescer.OnPress(false, 10 * kMs));
  EXPECT_TRUE(coalescer.is_active(true));
  EXPECT_TRUE(coalescer.is_active(false));
  EXPECT_TRUE(coalescer.TakeRelease(true));
  EXPECT_FALSE(coalescer.is_active(true));
  EXPECT_TRUE(coalescer.is_active(false));
}

TEST(EvdevRepeatCoalescer, ResetClearsState) {
  EvdevRepeatCoalescer coalescer;
  EXPECT_TRUE(coalescer.OnPress(true, 0));
  coalescer.Reset();
  EXPECT_FALSE(coalescer.is_active(true));
  EXPECT_FALSE(coalescer.TakeRelease(true));
  // After reset a press within the old window is treated as new.
  EXPECT_TRUE(coalescer.OnPress(true, 10 * kMs));
}

}  // namespace test
}  // namespace volume_button_listener
