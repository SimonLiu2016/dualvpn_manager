import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:dualvpn_manager/ui/widgets/proxy_list_widget.dart';
import 'dart:math' as dart_math;

class ProxyListScreen extends StatefulWidget {
  const ProxyListScreen({super.key});

  @override
  State<ProxyListScreen> createState() => _ProxyListScreenState();
}

class _ProxyListScreenState extends State<ProxyListScreen> {
  VPNConfig? _selectedConfig;
  List<VPNConfig> _configs = [];

  @override
  void initState() {
    super.initState();
    // 延迟加载代理列表，确保AppState已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Logger.info('=== ProxyListScreen initState 开始延迟 ===');
      // 添加额外延迟确保AppState完全初始化
      await Future.delayed(const Duration(seconds: 2));
      Logger.info('=== ProxyListScreen initState 延迟结束 ===');
      _loadConfigs();
    });
  }

  // 加载配置列表
  void _loadConfigs() async {
    final configs = await ConfigManager.loadConfigs();
    if (configs.isNotEmpty) {
      setState(() {
        _selectedConfig = configs.first;
        _configs = configs;
      });
      _loadProxies();
    }
  }

  // 加载代理列表
  void _loadProxies() async {
    final appState = Provider.of<AppState>(context, listen: false);
    Logger.info('=== 开始加载代理列表 ===');
    Logger.info('当前选中配置ID: ${appState.selectedConfig}');
    Logger.info('代理缓存数量: ${appState.proxiesByConfig.length}');

    // 打印代理缓存的详细信息
    appState.proxiesByConfig.forEach((configId, proxies) {
      Logger.info('配置 $configId 有 ${proxies.length} 个代理');
      for (var i = 0; i < proxies.length; i++) {
        final proxy = proxies[i];
        Logger.info(
          '  代理 $i: name=${proxy['name']}, latency=${proxy['latency']}, isSelected=${proxy['isSelected']}',
        );
      }
    });

    // 对于所有类型，只有在当前配置没有缓存代理列表时才重新加载
    // 移除OpenVPN类型的特殊处理，使其与其他类型保持一致
    final configs = await ConfigManager.loadConfigs();
    VPNConfig? currentConfig;
    try {
      currentConfig = configs.firstWhere(
        (config) => config.id == appState.selectedConfig,
      );
    } catch (e) {
      Logger.warn('未找到当前选中的配置: ${appState.selectedConfig}');
      if (configs.isNotEmpty) {
        currentConfig = configs.first;
      }
    }

    bool shouldReload = false;
    if (currentConfig != null) {
      // 对于所有类型，只有在没有缓存或缓存为空时才重新加载
      if (!appState.proxiesByConfig.containsKey(appState.selectedConfig) ||
          appState.proxiesByConfig[appState.selectedConfig]!.isEmpty) {
        Logger.info('当前配置没有缓存的代理列表，正在加载...');
        shouldReload = true;
      } else {
        Logger.info('使用缓存的代理列表');
        // 确保AppState中的当前代理列表与缓存一致
        appState.setProxies(appState.proxiesByConfig[appState.selectedConfig]!);
      }
    } else {
      Logger.info('没有找到当前配置，尝试重新加载');
      shouldReload = true;
    }

    if (shouldReload) {
      appState.loadProxies();
    }

    Logger.info('=== 代理列表加载请求已发送 ===');
  }

  // 测试单个代理延迟
  void _testLatency(String proxyName) async {
    final appState = Provider.of<AppState>(context, listen: false);

    // 显示测试中状态
    appState.updateProxyLatency(proxyName, -1); // -1表示测试中

    // 模拟网络延迟测试
    await Future.delayed(const Duration(seconds: 1));

    // 生成随机延迟值(10-1500ms)以测试颜色显示
    final random = dart_math.Random();
    final latency = 10 + random.nextInt(1491); // 10 to 1500

    // 更新延迟值
    appState.updateProxyLatency(proxyName, latency);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$proxyName 延迟: ${latency}ms')));
    }
  }

  // 刷新所有代理延迟
  void _refreshAllLatencies() async {
    final appState = Provider.of<AppState>(context, listen: false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在测试所有代理延迟...')));
    }

    // 更新所有代理为测试中状态
    for (var proxy in appState.proxies) {
      appState.updateProxyLatency(proxy['name'], -1); // -1表示测试中
    }

    // 模拟批量测试
    await Future.delayed(const Duration(seconds: 2));

    // 更新所有延迟值
    final random = dart_math.Random();
    for (var proxy in appState.proxies) {
      final latency = 20 + random.nextInt(1481); // 20 to 1500
      appState.updateProxyLatency(proxy['name'], latency);
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('所有代理延迟测试完成')));
    }
  }

  // 切换配置
  void _switchConfig(VPNConfig config) async {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setSelectedConfig(config.id);
    setState(() {
      _selectedConfig = config;
    });
    // 等待状态更新完成后再加载代理列表
    await Future.delayed(const Duration(milliseconds: 100));
    _loadProxies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('代理列表'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllLatencies,
            tooltip: '刷新所有延迟',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButtonFormField<VPNConfig>(
                  value: _selectedConfig,
                  decoration: const InputDecoration(
                    labelText: '选择代理源',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.source),
                  ),
                  items: _configs.map((config) {
                    return DropdownMenuItem<VPNConfig>(
                      value: config,
                      child: Text('${config.name} (${config.type})'),
                    );
                  }).toList(),
                  onChanged: (config) {
                    if (config != null) {
                      _switchConfig(config);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            ProxyListWidget(
              onTestLatency: _testLatency,
              onProxySelected: (proxyName, isSelected) async {
                final appState = Provider.of<AppState>(context, listen: false);
                // 当用户点击Switch时，我们应该设置代理的选中状态
                // Switch的value参数就是用户想要设置的状态
                appState.setProxySelected(proxyName, isSelected);
              },
            ),
          ],
        ),
      ),
    );
  }
}
