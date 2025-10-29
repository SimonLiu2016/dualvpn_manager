import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:dualvpn_manager/models/app_state.dart';

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
      await trayManager.setIcon('assets/icons/app_icon_32.png');

      // 创建托盘菜单
      Menu menu = Menu(
        items: [
          MenuItem(key: 'toggle_proxy', label: '启动/停止'),
          MenuItem(key: 'show_window', label: '显示主窗口'),
          MenuItem(key: 'separator1', label: ''),
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
      case 'toggle_proxy':
        // 启动/停止Go代理核心
        _toggleProxy();
        break;
      case 'show_window':
        // 显示主窗口
        _showWindow();
        break;
      case 'exit_app':
        // 退出应用前关闭Go代理核心服务并清除系统代理设置
        _exitApp();
        break;
    }
  }

  // 启动/停止Go代理核心
  void _toggleProxy() async {
    if (_appState != null) {
      try {
        if (_appState!.isGoProxyRunning) {
          // 停止Go代理核心
          await _appState!.stopGoProxy();
        } else {
          // 启动Go代理核心
          await _appState!.startGoProxy();
        }
      } catch (e) {
        print('切换代理核心状态失败: $e');
      }
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
}
