#!/bin/bash

# 构建脚本

echo "构建Go代理核心..."

# 创建bin目录
mkdir -p bin

# 构建主程序，只编译cmd目录下的代码
go build -o bin/go-proxy-core ./cmd

if [ $? -eq 0 ]; then
    echo "构建成功！"
    echo "可执行文件位置: bin/go-proxy-core"
else
    echo "构建失败！"
    exit 1
fi