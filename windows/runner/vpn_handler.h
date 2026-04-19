#ifndef RUNNER_VPN_HANDLER_H_
#define RUNNER_VPN_HANDLER_H_

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/encodable_value.h>
#include <windows.h>
#include <string>
#include <memory>
#include <atomic>
#include <thread>
#include <mutex>

class VpnHandler {
 public:
  static VpnHandler& Instance();
  
  void SetEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events);
  
  void Connect(const flutter::EncodableMap& config, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Disconnect(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetStatus(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  
  void OnListen(const flutter::EncodableValue* arguments,
                std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events);
  void OnCancel(const flutter::EncodableValue* arguments);
  
  // Platform channel handler
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  VpnHandler();
  ~VpnHandler();
  
  // v2ray-core 管理
  bool DownloadV2RayCore();
  bool GenerateConfig(const flutter::EncodableMap& config);
  bool StartV2RayProcess();
  void StopV2RayProcess();
  void MonitorProcess();
  void CollectTrafficStats();
  
  // 网络测试
  bool TestConnection();
  
  // Helper 函数
  std::string GetAppDataPath();
  std::string GetV2RayPath();
  std::string GetConfigPath();
  void SendEvent(const std::string& type, const flutter::EncodableMap& data);
  
  // 下载辅助
  bool DownloadFile(const std::string& url, const std::string& destPath);
  
  // 成员变量
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::atomic<bool> is_connected_{false};
  std::atomic<bool> is_running_{false};
  
  // 进程管理
  PROCESS_INFORMATION process_info_ = {};
  HANDLE process_handle_ = NULL;
  HANDLE job_handle_ = NULL;
  
  // 流量统计
  std::atomic<int64_t> upload_speed_{0};
  std::atomic<int64_t> download_speed_{0};
  std::atomic<int64_t> total_upload_{0};
  std::atomic<int64_t> total_download_{0};
  
  // 线程
  std::thread monitor_thread_;
  std::thread stats_thread_;
  std::mutex mutex_;
  
  // 路径
  std::string v2ray_path_;
  std::string config_path_;
  std::string working_dir_;
};

#endif  // RUNNER_VPN_HANDLER_H_
