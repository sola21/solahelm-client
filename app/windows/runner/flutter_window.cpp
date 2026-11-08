#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include <optional>

#pragma comment(lib, "dwmapi.lib")

namespace {

// Popup menus (the tray menu) follow the dark theme only when the process
// opts in through uxtheme's undocumented SetPreferredAppMode (ordinal 135,
// Windows 10 1903+); FlushMenuThemes (136) applies it to existing menus.
// mode: 1 = follow the system, 2 = always dark, 3 = always light.
void SetMenuTheme(int mode) {
  HMODULE uxtheme = ::LoadLibraryExW(L"uxtheme.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (!uxtheme) return;
  using SetPreferredAppModeFn = int(WINAPI*)(int);
  using FlushMenuThemesFn = void(WINAPI*)();
  auto set_mode = reinterpret_cast<SetPreferredAppModeFn>(
      ::GetProcAddress(uxtheme, MAKEINTRESOURCEA(135)));
  auto flush = reinterpret_cast<FlushMenuThemesFn>(
      ::GetProcAddress(uxtheme, MAKEINTRESOURCEA(136)));
  if (set_mode) set_mode(mode);
  if (flush) flush();
}

}  // namespace

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // SolaHelm: until Dart says otherwise, menus follow the system theme.
  SetMenuTheme(1);
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "solahelm/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setDarkMode") {
          const auto* dark = std::get_if<bool>(call.arguments());
          if (!dark) {
            result->Error("bad-args", "expected a bool");
            return;
          }
          SetMenuTheme(*dark ? 2 : 3);
          BOOL value = *dark ? TRUE : FALSE;
          ::DwmSetWindowAttribute(GetHandle(), 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, &value,
                                  sizeof(value));
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  // SolaHelm: the window is shown from Dart (window_manager), so the app can
  // start hidden in the tray.
  flutter_controller_->engine()->SetNextFrameCallback([&]() {});

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
