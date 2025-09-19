# DualVPN Go Proxy Core 实现文档

## 项目概述

DualVPN Go Proxy Core 是一个用 Go 语言实现的代理核心，用于管理多种代理协议（Clash、OpenVPN、Shadowsocks、V2Ray 等）并实现智能路由功能。该项目解决了 Clash 和 OpenVPN 之间的互斥问题，实现了统一的流量管理。

## 功能实现

### 1. 多代理源支持

#### HTTP/SOCKS5 代理监听

- 实现了 HTTP 代理服务器（监听端口 6160）
- 实现了 SOCKS5 代理服务器（监听端口 6161）
- 支持基本的代理协议处理

#### Clash 集成

- 通过 `clash/proxy.go` 模块集成 Clash 核心
- 支持启动和停止 Clash 进程
- 配置 Clash 监听端口（HTTP: 7890, SOCKS5: 7891, API: 9090）

#### OpenVPN 集成

- 通过 `openvpn/proxy.go` 模块集成 OpenVPN
- 支持启动和停止 OpenVPN 进程
- 配置 OpenVPN 代理端口（1080）

#### Shadowsocks/V2Ray 支持

- 通过 Clash 核心间接支持 Shadowsocks 和 V2Ray 协议
- 支持订阅配置解析

### 2. 路由规则

#### 规则解析和匹配

- 实现了基于域名后缀的匹配（DOMAIN-SUFFIX）
- 实现了基于 IP CIDR 的匹配（IP-CIDR）
- 实现了通用匹配规则（MATCH）
- 支持规则启用/禁用

#### 路由决策引擎

- 通过 `routing/engine.go` 实现路由决策
- 支持优先级匹配（按规则顺序）
- 支持直连（DIRECT）作为默认选项

### 3. TUN 模式解决互斥问题

#### 统一流量捕获

- 实现了 TUN 设备创建和管理（`proxy/tun.go`）
- 支持 macOS (utun)、Linux (tun) 和 Windows (需要 Wintun 驱动)
- 通过单一 TUN 设备捕获所有 TCP/UDP 流量

#### 流量分发

- 解析 TUN 数据包获取目标地址
- 根据路由规则决定转发目标
- 支持转发到 Clash、OpenVPN 或直连

### 4. DNS 防污染

#### Fake-IP 模式

- 实现了 Fake-IP DNS 服务器（`dns/server.go`）
- 返回虚假 IP 地址防止 DNS 泄漏
- 支持 A 记录查询

#### DoH 支持

- 配置支持 DoH（DNS over HTTPS）
- 可配置 DoH 服务器地址

### 5. 系统代理设置

#### 跨平台支持

- Windows：通过注册表设置系统代理
- macOS：通过 networksetup 命令设置系统代理
- Linux：提供环境变量设置指导

#### 自动配置

- 支持自动设置 HTTP、HTTPS 和 SOCKS 代理
- 支持自动清除系统代理配置

### 6. API 服务

#### RESTful API

- 实现了规则管理 API（GET/PUT /rules）
- 实现了状态查询 API（GET /status）
- 支持 JSON 格式数据交换

#### 配置管理

- 支持动态更新路由规则
- 支持获取当前运行状态

## 项目架构

```
go-proxy-core/
├── cmd/
│   └── main.go              # 主程序入口
├── proxy/
│   ├── core.go              # 代理核心
│   ├── http.go              # HTTP 服务器
│   ├── socks5.go            # SOCKS5 服务器
│   └── tun.go               # TUN 设备管理
├── clash/
│   └── proxy.go             # Clash 集成
├── openvpn/
│   └── proxy.go             # OpenVPN 集成
├── dns/
│   └── server.go            # DNS 服务器
├── routing/
│   └── engine.go            # 路由引擎
├── config/
│   ├── config.go            # 配置管理
│   └── rules.go             # 规则配置
├── api/
│   └── server.go            # API 服务
├── system/
│   └── proxy.go             # 系统代理设置
├── config.yaml              # 主配置文件
├── rules.yaml               # 路由规则文件
├── build.sh                 # 构建脚本
├── package.sh               # 打包脚本
└── README.md                # 项目说明
```

## 配置文件

### config.yaml

```yaml
http_port: 6160 # HTTP 代理端口
socks5_port: 6161 # SOCKS5 代理端口
api_port: 6162 # API 服务端口
clash_port: 7890 # Clash HTTP 端口
clash_api_port: 9090 # Clash API 端口
openvpn_port: 1080 # OpenVPN 代理端口
dns_port: 53 # DNS 服务器端口
dns_type: "fakeip" # DNS 类型 (fakeip 或 doh)
doh_server: "https://1.1.1.1/dns-query" # DoH 服务器
rules_file: "rules.yaml" # 路由规则文件
log_level: "info" # 日志级别
```

### rules.yaml

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

## API 接口

### 获取路由规则

```
GET /rules
响应: 路由规则列表 (JSON)
```

### 更新路由规则

```
PUT /rules
请求体: 路由规则列表 (JSON)
响应: "Rules updated"
```

### 获取状态

```
GET /status
响应: 系统状态信息 (JSON)
```

## 部署和使用

### 系统要求

- Go 1.20+
- Clash (用于 Shadowsocks/V2Ray 协议)
- OpenVPN (用于 OpenVPN 协议)

### 构建

```bash
# 构建主程序
go build -o dualvpn-proxy ./cmd/main.go

# 或使用构建脚本
./build.sh
```

### 运行

```bash
# 直接运行
./dualvpn-proxy

# 或使用打包脚本
./package.sh
cd dist
./dualvpn-proxy
```

### 配置

1. 编辑 `config.yaml` 配置文件
2. 编辑 `rules.yaml` 路由规则文件
3. 确保 Clash 和 OpenVPN 已正确安装

## Clash 集成说明

当前实现通过调用外部 Clash 二进制文件来实现 Clash 协议支持。为了使应用程序更加独立，可以采用以下方式集成 Clash：

### 方案一：将 Clash.Meta 作为库集成（推荐）

1. 将 Clash.Meta 作为 Go 模块直接集成到 Go 代理核心中
2. 这样就不需要单独的二进制文件，所有功能都在一个可执行文件中

要使用此方案，请执行以下步骤：

1. 更新 `go.mod` 文件以包含 Clash.Meta 依赖：

   ```
   require github.com/MetaCubeX/Clash.Meta latest
   ```

2. 运行 `go mod tidy` 下载依赖

3. 修改 `clash/proxy.go` 文件以使用 Clash.Meta 库而不是调用外部二进制文件

### 方案二：打包 Clash.Meta 二进制文件

1. 下载适用于不同平台的 Clash.Meta 二进制文件
2. 将它们打包到应用程序中
3. 修改代码以使用这些打包的二进制文件

## 未来改进方向

1. **完善协议支持**：实现完整的 HTTP/SOCKS5 协议解析
2. **增强 TUN 模式**：完善 Windows 平台的 Wintun 集成
3. **性能优化**：优化数据包处理和转发性能
4. **安全增强**：添加认证和加密机制
5. **监控功能**：实现流量统计和监控面板
6. **日志系统**：完善日志记录和分析功能

## 许可证

MIT
