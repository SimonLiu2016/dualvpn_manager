import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/ui/screens/config_screen.dart';
import 'package:dualvpn_manager/ui/screens/proxy_list_screen.dart';
import 'package:dualvpn_manager/ui/screens/routing_screen.dart';
import 'package:dualvpn_manager/ui/widgets/go_proxy_stats_widget.dart';
import 'package:dualvpn_manager/ui/widgets/selected_proxies_widget.dart';
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  int _currentIndex = 0;
  static const MethodChannel _macosChannel = MethodChannel(
    'dualvpn_manager/macos',
  );

  @override
  void initState() {
    super.initState();
    // 确保窗口管理器已初始化
    _initWindowManager();
  }

  Future<void> _initWindowManager() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      // 确保窗口管理器已初始化
      await windowManager.ensureInitialized();

      // 设置窗口关闭时的行为 - 防止窗口真正关闭
      await windowManager.setPreventClose(true);

      // 设置窗口标题
      await windowManager.setTitle('双捷VPN管理器');

      // 添加窗口监听器（在初始化完成后添加）
      windowManager.addListener(this);
    } catch (e) {
      print('窗口管理器初始化失败: $e');
    }
  }

  @override
  void dispose() {
    // 移除窗口监听器
    try {
      windowManager.removeListener(this);
    } catch (e) {
      print('移除窗口监听器失败: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        print('WillPopScope触发');
        try {
          // 隐藏窗口而不是关闭应用
          windowManager.hide();
          print('窗口已隐藏');

          // 在macOS上隐藏程序坞图标
          _hideDockIconIfNeeded();

          // 显示提示信息
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('应用已最小化到系统托盘，点击托盘图标可重新打开'),
                duration: Duration(seconds: 2),
              ),
            );
            print('提示信息已显示');
          }

          // 返回false表示不执行默认的返回操作（即不关闭应用）
          return false;
        } catch (e) {
          print('处理WillPopScope时出错: $e');
          // 即使出错也尝试隐藏窗口
          try {
            windowManager.hide();
          } catch (hideError) {
            print('隐藏窗口失败: $hideError');
          }
          // 返回false表示不执行默认的返回操作（即不关闭应用）
          return false;
        }
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 20),
          child: CustomTitleBar(),
        ),
        body: _buildPage(_currentIndex),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: '主页'),
            BottomNavigationBarItem(icon: Icon(Icons.list), label: '代理源'),
            BottomNavigationBarItem(icon: Icon(Icons.link), label: '代理列表'),
            BottomNavigationBarItem(icon: Icon(Icons.route), label: '路由'),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const HomeContent();
      case 1:
        return const ConfigScreen(); // 使用完整的配置管理界面
      case 2:
        return const ProxyListScreen(); // 添加代理列表屏幕
      case 3:
        return const RoutingScreen(); // 使用完整的路由配置界面
      default:
        return const HomeContent();
    }
  }

  // 窗口关闭事件处理
  @override
  void onWindowClose() {
    print('窗口关闭事件触发');
    try {
      // 在macOS上隐藏程序坞图标
      _hideDockIconIfNeeded();

      // 稍微延迟隐藏窗口，确保程序坞图标隐藏完成
      Future.delayed(const Duration(milliseconds: 150), () {
        // 隐藏窗口而不是关闭应用
        windowManager.hide();
      });

      // 显示提示信息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('应用已最小化到系统托盘，点击托盘图标可重新打开'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 即使出错也尝试隐藏窗口
      try {
        windowManager.hide();
      } catch (hideError) {
        print('隐藏窗口失败: $hideError');
      }
    }
  }

  // 窗口显示事件处理
  @override
  void onWindowShow() {
    // 在macOS上显示程序坞图标
    _showDockIconIfNeeded();

    // 确保窗口获得焦点
    windowManager.focus();
  }

  // 在macOS上隐藏程序坞图标
  void _hideDockIconIfNeeded() {
    if (Platform.isMacOS) {
      try {
        print('调用隐藏程序坞图标方法');
        _macosChannel
            .invokeMethod('hideDockIcon')
            .then((result) {
              print('隐藏程序坞图标方法调用成功: $result');
            })
            .catchError((error) {
              print('调用隐藏程序坞图标方法失败: $error');
            });
      } catch (e) {
        developer.log('调用隐藏程序坞图标方法失败: $e');
      }
    }
  }

  // 在macOS上显示程序坞图标
  void _showDockIconIfNeeded() {
    if (Platform.isMacOS) {
      try {
        print('调用显示程序坞图标方法');
        _macosChannel
            .invokeMethod('showDockIcon')
            .then((result) {
              print('显示程序坞图标方法调用成功: $result');
            })
            .catchError((error) {
              print('调用显示程序坞图标方法失败: $error');
            });
      } catch (e) {
        developer.log('调用显示程序坞图标方法失败: $e');
      }
    }
  }
}

// 自定义标题栏
class CustomTitleBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  final Size preferredSize;

  CustomTitleBar({Key? key})
    : preferredSize = const Size.fromHeight(kToolbarHeight + 20),
      super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: Colors.blue,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: const Center(
        child: Text(
          '双捷VPN管理器',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// 主页内容
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const VPNStatusPanel();
  }
}

// 简化的关于内容
class AboutContent extends StatelessWidget {
  const AboutContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // 添加滚动视图
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Column(
                children: [
                  // 添加动画效果的图标
                  AnimatedVPNIcon(),
                  SizedBox(height: 10),
                  Text(
                    '双捷VPN管理器',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'DualVPN Manager',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              '应用信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildInfoRow('版本', '0.1.0'),
            _buildInfoRow('开发者', 'DualVPN Team'),
            _buildInfoRow('许可证', 'MIT'),
            const SizedBox(height: 20),
            const Text(
              '功能说明',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '双捷VPN管理器是一个轻量级的VPN管理工具，可以同时管理OpenVPN和Clash两种VPN连接，实现内外网同时访问的功能。\n\n'
              '主要功能包括：\n'
              '• 双VPN同时连接：支持同时连接OpenVPN（公司内网）和Clash（外部网络）\n'
              '• 智能路由：自动区分内外网流量，确保正确路由\n'
              '• 统一管理界面：集中管理两种VPN的配置和连接状态\n'
              '• 跨平台支持：支持Windows、macOS和Linux系统\n'
              '• 轻量级设计：无需安装Tunnelblick和ClashX，一个工具搞定所有',
            ),
            const SizedBox(height: 20),
            const Text(
              '使用说明',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '1. 在"配置"页面添加OpenVPN配置文件路径或Clash订阅链接\n'
              '2. 在"主页"切换两种VPN的连接状态\n'
              '3. 在"路由"页面配置内外网域名并启用智能路由\n'
              '4. 享受同时访问内外网的便利',
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(': $value'),
        ],
      ),
    );
  }
}

// 带动画效果的VPN图标
class AnimatedVPNIcon extends StatefulWidget {
  const AnimatedVPNIcon({Key? key}) : super(key: key);

  @override
  State<AnimatedVPNIcon> createState() => _AnimatedVPNIconState();
}

class _AnimatedVPNIconState extends State<AnimatedVPNIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value * 2 * 3.14159,
          child: const Icon(Icons.vpn_lock, size: 64, color: Colors.blue),
        );
      },
    );
  }
}

// VPN状态面板
class VPNStatusPanel extends StatelessWidget {
  const VPNStatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '连接状态',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // 使用说明
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '使用说明：',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '1. 在"代理源"页面添加并启用代理配置',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '2. 在"代理列表"页面选择具体的代理服务器',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '3. 在本页面查看已启用的代理源和选中的代理',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 显示已启用的代理源（仅作展示，不可交互）
              // 代理源的启用/禁用应在"代理源"页面中操作
              const Text(
                '已启用代理源',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<VPNConfig>>(
                future: ConfigManager.loadConfigs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text('加载配置失败: ${snapshot.error}');
                  }

                  // 只显示启用的配置
                  final configs = (snapshot.data ?? [])
                      .where((config) => config.isActive)
                      .toList();

                  // 按类型分组
                  final openVPNConfigs = configs
                      .where((config) => config.type == VPNType.openVPN)
                      .toList();
                  final clashConfigs = configs
                      .where((config) => config.type == VPNType.clash)
                      .toList();
                  final shadowsocksConfigs = configs
                      .where((config) => config.type == VPNType.shadowsocks)
                      .toList();
                  final v2rayConfigs = configs
                      .where((config) => config.type == VPNType.v2ray)
                      .toList();
                  final httpProxyConfigs = configs
                      .where((config) => config.type == VPNType.httpProxy)
                      .toList();
                  final socks5ProxyConfigs = configs
                      .where((config) => config.type == VPNType.socks5)
                      .toList();

                  // 如果没有启用的配置，显示提示信息
                  if (configs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      child: const Text(
                        '暂无启用的代理源',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // OpenVPN代理源
                      if (openVPNConfigs.isNotEmpty) ...[
                        const Text('OpenVPN:', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: openVPNConfigs.map((config) {
                            return Selector<AppState, String>(
                              selector: (context, appState) =>
                                  appState.selectedConfig,
                              builder: (context, selectedConfig, child) {
                                final isSelected = selectedConfig == config.id;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.withOpacity(0.3)
                                        : Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.blue.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.blue,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    child: Text(config.name),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      if (openVPNConfigs.isNotEmpty) const SizedBox(height: 8),

                      // Clash代理源
                      if (clashConfigs.isNotEmpty) ...[
                        const Text('Clash:', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: clashConfigs.map((config) {
                            return Selector<AppState, String>(
                              selector: (context, appState) =>
                                  appState.selectedConfig,
                              builder: (context, selectedConfig, child) {
                                final isSelected = selectedConfig == config.id;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.green
                                          : Colors.green.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.green
                                          : Colors.green,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    child: Text(config.name),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      if (clashConfigs.isNotEmpty) const SizedBox(height: 8),

                      // Shadowsocks代理源
                      if (shadowsocksConfigs.isNotEmpty) ...[
                        const Text(
                          'Shadowsocks:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: shadowsocksConfigs.map((config) {
                            return Selector<AppState, String>(
                              selector: (context, appState) =>
                                  appState.selectedConfig,
                              builder: (context, selectedConfig, child) {
                                final isSelected = selectedConfig == config.id;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.purple.withOpacity(0.3)
                                        : Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.purple
                                          : Colors.purple.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.purple
                                          : Colors.purple,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    child: Text(config.name),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      if (shadowsocksConfigs.isNotEmpty)
                        const SizedBox(height: 8),

                      // V2Ray代理源
                      if (v2rayConfigs.isNotEmpty) ...[
                        const Text('V2Ray:', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: v2rayConfigs.map((config) {
                            return Selector<AppState, String>(
                              selector: (context, appState) =>
                                  appState.selectedConfig,
                              builder: (context, selectedConfig, child) {
                                final isSelected = selectedConfig == config.id;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.orange.withOpacity(0.3)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.orange
                                          : Colors.orange.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.orange
                                          : Colors.orange,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    child: Text(config.name),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      if (v2rayConfigs.isNotEmpty) const SizedBox(height: 8),

                      // HTTP代理源
                      if (httpProxyConfigs.isNotEmpty) ...[
                        const Text('HTTP代理:', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: httpProxyConfigs.map((config) {
                            return Selector<AppState, String>(
                              selector: (context, appState) =>
                                  appState.selectedConfig,
                              builder: (context, selectedConfig, child) {
                                final isSelected = selectedConfig == config.id;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.red.withOpacity(0.3)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.red
                                          : Colors.red.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.red
                                          : Colors.red,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    child: Text(config.name),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      if (httpProxyConfigs.isNotEmpty)
                        const SizedBox(height: 8),

                      // SOCKS5代理源
                      if (socks5ProxyConfigs.isNotEmpty) ...[
                        const Text('SOCKS5代理:', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: socks5ProxyConfigs.map((config) {
                            return Selector<AppState, String>(
                              selector: (context, appState) =>
                                  appState.selectedConfig,
                              builder: (context, selectedConfig, child) {
                                final isSelected = selectedConfig == config.id;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.teal.withOpacity(0.3)
                                        : Colors.teal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.teal
                                          : Colors.teal.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.teal
                                          : Colors.teal,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    child: Text(config.name),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // 显示启用的代理源对应的代理列表中被选中的代理
              const Text(
                '已选中代理',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const SelectedProxiesWidget(),
              const SizedBox(height: 16),
              // Go代理核心控制
              const Text(
                'Go代理核心',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Selector<AppState, bool>(
                selector: (context, appState) => appState.isGoProxyRunning,
                builder: (context, isGoProxyRunning, child) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isGoProxyRunning
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isGoProxyRunning ? Colors.green : Colors.grey,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isGoProxyRunning ? Icons.check_circle : Icons.cancel,
                          color: isGoProxyRunning ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Text('Go代理核心'),
                        const Spacer(),
                        // 显示实时上传下载速率
                        const GoProxyStatsWidget(),
                        Selector<AppState, bool>(
                          selector: (context, appState) =>
                              appState.isGoProxyRunning,
                          builder: (context, isRunning, child) {
                            return ElevatedButton(
                              onPressed: isRunning
                                  ? () async {
                                      final appState = context.read<AppState>();
                                      await appState.stopGoProxy();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Go代理核心已停止'),
                                          ),
                                        );
                                      }
                                    }
                                  : () async {
                                      final appState = context.read<AppState>();
                                      final success = await appState
                                          .startGoProxy();
                                      if (context.mounted) {
                                        if (success) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Go代理核心启动成功'),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Go代理核心启动失败'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRunning
                                    ? Colors.red
                                    : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(isRunning ? '停止' : '启动'),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 带动画效果的选择芯片
class AnimatedChoiceChip extends StatefulWidget {
  final Widget label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const AnimatedChoiceChip({
    Key? key,
    required this.label,
    required this.selected,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<AnimatedChoiceChip> createState() => _AnimatedChoiceChipState();
}

class _AnimatedChoiceChipState extends State<AnimatedChoiceChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _colorAnimation = ColorTween(
      begin: Colors.grey.withOpacity(0.2),
      end: Colors.blue.withOpacity(0.3),
    ).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedChoiceChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected ? Colors.blue : Colors.grey,
              width: 2,
            ),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: widget.selected ? Colors.blue : Colors.grey[600],
              fontWeight: widget.selected ? FontWeight.bold : FontWeight.normal,
            ),
            child: widget.label,
          ),
        ),
      ),
    );
  }
}
