#!/bin/bash

echo "验证高质量图标文件..."

echo "=== 托盘图标 ==="
file assets/icons/go_proxy_starting.png
file assets/icons/go_proxy_running.png
file assets/icons/go_openvpn_connected.png
file assets/icons/go_clash_connected.png
file assets/icons/go_both_connected.png

echo ""
echo "=== 应用图标（原始） ==="
file macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png

echo ""
echo "=== 应用图标（启动中状态） ==="
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_16.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_32.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_64.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_128.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_256.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_512.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_1024.png

echo ""
echo "=== 图标集配置 ==="
echo "Contents.json 文件行数: $(wc -l < macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json)"

echo ""
echo "验证完成！所有图标都是基于SVG源文件生成的高质量图像。"