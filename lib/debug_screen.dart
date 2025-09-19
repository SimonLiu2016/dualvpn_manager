import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
// 添加导入
import 'package:dualvpn_manager/check_proxy_states_screen.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _proxyStatesData = 'Loading...';
  String _routingRulesData = 'Loading...';
  String _appStateData = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 检查SharedPreferences数据
      final prefs = await SharedPreferences.getInstance();

      // 检查代理状态键
      final proxyStatesKey = 'proxy_states';
      final String? statesJson = prefs.getString(proxyStatesKey);

      String proxyStatesResult = '=== 代理状态数据检查 ===\n';
      if (statesJson != null && statesJson.isNotEmpty) {
        proxyStatesResult += '找到代理状态数据:\n';
        try {
          final Map<String, dynamic> statesMap = jsonDecode(statesJson);
          proxyStatesResult += '配置数量: ${statesMap.length}\n';

          statesMap.forEach((configId, proxiesList) {
            proxyStatesResult += '配置ID: $configId\n';
            if (proxiesList is List) {
              proxyStatesResult += '  代理数量: ${proxiesList.length}\n';
              for (var i = 0; i < proxiesList.length; i++) {
                final proxy = proxiesList[i];
                if (proxy is Map) {
                  proxyStatesResult +=
                      '    代理 $i: ${proxy['name']}, 延迟: ${proxy['latency']}, 选中: ${proxy['isSelected']}\n';
                }
              }
            } else {
              proxyStatesResult += '  代理数据格式错误\n';
            }
          });
        } catch (e) {
          proxyStatesResult += '解析代理状态数据时出错: $e\n';
          proxyStatesResult += '原始数据: $statesJson\n';
        }
      } else {
        proxyStatesResult += '未找到代理状态数据\n';
      }

      // 检查路由规则键
      final routingRulesKey = 'routing_rules';
      final String? rulesJson = prefs.getString(routingRulesKey);

      String routingRulesResult = '\n=== 路由规则数据检查 ===\n';
      if (rulesJson != null && rulesJson.isNotEmpty) {
        routingRulesResult += '找到路由规则数据:\n';
        try {
          final List<dynamic> rulesList = jsonDecode(rulesJson);
          routingRulesResult += '路由规则数量: ${rulesList.length}\n';
          for (var i = 0; i < rulesList.length; i++) {
            final rule = rulesList[i];
            if (rule is Map) {
              routingRulesResult +=
                  '  规则 $i: ${rule['pattern']}, 类型: ${rule['type']}, 代理ID: ${rule['proxyId']}, 启用: ${rule['isEnabled']}\n';
            }
          }
        } catch (e) {
          routingRulesResult += '解析路由规则数据时出错: $e\n';
          routingRulesResult += '原始数据: $rulesJson\n';
        }
      } else {
        routingRulesResult += '未找到路由规则数据\n';
      }

      setState(() {
        _proxyStatesData = proxyStatesResult;
        _routingRulesData = routingRulesResult;
      });
    } catch (e) {
      setState(() {
        _proxyStatesData = '加载数据时出错: $e';
        _routingRulesData = '加载数据时出错: $e';
      });
    }
  }

  Future<void> _loadAppStateData() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);

      String appStateResult = '=== AppState数据检查 ===\n';
      appStateResult += '当前选中配置ID: ${appState.selectedConfig}\n';
      appStateResult += '代理缓存数量: ${appState.proxiesByConfig.length}\n';

      appState.proxiesByConfig.forEach((configId, proxies) {
        appStateResult += '配置 $configId 有 ${proxies.length} 个代理\n';
        for (var i = 0; i < proxies.length; i++) {
          final proxy = proxies[i];
          appStateResult +=
              '  代理 $i: ${proxy['name']}, 延迟: ${proxy['latency']}, 选中: ${proxy['isSelected']}\n';
        }
      });

      appStateResult += '当前代理列表数量: ${appState.proxies.length}\n';
      for (var i = 0; i < appState.proxies.length; i++) {
        final proxy = appState.proxies[i];
        appStateResult +=
            '  当前代理 $i: ${proxy['name']}, 延迟: ${proxy['latency']}, 选中: ${proxy['isSelected']}\n';
      }

      setState(() {
        _appStateData = appStateResult;
      });
    } catch (e) {
      setState(() {
        _appStateData = '加载AppState数据时出错: $e';
      });
    }
  }

  Future<void> _applySelectedProxiesManually() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      // 调用应用选中代理的公共方法
      await appState.applySelectedProxiesManually();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('手动触发应用选中代理完成')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('触发失败: $e')));
    }
  }

  // 添加导航到检查代理状态界面的方法
  void _navigateToCheckProxyStates() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckProxyStatesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试信息'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SharedPreferences 数据检查',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(_proxyStatesData),
              const SizedBox(height: 16),
              Text(_routingRulesData),
              const SizedBox(height: 16),
              const Text(
                'AppState 数据检查',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(_appStateData),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('刷新SharedPreferences数据'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAppStateData,
                child: const Text('刷新AppState数据'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _applySelectedProxiesManually,
                child: const Text('手动应用选中代理'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _navigateToCheckProxyStates,
                child: const Text('检查代理状态数据'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
