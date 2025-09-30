# OpenVPN 集成说明

## 概述

本文档说明了如何在双捷 VPN 管理器中集成和使用 OpenVPN 类型的代理源。当用户在代理列表中选择 OpenVPN 类型的代理源时，系统会自动解析配置文件中的服务器地址和端口信息，并将完整的信息发送给 Go 代理核心。

## 配置文件解析

### 解析逻辑

当用户选择 OpenVPN 类型的代理源时，系统会执行以下步骤：

1. 读取 OpenVPN 配置文件（`.ovpn`文件）
2. 解析配置文件中的`remote`指令获取服务器地址和端口
3. 解析配置文件中的`proto`指令获取协议类型
4. 从代理源配置中获取用户名和密码
5. 构建完整的代理信息 JSON 并发送给 Go 代理核心

### 配置文件示例

```ovpn
client
dev tun
proto udp
remote 120.25.102.59 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert vsc-wz9ikdcw6l8kwpbom36s1.crt
key vsc-wz9ikdcw6l8kwpbom36s1.key
cipher AES-128-CBC
;comp-lzo
verb 4
auth-user-pass
dhcp-option DNS 172.16.30.27
```

从上面的配置文件中，系统会解析出：

- 服务器地址: `120.25.102.59`
- 端口: `1194`
- 协议: `udp`

## 代理列表显示

现在 OpenVPN 类型的代理源也会在代理列表中显示代理信息。系统会解析配置文件并创建一个代理条目，显示以下信息：

- 代理名称（与代理源名称相同）
- 服务器地址和端口
- 协议类型

## 发送给 Go 代理核心的数据格式

解析完成后，系统会构建如下 JSON 格式的数据发送给 Go 代理核心：

```json
{
  "id": "代理ID",
  "name": "代理名称",
  "type": "openvpn",
  "server": "120.25.102.59",
  "port": 1194,
  "config": {
    "config_path": "/Users/simon/ctf-vpn-config/ctf-new-1128/config.ovpn",
    "username": "liuzhongren",
    "password": "Ctf#1234.panshi09"
  }
}
```

## 代码实现

### 核心解析类

`lib/utils/openvpn_config_parser.dart`文件中包含了 OpenVPN 配置解析的核心逻辑：

1. `OpenVPNConfigParser.parseRemoteInfo()` - 解析远程服务器信息
2. `OpenVPNConfigParser.parseProxyInfo()` - 构建完整的代理信息

### 集成点

1. `lib/services/openvpn_service.dart` - 在连接 OpenVPN 时使用解析器
2. `lib/models/app_state.dart` - 在加载代理列表时为 OpenVPN 类型生成代理信息
3. `lib/ui/widgets/proxy_list_widget.dart` - 在代理列表中显示 OpenVPN 代理信息

## 测试验证

可以通过运行`bin/simple_openvpn_test.dart`来测试解析功能：

```bash
cd /Users/simon/Workspace/vsProject/dualvpn_manager
dart bin/simple_openvpn_test.dart
```

测试输出应该显示正确解析的服务器地址、端口和协议信息。
