#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <map>
#include <string>

#include "include/volume_button_listener/volume_button_listener_plugin.h"
#include "volume_button_listener_plugin_private.h"

namespace volume_button_listener {
namespace test {

class WaylandSessionTest : public ::testing::Test {
 protected:
  void SetUp() override {
    SaveEnv("WAYLAND_DISPLAY");
    SaveEnv("XDG_SESSION_TYPE");
    g_unsetenv("WAYLAND_DISPLAY");
    g_unsetenv("XDG_SESSION_TYPE");
  }

  void TearDown() override {
    RestoreEnv("WAYLAND_DISPLAY");
    RestoreEnv("XDG_SESSION_TYPE");
  }

 private:
  struct SavedEnv {
    bool was_set = false;
    std::string value;
  };

  void SaveEnv(const char* name) {
    const gchar* value = g_getenv(name);
    SavedEnv saved;
    if (value != nullptr) {
      saved.was_set = true;
      saved.value = value;
    }
    saved_[name] = saved;
  }

  void RestoreEnv(const char* name) {
    const SavedEnv& saved = saved_[name];
    if (saved.was_set) {
      g_setenv(name, saved.value.c_str(), TRUE);
    } else {
      g_unsetenv(name);
    }
  }

  std::map<std::string, SavedEnv> saved_;
};

TEST_F(WaylandSessionTest, ReturnsFalseWithoutSessionHints) {
  EXPECT_FALSE(volume_button_listener_is_wayland_session());
}

TEST_F(WaylandSessionTest, ReturnsTrueForWaylandDisplay) {
  g_setenv("WAYLAND_DISPLAY", "wayland-0", TRUE);
  EXPECT_TRUE(volume_button_listener_is_wayland_session());
}

TEST_F(WaylandSessionTest, ReturnsTrueForWaylandSessionType) {
  g_setenv("XDG_SESSION_TYPE", "wayland", TRUE);
  EXPECT_TRUE(volume_button_listener_is_wayland_session());
}

TEST_F(WaylandSessionTest, ReturnsFalseForX11SessionType) {
  g_setenv("XDG_SESSION_TYPE", "x11", TRUE);
  EXPECT_FALSE(volume_button_listener_is_wayland_session());
}

}  // namespace test
}  // namespace volume_button_listener
