#!/bin/bash

# DualVPN Proxy Core 打包脚本

set -e

echo "Packaging DualVPN Proxy Core..."

# 检查Go是否安装
if ! command -v go &> /dev/null
then
    echo "Error: Go is not installed"
    exit 1
fi

# 获取操作系统和架构
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

echo "Packaging for $OS/$ARCH"

# 设置输出目录
OUTPUT_DIR="dist"
mkdir -p "$OUTPUT_DIR"

# 构建主程序
echo "Building main proxy core..."
go build -o "$OUTPUT_DIR/dualvpn-proxy" ./cmd/main.go

# 复制配置文件
echo "Copying configuration files..."
cp config.yaml "$OUTPUT_DIR/"
cp rules.yaml "$OUTPUT_DIR/"

# 创建README文件
cat > "$OUTPUT_DIR/README.txt" << EOF
DualVPN Proxy Core
==================

这是一个轻量级的代理核心，支持多种代理协议并实现智能路由功能。

使用方法：
1. 编辑 config.yaml 配置文件
2. 编辑 rules.yaml 路由规则文件
3. 运行 dualvpn-proxy 可执行文件

系统要求：
- Clash (用于Shadowsocks/V2Ray协议)
- OpenVPN (用于OpenVPN协议)

支持的操作系统：
- Windows
- macOS
- Linux
EOF

echo "Packaging completed successfully!"
echo "Distribution package is located in the $OUTPUT_DIR directory:"
ls -la "$OUTPUT_DIR"