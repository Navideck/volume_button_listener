#include "evdev_backend.h"

#include <glib-unix.h>

#include <fcntl.h>
#include <linux/input.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <cerrno>

#include "evdev_repeat_coalescer.h"

struct _EvdevBackend;

struct EvdevDevice {
  EvdevBackend* backend;
  gint fd;
  guint source_id;
};

// Passed to each key's release timer so the callback knows which key elapsed.
struct ReleaseTimerContext {
  EvdevBackend* backend;
  bool is_volume_up;
};

struct _EvdevBackend {
  GPtrArray* devices;
  volume_button_listener::EvdevRepeatCoalescer* coalescer;
  VolumeButtonCallback callback;
  gpointer callback_data;
  // Release timers per volume key (index 0 = down, 1 = up).
  guint release_timer[2];
  ReleaseTimerContext release_context[2];
};

namespace {

void report(EvdevBackend* self, bool is_volume_up, bool is_pressed) {
  if (self->callback != nullptr) {
    self->callback(is_volume_up, is_pressed, self->callback_data);
  }
}

// Never grab a regular keyboard; grabbing one would block all typing.
bool is_grabbable(gint fd) {
  guint8 key_bits[(KEY_MAX / 8) + 1] = {0};
  if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(key_bits)), key_bits) < 0) {
    return false;
  }
  const bool has_volume_up =
      key_bits[KEY_VOLUMEUP / 8] & (1 << (KEY_VOLUMEUP % 8));
  const bool has_volume_down =
      key_bits[KEY_VOLUMEDOWN / 8] & (1 << (KEY_VOLUMEDOWN % 8));
  const bool is_keyboard = key_bits[KEY_A / 8] & (1 << (KEY_A % 8));
  return (has_volume_up || has_volume_down) && !is_keyboard;
}

gboolean on_release_timer(gpointer user_data) {
  ReleaseTimerContext* context =
      static_cast<ReleaseTimerContext*>(user_data);
  EvdevBackend* self = context->backend;
  self->release_timer[context->is_volume_up ? 1 : 0] = 0;
  if (self->coalescer->TakeRelease(context->is_volume_up)) {
    report(self, context->is_volume_up, false);
  }
  return G_SOURCE_REMOVE;
}

void schedule_release(EvdevBackend* self, bool is_volume_up) {
  const int index = is_volume_up ? 1 : 0;
  if (self->release_timer[index] != 0) {
    g_source_remove(self->release_timer[index]);
  }
  const guint delay_ms = static_cast<guint>(
      volume_button_listener::EvdevRepeatCoalescer::kReleaseDelayUs / 1000);
  self->release_timer[index] =
      g_timeout_add(delay_ms, on_release_timer, &self->release_context[index]);
}

gboolean on_evdev_event(gint fd, GIOCondition condition, gpointer user_data) {
  EvdevDevice* device = static_cast<EvdevDevice*>(user_data);
  if ((condition & G_IO_IN) == 0) {
    return TRUE;
  }

  struct input_event events[64];
  const ssize_t bytes = read(fd, events, sizeof(events));
  if (bytes < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
      return TRUE;
    }
    close(fd);
    device->fd = -1;
    device->source_id = 0;
    return FALSE;
  }
  if (bytes == 0) {
    return TRUE;
  }

  EvdevBackend* self = device->backend;
  const ssize_t count =
      bytes / static_cast<ssize_t>(sizeof(struct input_event));
  for (ssize_t i = 0; i < count; ++i) {
    if (events[i].type != EV_KEY) {
      continue;
    }
    const guint16 code = events[i].code;
    if (code != KEY_VOLUMEUP && code != KEY_VOLUMEDOWN) {
      continue;
    }
    if (events[i].value != 1) {
      // Releases are handled by the coalescing timer; value 2 is a plain
      // auto-repeat.
      continue;
    }
    const int64_t event_time_us =
        static_cast<int64_t>(events[i].time.tv_sec) * 1000000 +
        events[i].time.tv_usec;
    const bool is_volume_up = code == KEY_VOLUMEUP;
    if (self->coalescer->OnPress(is_volume_up, event_time_us)) {
      report(self, is_volume_up, true);
    }
    schedule_release(self, is_volume_up);
  }
  return TRUE;
}

}  // namespace

EvdevBackend* evdev_backend_new() {
  EvdevBackend* self = g_new0(EvdevBackend, 1);
  self->devices = g_ptr_array_new_with_free_func(g_free);
  self->coalescer = new volume_button_listener::EvdevRepeatCoalescer();
  for (int index = 0; index < 2; ++index) {
    self->release_context[index].backend = self;
    self->release_context[index].is_volume_up = index == 1;
  }
  return self;
}

gboolean evdev_backend_start(EvdevBackend* self, VolumeButtonCallback callback,
                             gpointer user_data) {
  self->callback = callback;
  self->callback_data = user_data;
  for (int i = 0; i < 64; ++i) {
    g_autofree gchar* path = g_strdup_printf("/dev/input/event%d", i);
    const int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) {
      continue;
    }
    if (!is_grabbable(fd) || ioctl(fd, EVIOCGRAB, 1) < 0) {
      close(fd);
      continue;
    }
    EvdevDevice* device = g_new0(EvdevDevice, 1);
    device->backend = self;
    device->fd = fd;
    device->source_id = g_unix_fd_add(fd, G_IO_IN, on_evdev_event, device);
    g_ptr_array_add(self->devices, device);
  }
  return self->devices->len > 0;
}

void evdev_backend_stop(EvdevBackend* self) {
  for (int index = 0; index < 2; ++index) {
    if (self->release_timer[index] != 0) {
      g_source_remove(self->release_timer[index]);
      self->release_timer[index] = 0;
    }
  }
  self->coalescer->Reset();
  for (guint i = 0; i < self->devices->len; ++i) {
    EvdevDevice* device =
        static_cast<EvdevDevice*>(g_ptr_array_index(self->devices, i));
    if (device->source_id != 0) {
      g_source_remove(device->source_id);
    }
    if (device->fd >= 0) {
      ioctl(device->fd, EVIOCGRAB, 0);
      close(device->fd);
    }
  }
  g_ptr_array_set_size(self->devices, 0);
  self->callback = nullptr;
  self->callback_data = nullptr;
}

gboolean evdev_backend_is_active(EvdevBackend* self) {
  return self->devices->len > 0;
}

void evdev_backend_free(EvdevBackend* self) {
  if (self == nullptr) {
    return;
  }
  evdev_backend_stop(self);
  g_ptr_array_unref(self->devices);
  delete self->coalescer;
  g_free(self);
}
