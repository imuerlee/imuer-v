#include "vpn_handler.h"
#include <flutter/standard_method_codec.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <chrono>
#include <map>
#include <psapi.h>
#include <ws2tcpip.h>
#include <wininet.h>

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "wininet.lib")

namespace {
  constexpr const char* V2RAY_VERSION = "v5.22.0";
  constexpr const char* V2RAY_URL = "https://github.com/v2fly/v2ray-core/releases/download/v5.22.0/v2ray-windows-64.zip";
  constexpr const int STATS_INTERVAL_MS = 1000;
  constexpr const int CONNECTION_TIMEOUT_MS = 5000;
}

VpnHandler& VpnHandler::Instance() {
  static VpnHandler instance;
  return instance;
}

VpnHandler::VpnHandler() {
  working_dir_ = GetAppDataPath();
  v2ray_path_ = GetV2RayPath();
  config_path_ = GetConfigPath();
}

VpnHandler::~VpnHandler() {
  StopV2RayProcess();
  if (monitor_thread_.joinable()) {
    monitor_thread_.join();
  }
  if (stats_thread_.joinable()) {
    stats_thread_.join();
  }
}

void VpnHandler::SetEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  std::lock_guard<std::mutex> lock(mutex_);
  event_sink_ = std::move(events);
}

void VpnHandler::OnListen(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  SetEventSink(std::move(events));
}

void VpnHandler::OnCancel(const flutter::EncodableValue* arguments) {
  std::lock_guard<std::mutex> lock(mutex_);
  event_sink_.reset();
}

void VpnHandler::SendEvent(const std::string& type, const flutter::EncodableMap& data) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (!event_sink_) {
    return;
  }
  
  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue(type);
  for (const auto& [key, value] : data) {
    event[key] = value;
  }
  event_sink_->Success(flutter::EncodableValue(event));
}

void VpnHandler::Connect(
    const flutter::EncodableMap& config,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  std::thread([this, config, result = std::move(result)]() mutable {
    std::lock_guard<std::mutex> lock(mutex_);
    
    if (is_running_) {
      result->Error("ALREADY_RUNNING", "v2ray-core is already running");
      return;
    }
    
    SendEvent("connecting", flutter::EncodableMap{});
    
    // 步骤 1: 检查/下载 v2ray-core
    if (!DownloadV2RayCore()) {
      SendEvent("error", {
        {flutter::EncodableValue("message"), flutter::EncodableValue("Failed to download v2ray-core")}
      });
      result->Error("DOWNLOAD_FAILED", "Failed to download v2ray-core");
      return;
    }
    
    // 步骤 2: 生成配置文件
    if (!GenerateConfig(config)) {
      SendEvent("error", {
        {flutter::EncodableValue("message"), flutter::EncodableValue("Failed to generate config")}
      });
      result->Error("CONFIG_ERROR", "Failed to generate configuration");
      return;
    }
    
    // 步骤 3: 启动 v2ray-core 进程
    if (!StartV2RayProcess()) {
      SendEvent("error", {
        {flutter::EncodableValue("message"), flutter::EncodableValue("Failed to start v2ray-core")}
      });
      result->Error("START_FAILED", "Failed to start v2ray-core");
      return;
    }
    
    // 步骤 4: 等待启动并测试连接
    std::this_thread::sleep_for(std::chrono::seconds(2));
    bool connectionOk = TestConnection();
    
    if (!connectionOk) {
      StopV2RayProcess();
      SendEvent("error", {
        {flutter::EncodableValue("message"), flutter::EncodableValue("Connection test failed")}
      });
      result->Error("CONNECTION_FAILED", "Connection test failed");
      return;
    }
    
    // 启动监控和统计线程
    is_running_ = true;
    is_connected_ = true;
    
    monitor_thread_ = std::thread(&VpnHandler::MonitorProcess, this);
    stats_thread_ = std::thread(&VpnHandler::CollectTrafficStats, this);
    
    // 发送连接成功事件
    SendEvent("connected", {
      {flutter::EncodableValue("message"), flutter::EncodableValue("VPN connected successfully")}
    });
    
    result->Success(flutter::EncodableValue(true));
  }).detach();
}

void VpnHandler::Disconnect(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  if (!is_running_) {
    result->Success(flutter::EncodableValue(true));
    return;
  }
  
  SendEvent("disconnecting", flutter::EncodableMap{});
  
  StopV2RayProcess();
  
  is_running_ = false;
  is_connected_ = false;
  upload_speed_ = 0;
  download_speed_ = 0;
  total_upload_ = 0;
  total_download_ = 0;
  
  SendEvent("disconnected", flutter::EncodableMap{});
  
  result->Success(flutter::EncodableValue(true));
}

void VpnHandler::GetStatus(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  flutter::EncodableMap status;
  status[flutter::EncodableValue("connected")] = flutter::EncodableValue(is_connected_.load());
  status[flutter::EncodableValue("running")] = flutter::EncodableValue(is_running_.load());
  status[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(upload_speed_.load());
  status[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(download_speed_.load());
  status[flutter::EncodableValue("totalUpload")] = flutter::EncodableValue(total_upload_.load());
  status[flutter::EncodableValue("totalDownload")] = flutter::EncodableValue(total_download_.load());
  
  result->Success(flutter::EncodableValue(status));
}

bool VpnHandler::DownloadV2RayCore() {
  // 检查是否已存在
  if (PathFileExistsA(v2ray_path_.c_str())) {
    return true;
  }
  
  // 创建目录
  CreateDirectoryA(working_dir_.c_str(), NULL);
  
  // 下载 v2ray-core zip 文件
  std::string zipPath = working_dir_ + "\\v2ray.zip";
  
  if (!DownloadFile(V2RAY_URL, zipPath)) {
    return false;
  }
  
  // 解压文件 (使用 PowerShell)
  std::string extractCmd = "powershell -command \"Expand-Archive -Path '" + zipPath + 
                          "' -DestinationPath '" + working_dir_ + "' -Force\"";
  
  int ret = system(extractCmd.c_str());
  if (ret != 0) {
    DeleteFileA(zipPath.c_str());
    return false;
  }
  
  // 删除 zip 文件
  DeleteFileA(zipPath.c_str());
  
  // 验证文件是否存在
  if (!PathFileExistsA(v2ray_path_.c_str())) {
    return false;
  }
  
  return true;
}

bool VpnHandler::DownloadFile(const std::string& url, const std::string& destPath) {
  HINTERNET hInternet = InternetOpenA("NebulaVPN/1.0", INTERNET_OPEN_TYPE_PRECONFIG, NULL, NULL, 0);
  if (!hInternet) {
    return false;
  }
  
  HINTERNET hUrl = InternetOpenUrlA(hInternet, url.c_str(), NULL, 0, 
                                     INTERNET_FLAG_RELOAD | INTERNET_FLAG_SECURE, 0);
  if (!hUrl) {
    InternetCloseHandle(hInternet);
    return false;
  }
  
  HANDLE hFile = CreateFileA(destPath.c_str(), GENERIC_READ | GENERIC_WRITE, 0, NULL, 
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
  if (hFile == INVALID_HANDLE_VALUE) {
    InternetCloseHandle(hUrl);
    InternetCloseHandle(hInternet);
    return false;
  }
  
  char buffer[8192];
  DWORD bytesRead, bytesWritten;
  
  while (InternetReadFile(hUrl, buffer, sizeof(buffer), &bytesRead) && bytesRead > 0) {
    WriteFile(hFile, buffer, bytesRead, &bytesWritten, NULL);
  }
  
  CloseHandle(hFile);
  InternetCloseHandle(hUrl);
  InternetCloseHandle(hInternet);
  
  return true;
}

bool VpnHandler::GenerateConfig(const flutter::EncodableMap& flutterConfig) {
  std::string protocol, address, uuid, security, network;
  int port = 443;
  
  // 从 Flutter 配置中提取参数
  for (const auto& [key, value] : flutterConfig) {
    if (key.IsString()) {
      const std::string& keyStr = std::get<std::string>(key);
      
      if (keyStr == "protocol" && value.IsString()) {
        protocol = std::get<std::string>(value);
      } else if (keyStr == "address" && value.IsString()) {
        address = std::get<std::string>(value);
      } else if (keyStr == "port" && value.IsInt()) {
        port = std::get<int>(value);
      } else if (keyStr == "uuid" && value.IsString()) {
        uuid = std::get<std::string>(value);
      } else if (keyStr == "security" && value.IsString()) {
        security = std::get<std::string>(value);
      } else if (keyStr == "network" && value.IsString()) {
        network = std::get<std::string>(value);
      }
    }
  }
  
  // 生成 v2ray config.json
  std::ostringstream json;
  json << R"({
    "log": {
      "loglevel": "warning"
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
            "security": ")" << (security.empty() ? "auto" : security) << R"("
          }]
        }]
      },
      "streamSettings": {
        "network": ")" << (network.empty() ? "tcp" : network) << R"(",
        "security": ")" << (port == 443 ? "tls" : "none") << R"("
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
  
  std::ofstream file(config_path_);
  if (!file.is_open()) {
    return false;
  }
  
  file << json.str();
  file.close();
  
  return true;
}

bool VpnHandler::StartV2RayProcess() {
  STARTUPINFOA si = {};
  si.cb = sizeof(si);
  
  std::string cmdLine = "\"" + v2ray_path_ + "\" -config=\"" + config_path_ + "\"";
  
  // 创建 Job Object 限制进程
  job_handle_ = CreateJobObjectA(NULL, NULL);
  if (job_handle_) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limit = {};
    limit.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    SetInformationJobObject(job_handle_, JobObjectExtendedLimitInformation, &limit, sizeof(limit));
  }
  
  if (!CreateProcessA(NULL, (LPSTR)cmdLine.c_str(), NULL, NULL, FALSE,
                      CREATE_NO_WINDOW, NULL, working_dir_.c_str(), &si, &process_info_)) {
    return false;
  }
  
  process_handle_ = process_info_.hProcess;
  
  // 将进程加入 Job Object
  if (job_handle_) {
    AssignProcessToJobObject(job_handle_, process_handle_);
  }
  
  return true;
}

void VpnHandler::StopV2RayProcess() {
  if (process_handle_) {
    TerminateProcess(process_handle_, 0);
    WaitForSingleObject(process_handle_, INFINITE);
    CloseHandle(process_handle_);
    process_handle_ = NULL;
  }
  
  if (process_info_.hThread) {
    CloseHandle(process_info_.hThread);
    process_info_.hThread = NULL;
  }
  
  if (job_handle_) {
    CloseHandle(job_handle_);
    job_handle_ = NULL;
  }
}

void VpnHandler::MonitorProcess() {
  while (is_running_) {
    if (process_handle_) {
      DWORD exitCode;
      if (GetExitCodeProcess(process_handle_, &exitCode) && exitCode != STILL_ACTIVE) {
        is_running_ = false;
        is_connected_ = false;
        SendEvent("error", {
          {flutter::EncodableValue("message"), flutter::EncodableValue("v2ray-core process exited")}
        });
        break;
      }
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
  }
}

void VpnHandler::CollectTrafficStats() {
  // IO_COUNTERS 返回的是累计值，需要记录初始值
  IO_COUNTERS initialCounters = {};
  if (process_handle_) {
    GetProcessIoCounters(process_handle_, &initialCounters);
  }
  
  int64_t lastRead = initialCounters.ReadTransferCount;
  int64_t lastWrite = initialCounters.WriteTransferCount;
  
  while (is_running_) {
    IO_COUNTERS ioCounters = {};
    
    if (process_handle_ && GetProcessIoCounters(process_handle_, &ioCounters)) {
      // 计算本次间隔的流量
      int64_t deltaRead = ioCounters.ReadTransferCount - lastRead;
      int64_t deltaWrite = ioCounters.WriteTransferCount - lastWrite;
      
      // 更新上次值
      lastRead = ioCounters.ReadTransferCount;
      lastWrite = ioCounters.WriteTransferCount;
      
      // 累加会话总流量（字节）
      total_upload_ = total_upload_.load() + deltaWrite;
      total_download_ = total_download_.load() + deltaRead;
      
      // 计算速度（字节/秒）
      upload_speed_ = deltaWrite;
      download_speed_ = deltaRead;
      
      // 发送统计更新事件
      SendEvent("stats", {
        {flutter::EncodableValue("uploadSpeed"), flutter::EncodableValue(upload_speed_.load())},
        {flutter::EncodableValue("downloadSpeed"), flutter::EncodableValue(download_speed_.load())},
        {flutter::EncodableValue("totalUpload"), flutter::EncodableValue(total_upload_.load())},
        {flutter::EncodableValue("totalDownload"), flutter::EncodableValue(total_download_.load())}
      });
    }
    
    std::this_thread::sleep_for(std::chrono::milliseconds(STATS_INTERVAL_MS));
  }
}

bool VpnHandler::TestConnection() {
  WSADATA wsaData;
  if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
    return false;
  }
  
  SOCKET sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (sock == INVALID_SOCKET) {
    WSACleanup();
    return false;
  }
  
  u_long mode = 1;
  ioctlsocket(sock, FIONBIO, &mode);
  
  sockaddr_in server = {};
  server.sin_family = AF_INET;
  inet_pton(AF_INET, "8.8.8.8", &server.sin_addr);
  server.sin_port = htons(53);
  
  int result = connect(sock, (sockaddr*)&server, sizeof(server));
  if (result == SOCKET_ERROR && WSAGetLastError() != WSAEWOULDBLOCK) {
    closesocket(sock);
    WSACleanup();
    return false;
  }
  
  fd_set fdWrite;
  FD_ZERO(&fdWrite);
  FD_SET(sock, &fdWrite);
  
  timeval timeout = {};
  timeout.tv_sec = CONNECTION_TIMEOUT_MS / 1000;
  timeout.tv_usec = (CONNECTION_TIMEOUT_MS % 1000) * 1000;
  
  result = select(0, NULL, &fdWrite, NULL, &timeout);
  mode = 0;
  ioctlsocket(sock, FIONBIO, &mode);
  
  closesocket(sock);
  WSACleanup();
  
  return (result > 0);
}

std::string VpnHandler::GetAppDataPath() {
  char path[MAX_PATH];
  if (GetEnvironmentVariableA("APPDATA", path, MAX_PATH) > 0) {
    return std::string(path) + "\\NebulaVPN";
  }
  return "C:\\NebulaVPN";
}

std::string VpnHandler::GetV2RayPath() {
  return working_dir_ + "\\v2ray.exe";
}

std::string VpnHandler::GetConfigPath() {
  return working_dir_ + "\\config.json";
}

void VpnHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const auto& method_name = method_call.method_name();
  
  if (method_name == "connect") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments == nullptr) {
      result->Error("INVALID_ARGUMENTS", "Expected EncodableMap");
      return;
    }
    
    // 从参数中提取 config
    auto configIt = arguments->find(flutter::EncodableValue("config"));
    if (configIt == arguments->end() || !configIt->second.IsMap()) {
      result->Error("INVALID_CONFIG", "config field is required");
      return;
    }
    
    const auto& configMap = std::get<flutter::EncodableMap>(configIt->second);
    Connect(configMap, std::move(result));
    
  } else if (method_name == "disconnect") {
    Disconnect(std::move(result));
    
  } else if (method_name == "getStatus") {
    GetStatus(std::move(result));
    
  } else {
    result->NotImplemented();
  }
}
