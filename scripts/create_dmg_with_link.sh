#!/bin/bash

# 创建带有Applications链接的DMG文件

set -e

WORKSPACE_DIR=$(pwd)
RELEASE_DIR="${WORKSPACE_DIR}/build/macos/Build/Products/Release"
DMG_DIR="/tmp/dualvpn-dmg"

echo "创建带Applications链接的DMG文件..."

# 检查必要的文件是否存在
if [ ! -d "${RELEASE_DIR}/dualvpn_manager.app" ]; then
    echo "错误: dualvpn_manager.app 不存在"
    exit 1
fi

# 清理临时目录
if [ -d "${DMG_DIR}" ]; then
    rm -rf "${DMG_DIR}"
fi

# 创建临时目录并复制应用
mkdir -p "${DMG_DIR}"
cp -R "${RELEASE_DIR}/dualvpn_manager.app" "${DMG_DIR}/"

# 创建Applications链接
ln -s /Applications "${DMG_DIR}/Applications"

# 创建DMG文件
cd /tmp
rm -f "${RELEASE_DIR}/dualvpn_manager.dmg"
hdiutil create -volname "DualVPN Manager" -srcfolder "${DMG_DIR}" -ov -format UDZO "${RELEASE_DIR}/dualvpn_manager.dmg"

# 清理临时目录
rm -rf "${DMG_DIR}"

echo "DMG文件创建完成: ${RELEASE_DIR}/dualvpn_manager.dmg"