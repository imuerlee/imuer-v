#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include "vpn_handler.h"
#include <flutter/basic_message_channel.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/standard_method_codec.h>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupVpnChannels();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

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

class VpnStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  VpnStreamHandler() {}

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
    VpnHandler::Instance().SetEventSink(std::move(events));
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override {
    VpnHandler::Instance().SetEventSink(nullptr);
    return nullptr;
  }
};

void FlutterWindow::SetupVpnChannels() {
  // Create method channel - use default codec
  vpn_method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "nebula_vpn/method");

  // Create event channel - use default codec
  vpn_event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "nebula_vpn/events");

  // Set method call handler
  vpn_method_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& method_call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        VpnHandler::Instance().HandleMethodCall(method_call, std::move(result));
      });

  // Set stream handler for event channel
  vpn_event_channel_->SetStreamHandler(std::make_unique<VpnStreamHandler>());
}
