#include <flutter_linux/flutter_linux.h>
#include <glib.h>

#include "include/volume_button_listener/volume_button_listener_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Returns whether the current session is running on Wayland, where global
// media key grabs are not available.
bool volume_button_listener_is_wayland_session();
