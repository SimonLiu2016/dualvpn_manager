# 双捷 VPN 管理器 (DualVPN Manager)

一个轻量级的 VPN 管理工具，可以同时管理多种类型的网络代理连接，实现指定地址使用指定代理源访问的需求，
典型应用场景：不需要频繁反复切换网络或代理，达到同时访问内外网。

注意：由于 macOS App Store 审核问题，暂时无法提交 macOS 应用，请谅解。

## 功能特点

- **多协议支持**: 支持 OpenVPN、Clash、Shadowsocks、V2Ray、HTTP代理、SOCKS5代理等多种协议
- **智能路由**: 自动区分内外网流量，确保正确路由
- **统一管理界面**: 集中管理各种代理的配置和连接状态
- **跨平台支持**: 暂时仅支持macOS系统，其余平台支持后续支持更新
- **轻量级设计**: 无需安装多个独立的客户端工具

## 技术架构

### 核心组件

- **开发框架**: Flutter
- **编程语言**: Dart (应用层) / Go (代理核心)
- **核心功能**:
  - 多协议代理客户端集成
  - 智能路由系统
  - 配置管理
  - 流量及流速统计
  - 系统托盘支持
  - Go 代理核心（用于处理复杂的网络代理和路由）

### 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    用户界面 (Flutter/Dart)                  │
├─────────────────────────────────────────────────────────────┤
│                   应用状态管理 (AppState)                   │
├─────────────────────────────────────────────────────────────┤
│                   服务层 (VPNManager等)                     │
├─────────────────────────────────────────────────────────────┤
│              平台特定功能 (特权助手、系统代理)              │
├─────────────────────────────────────────────────────────────┤
│                    Go 代理核心 (go-proxy-core)             │
├─────────────────────────────────────────────────────────────┤
│              各种协议实现 (OpenVPN, Clash, etc.)            │
└─────────────────────────────────────────────────────────────┘
```

### macOS 特权助手机制

在 macOS 上，应用使用特权助手 (Privileged Helper) 来执行需要管理员权限的操作：

1. **OpenVPN 配置文件处理**: 安全地复制和管理 OpenVPN 配置文件
2. **Go 代理核心启动**: 以特权身份运行网络代理服务
3. **系统级网络配置**: 设置系统代理和路由规则

为了解决首次启动时因权限请求导致的界面漆黑问题，我们实现了以下机制：

1. 延迟特权助手的安装直到主窗口显示完成
2. 在 Go 代理核心初始化前等待特权助手安装完成
3. 通过 Flutter 方法通道实现原生代码与 Dart 代码的通信

### Go 代理核心

Go 代理核心是应用的核心组件，负责处理所有网络代理和路由功能：

- **多协议支持**: OpenVPN、Clash、Shadowsocks、V2Ray、HTTP代理、SOCKS5代理
- **智能路由**: 基于域名和IP的路由规则
- **API 接口**: 提供 RESTful API 供 Flutter 应用控制
- **系统集成**: 与系统代理设置和网络配置集成

## 安装依赖

```bash
flutter pub get
```

## 运行应用

```bash
flutter run
```

## 构建应用

```bash
# pkg 安装包
./scripts/app_store/build_pkg_for_app_store_v2.sh

# dmg 安装包
./scripts/build_and_pakcage_fixed.sh
```

## 使用说明

1. 在"代理源"页面添加并启用各种代理配置
2. 在"代理列表"页面选择具体的代理服务器
3. 在"路由"页面配置内外网域名并启用智能路由
4. 享受同时访问内外网的便利

## 项目结构

```
.
├── lib/                      # Flutter 应用代码
│   ├── main.dart             # 应用入口
│   ├── models/               # 数据模型
│   │   ├── app_state.dart    # 应用状态模型
│   │   └── vpn_config.dart   # VPN配置模型
│   ├── services/             # 核心服务
│   │   ├── vpn_manager.dart  # VPN管理器
│   │   ├── go_proxy_service.dart # Go代理核心服务
│   │   ├── openvpn_service.dart # OpenVPN服务
│   │   ├── clash_service.dart # Clash服务
│   │   ├── shadowsocks_service.dart # Shadowsocks服务
│   │   ├── v2ray_service.dart # V2Ray服务
│   │   ├── http_proxy_service.dart # HTTP代理服务
│   │   ├── socks5_proxy_service.dart # SOCKS5代理服务
│   │   └── ...               # 其他服务
│   ├── ui/                   # 用户界面
│   │   ├── screens/          # 页面
│   │   │   ├── home_screen.dart # 主页
│   │   │   ├── config_screen.dart # 配置管理
│   │   │   ├── proxy_list_screen.dart # 代理列表
│   │   │   ├── routing_screen.dart # 路由配置
│   │   │   └── routing_rules_screen.dart # 路由规则
│   │   └── widgets/          # 组件
│   └── utils/                # 工具类
│       ├── config_manager.dart # 配置管理器
│       ├── tray_manager.dart # 系统托盘管理器
│       ├── logger.dart       # 日志工具
│       └── openvpn_config_parser.dart # OpenVPN配置解析器
├── go-proxy-core/            # Go 代理核心
│   ├── cmd/                  # 主程序入口
│   ├── proxy/                # 各种协议实现
│   ├── routing/              # 路由引擎
│   ├── api/                  # API 接口
│   ├── config/               # 配置管理
│   ├── openvpn/              # OpenVPN 客户端
│   └── system/               # 系统集成
├── macos/                    # macOS 特定代码
│   ├── Runner/               # 主应用
│   │   └── AppDelegate.swift # 应用委托
│   └── PrivilegedHelper/     # 特权助手
├── scripts/                  # 构建和部署脚本
└── assets/                   # 静态资源
```

## 开发计划

- [x] 项目初始化和基础结构搭建
- [x] UI 界面设计
- [x] 数据模型设计
- [x] 核心服务实现
- [x] macOS 启动体验优化
- [x] 多协议代理支持 (OpenVPN, Clash, Shadowsocks, V2Ray, HTTP, SOCKS5)
- [x] 智能路由功能实现
- [x] 配置管理功能完善
- [x] 系统托盘支持
- [ ] 测试和优化
- [ ] 发布准备

有关更详细的未来发展规划，请参阅 [FUTURE_PLANS.md](docs/FUTURE_PLANS.md) 文件。

## 许可证

MIT License

## 版本声明

当前版本：v0.1.0 开发版

作者：Simon  
邮箱：582883825@qq.com  
网址：[v8en.com](https://v8en.com)

## 隐私政策

本应用的隐私政策可在以下链接查看：
- 中文版：[隐私政策页面](https://SimonLiu2016.github.io/dualvpn_manager/privacy-policy.html)
- 英文版：[Privacy Policy](https://SimonLiu2016.github.io/dualvpn_manager/privacy-policy-en.html)

**免责声明**：本软件为开发预览版本，功能尚未完全稳定，仅供技术预览和测试使用。作者不对因使用本软件而造成的任何直接或间接损失负责。
