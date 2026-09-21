#ifndef VOLUME_BUTTON_LISTENER_LINUX_EVDEV_BACKEND_H_
#define VOLUME_BUTTON_LISTENER_LINUX_EVDEV_BACKEND_H_

#include <glib.h>

#include "volume_button_backend.h"

G_BEGIN_DECLS

// Captures volume keys by grabbing dedicated (non-keyboard) input devices
// exclusively with EVIOCGRAB. This is the Wayland-compatible backend: the
// compositor never sees the key, so the system volume change and its OSD are
// suppressed. Devices that report auto-repeat as repeated press/release pairs
// are coalesced.
typedef struct _EvdevBackend EvdevBackend;

EvdevBackend* evdev_backend_new();

// Starts listening. Returns true if at least one device was grabbed.
gboolean evdev_backend_start(EvdevBackend* self, VolumeButtonCallback callback,
                             gpointer user_data);

void evdev_backend_stop(EvdevBackend* self);

gboolean evdev_backend_is_active(EvdevBackend* self);

void evdev_backend_free(EvdevBackend* self);

G_END_DECLS

#endif  // VOLUME_BUTTON_LISTENER_LINUX_EVDEV_BACKEND_H_
