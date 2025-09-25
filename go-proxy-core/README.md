# DualVPN Go Proxy Core

DualVPN Go Proxy Core 是一个用 Go 语言实现的代理核心，用于管理多种代理协议（HTTP、SOCKS5、OpenVPN、WireGuard、IPsec、L2TP、PPTP、Shadowsocks、ShadowsocksR、VMess、Trojan、Snell、IKEv2、SoftEther 等）并实现智能路由功能。

## 功能特性

- **多协议支持**：支持 12 种 VPN 协议（OpenVPN、WireGuard、IPsec、L2TP、PPTP、Shadowsocks、ShadowsocksR、VMess、Trojan、Snell、IKEv2、SoftEther）以及 HTTP、SOCKS5 等代理协议
- **智能路由**：基于域名和 IP 的路由规则，支持内外网流量分离
- **DNS 防污染**：支持 Fake-IP 和 DoH（DNS over HTTPS）防止 DNS 泄漏
- **跨平台**：支持 Windows、macOS 和 Linux 系统
- **系统代理**：自动设置和清除系统代理配置
- **API 接口**：提供 RESTful API 用于配置管理和状态查询

## 架构设计

```
+-------------------+
|   Flutter UI      |
+-------------------+
         |
         | HTTP API
         v
+-------------------+
|  Go Proxy Core    |
|                   |
|  - HTTP Server    |
|  - SOCKS5 Server  |
|  - DNS Server     |
|  - Rules Engine   |
|  - Protocol Manager |
+-------------------+
         |
    +----+----+----+----+----+----+----+----+----+----+----+----+
    |    |    |    |    |    |    |    |    |    |    |    |    |
    v    v    v    v    v    v    v    v    v    v    v    v    v
+----+----+----+----+----+----+----+----+----+----+----+----+----+
|HTTP|HTTPS|SOCKS|DIRECT|OpenVPN|WireGuard|IPsec|L2TP|PPTP|Shadowsocks|
+----+----+----+----+----+----+----+----+----+----+----+----+----+
|ShadowsocksR|VMess|Trojan|Snell|IKEv2|SoftEther|
+----+----+----+----+----+----+----+----+----+----+

```

## 安装依赖

```bash
go mod tidy
```

## 编译

```bash
go build -o dualvpn-proxy ./cmd/main.go
```

## 配置文件

### config.yaml

```yaml
http_port: 6160
socks5_port: 6161
api_port: 6162
dns_port: 53
dns_type: "fakeip"
doh_server: "https://1.1.1.1/dns-query"
log_level: "info"
```

## API 接口

### 获取路由规则

```http
GET /rules
```

### 更新路由规则

```http
PUT /rules
Content-Type: application/json

[
  {
    "type": "DOMAIN-SUFFIX",
    "pattern": "example.com",
    "proxy_source": "openvpn",
    "enabled": true
  }
]
```

### 获取状态

```http
GET /status
```

### 获取协议列表

```http
GET /protocols
```

### 添加协议

```http
POST /protocols
Content-Type: application/json

{
  "type": "openvpn",
  "name": "my-openvpn",
  "server": "vpn.example.com",
  "port": 1194,
  "username": "user",
  "password": "pass"
}
```

## 使用方法

1. 配置 config.yaml 文件
2. 运行代理核心：

```bash
./dualvpn-proxy
```

3. 通过 Flutter UI 或 API 接口进行配置管理

## 许可证

MIT
