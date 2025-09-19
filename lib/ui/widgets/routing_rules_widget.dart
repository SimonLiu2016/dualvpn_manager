import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart' hide RoutingRule;
import 'package:dualvpn_manager/services/smart_routing_engine.dart'
    as smart_routing_engine;
import 'package:dualvpn_manager/utils/config_manager.dart';

/// 路由规则列表小部件
/// 这个小部件只监听与路由规则相关的状态变化
class RoutingRulesWidget extends StatelessWidget {
  const RoutingRulesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, List<smart_routing_engine.RoutingRule>>(
      selector: (context, appState) => appState.routingRules,
      builder: (context, routingRules, child) {
        return _RoutingRulesList(rules: routingRules);
      },
    );
  }
}

/// 路由规则列表实现
class _RoutingRulesList extends StatelessWidget {
  final List<smart_routing_engine.RoutingRule> rules;

  const _RoutingRulesList({required this.rules});

  @override
  Widget build(BuildContext context) {
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
          final appState = context.watch<AppState>();

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
}
