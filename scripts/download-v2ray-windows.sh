#!/bin/bash

# Windows v2ray-core 自动下载脚本
# 在 flutter build windows 之前执行

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
V2RAY_DIR="$PROJECT_ROOT/windows/runner/v2ray"
V2RAY_VERSION="v5.22.0"
V2RAY_URL="https://github.com/v2fly/v2ray-core/releases/download/$V2RAY_VERSION/v2ray-windows-64.zip"

echo "========================================="
echo "Nebula VPN - v2ray-core 下载脚本"
echo "========================================="
echo ""

# 检查是否已存在
if [ -f "$V2RAY_DIR/v2ray.exe" ]; then
    echo "✓ v2ray-core 已存在，跳过下载"
    echo "  路径：$V2RAY_DIR/v2ray.exe"
    exit 0
fi

# 创建目录
echo "创建目录：$V2RAY_DIR"
mkdir -p "$V2RAY_DIR"

# 下载
echo ""
echo "下载 v2ray-core $V2RAY_VERSION..."
echo "URL: $V2RAY_URL"
echo ""

TEMP_ZIP=$(mktemp)
trap "rm -f $TEMP_ZIP" EXIT

if command -v curl &> /dev/null; then
    curl -L -# "$V2RAY_URL" -o "$TEMP_ZIP"
elif command -v wget &> /dev/null; then
    wget -q --show-progress "$V2RAY_URL" -O "$TEMP_ZIP"
else
    echo "错误：需要 curl 或 wget"
    exit 1
fi

echo ""
echo "解压文件..."
if command -v unzip &> /dev/null; then
    unzip -q "$TEMP_ZIP" -d "$V2RAY_DIR"
elif command -v 7z &> /dev/null; then
    7z x "$TEMP_ZIP" -o"$V2RAY_DIR" -y
else
    echo "错误：需要 unzip 或 7z"
    exit 1
fi

# 验证
if [ -f "$V2RAY_DIR/v2ray.exe" ]; then
    echo ""
    echo "========================================="
    echo "✓ v2ray-core 下载成功"
    echo "========================================="
    echo "位置：$V2RAY_DIR/"
    echo "文件："
    ls -lh "$V2RAY_DIR/"
    echo ""
else
    echo "错误：v2ray.exe 未找到"
    exit 1
fi
