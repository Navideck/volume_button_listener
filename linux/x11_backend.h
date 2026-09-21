#ifndef VOLUME_BUTTON_LISTENER_LINUX_X11_BACKEND_H_
#define VOLUME_BUTTON_LISTENER_LINUX_X11_BACKEND_H_

#include <glib.h>

#include "volume_button_backend.h"

G_BEGIN_DECLS

// Captures the volume media keys with a passive X11 keyboard grab. The grabbed
// key is consumed, so it neither changes the system volume nor shows the
// volume HUD. Works on X11 sessions only; not available on Wayland.
typedef struct _X11Backend X11Backend;

X11Backend* x11_backend_new();

// Starts listening. Returns nullptr on success or a newly allocated error
// message (free with g_free) on failure.
gchar* x11_backend_start(X11Backend* self, VolumeButtonCallback callback,
                         gpointer user_data);

void x11_backend_stop(X11Backend* self);

gboolean x11_backend_is_active(X11Backend* self);

void x11_backend_free(X11Backend* self);

G_END_DECLS

#endif  // VOLUME_BUTTON_LISTENER_LINUX_X11_BACKEND_H_
