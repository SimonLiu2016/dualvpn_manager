#!/bin/bash

# 卸载和清理特权助手工具脚本
# 用于卸载通过SMJobBless安装的特权助手工具

echo "开始卸载特权助手工具..."

# 设置变量
HELPER_LABEL="com.v8en.dualvpnManager.PrivilegedHelper"
HELPER_PATH="/Library/PrivilegedHelperTools/com.v8en.dualvpnManager.PrivilegedHelper"
LAUNCHD_PLIST="/Library/LaunchDaemons/com.v8en.dualvpnManager.PrivilegedHelper.plist"

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo "警告: 此脚本需要root权限来卸载特权助手工具"
  echo "请使用sudo运行此脚本: sudo ./uninstall_helper.sh"
  exit 1
fi

# 停止助手工具进程（如果正在运行）
echo "检查并停止特权助手工具进程..."
if launchctl list | grep -q "$HELPER_LABEL"; then
  echo "停止特权助手工具服务..."
  launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
  launchctl remove "$HELPER_LABEL" 2>/dev/null || true
else
  echo "特权助手工具服务未运行"
fi

# 终止可能正在运行的进程
echo "终止可能正在运行的特权助手工具进程..."
PIDS=$(pgrep -f "com.v8en.dualvpnManager.PrivilegedHelper")
if [ ! -z "$PIDS" ]; then
  for PID in $PIDS; do
    echo "终止进程 PID: $PID"
    kill -9 $PID 2>/dev/null || true
  done
else
  echo "未找到正在运行的特权助手工具进程"
fi

# 删除特权助手工具可执行文件
echo "删除特权助手工具可执行文件..."
if [ -f "$HELPER_PATH" ]; then
  rm -f "$HELPER_PATH"
  echo "已删除: $HELPER_PATH"
else
  echo "文件不存在: $HELPER_PATH"
fi

# 删除launchd plist文件
echo "删除launchd plist文件..."
if [ -f "$LAUNCHD_PLIST" ]; then
  rm -f "$LAUNCHD_PLIST"
  echo "已删除: $LAUNCHD_PLIST"
else
  echo "文件不存在: $LAUNCHD_PLIST"
fi

# 清理特权助手的容器目录
PRIVILEGED_HELPER_CONTAINER="/private/var/root/Library/Containers/com.v8en.dualvpnManager.PrivilegedHelper"
echo "检查特权助手容器目录: $PRIVILEGED_HELPER_CONTAINER"
if [ -d "$PRIVILEGED_HELPER_CONTAINER" ]; then
  echo "删除特权助手容器目录..."
  rm -rf "$PRIVILEGED_HELPER_CONTAINER"
  echo "已删除容器目录: $PRIVILEGED_HELPER_CONTAINER"
else
  echo "特权助手容器目录不存在"
fi

# 清理可能的缓存文件和日志
echo "清理可能的缓存文件和日志..."
CACHE_DIRS=(
  "/private/var/tmp/dualvpn_macos_helper_*.log"
  "/tmp/dualvpn_macos_helper_*.log"
)

for CACHE_PATTERN in "${CACHE_DIRS[@]}"; do
  if ls $CACHE_PATTERN 1> /dev/null 2>&1; then
    rm -f $CACHE_PATTERN
    echo "已清理缓存文件: $CACHE_PATTERN"
  fi
done

# 清理可能的socket文件
SOCKET_PATH="/var/run/dualvpn_openvpn_helper.sock"
if [ -S "$SOCKET_PATH" ]; then
  rm -f "$SOCKET_PATH"
  echo "已删除socket文件: $SOCKET_PATH"
fi

echo "特权助手工具卸载完成"

# 提示用户可能需要重启以完全清理
echo ""
echo "注意: 为了确保完全清理，建议重启系统"
echo "您可以手动检查以下位置确保文件已被删除:"
echo "  - $HELPER_PATH"
echo "  - $LAUNCHD_PLIST"


