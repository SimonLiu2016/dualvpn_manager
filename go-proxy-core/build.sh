#!/bin/bash

# 构建脚本
echo "Building DualVPN Proxy Core..."

# 设置Go模块
export GO111MODULE=on

# 构建主程序
echo "Building main program..."
go build -o bin/dualvpn-proxy cmd/main.go

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Binary location: bin/dualvpn-proxy"
else
    echo "Build failed!"
    exit 1
fi
