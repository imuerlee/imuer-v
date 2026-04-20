#include "vpn_handler.h"
#include <flutter/standard_method_codec.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <chrono>
#include <map>

#define WIN32_LEAN_AND_MEAN
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <winhttp.h>
#include <shlwapi.h>
#include <psapi.h>
#include <iphlpapi.h>

#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")

namespace {
  constexpr const char* V2RAY_VERSION = "v5.22.0";
  constexpr const int STATS_INTERVAL_MS = 1000;
  constexpr const int CONNECTION_TIMEOUT_MS = 5000;
  constexpr const int HTTP_TIMEOUT_MS = 10000;
}

inline void LogDebug(const char* tag, const char* msg) { 
  OutputDebugStringA((std::string("[") + tag + "] " + msg + "\n").c_str()); 
}
inline void LogDebugStr(const char* tag, const std::string& msg) { 
  OutputDebugStringA((std::string("[") + tag + "] " + msg + "\n").c_str()); 
}
inline void LogError(const char* tag, const char* msg) { 
  OutputDebugStringA((std::string("[ERROR][") + tag + "] " + msg + "\n").c_str()); 
}
inline void LogErrorStr(const char* tag, const std::string& msg) { 
  OutputDebugStringA((std::string("[ERROR][") + tag + "] " + msg + "\n").c_str()); 
}

#define LOGD(tag, msg) LogDebug(tag, msg)
#define LOGD_STR(tag, msg) LogDebugStr(tag, msg)
#define LOGE(tag, msg) LogError(tag, msg)
#define LOGE_STR(tag, msg) LogErrorStr(tag, msg)

VpnHandler& VpnHandler::Instance() {
  static VpnHandler instance;
  return instance;
}

VpnHandler::VpnHandler() {
  LOGD("VpnHandler", "Constructor: starting");
  
  working_dir_ = GetAppDataPath();
  v2ray_path_ = GetV2RayPath();
  config_path_ = GetConfigPath();
  
  LOGD_STR("VpnHandler", "Constructor: working_dir_ = " + working_dir_);
  LOGD_STR("VpnHandler", "Constructor: v2ray_path_ = " + v2ray_path_);
  LOGD_STR("VpnHandler", "Constructor: config_path_ = " + config_path_);
  
  // 确保工作目录存在
  if (!PathFileExistsA(working_dir_.c_str())) {
    LOGD_STR("VpnHandler", "Constructor: creating working directory: " + working_dir_);
    BOOL created = CreateDirectoryA(working_dir_.c_str(), NULL);
    if (created) {
      LOGD("VpnHandler", "Constructor: working directory created successfully");
    } else {
      DWORD err = GetLastError();
      LOGE_STR("VpnHandler", "Constructor: failed to create working directory, error=" + std::to_string(err));
    }
  } else {
    LOGD("VpnHandler", "Constructor: working directory already exists");
  }
  
  LOGD("VpnHandler", "Constructor: completed");
}

VpnHandler::~VpnHandler() {
  LOGD("VpnHandler", "Destructor: starting");
  
  StopV2RayProcess();
  LOGD("VpnHandler", "Destructor: stopped v2ray process");
  
  if (monitor_thread_.joinable()) {
    LOGD("VpnHandler", "Destructor: joining monitor_thread");
    monitor_thread_.join();
  }
  if (stats_thread_.joinable()) {
    LOGD("VpnHandler", "Destructor: joining stats_thread");
    stats_thread_.join();
  }
  
  LOGD("VpnHandler", "Destructor: completed");
}

void VpnHandler::SetEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  LOGD("VpnHandler", "SetEventSink: starting");
  
  std::lock_guard<std::mutex> lock(mutex_);
  event_sink_ = std::move(events);
  
  if (event_sink_) {
    LOGD("VpnHandler", "SetEventSink: event_sink set successfully");
  } else {
    LOGD("VpnHandler", "SetEventSink: event_sink is null");
  }
}

void VpnHandler::OnListen(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  LOGD("VpnHandler", "OnListen: starting");
  std::string argsStr = arguments ? "not null" : "null";
  LOGD_STR("VpnHandler", std::string("OnListen: arguments=") + argsStr);
  SetEventSink(std::move(events));
  LOGD("VpnHandler", "OnListen: completed");
}

void VpnHandler::OnCancel(const flutter::EncodableValue* arguments) {
  LOGD("VpnHandler", "OnCancel: starting");
  std::string argsStr = arguments ? "not null" : "null";
  LOGD_STR("VpnHandler", std::string("OnCancel: arguments=") + argsStr);
  
  std::lock_guard<std::mutex> lock(mutex_);
  event_sink_.reset();
  
  LOGD("VpnHandler", "OnCancel: event_sink reset");
  LOGD("VpnHandler", "OnCancel: completed");
}

void VpnHandler::SendEvent(const std::string& type, const flutter::EncodableMap& data) {
  LOGD_STR("VpnHandler", "SendEvent: type=" + type);
  LOGD_STR("VpnHandler", "SendEvent: data size=" + std::to_string(data.size()));
  
  std::lock_guard<std::mutex> lock(mutex_);
  
  if (!event_sink_) {
    LOGD("VpnHandler", "SendEvent: event_sink is null, skipping");
    return;
  }
  
  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue(type);
  
  for (const auto& [key, value] : data) {
    event[key] = value;
    std::string keyStr = "unknown";
    if (std::holds_alternative<std::string>(key)) {
      keyStr = std::get<std::string>(key);
    } else if (std::holds_alternative<int>(key)) {
      keyStr = std::to_string(std::get<int>(key));
    }
    LOGD_STR("VpnHandler", "SendEvent:   [" + keyStr + "]");
  }
  
  LOGD("VpnHandler", "SendEvent: sending event to flutter");
  event_sink_->Success(flutter::EncodableValue(event));
  LOGD("VpnHandler", "SendEvent: event sent successfully");
}

void VpnHandler::Connect(
    flutter::EncodableMap config,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  LOGD("Connect", "========== CONNECT START ==========");
  LOGD_STR("Connect", "config size=" + std::to_string(config.size()));
  
  // 打印所有配置参数
  LOGD("Connect", "---- Config Parameters ----");
  for (const auto& [key, value] : config) {
    std::string keyStr = "unknown";
    std::string valueStr = "unknown";
    
    if (std::holds_alternative<std::string>(key)) {
      keyStr = std::get<std::string>(key);
    } else if (std::holds_alternative<int>(key)) {
      keyStr = std::to_string(std::get<int>(key));
    }
    
    if (std::holds_alternative<std::string>(value)) {
      valueStr = std::get<std::string>(value);
    } else if (std::holds_alternative<int>(value)) {
      valueStr = std::to_string(std::get<int>(value));
    } else if (std::holds_alternative<double>(value)) {
      valueStr = std::to_string(std::get<double>(value));
    } else if (std::holds_alternative<bool>(value)) {
      valueStr = std::get<bool>(value) ? "true" : "false";
    }
    
    LOGD_STR("Connect", "  " + keyStr + " = " + valueStr);
  }
  LOGD("Connect", "----------------------------");
  
  std::thread([this, config, result = std::move(result)]() mutable {
    try {
      LOGD("Connect", "Connect: thread started");
      std::lock_guard<std::mutex> lock(mutex_);
      
      LOGD("Connect", "Connect: checking is_running_");
      if (is_running_) {
        LOGE("Connect", "Connect: v2ray-core is already running!");
        result->Error("ALREADY_RUNNING", "v2ray-core is already running");
        return;
      }
      LOGD("Connect", "Connect: is_running_ is false, proceeding");
      
      LOGD("Connect", "Connect: sending 'connecting' event");
      SendEvent("connecting", flutter::EncodableMap{});
      
      // 步骤 1: 检查/下载 v2ray-core
      LOGD("Connect", "Connect: ===== STEP 1: DownloadV2RayCore =====");
      if (!DownloadV2RayCore()) {
        LOGE("Connect", "Connect: DownloadV2RayCore FAILED!");
        SendEvent("error", {
          {flutter::EncodableValue("message"), flutter::EncodableValue("Failed to download v2ray-core")}
        });
        result->Error("DOWNLOAD_FAILED", "Failed to download v2ray-core");
        return;
      }
      LOGD("Connect", "Connect: DownloadV2RayCore SUCCESS");
      
      // 步骤 2: 生成配置文件
      LOGD("Connect", "Connect: ===== STEP 2: GenerateConfig =====");
      LOGD("Connect", "Connect: generating config with parameters:");
      for (const auto& [key, value] : config) {
        std::string keyStr = "unknown", valueStr = "unknown";
        if (std::holds_alternative<std::string>(key)) keyStr = std::get<std::string>(key);
        if (std::holds_alternative<std::string>(value)) valueStr = std::get<std::string>(value);
        else if (std::holds_alternative<int>(value)) valueStr = std::to_string(std::get<int>(value));
        LOGD_STR("Connect", "Connect:   " + keyStr + " = " + valueStr);
      }
      
      if (!GenerateConfig(config)) {
        LOGE("Connect", "Connect: GenerateConfig FAILED!");
        SendEvent("error", {
          {flutter::EncodableValue("message"), flutter::EncodableValue("Failed to generate config")}
        });
        result->Error("CONFIG_ERROR", "Failed to generate configuration");
        return;
      }
      LOGD("Connect", "Connect: GenerateConfig SUCCESS");
      
      // 步骤 3: 启动 v2ray-core 进程
      LOGD("Connect", "Connect: ===== STEP 3: StartV2RayProcess =====");
      if (!StartV2RayProcess()) {
        LOGE("Connect", "Connect: StartV2RayProcess FAILED!");
        SendEvent("error", {
          {flutter::EncodableValue("message"), flutter::EncodableValue("Failed to start v2ray-core")}
        });
        result->Error("START_FAILED", "Failed to start v2ray-core");
        return;
      }
      LOGD("Connect", "Connect: StartV2RayProcess SUCCESS");
      
      // 步骤 4: 等待启动并测试连接
      LOGD("Connect", "Connect: ===== STEP 4: TestConnection =====");
      LOGD("Connect", "Connect: waiting 2 seconds for v2ray to start...");
      std::this_thread::sleep_for(std::chrono::seconds(2));
      
      bool connectionOk = TestConnection();
      
      if (!connectionOk) {
        LOGE("Connect", "Connect: TestConnection FAILED!");
        LOGD("Connect", "Connect: stopping v2ray process due to connection test failure");
        StopV2RayProcess();
        SendEvent("error", {
          {flutter::EncodableValue("message"), flutter::EncodableValue("Connection test failed")}
        });
        result->Error("CONNECTION_FAILED", "Connection test failed");
        return;
      }
      LOGD("Connect", "Connect: TestConnection SUCCESS");
      
      // 启动监控和统计线程
      LOGD("Connect", "Connect: setting is_running_=true, is_connected_=true");
      is_running_ = true;
      is_connected_ = true;
      
      LOGD("Connect", "Connect: starting monitor thread");
      monitor_thread_ = std::thread(&VpnHandler::MonitorProcess, this);
      
      LOGD("Connect", "Connect: starting stats thread");
      stats_thread_ = std::thread(&VpnHandler::CollectTrafficStats, this);
      
      // 发送连接成功事件
      LOGD("Connect", "Connect: sending 'connected' event");
      SendEvent("connected", {
        {flutter::EncodableValue("message"), flutter::EncodableValue("VPN connected successfully")}
      });
      
      LOGD("Connect", "========== CONNECT SUCCESS ==========");
      result->Success(flutter::EncodableValue(true));
      
    } catch (const std::exception& e) {
      LOGE_STR("Connect", "Connect: EXCEPTION: " + std::string(e.what()));
      SendEvent("error", {
        {flutter::EncodableValue("message"), flutter::EncodableValue(e.what())}
      });
      result->Error("EXCEPTION", e.what());
    } catch (...) {
      LOGE("Connect", "Connect: UNKNOWN EXCEPTION!");
      SendEvent("error", {
        {flutter::EncodableValue("message"), flutter::EncodableValue("Unknown error occurred")}
      });
      result->Error("UNKNOWN_ERROR", "Unknown error occurred");
    }
  }).detach();
}

void VpnHandler::Disconnect(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  LOGD("Disconnect", "========== DISCONNECT START ==========");
  LOGD("Disconnect", "Disconnect: acquiring mutex lock");
  std::lock_guard<std::mutex> lock(mutex_);
  
  LOGD_STR("Disconnect", "Disconnect: is_running_=" + std::to_string(is_running_.load()));
  LOGD_STR("Disconnect", "Disconnect: is_connected_=" + std::to_string(is_connected_.load()));
  
  if (!is_running_) {
    LOGD("Disconnect", "Disconnect: not running, returning success immediately");
    result->Success(flutter::EncodableValue(true));
    return;
  }
  
  LOGD("Disconnect", "Disconnect: sending 'disconnecting' event");
  SendEvent("disconnecting", flutter::EncodableMap{});
  
  LOGD("Disconnect", "Disconnect: calling StopV2RayProcess");
  StopV2RayProcess();
  
  LOGD("Disconnect", "Disconnect: resetting state variables");
  is_running_ = false;
  is_connected_ = false;
  upload_speed_ = 0;
  download_speed_ = 0;
  total_upload_ = 0;
  total_download_ = 0;
  
  LOGD("Disconnect", "Disconnect: sending 'disconnected' event");
  SendEvent("disconnected", flutter::EncodableMap{});
  
  LOGD("Disconnect", "Disconnect: returning success");
  result->Success(flutter::EncodableValue(true));
  LOGD("Disconnect", "========== DISCONNECT COMPLETE ==========");
}

void VpnHandler::GetStatus(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  LOGD("GetStatus", "========== GET STATUS START ==========");
  LOGD("GetStatus", "GetStatus: acquiring mutex lock");
  std::lock_guard<std::mutex> lock(mutex_);
  
  flutter::EncodableMap status;
  
  bool connected = is_connected_.load();
  bool running = is_running_.load();
  int64_t upSpeed = upload_speed_.load();
  int64_t downSpeed = download_speed_.load();
  int64_t totalUp = total_upload_.load();
  int64_t totalDown = total_download_.load();
  
  LOGD_STR("GetStatus", "GetStatus: connected=" + std::to_string(connected));
  LOGD_STR("GetStatus", "GetStatus: running=" + std::to_string(running));
  LOGD_STR("GetStatus", "GetStatus: uploadSpeed=" + std::to_string(upSpeed));
  LOGD_STR("GetStatus", "GetStatus: downloadSpeed=" + std::to_string(downSpeed));
  LOGD_STR("GetStatus", "GetStatus: totalUpload=" + std::to_string(totalUp));
  LOGD_STR("GetStatus", "GetStatus: totalDownload=" + std::to_string(totalDown));
  
  status[flutter::EncodableValue("connected")] = flutter::EncodableValue(connected);
  status[flutter::EncodableValue("running")] = flutter::EncodableValue(running);
  status[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(upSpeed);
  status[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(downSpeed);
  status[flutter::EncodableValue("totalUpload")] = flutter::EncodableValue(totalUp);
  status[flutter::EncodableValue("totalDownload")] = flutter::EncodableValue(totalDown);
  
  LOGD("GetStatus", "GetStatus: returning status to flutter");
  result->Success(flutter::EncodableValue(status));
  LOGD("GetStatus", "========== GET STATUS COMPLETE ==========");
}

bool VpnHandler::DownloadV2RayCore() {
  LOGD("DownloadV2Ray", "==== DownloadV2RayCore START ====");
  
  // 获取 exe 所在目录
  LOGD("DownloadV2Ray", "DownloadV2Ray: getting module file name");
  char exePath[MAX_PATH];
  DWORD len = GetModuleFileNameA(NULL, exePath, MAX_PATH);
  
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: GetModuleFileNameA returned len=" + std::to_string(len));
  
  if (len == 0 || len == MAX_PATH) {
    DWORD err = GetLastError();
    LOGE_STR("DownloadV2Ray", "DownloadV2Ray: GetModuleFileNameA FAILED, error=" + std::to_string(err));
    return false;
  }
  
  std::string exeDir = exePath;
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: exePath=" + std::string(exePath));
  
  size_t lastSlash = exeDir.rfind('\\');
  if (lastSlash == std::string::npos) {
    LOGE("DownloadV2Ray", "DownloadV2Ray: no backslash found in path!");
    return false;
  }
  exeDir = exeDir.substr(0, lastSlash);
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: exeDir=" + exeDir);
  
  // 检查 exe 同目录下的 v2ray 文件夹
  std::string bundledPath = exeDir + "\\v2ray\\v2ray.exe";
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: checking bundledPath=" + bundledPath);
  
  BOOL exists = PathFileExistsA(bundledPath.c_str());
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: PathFileExistsA=" + std::to_string(exists));
  
  if (!exists) {
    LOGE("DownloadV2Ray", "DownloadV2Ray: bundled v2ray.exe NOT FOUND!");
    LOGE_STR("DownloadV2Ray", "DownloadV2Ray: expected at: " + bundledPath);
    return false;
  }
  
  LOGD("DownloadV2Ray", "DownloadV2Ray: v2ray.exe found, proceeding with copy");
  
  // 源文件路径
  std::string srcExe = exeDir + "\\v2ray\\v2ray.exe";
  std::string srcGeoip = exeDir + "\\v2ray\\geoip.dat";
  std::string srcGeosite = exeDir + "\\v2ray\\geosite.dat";
  
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: srcExe=" + srcExe);
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: srcGeoip=" + srcGeoip);
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: srcGeosite=" + srcGeosite);
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: v2ray_path_=" + v2ray_path_);
  
  // 复制 v2ray.exe
  LOGD("DownloadV2Ray", "DownloadV2Ray: copying v2ray.exe");
  BOOL copied = CopyFileA(srcExe.c_str(), v2ray_path_.c_str(), FALSE);
  if (!copied) {
    DWORD err = GetLastError();
    LOGE_STR("DownloadV2Ray", "DownloadV2Ray: CopyFileA FAILED for v2ray.exe, error=" + std::to_string(err));
    return false;
  }
  LOGD("DownloadV2Ray", "DownloadV2Ray: v2ray.exe copied successfully");
  
  // 复制 geoip.dat
  std::string destGeoip = working_dir_ + "\\geoip.dat";
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: destGeoip=" + destGeoip);
  
  if (PathFileExistsA(srcGeoip.c_str())) {
    LOGD("DownloadV2Ray", "DownloadV2Ray: geoip.dat exists, copying");
    CopyFileA(srcGeoip.c_str(), destGeoip.c_str(), FALSE);
    LOGD("DownloadV2Ray", "DownloadV2Ray: geoip.dat copied");
  } else {
    LOGD("DownloadV2Ray", "DownloadV2Ray: geoip.dat not found in bundle, skipping");
  }
  
  // 复制 geosite.dat
  std::string destGeosite = working_dir_ + "\\geosite.dat";
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: destGeosite=" + destGeosite);
  
  if (PathFileExistsA(srcGeosite.c_str())) {
    LOGD("DownloadV2Ray", "DownloadV2Ray: geosite.dat exists, copying");
    CopyFileA(srcGeosite.c_str(), destGeosite.c_str(), FALSE);
    LOGD("DownloadV2Ray", "DownloadV2Ray: geosite.dat copied");
  } else {
    LOGD("DownloadV2Ray", "DownloadV2Ray: geosite.dat not found in bundle, skipping");
  }
  
  // 验证复制结果
  LOGD("DownloadV2Ray", "DownloadV2Ray: verifying copied files");
  BOOL v2rayExists = PathFileExistsA(v2ray_path_.c_str());
  LOGD_STR("DownloadV2Ray", "DownloadV2Ray: v2ray.exe exists after copy=" + std::to_string(v2rayExists));
  
  LOGD("DownloadV2Ray", "==== DownloadV2RayCore SUCCESS ====");
  return true;
}

bool VpnHandler::GenerateConfig(const flutter::EncodableMap& flutterConfig) {
  LOGD("GenerateConfig", "==== GenerateConfig START ====");
  
  std::string protocol, address, uuid, security, network;
  int port = 443;
  
  LOGD("GenerateConfig", "GenerateConfig: parsing Flutter config parameters");
  
  // 从 Flutter 配置中提取参数
  for (const auto& [key, value] : flutterConfig) {
    if (std::holds_alternative<std::string>(key)) {
      const std::string& keyStr = std::get<std::string>(key);
      
      if (keyStr == "protocol") {
        if (std::holds_alternative<std::string>(value)) {
          protocol = std::get<std::string>(value);
          LOGD_STR("GenerateConfig", "GenerateConfig:   protocol=" + protocol);
        }
      } else if (keyStr == "address") {
        if (std::holds_alternative<std::string>(value)) {
          address = std::get<std::string>(value);
          LOGD_STR("GenerateConfig", "GenerateConfig:   address=" + address);
        }
      } else if (keyStr == "port") {
        if (std::holds_alternative<int>(value)) {
          port = std::get<int>(value);
          LOGD_STR("GenerateConfig", "GenerateConfig:   port=" + std::to_string(port));
        }
      } else if (keyStr == "uuid") {
        if (std::holds_alternative<std::string>(value)) {
          uuid = std::get<std::string>(value);
          LOGD_STR("GenerateConfig", "GenerateConfig:   uuid=" + uuid);
        }
      } else if (keyStr == "security") {
        if (std::holds_alternative<std::string>(value)) {
          security = std::get<std::string>(value);
          LOGD_STR("GenerateConfig", "GenerateConfig:   security=" + security);
        }
      } else if (keyStr == "network") {
        if (std::holds_alternative<std::string>(value)) {
          network = std::get<std::string>(value);
          LOGD_STR("GenerateConfig", "GenerateConfig:   network=" + network);
        }
      }
    }
  }
  
  LOGD("GenerateConfig", "GenerateConfig: all parameters parsed");
  LOGD_STR("GenerateConfig", "GenerateConfig: final protocol=" + protocol);
  LOGD_STR("GenerateConfig", "GenerateConfig: final address=" + address);
  LOGD_STR("GenerateConfig", "GenerateConfig: final port=" + std::to_string(port));
  LOGD_STR("GenerateConfig", "GenerateConfig: final uuid=" + uuid);
  LOGD_STR("GenerateConfig", "GenerateConfig: final security=" + security);
  LOGD_STR("GenerateConfig", "GenerateConfig: final network=" + network);
  
  // 生成 v2ray config.json
  LOGD("GenerateConfig", "GenerateConfig: generating JSON config");
  
  std::string streamSecurity = (port == 443 ? "tls" : "none");
  std::string networkType = (network.empty() ? "tcp" : network);
  std::string securityType = (security.empty() ? "auto" : security);
  
  LOGD_STR("GenerateConfig", "GenerateConfig: streamSecurity=" + streamSecurity);
  LOGD_STR("GenerateConfig", "GenerateConfig: networkType=" + networkType);
  LOGD_STR("GenerateConfig", "GenerateConfig: securityType=" + securityType);
  
  std::ostringstream json;
  json << R"({
    "log": {
      "loglevel": "warning"
    },
    "dns": {
      "servers": ["8.8.8.8", "1.1.1.1"]
    },
    "inbounds": [{
      "port": 10808,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true,
        "ip": "127.0.0.1"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }],
    "outbounds": [{
      "protocol": ")" << protocol << R"(",
      "settings": {
        "vnext": [{
          "address": ")" << address << R"(",
          "port": )" << port << R"(,
          "users": [{
            "id": ")" << uuid << R"(",
            "security": ")" << securityType << R"("
          }]
        }]
      },
      "streamSettings": {
        "network": ")" << networkType << R"(",
        "security": ")" << streamSecurity << R"("
      },
      "tag": "proxy"
    }],
    "routing": {
      "domainStrategy": "AsIs",
      "rules": [{
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "direct"
      }]
    }
  })";
  
  std::string configJson = json.str();
  LOGD_STR("GenerateConfig", "GenerateConfig: JSON config length=" + std::to_string(configJson.length()));
  
  LOGD("GenerateConfig", "GenerateConfig: opening file for write");
  LOGD_STR("GenerateConfig", "GenerateConfig: config_path=" + config_path_);
  
  std::ofstream file(config_path_);
  if (!file.is_open()) {
    DWORD err = GetLastError();
    LOGE_STR("GenerateConfig", "GenerateConfig: FAILED to open file, error=" + std::to_string(err));
    return false;
  }
  
  LOGD("GenerateConfig", "GenerateConfig: writing JSON to file");
  file << configJson;
  file.close();
  
  // 验证文件写入
  LOGD("GenerateConfig", "GenerateConfig: verifying file write");
  BOOL fileExists = PathFileExistsA(config_path_.c_str());
  LOGD_STR("GenerateConfig", "GenerateConfig: config file exists=" + std::to_string(fileExists));
  
  LOGD("GenerateConfig", "==== GenerateConfig SUCCESS ====");
  return true;
}

bool VpnHandler::StartV2RayProcess() {
  LOGD("StartV2Ray", "==== StartV2RayProcess START ====");
  LOGD_STR("StartV2Ray", "StartV2Ray: v2ray_path_=" + v2ray_path_);
  LOGD_STR("StartV2Ray", "StartV2Ray: config_path_=" + config_path_);
  LOGD_STR("StartV2Ray", "StartV2Ray: working_dir_=" + working_dir_);
  
  // 检查 v2ray 文件是否存在
  LOGD("StartV2Ray", "StartV2Ray: checking if v2ray.exe exists");
  if (!PathFileExistsA(v2ray_path_.c_str())) {
    LOGE("StartV2Ray", "StartV2Ray: v2ray.exe NOT FOUND!");
    return false;
  }
  LOGD("StartV2Ray", "StartV2Ray: v2ray.exe exists");
  
  // 检查配置文件是否存在
  LOGD("StartV2Ray", "StartV2Ray: checking if config.json exists");
  if (!PathFileExistsA(config_path_.c_str())) {
    LOGE("StartV2Ray", "StartV2Ray: config.json NOT FOUND!");
    return false;
  }
  LOGD("StartV2Ray", "StartV2Ray: config.json exists");
  
  // 准备启动信息
  LOGD("StartV2Ray", "StartV2Ray: preparing STARTUPINFOA");
  STARTUPINFOA si = {};
  si.cb = sizeof(si);
  
  // 构建命令行
  std::string cmdLine = "\"" + v2ray_path_ + "\" -config=\"" + config_path_ + "\"";
  LOGD_STR("StartV2Ray", "StartV2Ray: cmdLine=" + cmdLine);
  
  // 创建 Job Object
  LOGD("StartV2Ray", "StartV2Ray: creating Job Object");
  job_handle_ = CreateJobObjectA(NULL, NULL);
  if (job_handle_) {
    LOGD("StartV2Ray", "StartV2Ray: Job Object created");
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limit = {};
    limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    BOOL setInfo = SetInformationJobObject(job_handle_, JobObjectExtendedLimitInformation, &limit, sizeof(limit));
    if (!setInfo) {
      DWORD err = GetLastError();
      LOGE_STR("StartV2Ray", "StartV2Ray: SetInformationJobObject FAILED, error=" + std::to_string(err));
    } else {
      LOGD("StartV2Ray", "StartV2Ray: Job Object configured");
    }
  } else {
    DWORD err = GetLastError();
    LOGE_STR("StartV2Ray", "StartV2Ray: CreateJobObjectA FAILED, error=" + std::to_string(err));
  }
  
  // 创建进程
  LOGD("StartV2Ray", "StartV2Ray: calling CreateProcessA");
  BOOL created = CreateProcessA(
    NULL, (LPSTR)cmdLine.c_str(), NULL, NULL, FALSE,
    CREATE_NO_WINDOW, NULL, working_dir_.c_str(), &si, &process_info_);
  
  if (!created) {
    DWORD err = GetLastError();
    LOGE_STR("StartV2Ray", "StartV2Ray: CreateProcessA FAILED, error=" + std::to_string(err));
    return false;
  }
  
  process_handle_ = process_info_.hProcess;
  LOGD("StartV2Ray", "StartV2Ray: CreateProcessA SUCCESS");
  LOGD_STR("StartV2Ray", "StartV2Ray: process_handle_=" + std::to_string((uint64_t)process_handle_));
  LOGD_STR("StartV2Ray", "StartV2Ray: process_id=" + std::to_string(process_info_.dwProcessId));
  
  // 将进程加入 Job Object
  if (job_handle_) {
    LOGD("StartV2Ray", "StartV2Ray: assigning process to Job Object");
    BOOL assigned = AssignProcessToJobObject(job_handle_, process_handle_);
    if (!assigned) {
      DWORD err = GetLastError();
      LOGE_STR("StartV2Ray", "StartV2Ray: AssignProcessToJobObject FAILED, error=" + std::to_string(err));
    } else {
      LOGD("StartV2Ray", "StartV2Ray: process assigned to Job Object");
    }
  }
  
  LOGD("StartV2Ray", "==== StartV2RayProcess SUCCESS ====");
  return true;
}

void VpnHandler::StopV2RayProcess() {
  LOGD("StopV2Ray", "==== StopV2RayProcess START ====");
  LOGD_STR("StopV2Ray", "StopV2Ray: process_handle_=" + std::to_string((uint64_t)process_handle_));
  
  if (process_handle_) {
    LOGD("StopV2Ray", "StopV2Ray: terminating process");
    BOOL term = TerminateProcess(process_handle_, 0);
    if (term) {
      LOGD("StopV2Ray", "StopV2Ray: TerminateProcess called");
    } else {
      DWORD err = GetLastError();
      LOGE_STR("StopV2Ray", "StopV2Ray: TerminateProcess FAILED, error=" + std::to_string(err));
    }
    
    LOGD("StopV2Ray", "StopV2Ray: waiting for process to exit");
    DWORD wait = WaitForSingleObject(process_handle_, INFINITE);
    LOGD_STR("StopV2Ray", "StopV2Ray: WaitForSingleObject returned=" + std::to_string(wait));
    
    LOGD("StopV2Ray", "StopV2Ray: closing process handle");
    CloseHandle(process_handle_);
    process_handle_ = NULL;
    LOGD("StopV2Ray", "StopV2Ray: process handle closed");
  } else {
    LOGD("StopV2Ray", "StopV2Ray: process_handle_ is NULL, skipping");
  }
  
  if (process_info_.hThread) {
    LOGD("StopV2Ray", "StopV2Ray: closing thread handle");
    CloseHandle(process_info_.hThread);
    process_info_.hThread = NULL;
  }
  
  if (job_handle_) {
    LOGD("StopV2Ray", "StopV2Ray: closing job handle");
    CloseHandle(job_handle_);
    job_handle_ = NULL;
    LOGD("StopV2Ray", "StopV2Ray: job handle closed");
  }
  
  LOGD("StopV2Ray", "==== StopV2RayProcess COMPLETE ====");
}

void VpnHandler::MonitorProcess() {
  LOGD("Monitor", "==== MonitorProcess START ====");
  LOGD_STR("Monitor", "Monitor: thread id=" + std::to_string(GetCurrentThreadId()));
  
  while (is_running_) {
    LOGD_STR("Monitor", "Monitor: loop, is_running_=" + std::to_string(is_running_.load()));
    
    if (process_handle_) {
      LOGD_STR("Monitor", "Monitor: checking process handle=" + std::to_string((uint64_t)process_handle_));
      
      DWORD exitCode;
      BOOL gotExitCode = GetExitCodeProcess(process_handle_, &exitCode);
      if (gotExitCode) {
        LOGD_STR("Monitor", "Monitor: exitCode=" + std::to_string(exitCode) + ", STILL_ACTIVE=" + std::to_string(STILL_ACTIVE));
        
        if (exitCode != STILL_ACTIVE) {
          LOGE("Monitor", "Monitor: v2ray-core process has EXITED unexpectedly!");
          is_running_ = false;
          is_connected_ = false;
          LOGD("Monitor", "Monitor: sending error event to flutter");
          SendEvent("error", {
            {flutter::EncodableValue("message"), flutter::EncodableValue("v2ray-core process exited unexpectedly")}
          });
          LOGD("Monitor", "Monitor: breaking loop");
          break;
        }
      } else {
        DWORD err = GetLastError();
        LOGE_STR("Monitor", "Monitor: GetExitCodeProcess FAILED, error=" + std::to_string(err));
      }
    } else {
      LOGD("Monitor", "Monitor: process_handle_ is NULL");
    }
    
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
  }
  
  LOGD("Monitor", "==== MonitorProcess END ====");
}

void VpnHandler::CollectTrafficStats() {
  LOGD("Stats", "==== CollectTrafficStats START ====");
  LOGD_STR("Stats", "Stats: thread id=" + std::to_string(GetCurrentThreadId()));
  
  // 初始 IO 计数器
  IO_COUNTERS initialCounters = {};
  if (process_handle_) {
    LOGD("Stats", "Stats: getting initial IO counters");
    BOOL ok = GetProcessIoCounters(process_handle_, &initialCounters);
    if (ok) {
      LOGD_STR("Stats", "Stats: ReadTransferCount=" + std::to_string(initialCounters.ReadTransferCount));
      LOGD_STR("Stats", "Stats: WriteTransferCount=" + std::to_string(initialCounters.WriteTransferCount));
    } else {
      DWORD err = GetLastError();
      LOGE_STR("Stats", "Stats: GetProcessIoCounters FAILED, error=" + std::to_string(err));
    }
  }
  
  int64_t lastRead = initialCounters.ReadTransferCount;
  int64_t lastWrite = initialCounters.WriteTransferCount;
  
  LOGD("Stats", "Stats: entering main loop");
  
  while (is_running_) {
    IO_COUNTERS ioCounters = {};
    
    if (process_handle_) {
      BOOL ok = GetProcessIoCounters(process_handle_, &ioCounters);
      if (ok) {
        // 计算流量差值
        int64_t deltaRead = ioCounters.ReadTransferCount - lastRead;
        int64_t deltaWrite = ioCounters.WriteTransferCount - lastWrite;
        
        // 更新上次值
        lastRead = ioCounters.ReadTransferCount;
        lastWrite = ioCounters.WriteTransferCount;
        
        // 累加总流量
        total_upload_ = total_upload_.load() + deltaWrite;
        total_download_ = total_download_.load() + deltaRead;
        
        // 计算速度
        upload_speed_ = deltaWrite;
        download_speed_ = deltaRead;
        
        // 发送统计更新
        LOGD("Stats", "Stats: sending stats update");
        SendEvent("stats", {
          {flutter::EncodableValue("uploadSpeed"), flutter::EncodableValue(upload_speed_.load())},
          {flutter::EncodableValue("downloadSpeed"), flutter::EncodableValue(download_speed_.load())},
          {flutter::EncodableValue("totalUpload"), flutter::EncodableValue(total_upload_.load())},
          {flutter::EncodableValue("totalDownload"), flutter::EncodableValue(total_download_.load())}
        });
      }
    } else {
      LOGD("Stats", "Stats: process_handle_ is NULL");
    }
    
    std::this_thread::sleep_for(std::chrono::milliseconds(STATS_INTERVAL_MS));
  }
  
  LOGD("Stats", "==== CollectTrafficStats END ====");
}

bool VpnHandler::TestConnection() {
  LOGD("TestConn", "==== TestConnection START ====");
  
  // Test by connecting through v2ray SOCKS proxy
  LOGD("TestConn", "TestConn: creating socket");
  
  SOCKET sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (sock == INVALID_SOCKET) {
    DWORD err = WSAGetLastError();
    LOGE_STR("TestConn", "TestConn: socket() FAILED, error=" + std::to_string(err));
    return FALSE;
  }
  LOGD("TestConn", "TestConn: socket created");
  
  // Set timeout
  DWORD timeout = HTTP_TIMEOUT_MS;
  setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));
  setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&timeout, sizeof(timeout));
  
  // Connect to v2ray SOCKS proxy
  LOGD("TestConn", "TestConn: connecting to v2ray SOCKS proxy at 127.0.0.1:10808");
  sockaddr_in proxyAddr = {};
  proxyAddr.sin_family = AF_INET;
  proxyAddr.sin_addr.s_addr = inet_addr("127.0.0.1");
  proxyAddr.sin_port = htons(10808);
  
  int connResult = connect(sock, (sockaddr*)&proxyAddr, sizeof(proxyAddr));
  if (connResult == SOCKET_ERROR) {
    DWORD err = WSAGetLastError();
    LOGE_STR("TestConn", "TestConn: connect() to SOCKS proxy FAILED, error=" + std::to_string(err));
    closesocket(sock);
    return FALSE;
  }
  LOGD("TestConn", "TestConn: connected to SOCKS proxy");
  
  // Build SOCKS5 CONNECT request for www.google.com:443
  const char* targetHost = "www.google.com";
  int targetPort = 443;
  
  unsigned char socksRequest[100];
  socksRequest[0] = 0x05;  // SOCKS version
  socksRequest[1] = 0x01;  // CMD: CONNECT
  socksRequest[2] = 0x00;  // RSV
  socksRequest[3] = 0x03;  // ATYP: Domain name
  
  // Domain name length (1 byte) + domain name + port (2 bytes)
  size_t hostLen = strlen(targetHost);
  socksRequest[4] = (unsigned char)hostLen;
  memcpy(&socksRequest[5], targetHost, hostLen);
  
  socksRequest[5 + hostLen] = (unsigned char)(targetPort >> 8);
  socksRequest[6 + hostLen] = (unsigned char)(targetPort & 0xFF);
  
  size_t requestLen = 7 + hostLen;
  
  LOGD("TestConn", "TestConn: sending SOCKS5 CONNECT request");
  int sent = send(sock, (const char*)socksRequest, (int)requestLen, 0);
  if (sent == SOCKET_ERROR) {
    DWORD err = WSAGetLastError();
    LOGE_STR("TestConn", "TestConn: send() FAILED, error=" + std::to_string(err));
    closesocket(sock);
    return FALSE;
  }
  LOGD("TestConn", "TestConn: SOCKS request sent, bytes=" + std::to_string(sent));
  
  // Read SOCKS response
  unsigned char socksResponse[100];
  int received = recv(sock, (char*)socksResponse, sizeof(socksResponse), 0);
  if (received == SOCKET_ERROR) {
    DWORD err = WSAGetLastError();
    LOGE_STR("TestConn", "TestConn: recv() FAILED, error=" + std::to_string(err));
    closesocket(sock);
    return FALSE;
  }
  
  LOGD("TestConn", "TestConn: SOCKS response received, len=" + std::to_string(received));
  
  // Check SOCKS response (should be VER=0x05, REP=0x00)
  if (received < 2 || socksResponse[0] != 0x05 || socksResponse[1] != 0x00) {
    LOGE("TestConn", "TestConn: SOCKS connection FAILED!");
    closesocket(sock);
    return FALSE;
  }
  
  LOGD("TestConn", "TestConn: SOCKS CONNECT SUCCESS");
  
  // Send simple HTTPS request through SOCKS
  const char* httpRequest = "HEAD / HTTP/1.0\r\nHost: www.google.com\r\n\r\n";
  LOGD("TestConn", "TestConn: sending HTTP request through SOCKS");
  
  sent = send(sock, httpRequest, (int)strlen(httpRequest), 0);
  if (sent == SOCKET_ERROR) {
    DWORD err = WSAGetLastError();
    LOGE_STR("TestConn", "TestConn: send() HTTP request FAILED, error=" + std::to_string(err));
    closesocket(sock);
    return FALSE;
  }
  
  // Read response (should get some data back)
  char response[1024];
  received = recv(sock, response, sizeof(response) - 1, 0);
  
  if (received > 0) {
    response[received] = '\0';
    LOGD("TestConn", "TestConn: received response, len=" + std::to_string(received));
    LOGD_STR("TestConn", "TestConn: response starts with: " + std::string(response, std::min(50, received)));
    closesocket(sock);
    LOGD("TestConn", "==== TestConnection SUCCESS ====");
    return TRUE;
  }
  
  closesocket(sock);
  LOGD("TestConn", "==== TestConnection END ====");
  return FALSE;
}
  LOGD("TestConn", "TestConn: WinHttpOpen SUCCESS");
  
  // 设置超时
  LOGD("TestConn", "TestConn: setting timeouts");
  WinHttpSetTimeouts(hSession, HTTP_TIMEOUT_MS, HTTP_TIMEOUT_MS, HTTP_TIMEOUT_MS, HTTP_TIMEOUT_MS);
  
  // 连接
  LOGD("TestConn", "TestConn: connecting to www.google.com");
  HINTERNET hConnect = WinHttpConnect(hSession, L"www.google.com", INTERNET_DEFAULT_HTTPS_PORT, 0);
  if (!hConnect) {
    DWORD err = GetLastError();
    LOGE_STR("TestConn", "TestConn: WinHttpConnect FAILED, error=" + std::to_string(err));
    WinHttpCloseHandle(hSession);
    return FALSE;
  }
  LOGD("TestConn", "TestConn: WinHttpConnect SUCCESS");
  
  // 打开请求
  LOGD("TestConn", "TestConn: opening HTTP request");
  HINTERNET hRequest = WinHttpOpenRequest(
    hConnect, L"GET", L"/", NULL, NULL,
    WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE);
  
  if (!hRequest) {
    DWORD err = GetLastError();
    LOGE_STR("TestConn", "TestConn: WinHttpOpenRequest FAILED, error=" + std::to_string(err));
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);
    return FALSE;
  }
  LOGD("TestConn", "TestConn: WinHttpOpenRequest SUCCESS");
  
  // 设置请求超时
  LOGD("TestConn", "TestConn: setting request timeouts");
  DWORD timeout = HTTP_TIMEOUT_MS;
  WinHttpSetOption(hRequest, WINHTTP_OPTION_CONNECT_TIMEOUT, &timeout, sizeof(timeout));
  WinHttpSetOption(hRequest, WINHTTP_OPTION_RECEIVE_TIMEOUT, &timeout, sizeof(timeout));
  WinHttpSetOption(hRequest, WINHTTP_OPTION_SEND_TIMEOUT, &timeout, sizeof(timeout));
  
  // 发送请求
  LOGD("TestConn", "TestConn: sending HTTP request");
  BOOL result = WinHttpSendRequest(hRequest, NULL, 0, NULL, 0, 0, 0);
  
  if (result) {
    LOGD("TestConn", "TestConn: WinHttpSendRequest SUCCESS");
    
    LOGD("TestConn", "TestConn: receiving HTTP response");
    result = WinHttpReceiveResponse(hRequest, NULL);
    
    if (result) {
      LOGD("TestConn", "TestConn: WinHttpReceiveResponse SUCCESS - connection test PASSED");
    } else {
      DWORD err = GetLastError();
      LOGE_STR("TestConn", "TestConn: WinHttpReceiveResponse FAILED, error=" + std::to_string(err));
    }
  } else {
    DWORD err = GetLastError();
    LOGE_STR("TestConn", "TestConn: WinHttpSendRequest FAILED, error=" + std::to_string(err));
  }
  
  // 清理
  LOGD("TestConn", "TestConn: closing handles");
  WinHttpCloseHandle(hRequest);
  WinHttpCloseHandle(hConnect);
  WinHttpCloseHandle(hSession);
  
  LOGD_STR("TestConn", "TestConn: returning=" + std::to_string(result == TRUE));
  LOGD("TestConn", "==== TestConnection END ====");
  
  return result == TRUE;
}

std::string VpnHandler::GetAppDataPath() {
  LOGD("VpnHandler", "GetAppDataPath: getting APPDATA environment variable");
  char path[MAX_PATH];
  DWORD len = GetEnvironmentVariableA("APPDATA", path, MAX_PATH);
  
  if (len > 0 && len < MAX_PATH) {
    std::string result = std::string(path) + "\\NebulaVPN";
    LOGD_STR("VpnHandler", "GetAppDataPath: result=" + result);
    return result;
  }
  
  LOGD("VpnHandler", "GetAppDataPath: APPDATA not found, using fallback");
  return "C:\\NebulaVPN";
}

std::string VpnHandler::GetV2RayPath() {
  std::string result = working_dir_ + "\\v2ray.exe";
  LOGD_STR("VpnHandler", "GetV2RayPath: " + result);
  return result;
}

std::string VpnHandler::GetConfigPath() {
  std::string result = working_dir_ + "\\config.json";
  LOGD_STR("VpnHandler", "GetConfigPath: " + result);
  return result;
}

void VpnHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const auto& method_name = method_call.method_name();
  
  LOGD_STR("HandleMethod", "========== HandleMethodCall START ==========");
  LOGD_STR("HandleMethod", "HandleMethodCall: method_name=" + method_name);
  
  try {
    if (method_name == "connect") {
      LOGD("HandleMethod", "HandleMethodCall: processing 'connect'");
      
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments == nullptr) {
        LOGE("HandleMethod", "HandleMethodCall: arguments is nullptr!");
        result->Error("INVALID_ARGUMENTS", "Expected EncodableMap");
        return;
      }
      LOGD_STR("HandleMethod", "HandleMethodCall: arguments size=" + std::to_string(arguments->size()));
      
      // 打印 config 内容
      auto configIt = arguments->find(flutter::EncodableValue("config"));
      if (configIt == arguments->end()) {
        LOGE("HandleMethod", "HandleMethodCall: 'config' key not found!");
        result->Error("INVALID_CONFIG", "config field is required");
        return;
      }
      
      if (!std::holds_alternative<flutter::EncodableMap>(configIt->second)) {
        LOGE("HandleMethod", "HandleMethodCall: 'config' value is not a map!");
        result->Error("INVALID_CONFIG", "config field must be a map");
        return;
      }
      
      auto configMap = std::get<flutter::EncodableMap>(configIt->second);
      LOGD_STR("HandleMethod", "HandleMethodCall: config map size=" + std::to_string(configMap.size()));
      
      // 打印所有 config 参数
      LOGD("HandleMethod", "HandleMethodCall: config contents:");
      for (const auto& [key, value] : configMap) {
        std::string keyStr = "unknown", valueStr = "unknown";
        if (std::holds_alternative<std::string>(key)) keyStr = std::get<std::string>(key);
        else if (std::holds_alternative<int>(key)) keyStr = std::to_string(std::get<int>(key));
        
        if (std::holds_alternative<std::string>(value)) valueStr = std::get<std::string>(value);
        else if (std::holds_alternative<int>(value)) valueStr = std::to_string(std::get<int>(value));
        else if (std::holds_alternative<double>(value)) valueStr = std::to_string(std::get<double>(value));
        else if (std::holds_alternative<bool>(value)) valueStr = std::get<bool>(value) ? "true" : "false";
        
        LOGD_STR("HandleMethod", "HandleMethodCall:   " + keyStr + " = " + valueStr);
      }
      
      LOGD("HandleMethod", "HandleMethodCall: calling Connect");
      Connect(std::move(configMap), std::move(result));
      
    } else if (method_name == "disconnect") {
      LOGD("HandleMethod", "HandleMethodCall: processing 'disconnect'");
      Disconnect(std::move(result));
      
    } else if (method_name == "getStatus") {
      LOGD("HandleMethod", "HandleMethodCall: processing 'getStatus'");
      GetStatus(std::move(result));
      
    } else {
      LOGE_STR("HandleMethod", "HandleMethodCall: method not implemented: " + method_name);
      result->NotImplemented();
    }
  } catch (const std::exception& e) {
    LOGE_STR("HandleMethod", "HandleMethodCall: EXCEPTION: " + std::string(e.what()));
    result->Error("EXCEPTION", e.what());
  } catch (...) {
    LOGE("HandleMethod", "HandleMethodCall: UNKNOWN EXCEPTION!");
    result->Error("UNKNOWN_ERROR", "Unknown error occurred");
  }
  
  LOGD("HandleMethod", "========== HandleMethodCall END ==========");
}
