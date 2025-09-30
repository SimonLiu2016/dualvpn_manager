# Go 代理核心集成说明

## 概述

Go 代理核心是一个独立的代理服务器，用于统一管理多种代理协议（Clash、OpenVPN、Shadowsocks、V2Ray 等）并实现智能路由功能。它解决了 Clash 和 OpenVPN 之间的互斥问题，实现了统一的流量管理。

## 集成架构

```
Flutter应用 (UI层)
    ↓ (控制命令)
Go代理服务 (VPNManager)
    ↓ (启动/停止)
Go代理核心 (独立进程)
    ↓ (流量分发)
├── Shadowsocks
├── V2Ray
├── HTTP
├── SOCKS5
├── PPTP
├── L2TP
├── IKEv2
├── SoftEther
├── WireGuard
├── OpenVPN
└── 直连流量
```

## 启动方式

### 1. 手动启动 Go 代理核心

在终端中运行以下命令：

```bash
cd /Users/simon/Workspace/vsProject/dualvpn_manager/go-proxy-core
./go-proxy-core
```

### 2. 通过 Flutter 应用启动

在应用的主页中，您会看到"Go 代理核心"控制区域，点击"启动"按钮即可启动 Go 代理核心。

## 端口配置

Go 代理核心使用以下端口：

- HTTP 代理: 6160
- SOCKS5 代理: 6161
- API 服务: 6162
- OpenVPN 代理: 1080
- DNS 服务: 53

## API 接口

### 获取状态

```
GET http://127.0.0.1:6162/status
响应: {"running":true,"version":"0.1.0"}
```

### 获取路由规则

```
GET http://127.0.0.1:6162/rules
响应: 路由规则列表 (JSON格式)
```

### 更新路由规则

```
PUT http://127.0.0.1:6162/rules
请求体: 路由规则列表 (JSON格式)
响应: "Rules updated"
```

## 配置文件

### config.yaml

主配置文件，位于 `go-proxy-core/config.yaml`：

```yaml
http_port: 6160 # HTTP代理端口
socks5_port: 6161 # SOCKS5代理端口
api_port: 6162 # API服务端口
openvpn_port: 1080 # OpenVPN代理端口
dns_port: 53 # DNS服务器端口
dns_type: "fakeip" # DNS类型 (fakeip 或 doh)
doh_server: "https://1.1.1.1/dns-query" # DoH服务器
rules_file: "rules.yaml" # 路由规则文件
log_level: "info" # 日志级别
```

### rules.yaml

路由规则文件，位于 `go-proxy-core/rules.yaml`：

```yaml
rules:
  - type: "DOMAIN-SUFFIX" # 规则类型
    pattern: "google.com" # 匹配模式
    proxy_source: "clash" # 代理源 (clash/openvpn/DIRECT)
    enabled: true # 是否启用
  - type: "IP-CIDR"
    pattern: "192.168.1.0/24"
    proxy_source: "openvpn"
    enabled: true
  - type: "MATCH"
    pattern: ""
    proxy_source: "DIRECT"
    enabled: true
```

## 使用流程

1. **启动 Go 代理核心**：

   - 方法一：在 Flutter 应用中点击"启动"按钮
   - 方法二：在终端中手动运行 `./go-proxy-core`

2. **配置代理源**：

   - 在 Flutter 应用的"代理源"页面添加 Clash、OpenVPN 等配置
   - 启用需要使用的代理源

3. **设置路由规则**：

   - 在 Flutter 应用的"路由"页面配置域名/IP 路由规则
   - 规则会自动同步到 Go 代理核心

4. **使用代理**：
   - 系统代理已自动设置为 127.0.0.1:6160 (HTTP) 和 127.0.0.1:6161 (SOCKS5)
   - 所有网络流量将通过 Go 代理核心处理

## 故障排除

### Go 代理核心无法启动

1. 检查端口是否被占用：`lsof -i :6160`
3. 检查配置文件是否正确

### 路由规则不生效

1. 检查规则是否已启用
2. 确认规则类型和模式是否正确
3. 查看日志文件获取更多信息

### 代理连接失败

1. 检查代理源配置是否正确
2. 确认代理服务是否正常运行
3. 检查防火墙设置

## 日志查看

Go 代理核心的日志会输出到终端，您也可以通过以下方式查看：

```bash
# 查看最近的日志
tail -f go-proxy-core/logs/proxy.log

# 查看错误日志
tail -f go-proxy-core/logs/error.log
```

## 停止服务

### 通过 Flutter 应用停止

在主页的"Go 代理核心"控制区域点击"停止"按钮。

### 手动停止

在终端中按 `Ctrl+C` 或使用以下命令：

```bash
# 查找进程ID
ps aux | grep go-proxy-core

# 杀死进程
kill -9 <进程ID>
```
