#!/bin/bash

# 自动打包并集成Go代理核心、助手工具和Flutter界面的脚本
# 最终生成macOS的.pkg安装文件，适用于App Store分发

set -e  # 遇到错误时停止执行

# 错误处理函数
handle_error() {
  log_error "脚本在第 $1 行执行失败"
  log_error "请检查相关日志并重新运行脚本"
  exit 1
}

# 设置错误处理陷阱
trap 'handle_error $LINENO' ERR

# 日志记录函数
log_info() {
  echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
  echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_info "开始构建和集成DualVPN Manager (PKG版本)..."

# 获取当前工作目录
WORKSPACE_DIR=$(pwd)
BUILD_DIR="${WORKSPACE_DIR}/build"
MACOS_BUILD_DIR="${BUILD_DIR}/macos"
RELEASE_DIR="${BUILD_DIR}/macos/Build/Products/Release"
PKG_OUTPUT_DIR="${BUILD_DIR}/pkg"

log_info "工作目录: ${WORKSPACE_DIR}"

# 1. 清理之前的构建
log_info "步骤1: 清理之前的构建..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 2. 设置代码签名
log_info "步骤2: 设置代码签名..."
SIGNING_ENABLED=true
log_info "在本地环境中启用代码签名..."

# 3. 构建Go代理核心
log_info "步骤3: 构建Go代理核心..."
cd "${WORKSPACE_DIR}/go-proxy-core"
# 构建通用二进制文件（支持Intel和Apple Silicon）
GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core-amd64" ./cmd
GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core-arm64" ./cmd
# 创建通用二进制文件
if command -v lipo &> /dev/null; then
  lipo -create -output "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core-amd64" "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core-arm64"
else
  # 如果lipo不可用，使用默认架构
  cp "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core-amd64" "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core"
fi
# 设置正确的权限
chmod +x "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core"

# 验证构建的二进制文件架构
if command -v file &> /dev/null; then
  log_info "Go代理核心二进制文件架构信息:"
  file "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core"
fi

if command -v lipo &> /dev/null; then
  log_info "Go代理核心二进制文件详细架构信息:"
  lipo -info "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core"
fi

# 清理临时文件
rm "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core-amd64" "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core-arm64"

if [ ! -f "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" ]; then
    log_info "错误: Go代理核心构建失败"
    exit 1
fi

# 验证Go代理核心可执行文件
if [ -x "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" ]; then
  log_info "Go代理核心可执行文件具有执行权限"
else
  log_info "错误: Go代理核心可执行文件没有执行权限"
  exit 1
fi

log_info "Go代理核心构建成功"

# 4. 构建Flutter应用
log_info "步骤4: 构建Flutter应用..."
cd "${WORKSPACE_DIR}"
# 设置Flutter构建环境变量以启用代码签名
export MACOS_DEVELOPMENT_TEAM="4UKN65653U"
export MACOS_SIGNING_CERTIFICATE="Apple Distribution: Simon Liu (4UKN65653U)"
export MACOS_SIGNING_CERTIFICATE_PWD=""
export FLUTTER_BUILD_NUMBER="1"
export CODE_SIGN_IDENTITY="Apple Distribution: Simon Liu (4UKN65653U)"
export CODE_SIGNING_REQUIRED="YES"
export CODE_SIGN_INJECT_BASE_ENTITLEMENTS="YES"
flutter build macos --release

# 验证Flutter构建结果
if [ ! -f "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app/Contents/MacOS/Dualvpn Manager" ]; then
    log_info "错误: Flutter应用构建失败"
    exit 1
fi

# 验证主应用可执行文件权限
if [ -x "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app/Contents/MacOS/Dualvpn Manager" ]; then
  log_info "主应用可执行文件具有执行权限"
else
  log_info "错误: 主应用可执行文件没有执行权限"
  exit 1
fi

log_info "Flutter应用构建成功"

# 5. 复制Go代理核心到应用包中
log_info "步骤5: 复制Go代理核心到应用包中..."
APP_CONTENTS_DIR="${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app/Contents"

# https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
log_info "复制隐私信息文件..."
cp "${WORKSPACE_DIR}/build/macos/Build/Products/Release/device_info_plus/device_info_plus_privacy.bundle/Contents/Resources/PrivacyInfo.xcprivacy" "${APP_CONTENTS_DIR}/Resources/"

# 创建完整的bundle结构以满足App Store要求
mkdir -p "${APP_CONTENTS_DIR}/Resources/bin/Contents/MacOS"
mkdir -p "${APP_CONTENTS_DIR}/Resources/bin/Contents/Resources"
cp "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" "${APP_CONTENTS_DIR}/Resources/bin/Contents/MacOS/"
cp "${WORKSPACE_DIR}/go-proxy-core/config.yaml" "${APP_CONTENTS_DIR}/Resources/bin/Contents/Resources/"
cp "${WORKSPACE_DIR}/go-proxy-core/Info.plist" "${APP_CONTENTS_DIR}/Resources/bin/Contents/"
# 设置正确的权限
chmod +x "${APP_CONTENTS_DIR}/Resources/bin/Contents/MacOS/go-proxy-core"

# 6. 对添加的文件重新签名
log_info "步骤6: 对添加的文件签名..."
# 对Go代理核心bundle进行签名
codesign --force --sign "Apple Distribution: Simon Liu (4UKN65653U)" --timestamp --options runtime --entitlements "${WORKSPACE_DIR}/go-proxy-core/go-proxy-core.entitlements" "${APP_CONTENTS_DIR}/Resources/bin/Contents/MacOS/go-proxy-core"
codesign --force --sign "Apple Distribution: Simon Liu (4UKN65653U)" --timestamp --options runtime "${APP_CONTENTS_DIR}/Resources/bin/"

# 验证Go代理核心bundle签名
if codesign --verify --strict "${APP_CONTENTS_DIR}/Resources/bin/"; then
  log_info "Go代理核心bundle签名验证通过"
else
  log_info "警告: Go代理核心bundle签名验证失败，尝试重新签名..."
  # 如果验证失败，尝试重新签名
  codesign --force --sign "Apple Distribution: Simon Liu (4UKN65653U)" --timestamp --options runtime --entitlements "${WORKSPACE_DIR}/go-proxy-core/go-proxy-core.entitlements" "${APP_CONTENTS_DIR}/Resources/bin/Contents/MacOS/go-proxy-core"
  codesign --force --sign "Apple Distribution: Simon Liu (4UKN65653U)" --timestamp --options runtime "${APP_CONTENTS_DIR}/Resources/bin/"
  # 再次验证
  if codesign --verify --strict "${APP_CONTENTS_DIR}/Resources/bin/"; then
    log_info "Go代理核心bundle签名重新验证通过"
  else
    log_info "错误: Go代理核心bundle签名重新验证失败"
    exit 1
  fi
fi

# 进入应用框架目录
FRAMEWORKS_DIR="${APP_CONTENTS_DIR}/Frameworks"

# 对所有框架签名（包括报错的 device_info_plus.framework）
for framework in "$FRAMEWORKS_DIR"/*.framework; do
  codesign --force --sign "Apple Distribution: Simon Liu (4UKN65653U)" --timestamp "$framework"
done

# 重新签名整个应用
codesign --force --sign "Apple Distribution: Simon Liu (4UKN65653U)" --timestamp --options runtime --entitlements "${WORKSPACE_DIR}/macos/Runner/Release.entitlements" "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app"

# 验证签名
codesign --verify --strict "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app"

# 验证应用包完整性
if [ -f "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app/Contents/MacOS/Dualvpn Manager" ]; then
  log_info "主应用可执行文件存在"
  # 检查主应用可执行文件权限
  if [ -x "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app/Contents/MacOS/Dualvpn Manager" ]; then
    log_info "主应用可执行文件具有执行权限"
  else
    log_info "错误: 主应用可执行文件没有执行权限"
    exit 1
  fi
else
  log_info "错误: 主应用可执行文件不存在"
  exit 1
fi

# 验证Go代理核心可执行文件
if [ -f "${APP_CONTENTS_DIR}/Resources/bin/Contents/MacOS/go-proxy-core" ]; then
  log_info "Go代理核心可执行文件存在"
  # 检查文件权限
  if [ -x "${APP_CONTENTS_DIR}/Resources/bin/Contents/MacOS/go-proxy-core" ]; then
    log_info "Go代理核心可执行文件具有执行权限"
  else
    log_info "错误: Go代理核心可执行文件没有执行权限"
    exit 1
  fi
  
  # 验证Go代理核心bundle结构
  if [ -f "${APP_CONTENTS_DIR}/Resources/bin/Contents/Info.plist" ]; then
    log_info "Go代理核心bundle Info.plist存在"
  else
    log_info "错误: Go代理核心bundle Info.plist不存在"
    exit 1
  fi
  
  if [ -f "${APP_CONTENTS_DIR}/Resources/bin/Contents/Resources/config.yaml" ]; then
    log_info "Go代理核心配置文件存在"
  else
    log_info "错误: Go代理核心配置文件不存在"
    exit 1
  fi
  
  # 验证整个应用包签名
  if codesign --verify --strict "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app"; then
    log_info "应用包签名验证通过"
  else
    log_info "错误: 应用包签名验证失败"
    exit 1
  fi
  
  # 验证Go代理核心bundle签名
  if codesign --verify --strict "${APP_CONTENTS_DIR}/Resources/bin/"; then
    log_info "Go代理核心bundle签名验证通过"
  else
    log_info "错误: Go代理核心bundle签名验证失败"
    exit 1
  fi
else
  log_info "错误: Go代理核心可执行文件不存在"
  exit 1
fi
log_info "应用签名完成并验证通过"

log_info "Go代理核心复制完成"

# 7. 创建PKG安装文件
log_info "步骤7: 创建PKG安装文件..."

# 获取版本号
VERSION=$(grep "version:" "${WORKSPACE_DIR}/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')
# 如果版本号为空，则使用默认版本号
if [ -z "$VERSION" ]; then
  VERSION="1.0.0"
fi

# 使用pkgbuild创建PKG文件
PKG_NAME="DualVPN_Manager_${VERSION}.pkg"
PKG_PATH="${PKG_OUTPUT_DIR}/${PKG_NAME}"

# 创建pkg输出目录
mkdir -p "${PKG_OUTPUT_DIR}"

# 创建临时目录用于PKG构建
PKG_TEMP_DIR="/tmp/dualvpn-pkg"
if [ -d "${PKG_TEMP_DIR}" ]; then
    rm -rf "${PKG_TEMP_DIR}"
fi
mkdir -p "${PKG_TEMP_DIR}"

# 复制应用到临时目录
cp -R "${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app" "${PKG_TEMP_DIR}/"

# 创建组件包
pkgbuild \
  --root "${PKG_TEMP_DIR}" \
  --identifier "com.v8en.dualvpnManager.pkg" \
  --version "${VERSION}" \
  --install-location "/Applications" \
  "${PKG_OUTPUT_DIR}/component.pkg"

# 检查组件包是否创建成功
if [ ! -f "${PKG_OUTPUT_DIR}/component.pkg" ]; then
  log_info "错误: 组件包创建失败"
  exit 1
fi

# 创建产品包
productbuild \
  --package "${PKG_OUTPUT_DIR}/component.pkg" \
  --sign "3rd Party Mac Developer Installer: Simon Liu (4UKN65653U)" \
  "${PKG_PATH}"

# 验证PKG文件
if [ -f "${PKG_PATH}" ]; then
  log_info "PKG文件创建成功"
  # 验证PKG文件签名
  if pkgutil --check-signature "${PKG_PATH}"; then
    log_info "PKG文件签名验证通过"
  else
    log_info "错误: PKG文件签名验证失败"
    exit 1
  fi
  
  # 验证PKG文件完整性
  if pkgutil --expand "${PKG_PATH}" /tmp/pkg-expand-test; then
    log_info "PKG文件完整性验证通过"
    rm -rf /tmp/pkg-expand-test
  else
    log_info "错误: PKG文件完整性验证失败"
    rm -rf /tmp/pkg-expand-test
    exit 1
  fi
  
  # 验证PKG文件安装位置
  if pkgutil --payload-files "${PKG_PATH}" | grep -q "Dualvpn Manager.app"; then
    log_info "PKG文件安装位置验证通过"
  else
    log_info "错误: PKG文件安装位置验证失败"
    exit 1
  fi
else
  log_info "错误: PKG文件创建失败"
  exit 1
fi

# 验证PKG文件
if [ -f "${PKG_PATH}" ]; then
  log_info "PKG文件创建成功"
  # 验证PKG文件签名
  if pkgutil --check-signature "${PKG_PATH}"; then
    log_info "PKG文件签名验证通过"
  else
    log_info "错误: PKG文件签名验证失败"
    exit 1
  fi
  
  # 验证PKG文件完整性
  if pkgutil --expand "${PKG_PATH}" /tmp/pkg-expand-test; then
    log_info "PKG文件完整性验证通过"
    rm -rf /tmp/pkg-expand-test
  else
    log_info "错误: PKG文件完整性验证失败"
    rm -rf /tmp/pkg-expand-test
    exit 1
  fi
  
  # 验证PKG文件安装位置
  if pkgutil --payload-files "${PKG_PATH}" | grep -q "Dualvpn Manager.app"; then
    log_info "PKG文件安装位置验证通过"
  else
    log_info "错误: PKG文件安装位置验证失败"
    exit 1
  fi
else
  log_info "错误: PKG文件创建失败"
  exit 1
fi

# 清理临时文件
rm -f "${PKG_OUTPUT_DIR}/component.pkg"
rm -rf "${PKG_TEMP_DIR}"
# 清理构建目录
rm -rf "${BUILD_DIR}/macos/Build/Products/Release/Dualvpn Manager.app"
# 清理Go代理核心构建目录
rm -rf "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core"
# 清理其他临时文件
rm -rf "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core-amd64" "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core-arm64"

# 显示构建结果
log_info ""
log_info "==================== 构建完成 ===================="
log_info "PKG安装文件位置: ${PKG_PATH}"
log_info "=================================================="
log_info ""
log_info "此PKG文件可用于App Store分发。"
log_info "注意：对于App Store分发，您需要使用Xcode Organizer或Transporter上传此PKG文件。"
log_info ""

# 最终验证
if [ -f "${PKG_PATH}" ]; then
  log_info "最终验证通过: PKG文件存在"
  
  # 验证PKG文件完整性
  if pkgutil --check-signature "${PKG_PATH}"; then
    log_info "PKG文件签名验证通过"
  else
    log_info "错误: PKG文件签名验证失败"
    exit 1
  fi
  
  # 验证应用包结构
  if pkgutil --payload-files "${PKG_PATH}" | grep -q "Dualvpn Manager.app"; then
    log_info "应用包结构验证通过"
  else
    log_info "错误: 应用包结构验证失败"
    exit 1
  fi
else
  log_info "错误: 最终验证失败，PKG文件不存在"
  exit 1
fi

exit 0