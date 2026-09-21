#include "x11_backend.h"

#include <glib-unix.h>

#include <X11/XKBlib.h>
#include <X11/XF86keysym.h>
#include <X11/Xlib.h>

#include <cstring>

struct _X11Backend {
  Display* display;
  Window root;
  int up_keycode;
  int down_keycode;
  guint event_source_id;
  VolumeButtonCallback callback;
  gpointer callback_data;
};

namespace {

gboolean g_x_error_occurred = FALSE;

int x_error_handler(Display* display, XErrorEvent* event) {
  (void)display;
  if (event->error_code == BadAccess || event->error_code == BadValue) {
    g_x_error_occurred = TRUE;
  }
  return 0;
}

gboolean on_x11_event(gint, GIOCondition condition, gpointer user_data) {
  X11Backend* self = static_cast<X11Backend*>(user_data);
  if (self->display == nullptr) {
    return FALSE;
  }
  if ((condition & G_IO_IN) == 0) {
    return TRUE;
  }
  while (XPending(self->display) > 0) {
    XEvent event;
    XNextEvent(self->display, &event);
    if (event.type != KeyPress && event.type != KeyRelease) {
      continue;
    }
    const int keycode = event.xkey.keycode;
    if (keycode != self->up_keycode && keycode != self->down_keycode) {
      continue;
    }
    if (self->callback != nullptr) {
      self->callback(keycode == self->up_keycode, event.type == KeyPress,
                     self->callback_data);
    }
  }
  return TRUE;
}

}  // namespace

X11Backend* x11_backend_new() {
  return g_new0(X11Backend, 1);
}

gchar* x11_backend_start(X11Backend* self, VolumeButtonCallback callback,
                         gpointer user_data) {
  Display* display = XOpenDisplay(nullptr);
  if (display == nullptr) {
    return g_strdup("Failed to open X display");
  }

  Window root = DefaultRootWindow(display);
  int up_keycode = XKeysymToKeycode(display, XF86XK_AudioRaiseVolume);
  int down_keycode = XKeysymToKeycode(display, XF86XK_AudioLowerVolume);
  if (up_keycode == 0 || down_keycode == 0) {
    XCloseDisplay(display);
    return g_strdup("Volume keys are not mapped in the current keyboard layout");
  }

  // Detectable auto-repeat ensures a held key produces a single KeyPress and a
  // single KeyRelease, which the long-press logic in Dart relies on.
  Bool detectable_repeat = False;
  XkbSetDetectableAutoRepeat(display, True, &detectable_repeat);

  g_x_error_occurred = FALSE;
  XErrorHandler previous_handler = XSetErrorHandler(x_error_handler);
  XGrabKey(display, up_keycode, AnyModifier, root, False, GrabModeAsync,
           GrabModeAsync);
  XGrabKey(display, down_keycode, AnyModifier, root, False, GrabModeAsync,
           GrabModeAsync);
  XSync(display, False);
  XSetErrorHandler(previous_handler);

  if (g_x_error_occurred) {
    XUngrabKey(display, up_keycode, AnyModifier, root);
    XUngrabKey(display, down_keycode, AnyModifier, root);
    XSync(display, False);
    XCloseDisplay(display);
    return g_strdup("Another application is already grabbing the volume keys");
  }

  self->display = display;
  self->root = root;
  self->up_keycode = up_keycode;
  self->down_keycode = down_keycode;
  self->callback = callback;
  self->callback_data = user_data;
  self->event_source_id =
      g_unix_fd_add(ConnectionNumber(display), G_IO_IN, on_x11_event, self);
  return nullptr;
}

void x11_backend_stop(X11Backend* self) {
  if (self->event_source_id != 0) {
    g_source_remove(self->event_source_id);
    self->event_source_id = 0;
  }
  if (self->display != nullptr) {
    XUngrabKey(self->display, self->up_keycode, AnyModifier, self->root);
    XUngrabKey(self->display, self->down_keycode, AnyModifier, self->root);
    XSync(self->display, False);
    XCloseDisplay(self->display);
    self->display = nullptr;
  }
  self->callback = nullptr;
  self->callback_data = nullptr;
}

gboolean x11_backend_is_active(X11Backend* self) {
  return self->display != nullptr;
}

void x11_backend_free(X11Backend* self) {
  if (self == nullptr) {
    return;
  }
  x11_backend_stop(self);
  g_free(self);
}
