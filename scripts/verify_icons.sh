#!/bin/bash

echo "验证生成的图标文件..."

# 验证托盘图标
echo "=== 托盘图标 ==="
file assets/icons/go_proxy_starting.png
file assets/icons/go_proxy_running.png
file assets/icons/go_both_connected.png
file assets/icons/go_openvpn_connected.png
file assets/icons/go_clash_connected.png

echo ""
echo "=== 应用图标 ==="
# 验证应用图标
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_16.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_32.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_64.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_128.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_256.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_512.png
file macos/Runner/Assets.xcassets/AppIcon.appiconset/go_app_icon_1024.png

echo ""
echo "验证完成！"