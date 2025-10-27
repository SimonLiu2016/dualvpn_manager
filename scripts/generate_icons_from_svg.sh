#!/bin/bash

# 基于SVG源文件生成高质量图标
echo "基于SVG源文件生成高质量图标..."

# 创建临时目录
TEMP_DIR="/tmp/dualvpn_icons_$(date +%s)"
mkdir -p "$TEMP_DIR"

# 定义图标尺寸
SIZES=(16 32 64 128 256 512 1024)

# 生成不同状态的SVG文件
echo "生成不同状态的SVG文件..."

# 1. 启动中状态SVG（添加橙色边框）
cat > "$TEMP_DIR/go_proxy_starting.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <!-- 橙色边框 -->
    <rect x="0" y="0" width="100" height="100" fill="none" stroke="orange" stroke-width="8"/>
    <!-- 背景圆形 -->
    <circle cx="50" cy="50" r="45" fill="#2196F3"/>
    <!-- Dual 字母 D -->
    <path d="M30 25 L30 75 L55 75 C65 75 70 70 70 60 L70 40 C70 30 65 25 55 25 Z" fill="white"/>
    <path d="M35 30 L35 70 L55 70 C60 70 65 65 65 60 L65 40 C65 35 60 30 55 30 Z" fill="#2196F3"/>
    <!-- VPN 文字 -->
    <text x="50" y="90" font-family="Arial, sans-serif" font-weight="bold" font-size="14" fill="white" text-anchor="middle">VPN</text>
</svg>
EOF

# 2. 运行中状态SVG（添加绿色边框）
cat > "$TEMP_DIR/go_proxy_running.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <!-- 绿色边框 -->
    <rect x="0" y="0" width="100" height="100" fill="none" stroke="green" stroke-width="8"/>
    <!-- 背景圆形 -->
    <circle cx="50" cy="50" r="45" fill="#2196F3"/>
    <!-- Dual 字母 D -->
    <path d="M30 25 L30 75 L55 75 C65 75 70 70 70 60 L70 40 C70 30 65 25 55 25 Z" fill="white"/>
    <path d="M35 30 L35 70 L55 70 C60 70 65 65 65 60 L65 40 C65 35 60 30 55 30 Z" fill="#2196F3"/>
    <!-- VPN 文字 -->
    <text x="50" y="90" font-family="Arial, sans-serif" font-weight="bold" font-size="14" fill="white" text-anchor="middle">VPN</text>
</svg>
EOF

# 3. OpenVPN连接状态SVG（添加蓝色边框）
cat > "$TEMP_DIR/go_openvpn_connected.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <!-- 蓝色边框 -->
    <rect x="0" y="0" width="100" height="100" fill="none" stroke="blue" stroke-width="8"/>
    <!-- 背景圆形 -->
    <circle cx="50" cy="50" r="45" fill="#2196F3"/>
    <!-- Dual 字母 D -->
    <path d="M30 25 L30 75 L55 75 C65 75 70 70 70 60 L70 40 C70 30 65 25 55 25 Z" fill="white"/>
    <path d="M35 30 L35 70 L55 70 C60 70 65 65 65 60 L65 40 C65 35 60 30 55 30 Z" fill="#2196F3"/>
    <!-- VPN 文字 -->
    <text x="50" y="90" font-family="Arial, sans-serif" font-weight="bold" font-size="14" fill="white" text-anchor="middle">VPN</text>
</svg>
EOF

# 4. Clash连接状态SVG（添加绿色边框）
cat > "$TEMP_DIR/go_clash_connected.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <!-- 绿色边框 -->
    <rect x="0" y="0" width="100" height="100" fill="none" stroke="green" stroke-width="8"/>
    <!-- 背景圆形 -->
    <circle cx="50" cy="50" r="45" fill="#2196F3"/>
    <!-- Dual 字母 D -->
    <path d="M30 25 L30 75 L55 75 C65 75 70 70 70 60 L70 40 C70 30 65 25 55 25 Z" fill="white"/>
    <path d="M35 30 L35 70 L55 70 C60 70 65 65 65 60 L65 40 C65 35 60 30 55 30 Z" fill="#2196F3"/>
    <!-- VPN 文字 -->
    <text x="50" y="90" font-family="Arial, sans-serif" font-weight="bold" font-size="14" fill="white" text-anchor="middle">VPN</text>
</svg>
EOF

# 5. 双重连接状态SVG（添加紫色边框）
cat > "$TEMP_DIR/go_both_connected.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <!-- 紫色边框 -->
    <rect x="0" y="0" width="100" height="100" fill="none" stroke="purple" stroke-width="8"/>
    <!-- 背景圆形 -->
    <circle cx="50" cy="50" r="45" fill="#2196F3"/>
    <!-- Dual 字母 D -->
    <path d="M30 25 L30 75 L55 75 C65 75 70 70 70 60 L70 40 C70 30 65 25 55 25 Z" fill="white"/>
    <path d="M35 30 L35 70 L55 70 C60 70 65 65 65 60 L65 40 C65 35 60 30 55 30 Z" fill="#2196F3"/>
    <!-- VPN 文字 -->
    <text x="50" y="90" font-family="Arial, sans-serif" font-weight="bold" font-size="14" fill="white" text-anchor="middle">VPN</text>
    <!-- 双重连接的两个对勾 -->
    <path d="M30 45 L38 53 L55 35" fill="none" stroke="white" stroke-width="3"/>
    <path d="M45 55 L53 63 L70 45" fill="none" stroke="white" stroke-width="3"/>
</svg>
EOF

echo "SVG文件生成完成，开始转换为PNG..."

# 使用rsvg-convert将SVG转换为各种尺寸的PNG
for size in "${SIZES[@]}"; do
    echo "生成 ${size}x${size} 尺寸图标..."
    
    # 生成托盘图标（使用32x32尺寸）
    if [ $size -eq 32 ]; then
        rsvg-convert -w $size -h $size "$TEMP_DIR/go_proxy_starting.svg" -o "assets/icons/go_proxy_starting.png"
        rsvg-convert -w $size -h $size "$TEMP_DIR/go_proxy_running.svg" -o "assets/icons/go_proxy_running.png"
        rsvg-convert -w $size -h $size "$TEMP_DIR/go_openvpn_connected.svg" -o "assets/icons/go_openvpn_connected.png"
        rsvg-convert -w $size -h $size "$TEMP_DIR/go_clash_connected.svg" -o "assets/icons/go_clash_connected.png"
        rsvg-convert -w $size -h $size "$TEMP_DIR/go_both_connected.svg" -o "assets/icons/go_both_connected.png"
    fi
    
    # 生成应用图标
    rsvg-convert -w $size -h $size "$TEMP_DIR/go_proxy_starting.svg" -o "macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_${size}.png"
done

# 为macOS应用图标集生成标准尺寸的图标（基于原始app_icon.svg）
echo "生成标准应用图标..."
for size in "${SIZES[@]}"; do
    rsvg-convert -w $size -h $size "assets/icons/app_icon.svg" -o "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png"
done

# 清理临时目录
rm -rf "$TEMP_DIR"

echo "高质量图标生成完成！"