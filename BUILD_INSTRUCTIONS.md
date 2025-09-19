# DualVPN Manager 构建说明

## 项目架构

DualVPN Manager 采用前后端分离架构：

- 前端：Flutter (Dart)
- 后端：Go 代理核心

两者通过 HTTP API 进行通信。

## 构建步骤

### 1. 构建 Go 代理核心

```bash
# 进入 Go 代理核心目录
cd go-proxy-core

# 构建可执行文件
go build -o dualvpn-proxy ./cmd/main.go

# 验证构建成功
ls -la dualvpn-proxy
```

### 2. 配置 Go 代理核心

确保 [config.yaml](file:///Users/simon/Workspace/vsProject/dualvpn_manager/go-proxy-core/config.yaml) 文件存在并正确配置：

```yaml
http_port: 6160
socks5_port: 6161
api_port: 6162
dns_port: 53
dns_type: "fakeip"
doh_server: "https://1.1.1.1/dns-query"
log_level: "info"
```

### 3. 构建 Flutter 应用

```bash
# 返回项目根目录
cd ..

# 获取依赖
flutter pub get

# 构建桌面应用 (以 macOS 为例)
flutter build macos

# 或构建 Windows 应用
# flutter build windows

# 或构建 Linux 应用
# flutter build linux
```

### 4. 运行应用

#### 开发模式运行

```bash
# 启动 Go 代理核心
cd go-proxy-core
./dualvpn-proxy &

# 返回项目根目录并运行 Flutter 应用
cd ..
flutter run
```

#### 生产模式运行

1. 首先启动 Go 代理核心：

   ```bash
   cd go-proxy-core
   ./dualvpn-proxy
   ```

2. 然后运行 Flutter 应用：
   ```bash
   flutter run
   ```

## 集成说明

### Go 代理核心功能

Go 代理核心提供以下功能：

1. 支持 12 种 VPN 协议（OpenVPN、WireGuard、IPsec、L2TP、PPTP、Shadowsocks、ShadowsocksR、VMess、Trojan、Snell、IKEv2、SoftEther）
2. HTTP 和 SOCKS5 代理服务器
3. 智能路由引擎
4. RESTful API 接口

### Flutter 与 Go 代理核心通信

Flutter 通过 [GoProxyService](file:///Users/simon/Workspace/vsProject/dualvpn_manager/lib/services/go_proxy_service.dart) 与 Go 代理核心进行通信：

1. 启动/停止 Go 代理核心进程
2. 通过 HTTP API 更新路由规则
3. 通过 HTTP API 获取状态信息

API 端点：

- `http://127.0.0.1:6162/rules` - 路由规则管理
- `http://127.0.0.1:6162/status` - 状态查询
- `http://127.0.0.1:6162/protocols` - 协议管理

### 代理协议支持

Go 代理核心支持以下协议：

- DIRECT - 直连
- HTTP/HTTPS - HTTP 代理
- SOCKS5 - SOCKS5 代理
- OpenVPN - OpenVPN 协议
- WireGuard - WireGuard 协议
- IPsec - IPsec 协议
- L2TP - L2TP 协议
- PPTP - PPTP 协议
- Shadowsocks - Shadowsocks 协议
- ShadowsocksR - ShadowsocksR 协议
- VMess - VMess 协议
- Trojan - Trojan 协议
- Snell - Snell 协议
- IKEv2 - IKEv2 协议
- SoftEther - SoftEther 协议

## 部署说明

### macOS 部署

```bash
# 构建应用
flutter build macos

# 找到构建产物
open build/macos/Build/Products/Release/
```

### Windows 部署

```bash
# 构建应用
flutter build windows

# 找到构建产物
explorer build\windows\x64\runner\Release
```

### Linux 部署

```bash
# 构建应用
flutter build linux

# 找到构建产物
ls build/linux/x64/release/bundle/
```

## 故障排除

### Go 代理核心无法启动

1. 检查端口是否被占用：

   ```bash
   lsof -i :6160
   lsof -i :6161
   lsof -i :6162
   ```

2. 检查配置文件是否存在且格式正确

### Flutter 应用无法连接 Go 代理核心

1. 确保 Go 代理核心正在运行
2. 检查防火墙设置
3. 验证 API 端点是否可访问：
   ```bash
   curl http://127.0.0.1:6162/status
   ```

### 网站无法访问（连接超时）

1. 检查路由规则是否正确配置：

   ```bash
   curl http://127.0.0.1:6162/rules
   ```

2. 检查代理协议是否已添加：

   ```bash
   curl http://127.0.0.1:6162/protocols
   ```

3. 确保代理服务（如 Clash）正在运行并监听指定端口：

   ```bash
   lsof -i :7890
   ```

4. 验证代理服务是否能正常工作：
   ```bash
   curl -x http://127.0.0.1:7890 http://www.google.com
   ```

### 日志分析

Go 代理核心日志中的关键信息：

- `matched proxy source: DIRECT` - 请求被路由到直连
- `matched proxy source: clash-proxy` - 请求被路由到 Clash 代理
- `Error connecting to target` - 连接目标失败

## 开发建议

1. 在开发过程中，可以分别启动 Go 代理核心和 Flutter 应用以便调试
2. 使用日志系统跟踪通信过程
3. 确保在不同平台上测试应用的兼容性
