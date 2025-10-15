#!/bin/bash

# 构建特权助手工具

# 设置变量
HELPER_NAME="PrivilegedHelper"
HELPER_DIR="macos/PrivilegedHelper"  # 更新助手工具目录路径
BUILD_DIR="build/macos/Build/Products/Release"
WORKSPACE_DIR=$(pwd)

# 创建构建目录
mkdir -p "${BUILD_DIR}"

# 构建助手工具
echo "构建特权助手工具..."
cd "${WORKSPACE_DIR}/${HELPER_DIR}"

# 对于Swift项目，我们直接编译源文件
# 创建临时构建目录
TEMP_BUILD_DIR="/tmp/privileged_helper_build"
rm -rf "${TEMP_BUILD_DIR}"
mkdir -p "${TEMP_BUILD_DIR}"

# 编译Swift文件
swiftc -o "${TEMP_BUILD_DIR}/${HELPER_NAME}" main.swift

# 验证构建是否成功
if [ ! -f "${TEMP_BUILD_DIR}/${HELPER_NAME}" ]; then
    echo "错误: 构建特权助手工具失败"
    exit 1
fi

echo "特权助手工具构建成功: ${TEMP_BUILD_DIR}/${HELPER_NAME}"

# 创建.app bundle结构
HELPER_APP_DIR="${WORKSPACE_DIR}/${BUILD_DIR}/${HELPER_NAME}.app"
mkdir -p "${HELPER_APP_DIR}/Contents/MacOS"
mkdir -p "${HELPER_APP_DIR}/Contents/Resources"

# 复制可执行文件
cp "${TEMP_BUILD_DIR}/${HELPER_NAME}" "${HELPER_APP_DIR}/Contents/MacOS/com.v8en.dualvpnManager.PrivilegedHelper"

# 复制Info.plist
cp com.v8en.dualvpnManager.PrivilegedHelper-Info.plist "${HELPER_APP_DIR}/Contents/com.v8en.dualvpnManager.PrivilegedHelper-Info.plist"
cp com.v8en.dualvpnManager.PrivilegedHelper-Launchd.plist "${HELPER_APP_DIR}/Contents/com.v8en.dualvpnManager.PrivilegedHelper-Launchd.plist"

echo "助手工具.app bundle创建完成: ${HELPER_APP_DIR}"

# 将助手工具复制到Flutter应用资源目录中，以便在构建时包含
FLUTTER_ASSETS_DIR="${WORKSPACE_DIR}/macos/Runner/Assets"
rm -rf "${FLUTTER_ASSETS_DIR}"
mkdir -p "${FLUTTER_ASSETS_DIR}"
cp -R "${HELPER_APP_DIR}" "${FLUTTER_ASSETS_DIR}/"

# 清理临时目录
rm -rf "${TEMP_BUILD_DIR}"

echo "助手工具已复制到Flutter资源目录"