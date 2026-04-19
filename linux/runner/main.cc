#include <flutter/dart_project.h>
#include <flutter/engine_method_proxy.h>
#include <iostream>
#include <cstdlib>

#include "vpn_handler.h"

int main(int argc, char** argv) {
  std::cout << "NebulaVPN Linux Runner" << std::endl;
  
  // 初始化 VPN Handler
  VpnHandler& vpnHandler = VpnHandler::Instance();
  
  // 注意：真正的 Flutter Engine 集成需要在 Flutter Linux Shell 中进行
  // 这个 main.cc 只是占位符，实际的平台通道集成在 my_application.cc 中
  
  return 0;
}
