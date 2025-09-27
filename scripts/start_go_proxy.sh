#!/bin/bash

# Go代理核心服务启动脚本
# 在启动前检查端口占用情况，如果服务已运行则先停止再启动

echo "Go代理核心服务启动脚本"
echo "======================"

# 检查端口占用情况
echo "检查端口占用情况..."
PORTS_USED=false

# 检查端口时忽略权限错误
if netstat -an | grep LISTEN | grep -q "\.6160 "; then
    echo "  发现端口 6160 (HTTP代理) 被占用"
    PORTS_USED=true
fi

if netstat -an | grep LISTEN | grep -q "\.6161 "; then
    echo "  发现端口 6161 (SOCKS5代理) 被占用"
    PORTS_USED=true
fi

if netstat -an | grep LISTEN | grep -q "\.6162 "; then
    echo "  发现端口 6162 (API服务) 被占用"
    PORTS_USED=true
fi

# 如果端口被占用，先停止现有服务
if [ "$PORTS_USED" = true ]; then
    echo ""
    echo "检测到端口被占用，正在停止现有服务..."
    /Users/simon/Workspace/vsProject/dualvpn_manager/scripts/stop_go_proxy.sh
    sleep 2
else
    echo "  所有端口均未被占用"
fi

# 再次检查端口是否已释放
echo ""
echo "再次检查端口状态..."
PORTS_STILL_USED=false

if netstat -an | grep LISTEN | grep -q "\.6160 "; then
    echo "  端口 6160 (HTTP代理) 仍然被占用，无法启动服务"
    PORTS_STILL_USED=true
fi

if netstat -an | grep LISTEN | grep -q "\.6161 "; then
    echo "  端口 6161 (SOCKS5代理) 仍然被占用，无法启动服务"
    PORTS_STILL_USED=true
fi

if netstat -an | grep LISTEN | grep -q "\.6162 "; then
    echo "  端口 6162 (API服务) 仍然被占用，无法启动服务"
    PORTS_STILL_USED=true
fi

if [ "$PORTS_STILL_USED" = true ]; then
    echo ""
    echo "错误：端口仍然被占用，无法启动服务"
    exit 1
fi

echo "端口检查通过，准备启动服务..."

# 启动Go代理核心服务
echo ""
echo "启动Go代理核心服务..."
cd /Users/simon/Workspace/vsProject/dualvpn_manager/go-proxy-core

# 检查go-proxy-core可执行文件是否存在
if [ -f "./bin/go-proxy-core" ]; then
    echo "使用已编译的可执行文件启动服务..."
    # OpenVPN需要管理员权限来创建TUN设备
    if [ "$NEEDS_ROOT" = "true" ]; then
        echo "以管理员权限启动服务..."
        # 检查是否在macOS上运行
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # 在macOS上，使用sudo启动并确保TUN设备可访问
            sudo -b nohup ./bin/go-proxy-core > /tmp/go-proxy-core.log 2>&1
            echo "服务启动命令已执行（管理员权限）"
        else
            # 在其他系统上直接使用sudo
            sudo -b nohup ./bin/go-proxy-core > /tmp/go-proxy-core.log 2>&1
            echo "服务启动命令已执行（管理员权限）"
        fi
    else
        nohup ./bin/go-proxy-core > /tmp/go-proxy-core.log 2>&1 &
        PID=$!
        echo "服务启动命令已执行，PID: $PID"
    fi
else
    echo "未找到可执行文件，使用go run启动服务..."
    if [ "$NEEDS_ROOT" = "true" ]; then
        echo "以管理员权限启动服务..."
        # 检查是否在macOS上运行
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # 在macOS上，使用sudo启动并确保TUN设备可访问
            sudo -b nohup go run . > /tmp/go-proxy-core.log 2>&1
            echo "服务启动命令已执行（管理员权限）"
        else
            # 在其他系统上直接使用sudo
            sudo -b nohup go run . > /tmp/go-proxy-core.log 2>&1
            echo "服务启动命令已执行（管理员权限）"
        fi
    else
        nohup go run . > /tmp/go-proxy-core.log 2>&1 &
        PID=$!
        echo "服务启动命令已执行，PID: $PID"
    fi
fi

# 等待更长时间让服务启动
echo "等待服务启动..."
sleep 10

# 检查服务是否成功启动
echo ""
echo "检查服务启动状态..."
SERVICE_STARTED=false

if netstat -an | grep LISTEN | grep -q "\.6160 "; then
    echo "  HTTP代理服务已启动 (端口 6160)"
    SERVICE_STARTED=true
else
    echo "  HTTP代理服务启动失败 (端口 6160)"
fi

if netstat -an | grep LISTEN | grep -q "\.6161 "; then
    echo "  SOCKS5代理服务已启动 (端口 6161)"
    SERVICE_STARTED=true
else
    echo "  SOCKS5代理服务启动失败 (端口 6161)"
fi

if netstat -an | grep LISTEN | grep -q "\.6162 "; then
    echo "  API服务已启动 (端口 6162)"
    SERVICE_STARTED=true
else
    echo "  API服务启动失败 (端口 6162)"
fi

if [ "$SERVICE_STARTED" = true ]; then
    echo ""
    echo "Go代理核心服务启动完成！"
    echo "日志文件位置: /tmp/go-proxy-core.log"
    echo ""
    echo "服务端口信息:"
    echo "  HTTP代理端口: 6160"
    echo "  SOCKS5代理端口: 6161"
    echo "  API端口: 6162"
else
    echo ""
    echo "错误：服务启动失败，请检查日志文件 /tmp/go-proxy-core.log"
    echo "显示最近的日志内容："
    tail -n 20 /tmp/go-proxy-core.log
    exit 1
fi