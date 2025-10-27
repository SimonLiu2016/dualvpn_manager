import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';

class DualVPNTrayManager with TrayListener {
  bool _isInitialized = false;
  VoidCallback? _showWindowCallback;
  AppState? _appState; // 添加AppState引用

  // 设置AppState引用
  void setAppState(AppState appState) {
    _appState = appState;
  }

  // 设置显示窗口的回调函数
  void setShowWindowCallback(VoidCallback callback) {
    _showWindowCallback = callback;
  }

  Future<void> initTray() async {
    if (_isInitialized) return;

    try {
      // 初始化系统托盘，使用PNG图标
      await trayManager.setIcon('assets/icons/app_icon.png');

      // 创建托盘菜单
      Menu menu = Menu(
        items: [
          MenuItem(key: 'show_window', label: '显示主窗口'),
          MenuItem(key: 'separator1', label: ''),
          MenuItem(key: 'openvpn_connect', label: '连接OpenVPN'),
          MenuItem(key: 'openvpn_disconnect', label: '断开OpenVPN'),
          MenuItem(key: 'separator2', label: ''),
          MenuItem(key: 'clash_connect', label: '连接Clash'),
          MenuItem(key: 'clash_disconnect', label: '断开Clash'),
          MenuItem(key: 'separator3', label: ''),
          MenuItem(key: 'shadowsocks_connect', label: '连接Shadowsocks'),
          MenuItem(key: 'shadowsocks_disconnect', label: '断开Shadowsocks'),
          MenuItem(key: 'separator4', label: ''),
          MenuItem(key: 'v2ray_connect', label: '连接V2Ray'),
          MenuItem(key: 'v2ray_disconnect', label: '断开V2Ray'),
          MenuItem(key: 'separator5', label: ''),
          MenuItem(key: 'http_proxy_connect', label: '连接HTTP代理'),
          MenuItem(key: 'http_proxy_disconnect', label: '断开HTTP代理'),
          MenuItem(key: 'separator6', label: ''),
          MenuItem(key: 'socks5_proxy_connect', label: '连接SOCKS5代理'),
          MenuItem(key: 'socks5_proxy_disconnect', label: '断开SOCKS5代理'),
          MenuItem(key: 'separator7', label: ''),
          MenuItem(key: 'exit_app', label: '退出应用'),
        ],
      );

      await trayManager.setContextMenu(menu);
      trayManager.addListener(this); // 添加监听器
      _isInitialized = true;
    } catch (e) {
      // 如果托盘初始化失败，不抛出异常，应用仍可正常运行
      print('托盘初始化失败: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    // 点击托盘图标时显示主窗口
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        // 显示主窗口
        _showWindow();
        break;
      case 'openvpn_connect':
        // 连接OpenVPN
        _connectOpenVPN();
        break;
      case 'openvpn_disconnect':
        // 断开OpenVPN
        _disconnectOpenVPN();
        break;
      case 'clash_connect':
        // 连接Clash
        _connectClash();
        break;
      case 'clash_disconnect':
        // 断开Clash
        _disconnectClash();
        break;
      case 'shadowsocks_connect':
        // 连接Shadowsocks
        _connectShadowsocks();
        break;
      case 'shadowsocks_disconnect':
        // 断开Shadowsocks
        _disconnectShadowsocks();
        break;
      case 'v2ray_connect':
        // 连接V2Ray
        _connectV2Ray();
        break;
      case 'v2ray_disconnect':
        // 断开V2Ray
        _disconnectV2Ray();
        break;
      case 'http_proxy_connect':
        // 连接HTTP代理
        _connectHTTPProxy();
        break;
      case 'http_proxy_disconnect':
        // 断开HTTP代理
        _disconnectHTTPProxy();
        break;
      case 'socks5_proxy_connect':
        // 连接SOCKS5代理
        _connectSOCKS5Proxy();
        break;
      case 'socks5_proxy_disconnect':
        // 断开SOCKS5代理
        _disconnectSOCKS5Proxy();
        break;
      case 'exit_app':
        // 退出应用前关闭Go代理核心服务并清除系统代理设置
        _exitApp();
        break;
    }
  }

  // 退出应用
  void _exitApp() async {
    try {
      if (_appState != null) {
        // 停止Go代理核心
        await _appState!.stopGoProxy();
      }
    } catch (e) {
      print('退出应用时清理资源失败: $e');
    } finally {
      // 退出应用
      exit(0);
    }
  }

  // 显示主窗口
  void _showWindow() {
    // 如果设置了回调函数，优先使用回调函数
    if (_showWindowCallback != null) {
      _showWindowCallback!();
    } else {
      // 否则使用默认的窗口管理器方法
      windowManager.show();
      windowManager.focus();
    }

    // 在macOS上确保程序坞图标显示
    if (Platform.isMacOS) {
      _showDockIcon();
    }
  }

  // 显示程序坞图标 (macOS专用)
  void _showDockIcon() {
    if (Platform.isMacOS) {
      try {
        const MethodChannel macosChannel = MethodChannel(
          'dualvpn_manager/macos',
        );
        macosChannel.invokeMethod('showDockIcon');
      } catch (e) {
        developer.log('调用显示程序坞图标方法失败: $e');
      }
    }
  }

  Future<void> updateTrayIcon(
    bool openVPNConnected,
    bool clashConnected, {
    bool starting = false,
  }) async {
    // 根据连接状态更新托盘图标
    String iconPath = 'assets/icons/app_icon_32.png'; // 默认图标

    // 检查是否处于启动中状态
    if (starting) {
      // 启动中状态，使用启动中图标
      iconPath = 'assets/icons/starting.png';
    } else if (_appState != null && _appState!.isGoProxyRunning) {
      // 检查Go代理核心是否运行，如果运行则使用特殊的图标
      if (openVPNConnected && clashConnected) {
        iconPath = 'assets/icons/go_both_connected.png';
      } else if (openVPNConnected) {
        iconPath = 'assets/icons/go_openvpn_connected.png';
      } else if (clashConnected) {
        iconPath = 'assets/icons/go_clash_connected.png';
      } else {
        iconPath = 'assets/icons/go_proxy_running.png';
      }
    } else {
      // Go代理核心未运行，使用原来的图标逻辑
      if (openVPNConnected && clashConnected) {
        iconPath = 'assets/icons/both_connected.png';
      } else if (openVPNConnected) {
        iconPath = 'assets/icons/openvpn_connected.png';
      } else if (clashConnected) {
        iconPath = 'assets/icons/clash_connected.png';
      } else {
        iconPath = 'assets/icons/disconnected.png';
      }
    }

    try {
      // 检查图标文件是否存在
      if (await File(iconPath).exists()) {
        await trayManager.setIcon(iconPath);
      } else {
        // 如果特定图标不存在，使用默认图标
        await trayManager.setIcon('assets/icons/app_icon_32.png');
      }

      // 添加一个短暂的动画效果（仅在连接成功时）
      if (!starting &&
          (openVPNConnected ||
              clashConnected ||
              (_appState != null && _appState!.isGoProxyRunning))) {
        // 模拟连接动画
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          await trayManager.setIcon('assets/icons/app_icon_32.png');
          await Future.delayed(const Duration(milliseconds: 200));
          await trayManager.setIcon(iconPath);
        }
      }
    } catch (e) {
      // 如果更新托盘图标失败，不抛出异常
      print('更新托盘图标失败: $e');
    }
  }

  Future<void> destroyTray() async {
    try {
      trayManager.removeListener(this); // 移除监听器
      await trayManager.destroy();
      _isInitialized = false;
    } catch (e) {
      // 如果销毁托盘失败，不抛出异常
      print('销毁托盘失败: $e');
    }
  }

  // 检查托盘是否已初始化
  bool get isInitialized => _isInitialized;

  // 连接OpenVPN
  void _connectOpenVPN() async {
    if (_appState == null) return;

    try {
      // 获取启用的OpenVPN配置
      final configs = await ConfigManager.loadConfigs();
      final openVPNConfigs = configs
          .where((config) => config.type == VPNType.openVPN && config.isActive)
          .toList();

      if (openVPNConfigs.isEmpty) {
        // 显示提示信息
        print('没有启用的OpenVPN配置');
        return;
      }

      // 连接第一个启用的OpenVPN配置
      final config = openVPNConfigs.first;
      final result = await _appState!.connectOpenVPN(config);

      if (result) {
        print('OpenVPN连接成功: ${config.name}');
      } else {
        print('OpenVPN连接失败: ${config.name}');
      }
    } catch (e) {
      print('连接OpenVPN时出错: $e');
    }
  }

  // 断开OpenVPN
  void _disconnectOpenVPN() async {
    if (_appState == null) return;

    try {
      await _appState!.disconnectOpenVPN();
      print('OpenVPN已断开连接');
    } catch (e) {
      print('断开OpenVPN时出错: $e');
    }
  }

  // 连接Clash
  void _connectClash() async {
    if (_appState == null) return;

    try {
      // 获取启用的Clash配置
      final configs = await ConfigManager.loadConfigs();
      final clashConfigs = configs
          .where((config) => config.type == VPNType.clash && config.isActive)
          .toList();

      if (clashConfigs.isEmpty) {
        // 显示提示信息
        print('没有启用的Clash配置');
        return;
      }

      // 连接第一个启用的Clash配置
      final config = clashConfigs.first;
      final result = await _appState!.connectClash(config);

      if (result) {
        print('Clash连接成功: ${config.name}');
      } else {
        print('Clash连接失败: ${config.name}');
      }
    } catch (e) {
      print('连接Clash时出错: $e');
    }
  }

  // 断开Clash
  void _disconnectClash() async {
    if (_appState == null) return;

    try {
      await _appState!.disconnectClash();
      print('Clash已断开连接');
    } catch (e) {
      print('断开Clash时出错: $e');
    }
  }

  // 连接Shadowsocks
  void _connectShadowsocks() async {
    if (_appState == null) return;

    try {
      // 获取启用的Shadowsocks配置
      final configs = await ConfigManager.loadConfigs();
      final shadowsocksConfigs = configs
          .where(
            (config) => config.type == VPNType.shadowsocks && config.isActive,
          )
          .toList();

      if (shadowsocksConfigs.isEmpty) {
        // 显示提示信息
        print('没有启用的Shadowsocks配置');
        return;
      }

      // 连接第一个启用的Shadowsocks配置
      final config = shadowsocksConfigs.first;
      final result = await _appState!.connectShadowsocks(config);

      if (result) {
        print('Shadowsocks连接成功: ${config.name}');
      } else {
        print('Shadowsocks连接失败: ${config.name}');
      }
    } catch (e) {
      print('连接Shadowsocks时出错: $e');
    }
  }

  // 断开Shadowsocks
  void _disconnectShadowsocks() async {
    if (_appState == null) return;

    try {
      await _appState!.disconnectShadowsocks();
      print('Shadowsocks已断开连接');
    } catch (e) {
      print('断开Shadowsocks时出错: $e');
    }
  }

  // 连接V2Ray
  void _connectV2Ray() async {
    if (_appState == null) return;

    try {
      // 获取启用的V2Ray配置
      final configs = await ConfigManager.loadConfigs();
      final v2rayConfigs = configs
          .where((config) => config.type == VPNType.v2ray && config.isActive)
          .toList();

      if (v2rayConfigs.isEmpty) {
        // 显示提示信息
        print('没有启用的V2Ray配置');
        return;
      }

      // 连接第一个启用的V2Ray配置
      final config = v2rayConfigs.first;
      final result = await _appState!.connectV2Ray(config);

      if (result) {
        print('V2Ray连接成功: ${config.name}');
      } else {
        print('V2Ray连接失败: ${config.name}');
      }
    } catch (e) {
      print('连接V2Ray时出错: $e');
    }
  }

  // 断开V2Ray
  void _disconnectV2Ray() async {
    if (_appState == null) return;

    try {
      await _appState!.disconnectV2Ray();
      print('V2Ray已断开连接');
    } catch (e) {
      print('断开V2Ray时出错: $e');
    }
  }

  // 连接HTTP代理
  void _connectHTTPProxy() async {
    if (_appState == null) return;

    try {
      // 获取启用的HTTP代理配置
      final configs = await ConfigManager.loadConfigs();
      final httpProxyConfigs = configs
          .where(
            (config) => config.type == VPNType.httpProxy && config.isActive,
          )
          .toList();

      if (httpProxyConfigs.isEmpty) {
        // 显示提示信息
        print('没有启用的HTTP代理配置');
        return;
      }

      // 连接第一个启用的HTTP代理配置
      final config = httpProxyConfigs.first;
      final result = await _appState!.connectHTTPProxy(config);

      if (result) {
        print('HTTP代理连接成功: ${config.name}');
      } else {
        print('HTTP代理连接失败: ${config.name}');
      }
    } catch (e) {
      print('连接HTTP代理时出错: $e');
    }
  }

  // 断开HTTP代理
  void _disconnectHTTPProxy() async {
    if (_appState == null) return;

    try {
      await _appState!.disconnectHTTPProxy();
      print('HTTP代理已断开连接');
    } catch (e) {
      print('断开HTTP代理时出错: $e');
    }
  }

  // 连接SOCKS5代理
  void _connectSOCKS5Proxy() async {
    if (_appState == null) return;

    try {
      // 获取启用的SOCKS5代理配置
      final configs = await ConfigManager.loadConfigs();
      final socks5ProxyConfigs = configs
          .where((config) => config.type == VPNType.socks5 && config.isActive)
          .toList();

      if (socks5ProxyConfigs.isEmpty) {
        // 显示提示信息
        print('没有启用的SOCKS5代理配置');
        return;
      }

      // 连接第一个启用的SOCKS5代理配置
      final config = socks5ProxyConfigs.first;
      final result = await _appState!.connectSOCKS5Proxy(config);

      if (result) {
        print('SOCKS5代理连接成功: ${config.name}');
      } else {
        print('SOCKS5代理连接失败: ${config.name}');
      }
    } catch (e) {
      print('连接SOCKS5代理时出错: $e');
    }
  }

  // 断开SOCKS5代理
  void _disconnectSOCKS5Proxy() async {
    if (_appState == null) return;

    try {
      await _appState!.disconnectSOCKS5Proxy();
      print('SOCKS5代理已断开连接');
    } catch (e) {
      print('断开SOCKS5代理时出错: $e');
    }
  }
}
