import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/services/smart_routing_engine.dart'
    as smart_routing_engine;
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:dualvpn_manager/l10n/app_localizations_delegate.dart';

// 添加扩展方法以支持firstWhereOrNull
extension ListExtensions<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class RoutingRulesScreen extends StatefulWidget {
  const RoutingRulesScreen({super.key});

  @override
  State<RoutingRulesScreen> createState() => _RoutingRulesScreenState();
}

class _RoutingRulesScreenState extends State<RoutingRulesScreen> {
  List<VPNConfig> configs = [];
  String? _selectedConfigId;
  final TextEditingController _patternController = TextEditingController();
  RouteType _selectedRouteType = RouteType.openVPN;
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  void _loadConfigs() async {
    final loadedConfigs = await ConfigManager.loadConfigs();
    setState(() {
      configs = loadedConfigs;
      if (loadedConfigs.isNotEmpty) {
        _selectedConfigId = loadedConfigs.first.id;
      }
    });
  }

  void _addRoutingRule() async {
    final localizations = AppLocalizations.of(context);

    if (_patternController.text.isEmpty || _selectedConfigId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.get('please_fill_complete_info'))),
      );
      return;
    }

    // 找到选中的配置
    final configIndex = configs.indexWhere((c) => c.id == _selectedConfigId);
    if (configIndex == -1) return;

    final config = configs[configIndex];

    // 创建新的路由规则，包含配置ID
    final newRule = RoutingRule(
      pattern: _patternController.text,
      routeType: _selectedRouteType,
      isEnabled: _isEnabled,
      configId: _selectedConfigId, // 保存配置ID
    );

    // 更新配置
    final updatedRules = List<RoutingRule>.from(config.routingRules);
    updatedRules.add(newRule);

    final updatedConfig = VPNConfig(
      id: config.id,
      name: config.name,
      type: config.type,
      configPath: config.configPath,
      settings: config.settings,
      isActive: config.isActive,
      routingRules: updatedRules,
    );

    // 保存更新后的配置
    await ConfigManager.updateConfig(updatedConfig);

    // 重新加载配置
    _loadConfigs();

    // 清空输入框
    _patternController.clear();

    // 同时更新AppState中的全局路由规则
    final appState = Provider.of<AppState>(context, listen: false);
    final smartRule = smart_routing_engine.RoutingRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pattern: newRule.pattern,
      type: _convertRouteTypeToRuleType(newRule.routeType),
      proxyId: newRule.configId ?? '',
      isEnabled: newRule.isEnabled,
    );
    appState.addRoutingRule(smartRule);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.get('routing_rule_added'))),
      );
    }
  }

  void _deleteRoutingRule(VPNConfig config, int ruleIndex) async {
    final localizations = AppLocalizations.of(context);

    final updatedRules = List<RoutingRule>.from(config.routingRules);
    final removedRule = updatedRules.removeAt(ruleIndex);

    final updatedConfig = VPNConfig(
      id: config.id,
      name: config.name,
      type: config.type,
      configPath: config.configPath,
      settings: config.settings,
      isActive: config.isActive,
      routingRules: updatedRules,
    );

    await ConfigManager.updateConfig(updatedConfig);

    // 同时从AppState中的全局路由规则中删除
    final appState = Provider.of<AppState>(context, listen: false);
    // 查找并删除对应的全局路由规则
    final smartRules = appState.routingRules;
    for (var i = 0; i < smartRules.length; i++) {
      final rule = smartRules[i];
      if (rule.pattern == removedRule.pattern &&
          rule.proxyId == (removedRule.configId ?? '')) {
        appState.removeRoutingRule(rule);
        break;
      }
    }

    _loadConfigs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.get('routing_rule_deleted'))),
      );
    }
  }

  void _toggleRule(VPNConfig config, int ruleIndex) async {
    final updatedRules = List<RoutingRule>.from(config.routingRules);
    final rule = updatedRules[ruleIndex];

    updatedRules[ruleIndex] = RoutingRule(
      pattern: rule.pattern,
      routeType: rule.routeType,
      isEnabled: !rule.isEnabled,
      configId: rule.configId, // 保留配置ID
    );

    final updatedConfig = VPNConfig(
      id: config.id,
      name: config.name,
      type: config.type,
      configPath: config.configPath,
      settings: config.settings,
      isActive: config.isActive,
      routingRules: updatedRules,
    );

    await ConfigManager.updateConfig(updatedConfig);

    // 同时更新AppState中的全局路由规则
    final appState = Provider.of<AppState>(context, listen: false);
    // 查找并更新对应的全局路由规则
    final smartRules = appState.routingRules;
    for (var i = 0; i < smartRules.length; i++) {
      final smartRule = smartRules[i];
      if (smartRule.pattern == rule.pattern &&
          smartRule.proxyId == (rule.configId ?? '')) {
        final updatedSmartRule = smart_routing_engine.RoutingRule(
          id: smartRule.id,
          pattern: smartRule.pattern,
          type: smartRule.type,
          proxyId: smartRule.proxyId,
          isEnabled: !rule.isEnabled,
        );
        appState.removeRoutingRule(smartRule);
        appState.addRoutingRule(updatedSmartRule);
        break;
      }
    }

    _loadConfigs();
  }

  // 获取路由类型标签
  String _getRouteTypeLabel(RouteType routeType) {
    final localizations = AppLocalizations.of(context);

    switch (routeType) {
      case RouteType.openVPN:
        return localizations.get('force_use_openvpn');
      case RouteType.clash:
        return localizations.get('force_use_clash');
      case RouteType.shadowsocks:
        return localizations.get('force_use_shadowsocks');
      case RouteType.v2ray:
        return localizations.get('force_use_v2ray');
      case RouteType.httpProxy:
        return localizations.get('force_use_http_proxy');
      case RouteType.socks5:
        return localizations.get('force_use_socks5_proxy');
      case RouteType.custom:
        return localizations.get('force_use_custom_proxy');
    }
  }

  // 获取VPN配置名称
  String _getConfigNameByRouteType(RouteType routeType, String? configId) {
    final localizations = AppLocalizations.of(context);

    // 如果configs为空，直接返回默认值
    if (configs.isEmpty) {
      return localizations.get('config_not_found');
    }

    // 如果有配置ID，优先根据配置ID查找
    if (configId != null) {
      final config = configs.firstWhereOrNull((c) => c.id == configId);
      if (config != null) {
        return config.name;
      }
    }

    // 如果没有配置ID或找不到对应配置，则根据路由类型查找
    for (var config in configs) {
      switch (routeType) {
        case RouteType.openVPN:
          if (config.type == VPNType.openVPN) return config.name;
          break;
        case RouteType.clash:
          if (config.type == VPNType.clash) return config.name;
          break;
        case RouteType.shadowsocks:
          if (config.type == VPNType.shadowsocks) return config.name;
          break;
        case RouteType.v2ray:
          if (config.type == VPNType.v2ray) return config.name;
          break;
        case RouteType.httpProxy:
          if (config.type == VPNType.httpProxy) return config.name;
          break;
        case RouteType.socks5:
          if (config.type == VPNType.socks5) return config.name;
          break;
        case RouteType.custom:
          if (config.type == VPNType.custom) return config.name;
          break;
      }
    }
    return localizations.get('config_not_found');
  }

  // 添加转换方法
  smart_routing_engine.RuleType _convertRouteTypeToRuleType(
    RouteType routeType,
  ) {
    switch (routeType) {
      case RouteType.openVPN:
        return smart_routing_engine.RuleType.domainSuffix;
      case RouteType.clash:
        return smart_routing_engine.RuleType.domainSuffix;
      case RouteType.shadowsocks:
        return smart_routing_engine.RuleType.domainSuffix;
      case RouteType.v2ray:
        return smart_routing_engine.RuleType.domainSuffix;
      case RouteType.httpProxy:
        return smart_routing_engine.RuleType.domainSuffix;
      case RouteType.socks5:
        return smart_routing_engine.RuleType.domainSuffix;
      case RouteType.custom:
        return smart_routing_engine.RuleType.domainSuffix;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.get('routing_rules_management')),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 添加路由规则表单
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.get('add_new_routing_rule'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _patternController,
                      decoration: InputDecoration(
                        labelText: localizations.get('website_or_ip_pattern'),
                        hintText: localizations.get(
                          'example_google_com_or_8_8_8_8',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedConfigId,
                      decoration: InputDecoration(
                        labelText: localizations.get('select_vpn_config'),
                        border: const OutlineInputBorder(),
                      ),
                      items: configs.map((config) {
                        return DropdownMenuItem(
                          value: config.id,
                          child: Text(config.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedConfigId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<RouteType>(
                      value: _selectedRouteType,
                      decoration: InputDecoration(
                        labelText: localizations.get('force_use_vpn_type'),
                        border: const OutlineInputBorder(),
                      ),
                      items: RouteType.values.map((type) {
                        String label;
                        switch (type) {
                          case RouteType.openVPN:
                            label = localizations.get('vpn_type_openvpn');
                            break;
                          case RouteType.clash:
                            label = localizations.get('vpn_type_clash');
                            break;
                          case RouteType.shadowsocks:
                            label = localizations.get('vpn_type_shadowsocks');
                            break;
                          case RouteType.v2ray:
                            label = localizations.get('vpn_type_v2ray');
                            break;
                          case RouteType.httpProxy:
                            label = localizations.get('vpn_type_http_proxy');
                            break;
                          case RouteType.socks5:
                            label = localizations.get('vpn_type_socks5_proxy');
                            break;
                          case RouteType.custom:
                            label = localizations.get('vpn_type_custom_proxy');
                            break;
                        }
                        return DropdownMenuItem(
                          value: type,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRouteType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(localizations.get('enable_rule')),
                        const SizedBox(width: 10),
                        Switch(
                          value: _isEnabled,
                          onChanged: (value) {
                            setState(() {
                              _isEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addRoutingRule,
                      child: Text(localizations.get('add_routing_rule')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 路由规则列表
            Text(
              localizations.get('existing_routing_rules'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: configs.isEmpty
                  ? Center(
                      child: Text(
                        localizations.get('no_vpn_config_please_add_config'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: configs.length,
                      itemBuilder: (context, configIndex) {
                        final config = configs[configIndex];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (config.routingRules.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Text(
                                      localizations.get('no_routing_rules'),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ...List.generate(config.routingRules.length, (
                                  ruleIndex,
                                ) {
                                  final rule = config.routingRules[ruleIndex];
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ListTile(
                                      title: Text(rule.pattern),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getRouteTypeLabel(rule.routeType),
                                          ),
                                          Text(
                                            '${localizations.get('proxy_source')}: ${_getConfigNameByRouteType(rule.routeType, rule.configId)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Switch(
                                            value: rule.isEnabled,
                                            onChanged: (value) =>
                                                _toggleRule(config, ruleIndex),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () => _deleteRoutingRule(
                                              config,
                                              ruleIndex,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
