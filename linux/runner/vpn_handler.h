#ifndef RUNNER_VPN_HANDLER_H_
#define RUNNER_VPN_HANDLER_H_

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/encodable_value.h>

#include <string>
#include <memory>
#include <atomic>
#include <thread>
#include <mutex>
#include <cstdint>

class VpnHandler {
 public:
  static VpnHandler& Instance();
  
  void SetEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events);
  
  void Connect(flutter::EncodableMap config,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Disconnect(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetStatus(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  
  void OnListen(const flutter::EncodableValue* arguments,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events);
  void OnCancel(const flutter::EncodableValue* arguments);
  
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  VpnHandler();
  ~VpnHandler();
  
  bool PrepareV2Ray();
  bool GenerateConfig(const flutter::EncodableMap& config);
  bool StartV2RayProcess();
  void StopV2RayProcess();
  void MonitorProcess();
  void CollectTrafficStats();
  bool TestConnection();
  
  std::string GetConfigPath();
  std::string GetV2RayPath();
  std::string GetWorkingDir();
  void SendEvent(const std::string& type, const flutter::EncodableMap& data);
  
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::atomic<bool> is_connected_{false};
  std::atomic<bool> is_running_{false};
  
  pid_t v2ray_pid_ = -1;
  
  std::atomic<int64_t> upload_speed_{0};
  std::atomic<int64_t> download_speed_{0};
  std::atomic<int64_t> total_upload_{0};
  std::atomic<int64_t> total_download_{0};
  
  std::thread monitor_thread_;
  std::thread stats_thread_;
  std::mutex mutex_;
  
  std::string v2ray_path_;
  std::string config_path_;
  std::string working_dir_;
};

#endif  // RUNNER_VPN_HANDLER_H_
