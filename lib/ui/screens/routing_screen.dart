import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart' hide RoutingRule;
import 'package:dualvpn_manager/services/smart_routing_engine.dart'
    as smart_routing_engine;
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:dualvpn_manager/ui/widgets/routing_rules_widget.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('智能路由配置', style: Theme.of(context).textTheme.headlineSmall),
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
                                  decoration: const InputDecoration(),
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
                                    context.read<AppState>().addRoutingRule(
                                      rule,
                                    );

                                    // 清空输入
                                    _domainController.clear();
                                    setState(() {
                                      _selectedConfig = null;
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('路由规则已添加')),
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
                      Text(
                        '已配置的路由规则',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const RoutingRulesWidget(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // 根据VPN类型获取规则类型
  smart_routing_engine.RuleType _getRuleType(VPNType type) {
    switch (type) {
      case VPNType.openVPN:
        return smart_routing_engine.RuleType.domainSuffix;
      case VPNType.clash:
        return smart_routing_engine.RuleType.domainSuffix;
      case VPNType.shadowsocks:
        return smart_routing_engine.RuleType.domainSuffix;
      case VPNType.v2ray:
        return smart_routing_engine.RuleType.domainSuffix;
      case VPNType.httpProxy:
        return smart_routing_engine.RuleType.domainSuffix;
      case VPNType.socks5:
        return smart_routing_engine.RuleType.domainSuffix;
      case VPNType.custom:
        return smart_routing_engine.RuleType.domainSuffix;
    }
  }
}
