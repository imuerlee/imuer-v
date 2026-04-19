#include "vpn_handler.h"
#include <flutter/standard_method_codec.h>

#include <iostream>
#include <fstream>
#include <sstream>
#include <chrono>
#include <map>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include <dirent.h>
#include <errno.h>

namespace {
  constexpr const char* V2RAY_VERSION = "v5.22.0";
  constexpr const int STATS_INTERVAL_MS = 1000;
  constexpr const int CONNECTION_TIMEOUT_MS = 5000;
  constexpr const int HTTP_TIMEOUT_MS = 10000;
  constexpr const char* PROXY_HOST = "127.0.0.1";
  constexpr const int PROXY_PORT = 10808;
}

inline void LogDebug(const char* tag, const char* msg) { 
  std::cerr << "[D][" << tag << "] " << msg << std::endl;
}
inline void LogDebugStr(const char* tag, const std::string& msg) { 
  std::cerr << "[D][" << tag << "] " << msg << std::endl;
}
inline void LogError(const char* tag, const char* msg) { 
  std::cerr << "[E][" << tag << "] " << msg << std::endl;
}
inline void LogErrorStr(const char* tag, const std::string& msg) { 
  std::cerr << "[E][" << tag << "] " << msg << std::endl;
}
inline void LogWarn(const char* tag, const char* msg) { 
  std::cerr << "[W][" << tag << "] " << msg << std::endl;
}

#define LOGD(tag, msg) LogDebug(tag, msg)
#define LOGD_STR(tag, msg) LogDebugStr(tag, msg)
#define LOGE(tag, msg) LogError(tag, msg)
#define LOGE_STR(tag, msg) LogErrorStr(tag, msg)
#define LOGW(tag, msg) LogWarn(tag, msg)

VpnHandler& VpnHandler::Instance() {
  static VpnHandler instance;
  return instance;
}

VpnHandler::VpnHandler() {
  LOGD("VpnHandler", "========== Constructor START ==========");
  
  working_dir_ = GetWorkingDir();
  v2ray_path_ = GetV2RayPath();
  config_path_ = GetConfigPath();
  
  LOGD_STR("VpnHandler", "Constructor: working_dir_ = " + working_dir_);
  LOGD_STR("VpnHandler", "Constructor: v2ray_path_ = " + v2ray_path_);
  LOGD_STR("VpnHandler", "Constructor: config_path_ = " + config_path_);
  
  // 确保工作目录存在
  DIR* dir = opendir(working_dir_.c_str());
  if (dir) {
    closedir(dir);
    LOGD("VpnHandler", "Constructor: working directory exists");
  } else {
    LOGD_STR("VpnHandler", "Constructor: creating working directory: " + working_dir_);
    if (mkdir(working_dir_.c_str(), 0755) != 0) {
      LOGE_STR("VpnHandler", "Constructor: failed to create directory, error=" + std::to_string(errno));
    }
  }
  
  LOGD("VpnHandler", "========== Constructor END ==========");
}

VpnHandler::~VpnHandler() {
  LOGD("VpnHandler", "========== Destructor START ==========");
  
  StopV2RayProcess();
  
  if (monitor_thread_.joinable()) {
    monitor_thread_.join();
  }
  if (stats_thread_.joinable()) {
    stats_thread_.join();
  }
  
  LOGD("VpnHandler", "========== Destructor END ==========");
}

void VpnHandler::SetEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  LOGD("VpnHandler", "SetEventSink: starting");
  std::lock_guard<std::mutex> lock(mutex_);
  event_sink_ = std::move(events);
  LOGD("VpnHandler", "SetEventSink: completed");
}

void VpnHandler::OnListen(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  LOGD("VpnHandler", "OnListen: starting");
  SetEventSink(std::move(events));
  LOGD("VpnHandler", "OnListen: completed");
}

void VpnHandler::OnCancel(const flutter::EncodableValue* arguments) {
  LOGD("VpnHandler", "OnCancel: starting");
  std::lock_guard<std::mutex> lock(mutex_);
  event_sink_.reset();
  LOGD("VpnHandler", "OnCancel: completed");
}

void VpnHandler::SendEvent(const std::string& type, const flutter::EncodableMap& data) {
  std::lock_guard<std::mutex> lock(mutex_);
  
  if (!event_sink_) {
    LOGD("VpnHandler", "SendEvent: event_sink_ is null, skipping");
    return;
  }
  
  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue(type);
  for (const auto& [key, value] : data) {
    event[key] = value;
  }
  
  LOGD_STR("VpnHandler", "SendEvent: sending event type=" + type);
  event_sink_->Success(flutter::EncodableValue(event));
}

void VpnHandler::Connect(
    flutter::EncodableMap config,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  LOGD("Connect", "========== CONNECT START ==========");
  LOGD_STR("Connect", "Connect: config size=" + std::to_string(config.size()));
  
  std::thread([this, config, result = std::move(result)]() mutable {
    try {
      LOGD("Connect", "Connect: thread started");
      
      {
        std::lock_guard<std::mutex> lock(mutex_);
        
        if (is_running_) {
          LOGE("Connect", "Connect: already running!");
          result->Error("ALREADY_RUNNING", "v2ray-core is already running");
          return;
        }
        
        LOGD("Connect", "Connect: sending 'connecting' event");
        SendEvent("connecting", flutter::EncodableMap{});
      }
      
      // 步骤 1: 准备 v2ray-core
      LOGD("Connect", "Connect: ===== STEP 1: PrepareV2Ray =====");
      if (!PrepareV2Ray()) {
        LOGE("Connect", "Connect: PrepareV2Ray FAILED!");
        SendEvent("error", {{flutter::EncodableValue("message"), flutter::EncodableValue("Failed to prepare v2ray-core")}});
        result->Error("PREPARE_FAILED", "Failed to prepare v2ray-core");
        return;
      }
      LOGD("Connect", "Connect: PrepareV2Ray SUCCESS");
      
      // 步骤 2: 生成配置文件
      LOGD("Connect", "Connect: ===== STEP 2: GenerateConfig =====");
      {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!GenerateConfig(config)) {
          LOGE("Connect", "Connect: GenerateConfig FAILED!");
          SendEvent("error", {{flutter::EncodableValue("message"), flutter::EncodableValue("Failed to generate config")}});
          result->Error("CONFIG_ERROR", "Failed to generate configuration");
          return;
        }
      }
      LOGD("Connect", "Connect: GenerateConfig SUCCESS");
      
      // 步骤 3: 启动 v2ray-core 进程
      LOGD("Connect", "Connect: ===== STEP 3: StartV2RayProcess =====");
      if (!StartV2RayProcess()) {
        LOGE("Connect", "Connect: StartV2RayProcess FAILED!");
        SendEvent("error", {{flutter::EncodableValue("message"), flutter::EncodableValue("Failed to start v2ray-core")}});
        result->Error("START_FAILED", "Failed to start v2ray-core");
        return;
      }
      LOGD("Connect", "Connect: StartV2RayProcess SUCCESS");
      
      // 步骤 4: 测试连接
      LOGD("Connect", "Connect: ===== STEP 4: TestConnection =====");
      std::this_thread::sleep_for(std::chrono::seconds(2));
      bool connectionOk = TestConnection();
      
      if (!connectionOk) {
        LOGE("Connect", "Connect: TestConnection FAILED!");
        StopV2RayProcess();
        SendEvent("error", {{flutter::EncodableValue("message"), flutter::EncodableValue("Connection test failed")}});
        result->Error("CONNECTION_FAILED", "Connection test failed");
        return;
      }
      LOGD("Connect", "Connect: TestConnection SUCCESS");
      
      // 启动监控和统计线程
      {
        std::lock_guard<std::mutex> lock(mutex_);
        is_running_ = true;
        is_connected_ = true;
      }
      
      LOGD("Connect", "Connect: starting monitor thread");
      monitor_thread_ = std::thread(&VpnHandler::MonitorProcess, this);
      
      LOGD("Connect", "Connect: starting stats thread");
      stats_thread_ = std::thread(&VpnHandler::CollectTrafficStats, this);
      
      SendEvent("connected", {{flutter::EncodableValue("message"), flutter::EncodableValue("VPN connected successfully")}});
      
      LOGD("Connect", "========== CONNECT SUCCESS ==========");
      result->Success(flutter::EncodableValue(true));
      
    } catch (const std::exception& e) {
      LOGE_STR("Connect", "Connect: EXCEPTION: " + std::string(e.what()));
      SendEvent("error", {{flutter::EncodableValue("message"), flutter::EncodableValue(e.what())}});
      result->Error("EXCEPTION", e.what());
    } catch (...) {
      LOGE("Connect", "Connect: UNKNOWN EXCEPTION!");
      SendEvent("error", {{flutter::EncodableValue("message"), flutter::EncodableValue("Unknown error occurred")}});
      result->Error("UNKNOWN_ERROR", "Unknown error occurred");
    }
  }).detach();
}

void VpnHandler::Disconnect(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  LOGD("Disconnect", "========== DISCONNECT START ==========");
  
  std::lock_guard<std::mutex> lock(mutex_);
  
  if (!is_running_) {
    LOGD("Disconnect", "Disconnect: not running, returning success");
    result->Success(flutter::EncodableValue(true));
    return;
  }
  
  LOGD("Disconnect", "Disconnect: sending 'disconnecting' event");
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
  LOGD("Disconnect", "========== DISCONNECT COMPLETE ==========");
}

void VpnHandler::GetStatus(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  LOGD("GetStatus", "========== GET STATUS START ==========");
  
  std::lock_guard<std::mutex> lock(mutex_);
  
  flutter::EncodableMap status;
  status[flutter::EncodableValue("connected")] = flutter::EncodableValue(is_connected_.load());
  status[flutter::EncodableValue("running")] = flutter::EncodableValue(is_running_.load());
  status[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(upload_speed_.load());
  status[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(download_speed_.load());
  status[flutter::EncodableValue("totalUpload")] = flutter::EncodableValue(total_upload_.load());
  status[flutter::EncodableValue("totalDownload")] = flutter::EncodableValue(total_download_.load());
  
  LOGD_STR("GetStatus", "GetStatus: connected=" + std::to_string(is_connected_.load()));
  LOGD_STR("GetStatus", "GetStatus: running=" + std::to_string(is_running_.load()));
  
  result->Success(flutter::EncodableValue(status));
  LOGD("GetStatus", "========== GET STATUS COMPLETE ==========");
}

bool VpnHandler::PrepareV2Ray() {
  LOGD("PrepareV2Ray", "==== PrepareV2Ray START ====");
  
  // 检查 v2ray 是否存在且可执行
  if (access(v2ray_path_.c_str(), X_OK) == 0) {
    LOGD_STR("PrepareV2Ray", "v2ray-core already exists at " + v2ray_path_);
    return true;
  }
  
  LOGD("PrepareV2Ray", "v2ray-core not found, searching...");
  
  // 搜索可能的位置
  std::vector<std::string> searchPaths = {
    "/usr/local/bin/v2ray",
    "/usr/bin/v2ray",
    "/opt/v2ray/v2ray",
    "/snap/bin/v2ray"
  };
  
  for (const auto& path : searchPaths) {
    LOGD_STR("PrepareV2Ray", "Checking " + path);
    if (access(path.c_str(), X_OK) == 0) {
      LOGD_STR("PrepareV2Ray", "Found v2ray at " + path);
      
      // 复制到工作目录
      std::string copyCmd = "cp " + path + " " + v2ray_path_;
      int ret = system(copyCmd.c_str());
      if (ret == 0) {
        // 设置执行权限
        chmod(v2ray_path_.c_str(), 0755);
        LOGD("PrepareV2Ray", "Copied v2ray successfully");
        return true;
      }
    }
  }
  
  // 从 PATH 环境变量搜索
  char* pathEnv = getenv("PATH");
  if (pathEnv) {
    std::string pathStr(pathEnv);
    std::stringstream ss(pathStr);
    std::string dir;
    
    while (std::getline(ss, dir, ':')) {
      std::string v2rayInPath = dir + "/v2ray";
      if (access(v2rayInPath.c_str(), X_OK) == 0) {
        LOGD_STR("PrepareV2Ray", "Found v2ray in PATH at " + v2rayInPath);
        
        std::string copyCmd = "cp " + v2rayInPath + " " + v2ray_path_;
        int ret = system(copyCmd.c_str());
        if (ret == 0) {
          chmod(v2ray_path_.c_str(), 0755);
          LOGD("PrepareV2Ray", "Copied v2ray successfully");
          return true;
        }
      }
    }
  }
  
  LOGE("PrepareV2Ray", "v2ray-core not found in any location!");
  return false;
}

bool VpnHandler::GenerateConfig(const flutter::EncodableMap& flutterConfig) {
  LOGD("GenerateConfig", "==== GenerateConfig START ====");
  
  std::string protocol, address, uuid, security, network;
  int port = 443;
  
  for (const auto& [key, value] : flutterConfig) {
    if (std::holds_alternative<std::string>(key)) {
      const std::string& keyStr = std::get<std::string>(key);
      
      if (keyStr == "protocol" && std::holds_alternative<std::string>(value)) {
        protocol = std::get<std::string>(value);
        LOGD_STR("GenerateConfig", "GenerateConfig: protocol=" + protocol);
      } else if (keyStr == "address" && std::holds_alternative<std::string>(value)) {
        address = std::get<std::string>(value);
        LOGD_STR("GenerateConfig", "GenerateConfig: address=" + address);
      } else if (keyStr == "port" && std::holds_alternative<int>(value)) {
        port = std::get<int>(value);
        LOGD_STR("GenerateConfig", "GenerateConfig: port=" + std::to_string(port));
      } else if (keyStr == "uuid" && std::holds_alternative<std::string>(value)) {
        uuid = std::get<std::string>(value);
        LOGD_STR("GenerateConfig", "GenerateConfig: uuid=" + uuid);
      } else if (keyStr == "security" && std::holds_alternative<std::string>(value)) {
        security = std::get<std::string>(value);
        LOGD_STR("GenerateConfig", "GenerateConfig: security=" + security);
      } else if (keyStr == "network" && std::holds_alternative<std::string>(value)) {
        network = std::get<std::string>(value);
        LOGD_STR("GenerateConfig", "GenerateConfig: network=" + network);
      }
    }
  }
  
  // 验证必需参数
  if (protocol.empty() || address.empty() || uuid.empty()) {
    LOGE("GenerateConfig", "Missing required parameters!");
    return false;
  }
  
  std::string streamSecurity = (port == 443 ? "tls" : "none");
  std::string networkType = (network.empty() ? "tcp" : network);
  std::string securityType = (security.empty() ? "auto" : security);
  
  std::ostringstream json;
  json << R"({
    "log": {
      "loglevel": "warning"
    },
    "inbounds": [{
      "port": )" << PROXY_PORT << R"(,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
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
  
  std::ofstream file(config_path_);
  if (!file.is_open()) {
    LOGE("GenerateConfig", "Failed to open config file for writing");
    LOGE_STR("GenerateConfig", "config_path=" + config_path_);
    return false;
  }
  
  file << json.str();
  file.close();
  
  LOGD_STR("GenerateConfig", "GenerateConfig: config written to " + config_path_);
  LOGD("GenerateConfig", "==== GenerateConfig SUCCESS ====");
  return true;
}

bool VpnHandler::StartV2RayProcess() {
  LOGD("StartV2Ray", "==== StartV2RayProcess START ====");
  LOGD_STR("StartV2Ray", "StartV2Ray: v2ray_path_=" + v2ray_path_);
  LOGD_STR("StartV2Ray", "StartV2Ray: config_path_=" + config_path_);
  LOGD_STR("StartV2Ray", "StartV2Ray: working_dir_=" + working_dir_);
  
  // 检查 v2ray 是否存在
  if (access(v2ray_path_.c_str(), X_OK) != 0) {
    LOGE("StartV2Ray", "v2ray not found or not executable!");
    return false;
  }
  
  // 检查配置文件
  if (access(config_path_.c_str(), R_OK) != 0) {
    LOGE("StartV2Ray", "config.json not found!");
    return false;
  }
  
  // 使用 fork 和 exec 启动 v2ray
  pid_t pid = fork();
  
  if (pid < 0) {
    LOGE("StartV2Ray", "fork() failed!");
    return false;
  }
  
  if (pid == 0) {
    // 子进程
    LOGD("StartV2Ray", "Child process: changing directory to working_dir");
    if (chdir(working_dir_.c_str()) != 0) {
      LOGE("StartV2Ray", "Child process: chdir() failed!");
      _exit(1);
    }
    
    // 重定向输出到文件
    std::string logFile = working_dir_ + "/v2ray.log";
    int logFd = open(logFile.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (logFd >= 0) {
      dup2(logFd, STDOUT_FILENO);
      dup2(logFd, STDERR_FILENO);
      close(logFd);
    }
    
    // 执行 v2ray
    LOGD_STR("StartV2Ray", "Child process: executing " + v2ray_path_);
    execl(v2ray_path_.c_str(), "v2ray", "-config", config_path_.c_str(), (char*)NULL);
    
    // 如果 execl 返回，说明失败了
    LOGE("StartV2Ray", "Child process: execl() failed!");
    _exit(1);
  }
  
  // 父进程
  v2ray_pid_ = pid;
  LOGD_STR("StartV2Ray", "StartV2Ray: v2ray started with pid=" + std::to_string(pid));
  
  // 等待一下让进程启动
  std::this_thread::sleep_for(std::chrono::milliseconds(500));
  
  // 检查进程是否还在运行
  int status;
  if (waitpid(pid, &status, WNOHANG) != 0) {
    LOGE("StartV2Ray", "v2ray process exited immediately!");
    v2ray_pid_ = -1;
    return false;
  }
  
  LOGD("StartV2Ray", "==== StartV2RayProcess SUCCESS ====");
  return true;
}

void VpnHandler::StopV2RayProcess() {
  LOGD("StopV2Ray", "==== StopV2RayProcess START ====");
  LOGD_STR("StopV2Ray", "StopV2Ray: v2ray_pid_=" + std::to_string(v2ray_pid_));
  
  if (v2ray_pid_ > 0) {
    LOGD("StopV2Ray", "Sending SIGTERM to v2ray");
    if (kill(v2ray_pid_, SIGTERM) == 0) {
      // 等待一下
      usleep(100000); // 100ms
      
      // 检查是否还在运行
      int status;
      if (waitpid(v2ray_pid_, &status, WNOHANG) == 0) {
        LOGD("StopV2Ray", "v2ray still running, sending SIGKILL");
        kill(v2ray_pid_, SIGKILL);
        waitpid(v2ray_pid_, &status, 0);
      }
    }
    
    v2ray_pid_ = -1;
    LOGD("StopV2Ray", "v2ray process stopped");
  }
  
  LOGD("StopV2Ray", "==== StopV2RayProcess END ====");
}

void VpnHandler::MonitorProcess() {
  LOGD("Monitor", "==== MonitorProcess START ====");
  
  while (is_running_) {
    if (v2ray_pid_ > 0) {
      int status;
      pid_t ret = waitpid(v2ray_pid_, &status, WNOHANG);
      
      if (ret != 0 && ret != -1) {
        LOGE("Monitor", "v2ray-core process has EXITED!");
        is_running_ = false;
        is_connected_ = false;
        SendEvent("error", {{flutter::EncodableValue("message"), flutter::EncodableValue("v2ray-core process exited unexpectedly")}});
        break;
      }
    }
    
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
  }
  
  LOGD("Monitor", "==== MonitorProcess END ====");
}

void VpnHandler::CollectTrafficStats() {
  LOGD("Stats", "==== CollectTrafficStats START ====");
  
  int64_t lastRx = 0, lastTx = 0;
  bool firstRead = true;
  
  while (is_running_) {
    std::this_thread::sleep_for(std::chrono::milliseconds(STATS_INTERVAL_MS));
    
    // 读取 tun0 接口的流量
    int64_t currentRx = 0, currentTx = 0;
    
    std::ifstream netFile("/proc/net/dev");
    std::string line;
    while (std::getline(netFile, line)) {
      // 查找 tun0 或其他代理接口
      if (line.find("tun0") != std::string::npos ||
          line.find("vpn") != std::string::npos ||
          line.find("utun") != std::string::npos) {
        std::istringstream iss(line);
        std::string iface;
        iss >> iface;
        // 去掉冒号
        iface = iface.substr(0, iface.length() - 1);
        
        int64_t rx, tx;
        iss >> rx >> tx;
        currentRx = rx;
        currentTx = tx;
        
        if (firstRead) {
          lastRx = currentRx;
          lastTx = currentTx;
          firstRead = false;
        }
        break;
      }
    }
    netFile.close();
    
    if (!firstRead) {
      int64_t deltaRx = currentRx - lastRx;
      int64_t deltaTx = currentTx - lastTx;
      
      lastRx = currentRx;
      lastTx = currentTx;
      
      if (deltaRx >= 0 && deltaTx >= 0) {
        total_upload_ += deltaTx;
        total_download_ += deltaRx;
        upload_speed_ = deltaTx;
        download_speed_ = deltaRx;
        
        SendEvent("stats", {
          {flutter::EncodableValue("uploadSpeed"), flutter::EncodableValue(upload_speed_.load())},
          {flutter::EncodableValue("downloadSpeed"), flutter::EncodableValue(download_speed_.load())},
          {flutter::EncodableValue("totalUpload"), flutter::EncodableValue(total_upload_.load())},
          {flutter::EncodableValue("totalDownload"), flutter::EncodableValue(total_download_.load())}
        });
      }
    }
  }
  
  LOGD("Stats", "==== CollectTrafficStats END ====");
}

bool VpnHandler::TestConnection() {
  LOGD("TestConn", "==== TestConnection START ====");
  
  int sock = socket(AF_INET, SOCK_STREAM, 0);
  if (sock < 0) {
    LOGE("TestConn", "socket() failed!");
    return false;
  }
  
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(PROXY_PORT);
  addr.sin_addr.s_addr = inet_addr(PROXY_HOST);
  
  // 设置超时
  struct timeval tv;
  tv.tv_sec = CONNECTION_TIMEOUT_MS / 1000;
  tv.tv_usec = 0;
  setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
  setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
  
  bool success = (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) == 0);
  
  close(sock);
  
  if (success) {
    LOGD("TestConn", "TestConnection SUCCESS - proxy is reachable");
  } else {
    LOGE("TestConn", "TestConnection FAILED - proxy is not reachable");
  }
  
  LOGD("TestConn", "==== TestConnection END ====");
  return success;
}

std::string VpnHandler::GetWorkingDir() {
  const char* home = getenv("HOME");
  std::string configDir;
  
  // 优先使用 XDG_CONFIG_HOME
  const char* xdgConfig = getenv("XDG_CONFIG_HOME");
  if (xdgConfig) {
    configDir = std::string(xdgConfig) + "/nebula_vpn";
  } else if (home) {
    configDir = std::string(home) + "/.config/nebula_vpn";
  } else {
    configDir = "/tmp/nebula_vpn";
  }
  
  LOGD_STR("VpnHandler", "GetWorkingDir: " + configDir);
  return configDir;
}

std::string VpnHandler::GetV2RayPath() {
  return GetWorkingDir() + "/v2ray";
}

std::string VpnHandler::GetConfigPath() {
  return GetWorkingDir() + "/config.json";
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
