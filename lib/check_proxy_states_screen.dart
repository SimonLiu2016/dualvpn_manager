import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CheckProxyStatesScreen extends StatefulWidget {
  const CheckProxyStatesScreen({super.key});

  @override
  State<CheckProxyStatesScreen> createState() => _CheckProxyStatesScreenState();
}

class _CheckProxyStatesScreenState extends State<CheckProxyStatesScreen> {
  String _proxyStatesData = 'Loading...';
  String _routingRulesData = 'Loading...';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('检查代理状态'),
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
              ElevatedButton(onPressed: _loadData, child: const Text('刷新数据')),
            ],
          ),
        ),
      ),
    );
  }
}
