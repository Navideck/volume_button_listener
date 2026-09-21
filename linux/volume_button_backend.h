#ifndef VOLUME_BUTTON_LISTENER_LINUX_VOLUME_BUTTON_BACKEND_H_
#define VOLUME_BUTTON_LISTENER_LINUX_VOLUME_BUTTON_BACKEND_H_

#include <glib.h>

G_BEGIN_DECLS

// Reports a volume button state change to the plugin.
typedef void (*VolumeButtonCallback)(gboolean is_volume_up, gboolean is_pressed,
                                     gpointer user_data);

G_END_DECLS

#endif  // VOLUME_BUTTON_LISTENER_LINUX_VOLUME_BUTTON_BACKEND_H_
