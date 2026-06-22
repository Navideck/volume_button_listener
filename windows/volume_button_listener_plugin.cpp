#include "volume_button_listener_plugin.h"
#include "volume_button_listener.g.h"
#include <comdef.h>
#include <endpointvolume.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <mmdeviceapi.h>
#include <windows.h>

static std::unique_ptr<
    volume_button_listener::VolumeButtonListenerCallbackChannel>
    callback_channel;

namespace volume_button_listener {

// Low-level keyboard hook state for volume key grab
namespace {
constexpr int kVolumeUpVk = 0xAF;   // VK_VOLUME_UP
constexpr int kVolumeDownVk = 0xAE; // VK_VOLUME_DOWN

HHOOK g_keyboard_hook = nullptr;
bool g_show_volume_ui = false;

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode != HC_ACTION || !callback_channel) {
    return CallNextHookEx(g_keyboard_hook, nCode, wParam, lParam);
  }

  auto *p = reinterpret_cast<KBDLLHOOKSTRUCT *>(lParam);
  const int vk = static_cast<int>(p->vkCode);
  const bool is_volume_up = (vk == kVolumeUpVk);
  const bool is_volume_key = is_volume_up || (vk == kVolumeDownVk);

  if (!is_volume_key) {
    return CallNextHookEx(g_keyboard_hook, nCode, wParam, lParam);
  }

  if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) {
    callback_channel->OnVolumeButtonPressed(
        is_volume_up, []() {}, [](const FlutterError &) {});
  } else if (wParam == WM_KEYUP || wParam == WM_SYSKEYUP) {
    callback_channel->OnVolumeButtonReleased(
        is_volume_up, []() {}, [](const FlutterError &) {});
  }

  // Consume key (block OS handling) when not showing volume UI
  if (!g_show_volume_ui) {
    return 1;
  }
  return CallNextHookEx(g_keyboard_hook, nCode, wParam, lParam);
}
} // namespace

void VolumeButtonListenerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<VolumeButtonListenerPlugin>(registrar);
  SetUp(registrar->messenger(), plugin.get());
  callback_channel = std::make_unique<VolumeButtonListenerCallbackChannel>(
      registrar->messenger());
  registrar->AddPlugin(std::move(plugin));
}

VolumeButtonListenerPlugin::VolumeButtonListenerPlugin(
    flutter::PluginRegistrarWindows *registrar) {}

VolumeButtonListenerPlugin::~VolumeButtonListenerPlugin() {
  if (g_keyboard_hook != nullptr) {
    UnhookWindowsHookEx(g_keyboard_hook);
    g_keyboard_hook = nullptr;
  }
}

std::optional<FlutterError>
VolumeButtonListenerPlugin::StartListener() {
  if (g_keyboard_hook != nullptr) {
    return std::nullopt; // Already listening
  }
  HMODULE hMod = nullptr;
  if (!GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
                          reinterpret_cast<LPCSTR>(&LowLevelKeyboardProc),
                          &hMod)) {
    hMod = nullptr;
  }
  g_keyboard_hook =
      SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, hMod, 0);
  if (g_keyboard_hook == nullptr) {
    return FlutterError("hook_error", "SetWindowsHookEx failed");
  }
  return std::nullopt;
}

std::optional<FlutterError>
VolumeButtonListenerPlugin::SetShowVolumeUi(bool show_volume_ui) {
  g_show_volume_ui = show_volume_ui;
  return std::nullopt;
}

std::optional<FlutterError> VolumeButtonListenerPlugin::StopListener() {
  if (g_keyboard_hook != nullptr) {
    UnhookWindowsHookEx(g_keyboard_hook);
    g_keyboard_hook = nullptr;
  }
  return std::nullopt;
}

ErrorOr<bool> VolumeButtonListenerPlugin::IsListening() {
  return g_keyboard_hook != nullptr;
}

static bool EnsureComInitialized() {
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  return (hr == S_OK || hr == S_FALSE);
}

static IAudioEndpointVolume *GetEndpointVolume() {
  if (!EnsureComInitialized()) {
    return nullptr;
  }
  IMMDeviceEnumerator *enumerator = nullptr;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                                reinterpret_cast<void **>(&enumerator));
  if (FAILED(hr) || !enumerator) {
    return nullptr;
  }
  IMMDevice *device = nullptr;
  hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
  enumerator->Release();
  if (FAILED(hr) || !device) {
    return nullptr;
  }
  IAudioEndpointVolume *endpoint_volume = nullptr;
  hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                        reinterpret_cast<void **>(&endpoint_volume));
  device->Release();
  if (FAILED(hr) || !endpoint_volume) {
    return nullptr;
  }
  return endpoint_volume;
}

ErrorOr<double> VolumeButtonListenerPlugin::GetVolume() {
  IAudioEndpointVolume *ev = GetEndpointVolume();
  if (!ev) {
    return FlutterError("audio_error", "Failed to get audio endpoint volume");
  }
  float level = 0.0f;
  HRESULT hr = ev->GetMasterVolumeLevelScalar(&level);
  ev->Release();
  if (FAILED(hr)) {
    return FlutterError("audio_error", "GetMasterVolumeLevelScalar failed");
  }
  return static_cast<double>(level);
}

std::optional<FlutterError>
VolumeButtonListenerPlugin::SetVolume(double volume) {
  double v = volume;
  if (v < 0.0)
    v = 0.0;
  if (v > 1.0)
    v = 1.0;
  IAudioEndpointVolume *ev = GetEndpointVolume();
  if (!ev) {
    return FlutterError("audio_error", "Failed to get audio endpoint volume");
  }
  HRESULT hr = ev->SetMasterVolumeLevelScalar(static_cast<float>(v), nullptr);
  ev->Release();
  if (FAILED(hr)) {
    return FlutterError("audio_error", "SetMasterVolumeLevelScalar failed");
  }
  return std::nullopt;
}

} // namespace volume_button_listener
