#!/bin/bash

# Go代理核心服务停止脚本
# 用于停止正在运行的go-proxy-core进程

echo "正在停止Go代理核心服务..."

# 查找并终止go-proxy-core进程
PIDS=$(pgrep -f "go-proxy-core")
if [ ! -z "$PIDS" ]; then
    echo "找到go-proxy-core进程，正在终止..."
    for PID in $PIDS; do
        echo "  终止进程 PID: $PID"
        kill $PID
    done
    
    # 等待进程终止
    sleep 2
    
    # 检查进程是否仍然存在
    for PID in $PIDS; do
        if kill -0 $PID 2>/dev/null; then
            echo "  进程 $PID 仍未终止，强制终止..."
            kill -9 $PID
        else
            echo "  进程 $PID 已成功终止"
        fi
    done
else
    echo "未找到运行中的go-proxy-core进程"
fi

# 查找并终止通过go run启动的进程
GO_RUN_PIDS=$(pgrep -f "go-build.*main")
if [ ! -z "$GO_RUN_PIDS" ]; then
    echo "找到通过go run启动的进程，正在终止..."
    for PID in $GO_RUN_PIDS; do
        echo "  终止进程 PID: $PID"
        kill $PID
    done
    
    # 等待进程终止
    sleep 2
    
    # 检查进程是否仍然存在
    for PID in $GO_RUN_PIDS; do
        if kill -0 $PID 2>/dev/null; then
            echo "  进程 $PID 仍未终止，强制终止..."
            kill -9 $PID
        else
            echo "  进程 $PID 已成功终止"
        fi
    done
else
    echo "未找到通过go run启动的进程"
fi

# 如果以上方法都找不到进程，尝试查找占用端口的进程
echo "检查端口占用情况..."
for PORT in 6160 6161 6162; do
    PORT_PIDS=$(lsof -ti :$PORT)
    if [ ! -z "$PORT_PIDS" ]; then
        echo "找到占用端口 $PORT 的进程，正在终止..."
        for PID in $PORT_PIDS; do
            echo "  终止进程 PID: $PID"
            kill $PID
        done
    fi
done

echo "服务停止完成"