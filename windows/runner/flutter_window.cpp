#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "vpn_handler.h"

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

  // Setup VPN platform channels
  SetupVpnChannels();

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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetupVpnChannels() {
  // Create method channel
  vpn_method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "nebula_vpn/method",
      &flutter::StandardMethodCodec::GetInstance());

  // Create event channel
  vpn_event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "nebula_vpn/events",
      &flutter::StandardMethodCodec::GetInstance());

  // Set method call handler
  vpn_method_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& method_call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        VpnHandler::Instance().HandleMethodCall(method_call, std::move(result));
      });

  // Set stream handler for event channel
  vpn_event_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<>>(
          [](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            VpnHandler::Instance().OnListen(arguments, std::move(events));
            return nullptr;
          },
          [](const flutter::EncodableValue* arguments)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            VpnHandler::Instance().OnCancel(arguments);
            return nullptr;
          }));
}
