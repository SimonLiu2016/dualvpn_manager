#!/bin/bash

# DualVPN Manager增强版macOS应用构建脚本
# 支持本地和CI环境中的代码签名

echo "Building DualVPN Manager macOS app (enhanced version)..."

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../.."

cd "$PROJECT_ROOT" || exit 1

# 获取当前工作目录
WORKSPACE_DIR=$(pwd)
BUILD_DIR="${WORKSPACE_DIR}/build"
MACOS_BUILD_DIR="${BUILD_DIR}/macos"
RELEASE_DIR="${BUILD_DIR}/macos/Build/Products/Release"

echo "工作目录: ${WORKSPACE_DIR}"

# 1. 清理之前的构建
echo "步骤1: 清理之前的构建..."
flutter clean
flutter pub get
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 2. 构建Go代理核心
echo "步骤2: 构建Go代理核心..."
cd "${WORKSPACE_DIR}/go-proxy-core"
go build -o "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" ./cmd/main.go

if [ ! -f "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" ]; then
    echo "错误: Go代理核心构建失败"
    exit 1
fi

echo "Go代理核心构建成功"

# 3. 构建Flutter应用（带签名）
echo "步骤3: 构建Flutter应用..."
cd "${WORKSPACE_DIR}"

# 检查是否在CI环境中
if [[ -n "$CI" ]]; then
  echo "Running in CI environment"
  
  # 如果有签名证书和配置文件设置，则配置签名
  if [[ -n "$MACOS_DEVELOPMENT_TEAM" ]] && [[ -n "$MACOS_SIGNING_CERTIFICATE" ]] && [[ -n "$MACOS_SIGNING_CERTIFICATE_PWD" ]] && [[ -n "$MACOS_PROVISIONING_PROFILE" ]]; then
    echo "Setting up code signing with provisioning profile..."
    chmod +x "$SCRIPT_DIR/setup-macos-signing.sh"
    "$SCRIPT_DIR/setup-macos-signing.sh"
    
    # 更新Xcode项目中的开发团队
    echo "Updating Xcode project with development team..."
    sed -i '' "s/DEVELOPMENT_TEAM = \"[^\"]*\"/DEVELOPMENT_TEAM = \"$MACOS_DEVELOPMENT_TEAM\"/g" macos/Runner.xcodeproj/project.pbxproj
    
    # 使用手动签名并指定您的配置文件 - 仅对Runner目标设置
    echo "Setting manual code signing with your provisioning profile for Runner target..."
    sed -i '' 's/CODE_SIGN_IDENTITY = "-"/CODE_SIGN_IDENTITY = "Apple Distribution"/g' macos/Runner.xcodeproj/project.pbxproj
    sed -i '' 's/CODE_SIGN_STYLE = Automatic/CODE_SIGN_STYLE = Manual/g' macos/Runner.xcodeproj/project.pbxproj
    
    # 设置您的特定配置文件 - 仅对Runner目标设置，避免对PrivilegedHelper设置
    echo "Setting your specific provisioning profile for Runner target only..."
    # 先为Runner目标设置配置文件
    sed -i '' 's/"PROVISIONING_PROFILE_SPECIFIER\[sdk=macosx\*]" = ""/"PROVISIONING_PROFILE_SPECIFIER[sdk=macosx*]" = "V8en DualVPN Manager Profile"/g' macos/Runner.xcodeproj/project.pbxproj
    # 然后确保特权助手工具的配置文件保持为空
    sed -i '' '/PRODUCT_BUNDLE_IDENTIFIER = com.v8en.dualvpnManager.PrivilegedHelper/,+10s/"PROVISIONING_PROFILE_SPECIFIER\[sdk=macosx\*]" = ".*"/"PROVISIONING_PROFILE_SPECIFIER[sdk=macosx*]" = ""/g' macos/Runner.xcodeproj/project.pbxproj
    
    # 构建macOS应用（带签名）
    echo "Building macOS app with code signing..."
    flutter build macos --release --build-number=${GITHUB_RUN_NUMBER:-1} -v
  else
    echo "No signing credentials provided, building without code signing"
    
    # 禁用Xcode项目中的代码签名
    echo "Disabling code signing in Xcode project..."
    # Debug配置
    sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Development"/CODE_SIGN_IDENTITY = "-"/g' macos/Runner.xcodeproj/project.pbxproj
    sed -i '' 's/CODE_SIGN_STYLE = Automatic/CODE_SIGN_STYLE = Manual/g' macos/Runner.xcodeproj/project.pbxproj
    sed -i '' 's/DEVELOPMENT_TEAM = "[^"]*"/DEVELOPMENT_TEAM = ""/g' macos/Runner.xcodeproj/project.pbxproj
    # Release配置
    sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Distribution"/CODE_SIGN_IDENTITY = "-"/g' macos/Runner.xcodeproj/project.pbxproj
    sed -i '' 's/CODE_SIGN_STYLE = Automatic/CODE_SIGN_STYLE = Manual/g' macos/Runner.xcodeproj/project.pbxproj
    sed -i '' 's/DEVELOPMENT_TEAM = "[^"]*"/DEVELOPMENT_TEAM = ""/g' macos/Runner.xcodeproj/project.pbxproj
    # Profile配置
    sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Development"/CODE_SIGN_IDENTITY = "-"/g' macos/Runner.xcodeproj/project.pbxproj
    sed -i '' 's/CODE_SIGN_STYLE = Automatic/CODE_SIGN_STYLE = Manual/g' macos/Runner.xcodeproj/project.pbxproj
    sed -i '' 's/DEVELOPMENT_TEAM = "[^"]*"/DEVELOPMENT_TEAM = ""/g' macos/Runner.xcodeproj/project.pbxproj
    
    # 构建macOS应用（不带签名）
    echo "Building macOS app without code signing..."
    flutter build macos --release --build-number=${GITHUB_RUN_NUMBER:-1} -v
  fi
else
  echo "Running in local environment"
  # 本地环境构建
  flutter build macos --release -v
fi

BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
  echo "macOS app built successfully"
  
  # 查找构建的应用
  MACOS_BUILD_DIR="build/macos/Build/Products/Release"
  if [ -d "$MACOS_BUILD_DIR" ]; then
    MACOS_APP_FILE=$(find "$MACOS_BUILD_DIR" -name "*.app" -type d | head -n 1)
    if [ -n "$MACOS_APP_FILE" ] && [ -d "$MACOS_APP_FILE" ]; then
      echo "Found built app: $MACOS_APP_FILE"
      
      # 4. 复制Go代理核心到应用包中
      echo "步骤4: 复制Go代理核心到应用包中..."
      APP_CONTENTS_DIR="${MACOS_APP_FILE}/Contents"
      mkdir -p "${APP_CONTENTS_DIR}/Resources/bin"
      cp "${WORKSPACE_DIR}/go-proxy-core/bin/go-proxy-core" "${APP_CONTENTS_DIR}/Resources/bin/"
      cp "${WORKSPACE_DIR}/go-proxy-core/config.yaml" "${APP_CONTENTS_DIR}/Resources/bin/"

      # 4.1 复制OpenVPN二进制文件到应用包Resources/bin目录
      echo "步骤4.1: 复制OpenVPN二进制文件到应用包Resources/bin目录..."
      cp "${WORKSPACE_DIR}/go-proxy-core/openvpn/openvpn_bin/openvpn" "${APP_CONTENTS_DIR}/Resources/bin/"
      chmod +x "${APP_CONTENTS_DIR}/Resources/bin/openvpn"

      # 4.2 复制OpenVPN库文件到应用包Resources目录
      echo "步骤4.2: 复制OpenVPN库文件到应用包Resources目录..."
      mkdir -p "${APP_CONTENTS_DIR}/Resources/openvpn_frameworks"
      cp -R "${WORKSPACE_DIR}/go-proxy-core/openvpn/frameworks/" "${APP_CONTENTS_DIR}/Resources/openvpn_frameworks/"

      echo "Go代理核心和OpenVPN文件复制完成"
      
      # 重新签名应用以包含新添加的文件
      if [[ -n "$CI" ]] && [[ -n "$MACOS_DEVELOPMENT_TEAM" ]] && [[ -n "$MACOS_SIGNING_CERTIFICATE" ]]; then
        echo "Re-signing app to include added files..."
        codesign --force --deep --sign "Apple Distribution" "$MACOS_APP_FILE"
      fi
      
      # 验证应用签名（如果在CI环境中且有签名设置）
      if [[ -n "$CI" ]] && [[ -n "$MACOS_DEVELOPMENT_TEAM" ]]; then
        echo "Verifying app signature..."
        codesign --verify --deep --strict "$MACOS_APP_FILE"
        if [ $? -eq 0 ]; then
          echo "App signature verified successfully"
        else
          echo "Warning: App signature verification failed"
        fi
      fi
    else
      echo "Warning: Could not find built .app file"
    fi
  else
    echo "Warning: Could not find build directory"
  fi
else
  echo "Error: Failed to build macOS app (exit code: $BUILD_RESULT)"
  
  # 提供一些调试信息
  echo "Flutter version:"
  flutter --version
  
  echo "Available Flutter build options:"
  flutter build macos -h
  
  exit 1
fi

echo ""
echo "==================== 构建完成 ===================="
echo "应用包位置: ${WORKSPACE_DIR}/build/macos/Build/Products/Release/Dualvpn Manager.app"
echo "=================================================="
echo ""

echo "macOS build process completed"