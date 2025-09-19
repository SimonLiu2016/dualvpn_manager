import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:dualvpn_manager/utils/logger.dart';
import 'dart:math' as dart_math;

class ProxyListScreen extends StatefulWidget {
  const ProxyListScreen({super.key});

  @override
  State<ProxyListScreen> createState() => _ProxyListScreenState();
}

class _ProxyListScreenState extends State<ProxyListScreen> {
  VPNConfig? _selectedConfig;

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
      });
      _loadProxies();
    }
  }

  // 加载代理列表
  void _loadProxies() {
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

    // 只有在当前配置没有缓存代理列表时才重新加载
    if (!appState.proxiesByConfig.containsKey(appState.selectedConfig) ||
        appState.proxiesByConfig[appState.selectedConfig]!.isEmpty) {
      Logger.info('当前配置没有缓存的代理列表，正在加载...');
      appState.loadProxies();
    } else {
      Logger.info('使用缓存的代理列表');
      // 确保AppState中的当前代理列表与缓存一致
      appState.setProxies(appState.proxiesByConfig[appState.selectedConfig]!);
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
            tooltip: '测试所有代理延迟',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _loadProxies,
            tooltip: '刷新代理列表',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '代理列表',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 配置选择器
            FutureBuilder<List<VPNConfig>>(
              future: ConfigManager.loadConfigs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (snapshot.hasError) {
                  return Text('加载配置失败: ${snapshot.error}');
                }

                // 显示所有配置的代理源，只保留Clash、Shadowsocks和V2Ray三种类型
                final allConfigs = snapshot.data ?? [];
                final configs = allConfigs
                    .where(
                      (config) =>
                          config.type == VPNType.clash ||
                          config.type == VPNType.shadowsocks ||
                          config.type == VPNType.v2ray,
                    )
                    .toList();

                // 处理_selectedConfig与configs的匹配问题
                if (configs.isEmpty) {
                  _selectedConfig = null;
                  return const Text('暂无支持代理列表的配置');
                } else if (_selectedConfig == null) {
                  _selectedConfig = configs.first;
                } else {
                  // 检查_selectedConfig是否在当前configs中存在（基于id匹配）
                  final matchingConfig = configs.firstWhere(
                    (config) => config.id == _selectedConfig!.id,
                    orElse: () => configs.first,
                  );
                  _selectedConfig = matchingConfig;
                }

                return Card(
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
                      items: configs.map((config) {
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
                );
              },
            ),
            const SizedBox(height: 16),
            Consumer<AppState>(
              builder: (context, appState, child) {
                Logger.info('=== ProxyListScreen Consumer 构建 ===');
                Logger.info('当前选中配置ID: ${appState.selectedConfig}');
                Logger.info('代理列表数量: ${appState.proxies.length}');

                // 打印当前代理列表的状态
                for (var i = 0; i < appState.proxies.length; i++) {
                  final proxy = appState.proxies[i];
                  Logger.info(
                    '代理 $i: ${proxy['name']}, isSelected=${proxy['isSelected']}',
                  );
                }

                Logger.info('=== ProxyListScreen Consumer 构建完成 ===');

                if (appState.isLoadingProxies) {
                  return const Center(child: CircularProgressIndicator());
                } else if (appState.proxies.isEmpty) {
                  // 检查当前选中的配置类型是否支持代理列表
                  final configs = ConfigManager.loadConfigsSync();
                  final currentConfig = configs.firstWhere(
                    (config) => config.id == appState.selectedConfig,
                    orElse: () => configs.isNotEmpty
                        ? configs.first
                        : VPNConfig(
                            id: '',
                            name: '',
                            type: VPNType.openVPN,
                            configPath: '',
                            settings: {},
                          ),
                  );

                  // 只有Clash、Shadowsocks和V2Ray三种类型支持代理列表
                  bool supportsProxyList =
                      currentConfig.type == VPNType.clash ||
                      currentConfig.type == VPNType.shadowsocks ||
                      currentConfig.type == VPNType.v2ray;

                  if (supportsProxyList) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.link_off,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '暂无代理信息',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '请确保已连接代理并配置了代理',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info, size: 48, color: Colors.blue),
                          const SizedBox(height: 10),
                          const Text(
                            '该代理类型不支持代理列表',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '此类型代理将直接使用配置进行连接',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                } else {
                  // 显示所有代理，不管是否启用
                  final allProxies = appState.proxies;

                  return Expanded(
                    child: ListView.builder(
                      itemCount: allProxies.length,
                      itemBuilder: (context, index) {
                        final proxy = allProxies[index];
                        final latency = proxy['latency'];
                        final isSelected = proxy['isSelected'];
                        final proxyName = proxy['name'];

                        Logger.info(
                          '构建代理项: $proxyName, isSelected=$isSelected',
                        );

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder:
                                    (
                                      Widget child,
                                      Animation<double> animation,
                                    ) {
                                      return ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      );
                                    },
                                child: Icon(
                                  latency == -2
                                      ? Icons.link
                                      : latency == -1
                                      ? Icons.hourglass_empty
                                      : Icons.link,
                                  key: ValueKey<int>(latency ?? 0),
                                  color: latency == -2
                                      ? Colors.grey
                                      : latency == -1
                                      ? Colors.orange
                                      : (latency < 0
                                            ? Colors.red
                                            : latency < 300
                                            ? Colors.green
                                            : latency < 1000
                                            ? Colors.deepOrange
                                            : Colors.red),
                                ),
                              ),
                              title: Text(
                                proxyName,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('类型: ${proxy['type']}'),
                                  if (latency == -2)
                                    const Text(
                                      '延迟: 未测试',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    )
                                  else if (latency == -1)
                                    const Text(
                                      '延迟: 测试中...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                    )
                                  else if (latency < 0)
                                    const Text(
                                      '延迟: 测试失败',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    )
                                  else
                                    Text(
                                      '延迟: ${latency}ms',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: latency < 300
                                            ? Colors.green
                                            : latency < 1000
                                            ? Colors.deepOrange
                                            : Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.speed),
                                    onPressed: () => _testLatency(proxyName),
                                    tooltip: '测试延迟',
                                  ),
                                  Switch(
                                    value: isSelected,
                                    onChanged: (value) async {
                                      final appState = Provider.of<AppState>(
                                        context,
                                        listen: false,
                                      );
                                      appState.setProxySelected(
                                        proxyName,
                                        value,
                                      );

                                      // 如果是Clash类型的配置，显示提示信息
                                      final configs =
                                          await ConfigManager.loadConfigs();
                                      final currentConfig = configs.firstWhere(
                                        (config) =>
                                            config.id ==
                                            appState.selectedConfig,
                                        orElse: () => configs.first,
                                      );

                                      // 如果是Clash类型的配置，确保代理能正确应用
                                      if (currentConfig.type == VPNType.clash) {
                                        // 确保代理能正确应用到已连接的Clash服务
                                        appState.ensureProxyAppliedForClash(
                                          currentConfig,
                                        );

                                        if (value && context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '已选择代理，正在应用到Clash...',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
