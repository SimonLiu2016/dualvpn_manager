#!/bin/bash

# 自动打包并集成Go代理核心、助手工具和Flutter界面的脚本
# 最终生成macOS的.pkg安装文件，适用于App Store分发

set -e  # 遇到错误时停止执行

echo "开始构建和集成DualVPN Manager (PKG版本)..."

# 获取当前工作目录
WORKSPACE_DIR=$(pwd)
BUILD_DIR="${WORKSPACE_DIR}/build"
MACOS_BUILD_DIR="${BUILD_DIR}/macos"
RELEASE_DIR="${BUILD_DIR}/macos/Build/Products/Release"
PKG_OUTPUT_DIR="${BUILD_DIR}/pkg"

echo "工作目录: ${WORKSPACE_DIR}"

# 1. 清理之前的构建
echo "步骤1: 清理之前的构建..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 2. 设置代码签名
echo "步骤2: 设置代码签名..."
SIGNING_ENABLED=true
echo "在本地环境中启用代码签名..."

# 3. 构建Go代理核心
echo "步骤3: 构建Go代理核心..."
cd "${WORKSPACE_DIR}/go-proxy-core"
go build -o "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" ./cmd/main.go

if [ ! -f "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" ]; then
    echo "错误: Go代理核心构建失败"
    exit 1
fi

echo "Go代理核心构建成功"

# 4. 构建Flutter应用
echo "步骤4: 构建Flutter应用..."
cd "${WORKSPACE_DIR}"
flutter build macos --release

if [ ! -f "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app/Contents/MacOS/Dualvpn Manager" ]; then
    echo "错误: Flutter应用构建失败"
    exit 1
fi

echo "Flutter应用构建成功"

# 5. 复制Go代理核心到应用包中
echo "步骤5: 复制Go代理核心到应用包中..."
APP_CONTENTS_DIR="${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app/Contents"

# https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
echo "复制隐私信息文件..."
cp "${WORKSPACE_DIR}/build/macos/Build/Products/Release/device_info_plus/device_info_plus_privacy.bundle/Contents/Resources/PrivacyInfo.xcprivacy" "${APP_CONTENTS_DIR}/Resources/"

mkdir -p "${APP_CONTENTS_DIR}/Resources/bin"
cp "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" "${APP_CONTENTS_DIR}/Resources/bin/"
cp "${WORKSPACE_DIR}/go-proxy-core/config.yaml" "${APP_CONTENTS_DIR}/Resources/bin/"

# 6. 对添加的文件重新签名
echo "步骤6: 对添加的文件签名..."
# 对Go代理核心进行签名
codesign --force --deep --sign "Apple Distribution: Simon Liu (4UKN65653U)" --timestamp --options runtime --entitlements "${WORKSPACE_DIR}/macos/Runner/go-proxy-entitlements.plist" "${APP_CONTENTS_DIR}/Resources/bin/go-proxy-core"

# 进入应用框架目录
FRAMEWORKS_DIR="${APP_CONTENTS_DIR}/Frameworks"

# 对所有框架签名（包括报错的 device_info_plus.framework）
for framework in "$FRAMEWORKS_DIR"/*.framework; do
  codesign --force --deep --timestamp --sign "Apple Distribution: Simon Liu (4UKN65653U)" "$framework"
done

# 重新签名整个应用
codesign --force --deep --sign "Apple Distribution: Simon Liu (4UKN65653U)" --timestamp --options runtime --entitlements "${WORKSPACE_DIR}/macos/Runner/DebugProfile.entitlements" "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app"

# 验证签名
codesign --verify --deep --strict "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app"
echo "应用签名完成并验证通过"

echo "Go代理核心复制完成"

# 7. 创建PKG安装文件
echo "步骤7: 创建PKG安装文件..."

# 创建临时目录用于PKG构建
PKG_TEMP_DIR="/tmp/dualvpn-pkg"
if [ -d "${PKG_TEMP_DIR}" ]; then
    rm -rf "${PKG_TEMP_DIR}"
fi
mkdir -p "${PKG_TEMP_DIR}"

# 复制应用到临时目录
cp -R "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app" "${PKG_TEMP_DIR}/"

# 获取版本号
VERSION=$(grep "version:" "${WORKSPACE_DIR}/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')

# 使用pkgbuild创建PKG文件
PKG_NAME="DualVPN_Manager_${VERSION}.pkg"
PKG_PATH="${PKG_OUTPUT_DIR}/${PKG_NAME}"

# 创建pkg输出目录
mkdir -p "${PKG_OUTPUT_DIR}"

# 创建组件plist文件
COMPONENT_PLIST="/tmp/Info.plist"
cat > "${COMPONENT_PLIST}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>BundleHasStrictIdentifier</key>
        <true/>
        <key>BundleIsRelocatable</key>
        <false/>
        <key>BundleIsVersionChecked</key>
        <true/>
        <key>BundleOverwriteAction</key>
        <string>upgrade</string>
        <key>RootRelativeBundlePath</key>
        <string>Dualvpn Manager.app</string>
    </dict>
</array>
</plist>
EOF

# 步骤7: 创建PKG安装文件
productbuild \
  --product "${PKG_TEMP_DIR}/Dualvpn Manager.app/Contents/Info.plist" \
  --identifier "com.v8en.dualvpnManager.pkg" \
  --version "${VERSION}" \
  --sign "3rd Party Mac Developer Installer: Simon Liu (4UKN65653U)" \
  --component "${PKG_TEMP_DIR}/Dualvpn Manager.app" /Applications \
  "${PKG_PATH}"

# 清理临时文件
rm -f "${COMPONENT_PLIST}"
rm -rf "${PKG_TEMP_DIR}"

if [ ! -f "${PKG_PATH}" ]; then
    echo "错误: PKG文件创建失败"
    exit 1
fi

echo "PKG安装文件创建成功: ${PKG_PATH}"

# 6. 显示构建结果
echo ""
echo "==================== 构建完成 ===================="
echo "应用包位置: ${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app"
echo "PKG安装文件位置: ${PKG_PATH}"
echo "=================================================="
echo ""
echo "此PKG文件可用于App Store分发。"
echo "注意：对于App Store分发，您需要使用Xcode Organizer或Transporter上传此PKG文件。"
echo ""

exit 0