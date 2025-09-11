import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/utils/config_manager.dart';

class RoutingScreen extends StatefulWidget {
  const RoutingScreen({super.key});

  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> {
  final TextEditingController _domainController = TextEditingController();
  VPNConfig? _selectedConfig;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('路由配置'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '智能路由配置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('为特定域名指定代理源'),
                  const SizedBox(height: 8),
                  FutureBuilder<List<VPNConfig>>(
                    future: ConfigManager.loadConfigs(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      if (snapshot.hasError) {
                        return Text('加载配置失败: ${snapshot.error}');
                      }

                      final configs = snapshot.data ?? [];

                      // 确保_selectedConfig在当前配置列表中
                      if (_selectedConfig != null && configs.isNotEmpty) {
                        final matchingConfig = configs.firstWhere(
                          (config) => config.id == _selectedConfig!.id,
                          orElse: () => configs.first,
                        );
                        _selectedConfig = matchingConfig;
                      } else if (configs.isNotEmpty) {
                        _selectedConfig = configs.first;
                      } else {
                        _selectedConfig = null;
                      }

                      return Column(
                        children: [
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _domainController,
                                      decoration: const InputDecoration(
                                        hintText: '输入域名，如: google.com',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.domain),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<VPNConfig>(
                                      value: _selectedConfig,
                                      hint: const Text('选择代理源'),
                                      items: configs.map((config) {
                                        return DropdownMenuItem<VPNConfig>(
                                          value: config,
                                          child: Text(config.name),
                                        );
                                      }).toList(),
                                      onChanged: (config) {
                                        setState(() {
                                          _selectedConfig = config;
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (_domainController.text.isNotEmpty &&
                                          _selectedConfig != null) {
                                        // 创建路由规则，包含配置ID
                                        final rule = RoutingRule(
                                          pattern: _domainController.text,
                                          routeType: _getRouteType(
                                            _selectedConfig!.type,
                                          ),
                                          isEnabled: true,
                                          configId:
                                              _selectedConfig!.id, // 保存配置ID
                                        );

                                        // 添加到AppState
                                        appState.addRoutingRule(rule);

                                        // 清空输入
                                        _domainController.clear();
                                        setState(() {
                                          _selectedConfig = null;
                                        });

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('路由规则已添加'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('添加'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '已配置的路由规则',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRoutingRulesList(
                            appState.routingRules,
                            appState,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: ElevatedButton.icon(
                        onPressed: appState.isRunning
                            ? () {
                                // 禁用所有路由规则
                                appState.disableAllRoutingRules();

                                // 禁用路由
                                appState.disableRouting();
                              }
                            : () {
                                // 启用所有路由规则
                                appState.enableAllRoutingRules();

                                // 配置并启用路由
                                appState.configureRouting().then((success) {
                                  if (success) {
                                    appState.enableRouting();
                                  } else {
                                    // 显示错误提示
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(content: Text('路由配置失败')),
                                      );
                                    }
                                  }
                                });
                              },
                        icon: Icon(
                          appState.isRunning ? Icons.stop : Icons.play_arrow,
                        ),
                        label: Text(appState.isRunning ? '全部停止' : '全部应用'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appState.isRunning
                              ? Colors.red
                              : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 根据VPN类型获取路由类型
  RouteType _getRouteType(VPNType type) {
    switch (type) {
      case VPNType.openVPN:
        return RouteType.openVPN;
      case VPNType.clash:
        return RouteType.clash;
      case VPNType.shadowsocks:
        return RouteType.shadowsocks;
      case VPNType.v2ray:
        return RouteType.v2ray;
      case VPNType.httpProxy:
        return RouteType.httpProxy;
      case VPNType.socks5:
        return RouteType.socks5;
      case VPNType.custom:
        return RouteType.custom;
    }
  }

  // 构建路由规则列表
  Widget _buildRoutingRulesList(List<RoutingRule> rules, AppState appState) {
    if (rules.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rule, size: 48, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                '暂无路由规则',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                '请添加域名和对应的代理源',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<List<VPNConfig>>(
        future: ConfigManager.loadConfigs(),
        builder: (context, snapshot) {
          final configs = snapshot.data ?? [];

          return ListView.builder(
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              // 获取代理源名称
              String proxyName = '未找到配置';
              Color proxyColor = Colors.grey;
              IconData proxyIcon = Icons.help;

              if (rule.configId != null) {
                final config = configs.firstWhere(
                  (c) => c.id == rule.configId,
                  orElse: () => VPNConfig(
                    id: '',
                    name: '未找到配置',
                    type: VPNType.openVPN,
                    configPath: '',
                    settings: {},
                  ),
                );
                proxyName = config.name;
                proxyColor = _getProxyColor(config.type);
                proxyIcon = _getProxyIcon(config.type);
              } else {
                // 回退到根据路由类型查找
                for (var config in configs) {
                  switch (rule.routeType) {
                    case RouteType.openVPN:
                      if (config.type == VPNType.openVPN) {
                        proxyName = config.name;
                        proxyColor = _getProxyColor(config.type);
                        proxyIcon = _getProxyIcon(config.type);
                      }
                      break;
                    case RouteType.clash:
                      if (config.type == VPNType.clash) {
                        proxyName = config.name;
                        proxyColor = _getProxyColor(config.type);
                        proxyIcon = _getProxyIcon(config.type);
                      }
                      break;
                    case RouteType.shadowsocks:
                      if (config.type == VPNType.shadowsocks) {
                        proxyName = config.name;
                        proxyColor = _getProxyColor(config.type);
                        proxyIcon = _getProxyIcon(config.type);
                      }
                      break;
                    case RouteType.v2ray:
                      if (config.type == VPNType.v2ray) {
                        proxyName = config.name;
                        proxyColor = _getProxyColor(config.type);
                        proxyIcon = _getProxyIcon(config.type);
                      }
                      break;
                    case RouteType.httpProxy:
                      if (config.type == VPNType.httpProxy) {
                        proxyName = config.name;
                        proxyColor = _getProxyColor(config.type);
                        proxyIcon = _getProxyIcon(config.type);
                      }
                      break;
                    case RouteType.socks5:
                      if (config.type == VPNType.socks5) {
                        proxyName = config.name;
                        proxyColor = _getProxyColor(config.type);
                        proxyIcon = _getProxyIcon(config.type);
                      }
                      break;
                    case RouteType.custom:
                      if (config.type == VPNType.custom) {
                        proxyName = config.name;
                        proxyColor = _getProxyColor(config.type);
                        proxyIcon = _getProxyIcon(config.type);
                      }
                      break;
                  }
                }
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  title: Text(
                    rule.pattern,
                    style: TextStyle(
                      fontWeight: rule.isEnabled
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(proxyIcon, size: 16, color: proxyColor),
                      const SizedBox(width: 4),
                      Text('${_getRouteTypeName(rule.routeType)} - $proxyName'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 添加状态指示器
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: rule.isEnabled ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 修改开关行为：只控制当前路由规则的启用状态，不影响全局路由
                      Switch(
                        value: rule.isEnabled,
                        onChanged: (value) {
                          // 更新规则状态
                          final updatedRule = RoutingRule(
                            pattern: rule.pattern,
                            routeType: rule.routeType,
                            isEnabled: value,
                            configId: rule.configId, // 保留配置ID
                          );
                          appState.removeRoutingRule(rule);
                          appState.addRoutingRule(updatedRule);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          appState.removeRoutingRule(rule);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 获取代理类型颜色
  Color _getProxyColor(VPNType type) {
    switch (type) {
      case VPNType.openVPN:
        return Colors.blue;
      case VPNType.clash:
        return Colors.green;
      case VPNType.shadowsocks:
        return Colors.purple;
      case VPNType.v2ray:
        return Colors.orange;
      case VPNType.httpProxy:
        return Colors.red;
      case VPNType.socks5:
        return Colors.teal;
      case VPNType.custom:
        return Colors.grey;
    }
  }

  // 获取代理类型图标
  IconData _getProxyIcon(VPNType type) {
    switch (type) {
      case VPNType.openVPN:
        return Icons.vpn_lock;
      case VPNType.clash:
        return Icons.shield;
      case VPNType.shadowsocks:
        return Icons.link;
      case VPNType.v2ray:
        return Icons.link;
      case VPNType.httpProxy:
        return Icons.http;
      case VPNType.socks5:
        return Icons.http;
      case VPNType.custom:
        return Icons.settings;
    }
  }

  // 获取路由类型名称
  String _getRouteTypeName(RouteType type) {
    switch (type) {
      case RouteType.openVPN:
        return 'OpenVPN';
      case RouteType.clash:
        return 'Clash';
      case RouteType.shadowsocks:
        return 'Shadowsocks';
      case RouteType.v2ray:
        return 'V2Ray';
      case RouteType.httpProxy:
        return 'HTTP代理';
      case RouteType.socks5:
        return 'SOCKS5代理';
      case RouteType.custom:
        return '自定义代理';
    }
  }
}
