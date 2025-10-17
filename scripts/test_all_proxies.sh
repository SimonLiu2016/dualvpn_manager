#!/bin/bash

# Go代理核心完整测试脚本
# 测试所有支持的代理类型：Shadowsocks, Trojan, VLESS, OpenVPN

echo "Go代理核心完整测试脚本"
echo "======================"

# 获取脚本所在目录作为项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "项目根目录: $PROJECT_ROOT"

# 1. 启动服务
echo "1. 启动Go代理核心服务..."
# 设置环境变量，指示需要管理员权限来运行OpenVPN
export NEEDS_ROOT=true
cd "$PROJECT_ROOT"
./scripts/start_go_proxy.sh
sleep 3

# 2. 检查服务状态
echo ""
echo "2. 检查服务状态..."
./scripts/check_go_proxy.sh

# 3. 添加代理源
echo ""
echo "3. 添加代理源..."

# 添加Shadowsocks代理源1
curl -s -X POST http://127.0.0.1:6162/proxy-sources \
  -H "Content-Type: application/json" \
  -d '{
    "id": "ss-source-1",
    "name": "🇭🇰香港-B-Relay-2X",
    "type": "shadowsocks",
    "config": {}
  }' && echo "  ✓ 添加Shadowsocks代理源1"

# 添加Shadowsocks代理源2
curl -s -X POST http://127.0.0.1:6162/proxy-sources \
  -H "Content-Type: application/json" \
  -d '{
    "id": "ss-source-2",
    "name": "🇭🇰香港-C-Relay-2X",
    "type": "shadowsocks",
    "config": {}
  }' && echo "  ✓ 添加Shadowsocks代理源2"

# 添加Trojan代理源
curl -s -X POST http://127.0.0.1:6162/proxy-sources \
  -H "Content-Type: application/json" \
  -d '{
    "id": "trojan-source",
    "name": "Trojan代理源",
    "type": "trojan",
    "config": {}
  }' && echo "  ✓ 添加Trojan代理源"

# 添加VLESS代理源
curl -s -X POST http://127.0.0.1:6162/proxy-sources \
  -H "Content-Type: application/json" \
  -d '{
    "id": "vless-source",
    "name": "VLESS代理源",
    "type": "vless",
    "config": {}
  }' && echo "  ✓ 添加VLESS代理源"

# 添加OpenVPN代理源
curl -s -X POST http://127.0.0.1:6162/proxy-sources \
  -H "Content-Type: application/json" \
  -d '{
    "id": "openvpn-source",
    "name": "OpenVPN代理源",
    "type": "openvpn",
    "config": {}
  }' && echo "  ✓ 添加OpenVPN代理源"

# 4. 设置代理源的当前代理
echo ""
echo "4. 设置代理源的当前代理..."

# 设置Shadowsocks代理源1的当前代理
curl -s -X PUT http://127.0.0.1:6162/proxy-sources/ss-source-1/current-proxy \
  -H "Content-Type: application/json" \
  -d '{
    "id": "ss-proxy-1",
    "name": "🇭🇰香港-B-Relay-2X",
    "type": "shadowsocks",
    "server": "cncm.hushitanke.top",
    "port": 50016,
    "config": {
      "cipher": "chacha20-ietf-poly1305",
      "password": "ef18df75-d207-38ca-90ea-97884c4a9397"
    }
  }' && echo "  ✓ 设置Shadowsocks代理1"

# 设置Shadowsocks代理源2的当前代理
curl -s -X PUT http://127.0.0.1:6162/proxy-sources/ss-source-2/current-proxy \
  -H "Content-Type: application/json" \
  -d '{
    "id": "ss-proxy-2",
    "name": "🇭🇰香港-C-Relay-2X",
    "type": "shadowsocks",
    "server": "cncm.hushitanke.top",
    "port": 50032,
    "config": {
      "cipher": "chacha20-ietf-poly1305",
      "password": "ef18df75-d207-38ca-90ea-97884c4a9397"
    }
  }' && echo "  ✓ 设置Shadowsocks代理2"

# 设置Trojan代理
curl -s -X PUT http://127.0.0.1:6162/proxy-sources/trojan-source/current-proxy \
  -H "Content-Type: application/json" \
  -d '{
    "id": "trojan-proxy-1",
    "name": "🇭🇰香港-A-Direct-1X",
    "type": "trojan",
    "server": "hkt.hushitanke.top",
    "port": 443,
    "config": {
      "password": "ef18df75-d207-38ca-90ea-97884c4a9397"
    }
  }' && echo "  ✓ 设置Trojan代理"

# 设置VLESS代理
curl -s -X PUT http://127.0.0.1:6162/proxy-sources/vless-source/current-proxy \
  -H "Content-Type: application/json" \
  -d '{
    "id": "vless-proxy-1",
    "name": "🇺🇸美国-A-Direct-1X",
    "type": "vless",
    "server": "usaa.hushitanke.top",
    "port": 443,
    "config": {
      "uuid": "ef18df75-d207-38ca-90ea-97884c4a9397",
      "network": "ws",
      "tls": true
    }
  }' && echo "  ✓ 设置VLESS代理"

# 设置OpenVPN代理
curl -s -X PUT http://127.0.0.1:6162/proxy-sources/openvpn-source/current-proxy \
  -H "Content-Type: application/json" \
  -d '{
    "id": "openvpn-proxy-1",
    "name": "CTF OpenVPN",
    "type": "openvpn",
    "server": "120.25.102.59",
    "port": 1194,
    "config": {
      "config_path": "/Users/simon/ctf-vpn-config/ctf-new-1128/config.ovpn",
      "username": "liuzhongren",
      "password": "Ctf#1234.panshi09"
    }
  }' && echo "  ✓ 设置OpenVPN代理"

# 5. 配置路由规则
echo ""
echo "5. 配置路由规则..."
curl -s -X PUT http://127.0.0.1:6162/rules \
  -H "Content-Type: application/json" \
  -d '[
    {
      "type": "DOMAIN-SUFFIX",
      "pattern": "google.com",
      "proxy_source": "ss-source-1",
      "enabled": true
    },
    {
      "type": "DOMAIN-SUFFIX",
      "pattern": "youtube.com",
      "proxy_source": "ss-source-2",
      "enabled": true
    },
    {
      "type": "DOMAIN-SUFFIX",
      "pattern": "github.com",
      "proxy_source": "trojan-source",
      "enabled": true
    },
    {
      "type": "DOMAIN-SUFFIX",
      "pattern": "microsoft.com",
      "proxy_source": "vless-source",
      "enabled": true
    },
    {
      "type": "DOMAIN-SUFFIX",
      "pattern": "pingcode.ctf.com.cn",
      "proxy_source": "openvpn-source",
      "enabled": true
    },
    {
      "type": "MATCH",
      "pattern": "",
      "proxy_source": "DIRECT",
      "enabled": true
    }
  ]' && echo "  ✓ 路由规则配置完成"

# 6. 验证配置
echo ""
echo "6. 验证配置..."

echo "  获取所有代理源:"
curl -s http://127.0.0.1:6162/proxy-sources | jq '.'

echo "  获取路由规则:"
curl -s http://127.0.0.1:6162/rules | jq '.'

echo "  获取支持的协议:"
curl -s http://127.0.0.1:6162/protocols | jq '.'

# 7. 测试代理连接并验证统计信息
echo ""
echo "7. 测试代理连接并验证统计信息..."

echo "  初始统计信息:"
curl -s http://127.0.0.1:6162/stats | jq '.'

echo "  测试baidu.com (直连):"
curl -s -x http://127.0.0.1:6160 -I https://www.baidu.com 2>/dev/null | head -n 1

echo "  测试google.com (Shadowsocks代理1):"
curl -s -x http://127.0.0.1:6160 -I https://www.google.com 2>/dev/null | head -n 1

echo "  测试youtube.com (Shadowsocks代理2):"
curl -s -x http://127.0.0.1:6160 -I https://www.youtube.com 2>/dev/null | head -n 1

echo "  测试github.com (Trojan代理):"
curl -s -x http://127.0.0.1:6160 -I https://www.github.com 2>/dev/null | head -n 1

echo "  测试microsoft.com (VLESS代理):"
curl -s -x http://127.0.0.1:6160 -I https://www.microsoft.com 2>/dev/null | head -n 1

echo "  测试https://pingcode.ctf.com.cn (OpenVPN代理):"
curl -s -x http://127.0.0.1:6160 -I https://pingcode.ctf.com.cn --connect-timeout 30 --max-time 60 2>/dev/null | head -n 1 || echo "  OpenVPN代理测试超时或失败"

echo "  等待统计信息更新..."
sleep 3

echo "  更新后的统计信息:"
curl -s http://127.0.0.1:6162/stats | jq '.'

echo ""
echo "测试完成！现在验证每个代理源的统计信息是否独立更新..."
echo "再次测试google.com (应该只更新ss-source-1的统计信息):"
curl -s -x http://127.0.0.1:6160 -I https://www.google.com 2>/dev/null | head -n 1

echo "  等待统计信息更新..."
sleep 3

echo "  再次获取统计信息:"
curl -s http://127.0.0.1:6162/stats | jq '.'

echo ""
echo "测试完成！"