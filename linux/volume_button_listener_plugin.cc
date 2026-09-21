#include "include/volume_button_listener/volume_button_listener_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>

#include "evdev_backend.h"
#include "volume_button_backend.h"
#include "volume_button_listener_plugin_private.h"
#include "x11_backend.h"

#define VOLUME_BUTTON_LISTENER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), volume_button_listener_plugin_get_type(), \
                              VolumeButtonListenerPlugin))

enum class VolumeBackend {
  kNone,
  kX11,
  kEvdev,
};

struct _VolumeButtonListenerPlugin {
  GObject parent_instance;
  FlMethodChannel* channel;
  X11Backend* x11;
  EvdevBackend* evdev;
  VolumeBackend backend;
};

G_DEFINE_TYPE(VolumeButtonListenerPlugin, volume_button_listener_plugin, g_object_get_type())

bool volume_button_listener_is_wayland_session() {
  const gchar* wayland_display = g_getenv("WAYLAND_DISPLAY");
  if (wayland_display != nullptr && *wayland_display != '\0') {
    return true;
  }
  const gchar* session_type = g_getenv("XDG_SESSION_TYPE");
  if (session_type != nullptr &&
      g_ascii_strcasecmp(session_type, "wayland") == 0) {
    return true;
  }
  return false;
}

namespace {

void on_volume_button_event(gboolean is_volume_up, gboolean is_pressed,
                            gpointer user_data) {
  VolumeButtonListenerPlugin* self =
      VOLUME_BUTTON_LISTENER_PLUGIN(user_data);
  if (self->channel == nullptr) {
    return;
  }
  const gchar* method =
      is_pressed ? "onVolumeButtonPressed" : "onVolumeButtonReleased";
  g_autoptr(FlValue) args = fl_value_new_bool(is_volume_up);
  fl_method_channel_invoke_method(self->channel, method, args, nullptr, nullptr,
                                  nullptr);
}

FlMethodResponse* start_listener(VolumeButtonListenerPlugin* self) {
  if (self->backend != VolumeBackend::kNone) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  // On non-Wayland sessions a passive X11 grab works without extra permissions
  // and consumes the key.
  if (!volume_button_listener_is_wayland_session()) {
    g_autofree gchar* error =
        x11_backend_start(self->x11, on_volume_button_event, self);
    if (error == nullptr) {
      self->backend = VolumeBackend::kX11;
      return FL_METHOD_RESPONSE(fl_method_success_response_new(
          fl_value_new_string("x11")));
    }
  }

  // Otherwise grab dedicated volume-key devices exclusively so the compositor
  // never sees the key and the system volume is not changed.
  if (evdev_backend_start(self->evdev, on_volume_button_event, self)) {
    self->backend = VolumeBackend::kEvdev;
    return FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string("evdev")));
  }

  // Let the Dart layer fall back to observing system volume changes.
  return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "no_capture_backend",
      "No volume key capture backend is available", nullptr));
}

FlMethodResponse* stop_listener(VolumeButtonListenerPlugin* self) {
  x11_backend_stop(self->x11);
  evdev_backend_stop(self->evdev);
  self->backend = VolumeBackend::kNone;
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

}  // namespace

// Called when a method call is received from Flutter.
static void volume_button_listener_plugin_handle_method_call(
    VolumeButtonListenerPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "startListener") == 0) {
    response = start_listener(self);
  } else if (strcmp(method, "stopListener") == 0) {
    response = stop_listener(self);
  } else if (strcmp(method, "isListening") == 0) {
    g_autoptr(FlValue) result =
        fl_value_new_bool(self->backend != VolumeBackend::kNone);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void volume_button_listener_plugin_dispose(GObject* object) {
  VolumeButtonListenerPlugin* self = VOLUME_BUTTON_LISTENER_PLUGIN(object);
  stop_listener(self);
  g_clear_pointer(&self->x11, x11_backend_free);
  g_clear_pointer(&self->evdev, evdev_backend_free);
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(volume_button_listener_plugin_parent_class)->dispose(object);
}

static void volume_button_listener_plugin_class_init(VolumeButtonListenerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = volume_button_listener_plugin_dispose;
}

static void volume_button_listener_plugin_init(VolumeButtonListenerPlugin* self) {
  self->channel = nullptr;
  self->x11 = x11_backend_new();
  self->evdev = evdev_backend_new();
  self->backend = VolumeBackend::kNone;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  VolumeButtonListenerPlugin* plugin = VOLUME_BUTTON_LISTENER_PLUGIN(user_data);
  volume_button_listener_plugin_handle_method_call(plugin, method_call);
}

void volume_button_listener_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  VolumeButtonListenerPlugin* plugin = VOLUME_BUTTON_LISTENER_PLUGIN(
      g_object_new(volume_button_listener_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "volume_button_listener", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
