#include "flutter_window.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {
// Doit correspondre exactement au nom utilisé côté Dart
// (native_channel_service.dart).
constexpr char kNativeChannelName[] = "malistock/native";
}  // namespace

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

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
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
    case WM_COPYDATA: {
      // Une autre tentative de lancement de MaliStock Pro (double-clic sur
      // un .mstk pendant que cette instance tourne déjà) a transmis un
      // chemin de fichier via main.cpp (ForwardToExistingInstance).
      auto* cds = reinterpret_cast<COPYDATASTRUCT*>(lparam);
      if (cds != nullptr && cds->lpData != nullptr && flutter_controller_) {
        auto file_path =
            std::wstring(reinterpret_cast<wchar_t*>(cds->lpData));
        flutter::MethodChannel<flutter::EncodableValue> channel(
            flutter_controller_->engine()->messenger(), kNativeChannelName,
            &flutter::StandardMethodCodec::GetInstance());
        channel.InvokeMethod(
            "openFileRequested",
            std::make_unique<flutter::EncodableValue>(
                Utf8FromUtf16(file_path.c_str())));
      }
      return TRUE;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
