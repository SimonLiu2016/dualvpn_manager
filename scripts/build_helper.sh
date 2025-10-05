#!/bin/bash

# 构建特权助手工具

# 设置变量
HELPER_NAME="PrivilegedHelper"
HELPER_DIR="macos/Runner/Helpers/${HELPER_NAME}"
BUILD_DIR="build/macos/Build/Products/Release"
WORKSPACE_DIR=$(pwd)

# 创建构建目录
mkdir -p "${BUILD_DIR}"

# 构建助手工具
echo "构建特权助手工具..."
cd "${WORKSPACE_DIR}/${HELPER_DIR}"

# 初始化助手工具的Go模块（独立于主应用）
go mod init com.dualvpn.manager.helper
go mod tidy

go build -o "${WORKSPACE_DIR}/${BUILD_DIR}/${HELPER_NAME}" .

# 验证构建是否成功
if [ ! -f "${WORKSPACE_DIR}/${BUILD_DIR}/${HELPER_NAME}" ]; then
    echo "错误: 构建特权助手工具失败"
    exit 1
fi

echo "特权助手工具构建成功: ${WORKSPACE_DIR}/${BUILD_DIR}/${HELPER_NAME}"

# 创建.app bundle结构
HELPER_APP_DIR="${WORKSPACE_DIR}/${BUILD_DIR}/${HELPER_NAME}.app"
mkdir -p "${HELPER_APP_DIR}/Contents/MacOS"
mkdir -p "${HELPER_APP_DIR}/Contents/Resources"

# 复制可执行文件
cp "${WORKSPACE_DIR}/${BUILD_DIR}/${HELPER_NAME}" "${HELPER_APP_DIR}/Contents/MacOS/"

# 复制Info.plist
cp Info.plist "${HELPER_APP_DIR}/Contents/"

# 复制entitlements文件
cp Helper.entitlements "${HELPER_APP_DIR}/Contents/Resources/"

echo "助手工具.app bundle创建完成: ${HELPER_APP_DIR}"

# 将助手工具复制到Flutter应用资源目录中，以便在构建时包含
FLUTTER_ASSETS_DIR="${WORKSPACE_DIR}/macos/Runner/Assets"
mkdir -p "${FLUTTER_ASSETS_DIR}"
cp -R "${HELPER_APP_DIR}" "${FLUTTER_ASSETS_DIR}/"