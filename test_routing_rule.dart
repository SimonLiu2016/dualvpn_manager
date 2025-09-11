import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'dart:convert';

void main() async {
  // 初始化Flutter绑定
  WidgetsFlutterBinding.ensureInitialized();

  // 测试路由规则的序列化和反序列化
  final testRule = RoutingRule(
    pattern: 'example.com',
    routeType: RouteType.clash,
    isEnabled: true,
    configId: 'test-config-id',
  );

  print('Original rule: ${testRule.toJson()}');

  // 测试序列化
  final jsonString = jsonEncode(testRule.toJson());
  print('Serialized rule: $jsonString');

  // 测试反序列化
  final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
  final restoredRule = RoutingRule.fromJson(decodedMap);
  print('Restored rule: ${restoredRule.toJson()}');

  // 测试SharedPreferences存储
  final prefs = await SharedPreferences.getInstance();

  // 保存路由规则列表
  final rules = [testRule];
  final List<Map<String, dynamic>> rulesJson = rules
      .map((rule) => rule.toJson())
      .toList();
  await prefs.setString('test_routing_rules', jsonEncode(rulesJson));

  print('Saved to SharedPreferences');

  // 从SharedPreferences读取
  final String? retrievedJson = prefs.getString('test_routing_rules');
  if (retrievedJson != null) {
    final List<dynamic> retrievedList = jsonDecode(retrievedJson);
    final restoredRules = retrievedList
        .map((rule) => RoutingRule.fromJson(rule as Map<String, dynamic>))
        .toList();

    print('Retrieved rules count: ${restoredRules.length}');
    print('First rule: ${restoredRules.first.toJson()}');
  }

  print('Test completed');
}
