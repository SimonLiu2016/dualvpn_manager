import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';

class ConfigManager {
  static const String _configsKey = 'vpn_configs';
  static List<VPNConfig>? _cachedConfigs; // 缓存配置列表

  // 保存配置列表
  static Future<void> saveConfigs(List<VPNConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> configStrings = configs
        .map((config) => jsonEncode(config.toJson()))
        .toList();
    await prefs.setStringList(_configsKey, configStrings);
    _cachedConfigs = null; // 清除缓存
  }

  // 加载配置列表
  static Future<List<VPNConfig>> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? configStrings = prefs.getStringList(_configsKey);

    if (configStrings == null || configStrings.isEmpty) {
      _cachedConfigs = [];
      return [];
    }

    _cachedConfigs = configStrings
        .map((configString) => VPNConfig.fromJson(jsonDecode(configString)))
        .toList();
    return _cachedConfigs!;
  }

  // 同步获取配置列表（需要先调用loadConfigs）
  static List<VPNConfig> loadConfigsSync() {
    return _cachedConfigs ?? [];
  }

  // 添加新配置
  static Future<void> addConfig(VPNConfig config) async {
    final configs = await loadConfigs();
    configs.add(config);
    await saveConfigs(configs);
  }

  // 更新配置
  static Future<void> updateConfig(VPNConfig config) async {
    final configs = await loadConfigs();
    final index = configs.indexWhere((c) => c.id == config.id);
    if (index != -1) {
      configs[index] = config;
      await saveConfigs(configs);
    }
  }

  // 删除配置
  static Future<void> deleteConfig(String configId) async {
    final configs = await loadConfigs();
    configs.removeWhere((config) => config.id == configId);
    await saveConfigs(configs);
  }

  // 获取特定配置
  static Future<VPNConfig?> getConfig(String configId) async {
    final configs = await loadConfigs();
    try {
      return configs.firstWhere((config) => config.id == configId);
    } catch (e) {
      return null;
    }
  }
}
