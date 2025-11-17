#!/bin/bash

# 自动打包并集成Go代理核心、助手工具和Flutter界面的脚本
# 最终生成macOS的.dmg安装文件

set -e  # 遇到错误时停止执行

echo "开始构建和集成DualVPN Manager..."

# 获取当前工作目录
WORKSPACE_DIR=$(pwd)
BUILD_DIR="${WORKSPACE_DIR}/build"
MACOS_BUILD_DIR="${BUILD_DIR}/macos"
RELEASE_DIR="${BUILD_DIR}/macos/Build/Products/Release"

echo "工作目录: ${WORKSPACE_DIR}"

# 1. 清理之前的构建
echo "步骤1: 清理之前的构建..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 2. 构建Go代理核心
echo "步骤2: 构建Go代理核心..."
cd "${WORKSPACE_DIR}/go-proxy-core"
./build.sh

if [ ! -d "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core.app" ]; then
    echo "错误: Go代理核心bundle构建失败"
    exit 1
fi

echo "Go代理核心构建成功"

# 3. 构建Flutter应用
echo "步骤3: 构建Flutter应用..."
cd "${WORKSPACE_DIR}"
flutter build macos --release

if [ ! -f "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app/Contents/MacOS/Dualvpn Manager" ]; then
    echo "错误: Flutter应用构建失败"
    exit 1
fi

echo "Flutter应用构建成功"

# 4. 复制Go代理核心bundle到应用包中
echo "步骤4: 复制Go代理核心bundle到应用包中..."
APP_CONTENTS_DIR="${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app/Contents"
mkdir -p "${APP_CONTENTS_DIR}/Resources"

# 复制整个go-proxy-core.app bundle到Resources目录
cp -R "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core.app" "${APP_CONTENTS_DIR}/Resources/"

# 4.1 复制OpenVPN二进制文件到应用包Resources目录
echo "步骤4.1: 复制OpenVPN二进制文件到应用包Resources目录..."
cp "${WORKSPACE_DIR}/go-proxy-core/openvpn/openvpn_bin/openvpn" "${APP_CONTENTS_DIR}/Resources/"
chmod +x "${APP_CONTENTS_DIR}/Resources/openvpn"

# 4.2 复制OpenVPN库文件到应用包Resources目录
echo "步骤4.2: 复制OpenVPN库文件到应用包Resources目录..."
mkdir -p "${APP_CONTENTS_DIR}/Resources/openvpn_frameworks"
cp -R "${WORKSPACE_DIR}/go-proxy-core/openvpn/frameworks/" "${APP_CONTENTS_DIR}/Resources/openvpn_frameworks/"

echo "Go代理核心bundle和OpenVPN文件复制完成"

# 5. 创建DMG安装文件
echo "步骤5: 创建DMG安装文件..."

# 创建带Applications链接的DMG文件
echo "创建带Applications链接的DMG文件..."
DMG_DIR="/tmp/dualvpn-dmg"

# 清理临时目录
if [ -d "${DMG_DIR}" ]; then
    rm -rf "${DMG_DIR}"
fi

# 创建临时目录并复制应用
mkdir -p "${DMG_DIR}"
cp -R "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app" "${DMG_DIR}/"

# 创建Applications链接
ln -s /Applications "${DMG_DIR}/Applications"

# 创建DMG文件
cd /tmp
rm -f "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.dmg"
hdiutil create -volname "DualVPN Manager" -srcfolder "${DMG_DIR}" -ov -format UDZO "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.dmg"

# 清理临时目录
rm -rf "${DMG_DIR}"

if [ ! -f "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.dmg" ]; then
    echo "错误: DMG文件创建失败"
    exit 1
fi

echo "DMG安装文件创建成功: ${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.dmg"

# 6. 显示构建结果
echo ""
echo "==================== 构建完成 ===================="
echo "应用包位置: ${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app"
echo "安装文件位置: ${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.dmg"
echo "=================================================="
echo ""
echo "要测试安装效果，请执行以下步骤："
echo "1. 双击Dualvpn Manager.dmg文件"
echo "2. 将应用拖拽到Applications文件夹"
echo "3. 从Applications文件夹启动应用"
echo ""
echo "首次运行时，系统会提示安装特权助手工具并要求输入管理员密码。"

exit 0