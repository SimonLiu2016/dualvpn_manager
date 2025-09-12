import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart' hide RoutingRule;
import 'package:dualvpn_manager/services/smart_routing_engine.dart'
    as smart_routing_engine;
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
                                        final rule =
                                            smart_routing_engine.RoutingRule(
                                              id: DateTime.now()
                                                  .millisecondsSinceEpoch
                                                  .toString(),
                                              pattern: _domainController.text,
                                              type: _getRuleType(
                                                _selectedConfig!.type,
                                              ),
                                              proxyId:
                                                  _selectedConfig!.id, // 保存配置ID
                                              isEnabled: true,
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
                        onPressed: () {
                          // 路由规则的启用/禁用应该只影响规则本身，而不应该启动或停止代理
                          // 代理的启动和停止应该由代理源的状态控制

                          // 切换所有路由规则的启用状态
                          if (appState.isRunning) {
                            // 如果当前是运行状态，则禁用所有路由规则
                            appState.disableAllRoutingRules();
                          } else {
                            // 如果当前是停止状态，则启用所有路由规则
                            appState.enableAllRoutingRules();
                          }

                          // 显示提示信息
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  appState.isRunning ? '路由规则已禁用' : '路由规则已启用',
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          appState.isRunning ? Icons.stop : Icons.play_arrow,
                        ),
                        label: Text(appState.isRunning ? '禁用路由' : '启用路由'),
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

  // 根据VPN类型获取规则类型
  smart_routing_engine.RuleType _getRuleType(VPNType type) {
    switch (type) {
      case VPNType.openVPN:
        return smart_routing_engine.RuleType.domain;
      case VPNType.clash:
        return smart_routing_engine.RuleType.domain;
      case VPNType.shadowsocks:
        return smart_routing_engine.RuleType.domain;
      case VPNType.v2ray:
        return smart_routing_engine.RuleType.domain;
      case VPNType.httpProxy:
        return smart_routing_engine.RuleType.domain;
      case VPNType.socks5:
        return smart_routing_engine.RuleType.domain;
      case VPNType.custom:
        return smart_routing_engine.RuleType.domain;
      default:
        return smart_routing_engine.RuleType.domain;
    }
  }

  // 构建路由规则列表
  Widget _buildRoutingRulesList(
    List<smart_routing_engine.RoutingRule> rules,
    AppState appState,
  ) {
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

              if (rule.proxyId.isNotEmpty) {
                final config = configs.firstWhere(
                  (c) => c.id == rule.proxyId,
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
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  leading: Icon(proxyIcon, color: proxyColor),
                  title: Text(rule.pattern),
                  subtitle: Text(proxyName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: rule.isEnabled,
                        onChanged: (value) {
                          // 创建更新后的规则
                          final updatedRule = smart_routing_engine.RoutingRule(
                            id: rule.id,
                            pattern: rule.pattern,
                            type: rule.type,
                            proxyId: rule.proxyId,
                            isEnabled: value,
                          );

                          // 更新AppState中的规则
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
  String _getRuleTypeName(smart_routing_engine.RuleType type) {
    switch (type) {
      case smart_routing_engine.RuleType.domain:
        return '域名匹配';
      case smart_routing_engine.RuleType.domainSuffix:
        return '域名后缀';
      case smart_routing_engine.RuleType.domainKeyword:
        return '域名关键字';
      case smart_routing_engine.RuleType.ip:
        return 'IP地址';
      case smart_routing_engine.RuleType.cidr:
        return 'CIDR';
      case smart_routing_engine.RuleType.regexp:
        return '正则表达式';
      case smart_routing_engine.RuleType.finalRule:
        return '最终规则';
      case smart_routing_engine.RuleType.geoip:
        return '地理位置';
    }
  }
}
