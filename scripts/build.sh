#!/bin/bash

# Nebula VPN 统一构建脚本
# 自动下载 v2ray-core 并构建所有平台

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "  Nebula VPN 构建脚本"
echo "========================================="
echo ""

# 检查命令
case "${1:-all}" in
    windows)
        echo "[1/2] 下载 Windows v2ray-core..."
        bash "$SCRIPT_DIR/download-v2ray-windows.sh"
        echo ""
        echo "[2/2] 构建 Windows 应用..."
        flutter build windows
        echo ""
        echo "✓ Windows 构建完成"
        ;;
    
    android)
        echo "[1/2] 下载 Android v2ray-core..."
        bash "$SCRIPT_DIR/download-v2ray-android.sh"
        echo ""
        echo "[2/2] 构建 Android APK..."
        flutter build apk
        echo ""
        echo "✓ Android 构建完成"
        ;;
    
    release)
        echo "[1/3] 下载 Windows v2ray-core..."
        bash "$SCRIPT_DIR/download-v2ray-windows.sh"
        echo ""
        echo "[2/3] 下载 Android v2ray-core..."
        bash "$SCRIPT_DIR/download-v2ray-android.sh"
        echo ""
        echo "[3/3] 构建所有平台..."
        echo ""
        echo "--- Windows ---"
        flutter build windows --release
        echo ""
        echo "--- Android Release ---"
        flutter build apk --release
        echo ""
        echo "--- Android Bundle ---"
        flutter build appbundle --release
        echo ""
        echo "✓ 所有平台构建完成"
        ;;
    
    all)
        $0 release
        ;;
    
    *)
        echo "用法：$0 {windows|android|release|all}"
        echo ""
        echo "  windows   - 仅构建 Windows"
        echo "  android   - 仅构建 Android"
        echo "  release   - 构建所有平台（Release 模式）"
        echo "  all       - 同 release"
        exit 1
        ;;
esac

echo "========================================="
