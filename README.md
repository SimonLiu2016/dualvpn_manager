# 双捷 VPN 管理器 (DualVPN Manager)

一个轻量级的 VPN 管理工具，可以同时管理 OpenVPN 和 Clash 两种 VPN 连接，实现内外网同时访问的功能。

## 功能特点

- **双 VPN 同时连接**: 支持同时连接 OpenVPN（公司内网）和 Clash（外部网络）
- **智能路由**: 自动区分内外网流量，确保正确路由
- **统一管理界面**: 集中管理两种 VPN 的配置和连接状态
- **跨平台支持**: 支持 Windows、macOS 和 Linux 系统
- **轻量级设计**: 无需安装 Tunnelblick 和 ClashX，一个工具搞定所有

## 技术架构

- **开发框架**: Flutter
- **编程语言**: Dart
- **核心功能**:
  - OpenVPN 客户端集成
  - Clash 核心集成
  - 智能路由系统
  - 配置管理
  - 系统托盘支持

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
# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux
```

## 使用说明

1. 在"配置"页面添加 OpenVPN 配置文件路径或 Clash 订阅链接
2. 在"主页"切换两种 VPN 的连接状态
3. 在"路由"页面配置内外网域名并启用智能路由
4. 享受同时访问内外网的便利

## Clash 集成说明

当前版本通过调用系统中安装的 Clash 二进制文件来实现 Clash 协议支持。为了使应用程序更加独立，未来的版本将采用以下方式集成 Clash：

### 方案一：将 Clash.Meta 作为库集成（推荐）

1. 将 Clash.Meta 作为 Go 模块直接集成到 Go 代理核心中
2. 这样就不需要单独的二进制文件，所有功能都在一个可执行文件中

### 方案二：打包 Clash.Meta 二进制文件

1. 下载适用于不同平台的 Clash.Meta 二进制文件
2. 将它们打包到应用程序中
3. 修改代码以使用这些打包的二进制文件

详细信息请参阅 [GO_PROXY_CORE_DOCUMENTATION.md](GO_PROXY_CORE_DOCUMENTATION.md) 中的 "Clash 集成说明" 部分。

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   ├── vpn_config.dart       # VPN配置模型
│   └── app_state.dart        # 应用状态模型
├── services/                 # 核心服务
│   ├── openvpn_service.dart  # OpenVPN服务
│   ├── clash_service.dart    # Clash服务
│   ├── routing_service.dart  # 路由服务
│   └── vpn_manager.dart      # VPN管理器
├── ui/                       # 用户界面
│   ├── screens/              # 页面
│   │   ├── home_screen.dart  # 主页
│   │   ├── config_screen.dart# 配置管理
│   │   └── routing_screen.dart# 路由配置
│   └── widgets/              # 组件
└── utils/                    # 工具类
    ├── config_manager.dart   # 配置管理器
    └── tray_manager.dart     # 系统托盘管理器
```

## 开发计划

- [x] 项目初始化和基础结构搭建
- [x] UI 界面设计
- [x] 数据模型设计
- [x] 核心服务实现
- [ ] OpenVPN 客户端集成
- [ ] Clash 核心集成
- [ ] 智能路由功能实现
- [ ] 配置管理功能完善
- [ ] 系统托盘支持
- [ ] 测试和优化
- [ ] 发布准备

## 许可证

MIT License

# dualvpn_manager

# 双捷 VPN 管理器 (DualVPN Manager) 一个轻量级的 VPN 管理工具，可以同时管理 OpenVPN 和 Clash 两种 VPN 连接，实现内外网同时访问的功能。
