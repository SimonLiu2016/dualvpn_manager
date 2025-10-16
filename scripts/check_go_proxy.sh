#!/bin/bash

# Go代理核心服务检测脚本
# 用于检测go-proxy-core服务的运行状态

echo "检测Go代理核心服务状态..."

# 检查端口是否被占用
echo "检查端口占用情况:"
PORTS_USED=false

# 检查端口是否被占用（改进的检测方法）
if lsof -Pi :6160 -sTCP:LISTEN >/dev/null 2>&1 || netstat -an | grep LISTEN | grep "\.6160 " >/dev/null 2>&1; then
    echo "  HTTP代理服务正在运行 (端口 6160)"
    PORTS_USED=true
else
    echo "  HTTP代理服务未运行 (端口 6160)"
fi

if lsof -Pi :6161 -sTCP:LISTEN >/dev/null 2>&1 || netstat -an | grep LISTEN | grep "\.6161 " >/dev/null 2>&1; then
    echo "  SOCKS5代理服务正在运行 (端口 6161)"
    PORTS_USED=true
else
    echo "  SOCKS5代理服务未运行 (端口 6161)"
fi

if lsof -Pi :6162 -sTCP:LISTEN >/dev/null 2>&1 || netstat -an | grep LISTEN | grep "\.6162 " >/dev/null 2>&1; then
    echo "  API服务正在运行 (端口 6162)"
    PORTS_USED=true
else
    echo "  API服务未运行 (端口 6162)"
fi

# 如果端口都没有被占用，直接返回
if [ "$PORTS_USED" = false ]; then
    echo ""
    echo "未检测到运行中的Go代理核心服务"
    echo "服务检测完成"
    exit 0
fi

# 检测API接口是否响应正常
echo ""
echo "检测API接口响应..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:6162/status 2>/dev/null)
if [ "$HTTP_STATUS" == "200" ]; then
    echo "  API服务响应正常 (HTTP状态码: $HTTP_STATUS)"
else
    echo "  API服务响应异常 (HTTP状态码: $HTTP_STATUS)"
fi

# 获取当前协议列表
echo ""
echo "当前支持的协议列表:"
PROTOCOLS_OUTPUT=$(curl -s http://127.0.0.1:6162/protocols 2>/dev/null)
if [ -n "$PROTOCOLS_OUTPUT" ]; then
    echo "$PROTOCOLS_OUTPUT" | jq '.' 2>/dev/null || echo "$PROTOCOLS_OUTPUT"
else
    echo "  无法获取协议列表"
fi

echo ""
echo "服务检测完成"