# Go 代理核心测试用例

## 支持的协议类型

Go 代理核心支持多种代理协议，包括：

- Shadowsocks (ss)
- Trojan
- VLESS
- VMess
- HTTP/HTTPS
- SOCKS5
- Direct (直连)
- OpenVPN
- WireGuard
- IPsec
- L2TP
- PPTP
- ShadowsocksR
- Snell
- IKEv2
- SoftEther

不同协议类型需要不同的配置参数：

### Shadowsocks 配置参数

- `cipher`: 加密方法 (如: chacha20-ietf-poly1305)
- `password`: 密码

### Trojan 配置参数

- `password`: 密码

### VLESS 配置参数

- `uuid`: 用户 UUID
- `network`: 网络类型 (如: tcp, ws)
- `tls`: 是否启用 TLS

## 统计信息说明

Go 代理核心现在支持更精准的流量统计能力：

1. **按代理源维度统计**：统计信息按代理源维度进行跟踪，每个代理源都有独立的上传和下载统计
2. **独立流量跟踪**：每个代理源的流量被独立跟踪，不再使用平均分配的方式
3. **实时更新**：统计信息实时更新，反映每个代理源的实际使用情况

## 服务启动脚本

在进行测试之前，需要先启动 Go 代理核心服务。可以使用以下方法之一启动服务：

### 方法 1：使用统一启动脚本（推荐）

```bash
# 使用集成的启动脚本，会自动检查并处理端口占用问题
./scripts/start_go_proxy.sh
```

### 方法 2：直接运行可执行文件

```
cd /Users/simon/Workspace/vsProject/dualvpn_manager/go-proxy-core
./go-proxy-core
```

### 方法 3：使用构建脚本

```
cd /Users/simon/Workspace/vsProject/dualvpn_manager/go-proxy-core
./build.sh
./bin/go-proxy-core
```

### 方法 4：直接使用 Go 运行

```
cd /Users/simon/Workspace/vsProject/dualvpn_manager/go-proxy-core
go run cmd/main.go
```

服务启动后，将监听以下端口：

- HTTP 代理端口: 6160
- SOCKS5 代理端口: 6161
- API 端口: 6162

## 服务运行检测脚本

启动服务后，可以使用独立的检测脚本检查服务是否正常运行：

```
# 运行检测脚本
./scripts/check_go_proxy.sh
```

## 服务停止脚本

测试完成后，可以使用独立的停止脚本停止服务：

```
# 运行停止脚本
./scripts/stop_go_proxy.sh
```

## 测试环境配置

1. 代理源 1：

   - 名称: "🇭🇰 香港-B-Relay-2X"
   - 类型: Shadowsocks (ss)
   - 服务器: cncm.hushitanke.top
   - 端口: 50016
   - 加密方法: chacha20-ietf-poly1305
   - 密码: ef18df75-d207-38ca-90ea-97884c4a9397

2. 代理源 2：

   - 名称: "🇭🇰 香港-C-Relay-2X"
   - 类型: Shadowsocks (ss)
   - 服务器: cncm.hushitanke.top
   - 端口: 50032
   - 加密方法: chacha20-ietf-poly1305
   - 密码: ef18df75-d207-38ca-90ea-97884c4a9397

3. 路由规则：
   - google.com -> 使用代理源 1
   - youtube.com -> 使用代理源 2
   - baidu.com -> 使用本地网络（直连）

## 测试用例 1: 添加代理源

```
# 添加第一个代理源
curl -X POST http://127.0.0.1:6162/proxy-sources \
  -H "Content-Type: application/json" \
  -d '{
    "id": "proxy-source-1",
    "name": "proxy-source-1",
    "type": "shadowsocks",
    "config": {}
  }'

# 添加第二个代理源
curl -X POST http://127.0.0.1:6162/proxy-sources \
  -H "Content-Type: application/json" \
  -d '{
    "id": "proxy-source-2",
    "name": "proxy-source-2",
    "type": "shadowsocks",
    "config": {}
  }'
```

## 测试用例 2: 设置代理源的当前代理

```
# 设置第一个代理源的当前代理
curl -X PUT http://127.0.0.1:6162/proxy-sources/proxy-source-1/current-proxy \
  -H "Content-Type: application/json" \
  -d '{
    "id": "proxy-1",
    "name": "🇭🇰香港-B-Relay-2X",
    "type": "shadowsocks",
    "server": "cncm.hushitanke.top",
    "port": 50016,
    "config": {
      "cipher": "chacha20-ietf-poly1305",
      "password": "ef18df75-d207-38ca-90ea-97884c4a9397"
    }
  }'

# 设置第二个代理源的当前代理
curl -X PUT http://127.0.0.1:6162/proxy-sources/proxy-source-2/current-proxy \
  -H "Content-Type: application/json" \
  -d '{
    "id": "proxy-2",
    "name": "🇭🇰香港-C-Relay-2X",
    "type": "shadowsocks",
    "server": "cncm.hushitanke.top",
    "port": 50032,
    "config": {
      "cipher": "chacha20-ietf-poly1305",
      "password": "ef18df75-d207-38ca-90ea-97884c4a9397"
    }
  }'
```

## 测试用例 3: 配置路由规则

```
# 设置路由规则
curl -X PUT http://127.0.0.1:6162/rules \
  -H "Content-Type: application/json" \
  -d '[
    {
      "type": "DOMAIN-SUFFIX",
      "pattern": "google.com",
      "proxy_source": "proxy-source-1",
      "enabled": true
    },
    {
      "type": "DOMAIN-SUFFIX",
      "pattern": "youtube.com",
      "proxy_source": "proxy-source-2",
      "enabled": true
    },
    {
      "type": "MATCH",
      "pattern": "",
      "proxy_source": "DIRECT",
      "enabled": true
    }
  ]'
```

## 测试用例 4: 验证路由和代理功能

```
# 验证baidu.com使用直连
curl -x http://127.0.0.1:6160 http://www.baidu.com

# 验证google.com使用代理源1
curl -x http://127.0.0.1:6160 http://www.google.com

# 验证youtube.com使用代理源2
curl -x http://127.0.0.1:6160 http://www.youtube.com
```

## 测试用例 5: 获取统计信息

```
# 获取统计信息
curl http://127.0.0.1:6162/stats
```

## 测试用例 6: 验证代理源信息

```
# 获取所有代理源
curl http://127.0.0.1:6162/proxy-sources

# 获取特定代理源信息
curl http://127.0.0.1:6162/proxy-sources/proxy-source-1
```

## API 接口使用方式

1. **启动代理核心**:

   - 运行 Go 代理核心程序，它会监听以下端口：
     - HTTP 代理端口: 6160
     - SOCKS5 代理端口: 6161
     - API 端口: 6162

2. **配置代理源**:

   - 使用 POST `/proxy-sources`添加代理源
   - 使用 PUT `/proxy-sources/{id}/current-proxy`设置当前代理

3. **配置路由规则**:

   - 使用 PUT `/rules`设置路由规则

4. **使用代理**:

   - 将 HTTP 客户端的代理设置为`127.0.0.1:6160`
   - 将 SOCKS5 客户端的代理设置为`127.0.0.1:6161`

5. **监控统计信息**:
   - 使用 GET `/stats`获取实时统计信息

## 验证测试结果

根据测试数据，预期结果如下：

1. **baidu.com**: 应该使用直连（DIRECT），不经过任何代理
2. **google.com**: 应该使用代理源 1（🇭🇰 香港-B-Relay-2X），通过 cncm.hushitanke.top:50016 连接
3. **youtube.com**: 应该使用代理源 2（🇭🇰 香港-C-Relay-2X），通过 cncm.hushitanke.top:50032 连接

通过检查日志和统计信息，可以验证请求是否正确地路由到了指定的代理。
