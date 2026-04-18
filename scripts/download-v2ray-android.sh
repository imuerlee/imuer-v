#!/bin/bash

# Android v2ray-core 自动下载脚本
# 在 flutter build apk 之前执行

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
V2RAY_BASE="$PROJECT_ROOT/android/app/src/main/jniLibs"
V2RAY_VERSION="v5.22.0"

echo "========================================="
echo "Nebula VPN - Android v2ray-core 下载"
echo "========================================="
echo ""

# 下载函数
download_arch() {
    local arch=$1
    local url=$2
    local dest_dir="$V2RAY_BASE/$arch"
    
    echo "处理架构：$arch"
    
    # 检查是否已存在
    if [ -f "$dest_dir/libv2ray.so" ]; then
        echo "  ✓ 已存在，跳过"
        return 0
    fi
    
    mkdir -p "$dest_dir"
    
    echo "  下载：$url"
    TEMP_ZIP=$(mktemp)
    trap "rm -f $TEMP_ZIP" EXIT
    
    if command -v curl &> /dev/null; then
        curl -L -# "$url" -o "$TEMP_ZIP"
    elif command -v wget &> /dev/null; then
        wget -q --show-progress "$url" -O "$TEMP_ZIP"
    else
        echo "  错误：需要 curl 或 wget"
        return 1
    fi
    
    echo "  解压..."
    if command -v unzip &> /dev/null; then
        unzip -q "$TEMP_ZIP" -d "$dest_dir"
    else
        echo "  错误：需要 unzip"
        return 1
    fi
    
    # 重命名 v2ray 为 libv2ray.so
    if [ -f "$dest_dir/v2ray" ]; then
        mv "$dest_dir/v2ray" "$dest_dir/libv2ray.so"
    fi
    
    echo "  ✓ 完成"
}

# 下载多个架构
download_arch "arm64-v8a" "https://github.com/v2fly/v2ray-core/releases/download/$V2RAY_VERSION/v2ray-android-arm64-v8a.zip"
download_arch "armeabi-v7a" "https://github.com/v2fly/v2ray-core/releases/download/$V2RAY_VERSION/v2ray-android-armeabi-v7a.zip"
# download_arch "x86" "https://github.com/v2fly/v2ray-core/releases/download/$V2RAY_VERSION/v2ray-android-386.zip"

echo ""
echo "========================================="
echo "✓ v2ray-core 下载完成"
echo "========================================="
echo "位置：$V2RAY_BASE/"
echo "架构："
find "$V2RAY_BASE" -name "libv2ray.so" -exec ls -lh {} \;
echo ""
