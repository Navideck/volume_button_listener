#include "include/volume_button_listener/volume_button_listener_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "volume_button_listener_plugin.h"

void VolumeButtonListenerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  volume_button_listener::VolumeButtonListenerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
