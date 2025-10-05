#!/bin/bash

# 创建带有Applications链接的DMG文件

set -e

WORKSPACE_DIR=$(pwd)
RELEASE_DIR="${WORKSPACE_DIR}/build/macos/Build/Products/Release"

echo "创建DMG文件..."

# 检查必要的文件是否存在
if [ ! -d "${RELEASE_DIR}/dualvpn_manager.app" ]; then
    echo "错误: dualvpn_manager.app 不存在"
    exit 1
fi

# 删除旧的DMG文件（如果存在）
if [ -f "${RELEASE_DIR}/dualvpn_manager.dmg" ]; then
    rm "${RELEASE_DIR}/dualvpn_manager.dmg"
fi

# 使用create-dmg创建新的DMG文件
cd "${RELEASE_DIR}"
create-dmg "dualvpn_manager.dmg" "dualvpn_manager.app"

echo "DMG文件创建完成: ${RELEASE_DIR}/dualvpn_manager.dmg"