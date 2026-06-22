#ifndef FLUTTER_PLUGIN_VOLUME_BUTTON_LISTENER_PLUGIN_H_
#define FLUTTER_PLUGIN_VOLUME_BUTTON_LISTENER_PLUGIN_H_

#include "volume_button_listener.g.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <iostream>
#include <memory>

namespace volume_button_listener {

class VolumeButtonListenerPlugin : public flutter::Plugin,
                                   public VolumeButtonListenerPlatformChannel {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  VolumeButtonListenerPlugin(flutter::PluginRegistrarWindows *registrar);

  virtual ~VolumeButtonListenerPlugin();

  VolumeButtonListenerPlugin(const VolumeButtonListenerPlugin &) = delete;
  VolumeButtonListenerPlugin &
  operator=(const VolumeButtonListenerPlugin &) = delete;

private:
  flutter::PluginRegistrarWindows *registrar_;

  // VolumeButtonListenerPlatformChannel implementation.
  std::optional<FlutterError> StartListener() override;
  std::optional<FlutterError> SetShowVolumeUi(bool show_volume_ui) override;
  std::optional<FlutterError> StopListener() override;
  ErrorOr<bool> IsListening() override;
  ErrorOr<double> GetVolume() override;
  std::optional<FlutterError> SetVolume(double volume) override;
};

} // namespace volume_button_listener

#endif // FLUTTER_PLUGIN_VOLUME_BUTTON_LISTENER_PLUGIN_H_
