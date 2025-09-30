# Go 代理核心 API 接口文档

## 支持的协议类型

Go 代理核心支持以下协议类型：

- `shadowsocks` - Shadowsocks 协议
- `trojan` - Trojan 协议
- `vless` - VLESS 协议
- `vmess` - VMess 协议
- `http` - HTTP 代理协议
- `https` - HTTPS 代理协议
- `socks5` - SOCKS5 代理协议
- `direct` - 直连协议
- `openvpn` - OpenVPN 协议
- `wireguard` - WireGuard 协议
- `ipsec` - IPsec 协议
- `l2tp` - L2TP 协议
- `pptp` - PPTP 协议
- `shadowsocksr` - ShadowsocksR 协议
- `snell` - Snell 协议
- `ikev2` - IKEv2 协议
- `softether` - SoftEther 协议

## 统计信息说明

Go 代理核心现在支持更精准的流量统计能力：

1. **按代理源维度统计**：统计信息按代理源维度进行跟踪，每个代理源都有独立的上传和下载统计
2. **独立流量跟踪**：每个代理源的流量被独立跟踪，不再使用平均分配的方式
3. **实时更新**：统计信息实时更新，反映每个代理源的实际使用情况

## OpenVPN 配置解析说明

当用户在代理列表中选择 OpenVPN 类型的代理源时，系统会自动解析配置文件中的服务器地址和端口信息。

### 配置文件解析逻辑

1. 从 OpenVPN 配置文件中解析 `remote` 指令获取服务器地址和端口
2. 从 OpenVPN 配置文件中解析 `proto` 指令获取协议类型
3. 从代理源配置中获取用户名和密码等认证信息

### OpenVPN 配置文件示例

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

## 1. 代理源管理接口

### 1.1 获取所有代理源

- **URL**: `/proxy-sources`
- **方法**: GET
- **描述**: 获取所有代理源及其代理列表
- **响应**:

```json
{
  "proxy_sources": {
    "source_id": {
      "id": "source_id",
      "name": "source_name",
      "type": "source_type",
      "config": {},
      "proxies": {
        "proxy_id": {
          "id": "proxy_id",
          "name": "proxy_name",
          "type": "proxy_type",
          "server": "server_address",
          "port": 1234,
          "config": {}
        }
      }
    }
  }
}
```

### 1.2 添加代理源

- **URL**: `/proxy-sources`
- **方法**: POST
- **描述**: 添加新的代理源
- **请求体**:

```json
{
  "id": "source_id",
  "name": "source_name",
  "type": "source_type",
  "config": {}
}
```

- **响应**:
  - 201 Created: 代理源添加成功
  - 400 Bad Request: 请求参数错误

### 1.3 获取单个代理源信息

- **URL**: `/proxy-sources/{id}`
- **方法**: GET
- **描述**: 获取指定代理源的详细信息
- **响应**:

```json
{
  "id": "source_id",
  "name": "source_name",
  "type": "source_type",
  "config": {},
  "proxies": {
    "proxy_id": {
      "id": "proxy_id",
      "name": "proxy_name",
      "type": "proxy_type",
      "server": "server_address",
      "port": 1234,
      "config": {}
    }
  }
}
```

### 1.4 删除代理源

- **URL**: `/proxy-sources/{id}`
- **方法**: DELETE
- **描述**: 删除指定代理源
- **响应**:
  - 204 No Content: 代理源删除成功
  - 404 Not Found: 代理源不存在

### 1.5 获取代理源的所有代理

- **URL**: `/proxy-sources/{id}/proxies`
- **方法**: GET
- **描述**: 获取指定代理源的所有代理
- **响应**:

```json
{
  "proxy_id": {
    "id": "proxy_id",
    "name": "proxy_name",
    "type": "proxy_type",
    "server": "server_address",
    "port": 1234,
    "config": {}
  }
}
```

### 1.6 更新代理源的所有代理

- **URL**: `/proxy-sources/{id}/proxies`
- **方法**: PUT
- **描述**: 更新指定代理源的所有代理
- **请求体**:

```json
[
  {
    "id": "proxy_id",
    "name": "proxy_name",
    "type": "proxy_type",
    "server": "server_address",
    "port": 1234,
    "config": {}
  }
]
```

- **响应**:
  - 200 OK: 代理列表更新成功
  - 400 Bad Request: 请求参数错误

### 1.7 获取代理源的当前代理

- **URL**: `/proxy-sources/{id}/current-proxy`
- **方法**: GET
- **描述**: 获取指定代理源的当前代理
- **响应**:

```json
{
  "id": "proxy_id",
  "name": "proxy_name",
  "type": "proxy_type",
  "server": "server_address",
  "port": 1234,
  "config": {}
}
```

### 1.8 设置代理源的当前代理

- **URL**: `/proxy-sources/{id}/current-proxy`
- **方法**: PUT
- **描述**: 设置指定代理源的当前代理
- **请求体** (OpenVPN 示例):

```json
{
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
}
```

- **响应**:
  - 200 OK: 当前代理设置成功
  - 400 Bad Request: 请求参数错误

## 2. 路由规则管理接口

### 2.1 获取路由规则

- **URL**: `/rules`
- **方法**: GET
- **描述**: 获取所有路由规则
- **响应**:

```json
[
  {
    "type": "DOMAIN",
    "pattern": "example.com",
    "proxy_source": "proxy_source_id",
    "enabled": true
  }
]
```

### 2.2 更新路由规则

- **URL**: `/rules`
- **方法**: PUT
- **描述**: 更新所有路由规则
- **请求体**:

```json
[
  {
    "type": "DOMAIN",
    "pattern": "example.com",
    "proxy_source": "proxy_source_id",
    "enabled": true
  }
]
```

- **响应**:
  - 200 OK: 路由规则更新成功

## 3. 统计信息接口

### 3.1 获取统计信息

- **URL**: `/stats`
- **方法**: GET
- **描述**: 获取所有代理源的统计信息
- **响应**:

```json
{
  "stats": {
    "source_id": {
      "source_id": "source_id",
      "proxy_id": "proxy_id",
      "proxy_name": "proxy_name",
      "upload": 12345,
      "download": 67890
    }
  },
  "upload_speed": "↑ 10 KB/s",
  "download_speed": "↓ 20 KB/s"
}
```

## 4. 协议管理接口

### 4.1 获取所有协议

- **URL**: `/protocols`
- **方法**: GET
- **描述**: 获取所有协议
- **响应**:

```json
{
  "protocols": {
    "protocol_name": {
      "name": "protocol_name",
      "type": "protocol_type"
    }
  }
}
```

### 4.2 添加协议

- **URL**: `/protocols`
- **方法**: POST
- **描述**: 添加新协议
- **请求体**:

```json
{
  "name": "protocol_name",
  "type": "protocol_type",
  "config_field": "config_value"
}
```

- **响应**:
  - 201 Created: 协议添加成功
  - 400 Bad Request: 请求参数错误

## 5. 状态接口

### 5.1 获取状态

- **URL**: `/status`
- **方法**: GET
- **描述**: 获取代理核心状态
- **响应**:

```json
{
  "running": true,
  "version": "0.1.0"
}
```
