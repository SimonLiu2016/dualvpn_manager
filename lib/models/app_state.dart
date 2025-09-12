import 'package:flutter/material.dart';
import 'package:dualvpn_manager/services/vpn_manager.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:dualvpn_manager/utils/tray_manager.dart';
import 'dart:io';
import 'dart:convert';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  final VPNManager _vpnManager = VPNManager();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final DualVPNTrayManager _trayManager;

  // 添加路由规则存储键
  static const String _routingRulesKey = 'routing_rules';

  AppState({required DualVPNTrayManager trayManager})
    : _trayManager = trayManager {
    // 设置托盘管理器的显示窗口回调函数
    _trayManager.setShowWindowCallback(_showWindow);
    // 初始化时加载路由规则
    _loadRoutingRules();
  }

  // 显示主窗口
  void _showWindow() {
    // 使用window_manager显示窗口
    windowManager.show();
    windowManager.focus();
  }

  // OpenVPN连接状态
  bool _openVPNConnected = false;
  bool get openVPNConnected => _openVPNConnected;

  // OpenVPN速率信息
  String _openVPNRateInfo = '↑ 0 KB/s ↓ 0 KB/s';
  String get openVPNRateInfo => _openVPNRateInfo;

  // Clash连接状态
  bool _clashConnected = false;
  bool get clashConnected => _clashConnected;

  // Clash速率信息
  String _clashRateInfo = '↑ 0 KB/s ↓ 0 KB/s';
  String get clashRateInfo => _clashRateInfo;

  // Shadowsocks连接状态
  bool _shadowsocksConnected = false;
  bool get shadowsocksConnected => _shadowsocksConnected;

  // Shadowsocks速率信息
  String _shadowsocksRateInfo = '↑ 0 KB/s ↓ 0 KB/s';
  String get shadowsocksRateInfo => _shadowsocksRateInfo;

  // V2Ray连接状态
  bool _v2rayConnected = false;
  bool get v2rayConnected => _v2rayConnected;

  // V2Ray速率信息
  String _v2rayRateInfo = '↑ 0 KB/s ↓ 0 KB/s';
  String get v2rayRateInfo => _v2rayRateInfo;

  // HTTP代理连接状态
  bool _httpProxyConnected = false;
  bool get httpProxyConnected => _httpProxyConnected;

  // HTTP代理速率信息
  String _httpProxyRateInfo = '↑ 0 KB/s ↓ 0 KB/s';
  String get httpProxyRateInfo => _httpProxyRateInfo;

  // SOCKS5代理连接状态
  bool _socks5ProxyConnected = false;
  bool get socks5ProxyConnected => _socks5ProxyConnected;

  // SOCKS5代理速率信息
  String _socks5ProxyRateInfo = '↑ 0 KB/s ↓ 0 KB/s';
  String get socks5ProxyRateInfo => _socks5ProxyRateInfo;

  // 应用运行状态
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // 当前选中的配置ID
  String _selectedConfig = '';
  String get selectedConfig => _selectedConfig;

  // 内网域名列表 (已废弃，保留以兼容旧版本)
  List<String> _internalDomains = [];
  List<String> get internalDomains => _internalDomains;

  // 外网域名列表 (已废弃，保留以兼容旧版本)
  List<String> _externalDomains = [];
  List<String> get externalDomains => _externalDomains;

  // 路由规则列表
  List<RoutingRule> _routingRules = [];
  List<RoutingRule> get routingRules => _routingRules;

  // 加载路由规则
  Future<void> _loadRoutingRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rulesJson = prefs.getString(_routingRulesKey);

      if (rulesJson != null && rulesJson.isNotEmpty) {
        final List<dynamic> rulesList = jsonDecode(rulesJson);
        _routingRules = rulesList
            .map((rule) => RoutingRule.fromJson(rule as Map<String, dynamic>))
            .toList();
        Logger.info('成功加载${_routingRules.length}条路由规则');
      } else {
        _routingRules = [];
        Logger.info('未找到已保存的路由规则');
      }
      notifyListeners();
    } catch (e) {
      Logger.error('加载路由规则失败: $e');
      _routingRules = [];
    }
  }

  // 保存路由规则
  Future<void> _saveRoutingRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> rulesJson = _routingRules
          .map((rule) => rule.toJson())
          .toList();
      await prefs.setString(_routingRulesKey, jsonEncode(rulesJson));
      Logger.info('路由规则已保存，共${_routingRules.length}条');
    } catch (e) {
      Logger.error('保存路由规则失败: $e');
    }
  }

  // 代理列表状态 - 按配置ID存储
  Map<String, List<Map<String, dynamic>>> _proxiesByConfig = {};
  List<Map<String, dynamic>> _proxies = [];
  List<Map<String, dynamic>> get proxies => _proxies;

  // 添加getter方法用于测试访问
  Map<String, List<Map<String, dynamic>>> get proxiesByConfig =>
      _proxiesByConfig;

  bool _isLoadingProxies = false;
  bool get isLoadingProxies => _isLoadingProxies;

  // 获取启用配置中被选中的代理列表
  Future<List<Map<String, dynamic>>> getSelectedProxies() async {
    final configs = await ConfigManager.loadConfigs();
    final List<Map<String, dynamic>> selectedProxies = [];

    // 只获取启用的配置
    final enabledConfigs = configs.where((config) => config.isActive).toList();

    Logger.debug('getSelectedProxies: 找到 ${enabledConfigs.length} 个启用的配置');
    Logger.debug('getSelectedProxies: _selectedConfig = $_selectedConfig');
    Logger.debug(
      'getSelectedProxies: _proxiesByConfig keys = ${_proxiesByConfig.keys}',
    );

    for (var config in enabledConfigs) {
      Logger.debug(
        'getSelectedProxies: 处理配置 ${config.name} (ID: ${config.id}, 类型: ${config.type})',
      );

      // 只有Clash、Shadowsocks和V2Ray三种类型支持代理列表
      if (config.type == VPNType.clash ||
          config.type == VPNType.shadowsocks ||
          config.type == VPNType.v2ray) {
        // 对于支持代理列表的类型，获取选中的代理
        List<Map<String, dynamic>> proxies = [];

        // 首先尝试从_proxiesByConfig获取
        if (_proxiesByConfig.containsKey(config.id)) {
          proxies = _proxiesByConfig[config.id]!;
          Logger.debug(
            'getSelectedProxies: 从_proxiesByConfig 获取到 ${proxies.length} 个代理',
          );
        } else if (_selectedConfig == config.id) {
          // 如果当前选中的配置就是这个配置，则使用当前的_proxies
          proxies = _proxies;
          Logger.debug(
            'getSelectedProxies: 从当前_proxies 获取到 ${proxies.length} 个代理',
          );
        } else {
          // 如果缓存中没有且不是当前选中的配置，则尝试加载该配置的代理列表
          Logger.debug('getSelectedProxies: 配置 ${config.id} 未在缓存中找到，尝试加载');

          try {
            // 保存当前状态
            final originalSelectedConfig = _selectedConfig;
            final originalProxies = List<Map<String, dynamic>>.from(_proxies);

            // 临时切换到目标配置
            _selectedConfig = config.id;
            _proxies = []; // 清空当前代理列表

            // 加载代理列表
            await loadProxies();
            proxies = List<Map<String, dynamic>>.from(_proxies);

            // 恢复原状态
            _selectedConfig = originalSelectedConfig;
            _proxies = originalProxies;

            Logger.debug(
              'getSelectedProxies: 为配置 ${config.id} 加载到 ${proxies.length} 个代理',
            );
          } catch (e) {
            Logger.error('getSelectedProxies: 加载配置 ${config.id} 的代理列表失败: $e');
            proxies = [];
          }
        }

        // 显示所有代理及其选中状态（用于调试）
        for (var proxy in proxies) {
          Logger.debug(
            'getSelectedProxies: 代理 ${proxy['name']}, isSelected = ${proxy['isSelected']}',
          );
        }

        // 查找选中的代理
        final selectedProxyList = proxies
            .where((proxy) => proxy['isSelected'] == true)
            .toList();
        Logger.debug(
          'getSelectedProxies: 找到 ${selectedProxyList.length} 个选中的代理',
        );

        if (selectedProxyList.isNotEmpty) {
          selectedProxies.add({
            'config': config,
            'proxy': selectedProxyList.first,
          });
          Logger.debug(
            'getSelectedProxies: 添加选中的代理 ${selectedProxyList.first['name']}',
          );
        }
      } else {
        // 对于不支持代理列表的类型，直接使用配置本身作为代理
        // 这些类型的代理不使用代理列表中的选中项
        selectedProxies.add({
          'config': config,
          'proxy': {
            'name': config.name,
            'type': config.type.toString(),
            'latency': -2, // 未测试
            'isSelected': true,
          },
        });
        Logger.debug('getSelectedProxies: 添加非代理列表类型配置 ${config.name}');
      }
    }

    Logger.debug('getSelectedProxies: 返回 ${selectedProxies.length} 个选中的代理');

    return selectedProxies;
  }

  // 设置OpenVPN连接状态
  void setOpenVPNConnected(bool connected) {
    _openVPNConnected = connected;
    notifyListeners();
    _updateTrayIcon();
  }

  // 设置OpenVPN速率信息
  void setOpenVPNRateInfo(String rateInfo) {
    _openVPNRateInfo = rateInfo;
    notifyListeners();
  }

  // 设置Clash连接状态
  void setClashConnected(bool connected) {
    _clashConnected = connected;
    notifyListeners();
    _updateTrayIcon();
  }

  // 设置Clash速率信息
  void setClashRateInfo(String rateInfo) {
    _clashRateInfo = rateInfo;
    notifyListeners();
  }

  // 设置Shadowsocks连接状态
  void setShadowsocksConnected(bool connected) {
    _shadowsocksConnected = connected;
    notifyListeners();
    _updateTrayIcon();
  }

  // 设置Shadowsocks速率信息
  void setShadowsocksRateInfo(String rateInfo) {
    _shadowsocksRateInfo = rateInfo;
    notifyListeners();
  }

  // 设置V2Ray连接状态
  void setV2RayConnected(bool connected) {
    _v2rayConnected = connected;
    notifyListeners();
    _updateTrayIcon();
  }

  // 设置V2Ray速率信息
  void setV2RayRateInfo(String rateInfo) {
    _v2rayRateInfo = rateInfo;
    notifyListeners();
  }

  // 设置HTTP代理连接状态
  void setHTTPProxyConnected(bool connected) {
    _httpProxyConnected = connected;
    notifyListeners();
    _updateTrayIcon();
  }

  // 设置HTTP代理速率信息
  void setHTTPProxyRateInfo(String rateInfo) {
    _httpProxyRateInfo = rateInfo;
    notifyListeners();
  }

  // 设置SOCKS5代理连接状态
  void setSOCKS5ProxyConnected(bool connected) {
    _socks5ProxyConnected = connected;
    notifyListeners();
    _updateTrayIcon();
  }

  // 设置SOCKS5代理速率信息
  void setSOCKS5ProxyRateInfo(String rateInfo) {
    _socks5ProxyRateInfo = rateInfo;
    notifyListeners();
  }

  // 设置应用运行状态
  void setIsRunning(bool running) {
    _isRunning = running;
    notifyListeners();
  }

  // 设置当前选中的配置
  void setSelectedConfig(String configId) {
    // 保存当前代理列表
    if (_selectedConfig.isNotEmpty) {
      _proxiesByConfig[_selectedConfig] = List<Map<String, dynamic>>.from(
        _proxies,
      );
    }

    _selectedConfig = configId;

    // 恢复选中配置的代理列表
    if (_proxiesByConfig.containsKey(configId)) {
      _proxies = _proxiesByConfig[configId]!;
    } else {
      _proxies = [];
    }

    notifyListeners();
  }

  // 设置内网域名列表
  void setInternalDomains(List<String> domains) {
    _internalDomains = domains;
    notifyListeners();
  }

  // 设置外网域名列表
  void setExternalDomains(List<String> domains) {
    _externalDomains = domains;
    notifyListeners();
  }

  // 设置路由规则列表
  void setRoutingRules(List<RoutingRule> rules) {
    _routingRules = rules;
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
  }

  // 添加路由规则
  void addRoutingRule(RoutingRule rule) {
    _routingRules.add(rule);
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
  }

  // 删除路由规则
  void removeRoutingRule(RoutingRule rule) {
    _routingRules.remove(rule);
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
  }

  // 设置代理列表
  void setProxies(List<Map<String, dynamic>> proxies) {
    _proxies = proxies;
    // 保存当前配置的代理列表
    if (_selectedConfig.isNotEmpty) {
      _proxiesByConfig[_selectedConfig] = proxies;
    }
    notifyListeners();
  }

  // 清除指定配置的代理列表缓存
  void clearProxyCache(String configId) {
    _proxiesByConfig.remove(configId);
    // 如果当前选中的配置就是被清除的配置，则清空当前代理列表
    if (_selectedConfig == configId) {
      _proxies = [];
      notifyListeners();
    }
  }

  // 设置代理列表加载状态
  void setIsLoadingProxies(bool isLoading) {
    _isLoadingProxies = isLoading;
    notifyListeners();
  }

  // 更新单个代理的延迟
  void updateProxyLatency(String proxyName, int latency) {
    for (var i = 0; i < _proxies.length; i++) {
      if (_proxies[i]['name'] == proxyName) {
        _proxies[i] = Map<String, dynamic>.from(_proxies[i])
          ..['latency'] = latency;
        break;
      }
    }
    // 更新存储的代理列表
    if (_selectedConfig.isNotEmpty) {
      _proxiesByConfig[_selectedConfig] = List<Map<String, dynamic>>.from(
        _proxies,
      );
    }
    notifyListeners();
  }

  // 设置代理选中状态
  void setProxySelected(String proxyName, bool isSelected) {
    for (var i = 0; i < _proxies.length; i++) {
      if (_proxies[i]['name'] == proxyName) {
        _proxies[i] = Map<String, dynamic>.from(_proxies[i])
          ..['isSelected'] = isSelected;
        // 如果选中了这个代理，取消其他代理的选中状态
        if (isSelected) {
          for (var j = 0; j < _proxies.length; j++) {
            if (j != i && _proxies[j]['isSelected'] == true) {
              _proxies[j] = Map<String, dynamic>.from(_proxies[j])
                ..['isSelected'] = false;
            }
          }

          // 立即应用选中的代理到Clash服务
          _applySelectedProxy(proxyName);
        }
        break;
      }
    }
    // 更新存储的代理列表
    if (_selectedConfig.isNotEmpty) {
      _proxiesByConfig[_selectedConfig] = List<Map<String, dynamic>>.from(
        _proxies,
      );
    }
    notifyListeners();
  }

  // 应用选中的代理到Clash服务
  Future<void> _applySelectedProxy(String proxyName) async {
    try {
      // 获取当前选中的配置
      final configs = await ConfigManager.loadConfigs();
      final currentConfig = configs.firstWhere(
        (config) => config.id == _selectedConfig,
        orElse: () => configs.first,
      );

      // 只对Clash类型的配置应用代理选择
      if (currentConfig.type == VPNType.clash) {
        Logger.info('正在应用Clash代理: $proxyName');
        // 使用'GLOBAL'作为默认的选择器名称，这是Clash的常见配置
        final result = await _vpnManager.selectClashProxy('GLOBAL', proxyName);
        if (result) {
          Logger.info('成功应用Clash代理: $proxyName');
        } else {
          Logger.error('应用Clash代理失败: $proxyName');
        }
      }
    } catch (e) {
      Logger.error('应用选中代理时出错: $e');
    }
  }

  // 更新托盘图标
  void _updateTrayIcon() {
    // 检查是否有任何VPN/代理连接
    bool hasAnyConnection =
        _openVPNConnected ||
        _clashConnected ||
        _shadowsocksConnected ||
        _v2rayConnected ||
        _httpProxyConnected ||
        _socks5ProxyConnected;

    // 目前我们只区分连接和未连接状态
    // 如果需要更详细的图标状态，可以扩展此逻辑
    _trayManager.updateTrayIcon(_openVPNConnected, _clashConnected);
  }

  // 连接OpenVPN
  Future<bool> connectOpenVPN(VPNConfig config) async {
    try {
      final result = await _vpnManager.connectOpenVPN(config);
      if (result) {
        setOpenVPNConnected(true);
        Logger.info('OpenVPN连接成功');
      } else {
        Logger.error('OpenVPN连接失败');
      }
      return result;
    } catch (e) {
      Logger.error('连接OpenVPN失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 断开OpenVPN
  Future<void> disconnectOpenVPN() async {
    try {
      await _vpnManager.disconnectOpenVPN();
      setOpenVPNConnected(false);
      Logger.info('OpenVPN已断开连接');
    } catch (e) {
      Logger.error('断开OpenVPN失败: $e');
      // 通知UI显示错误
    }
  }

  // 连接Clash
  Future<bool> connectClash(VPNConfig config) async {
    try {
      final result = await _vpnManager.connectClash(config);
      if (result) {
        setClashConnected(true);
        Logger.info('Clash连接成功');

        // 连接成功后，如果有已选中的代理，则应用该代理
        await _applySelectedProxyForClash(config);
      } else {
        Logger.error('Clash连接失败');
      }
      return result;
    } catch (e) {
      Logger.error('连接Clash失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 为Clash配置应用已选中的代理
  Future<void> _applySelectedProxyForClash(VPNConfig config) async {
    try {
      // 设置当前配置为选中状态
      setSelectedConfig(config.id);

      // 加载代理列表
      await loadProxies();

      // 查找已选中的代理
      Map<String, dynamic>? selectedProxy;
      try {
        selectedProxy = _proxies.firstWhere(
          (proxy) => proxy['isSelected'] == true,
        );
      } catch (e) {
        // 没有找到选中的代理
        selectedProxy = null;
      }

      // 如果找到了已选中的代理，则应用它
      if (selectedProxy != null) {
        Logger.info('应用已选中的Clash代理: ${selectedProxy['name']}');
        final result = await _vpnManager.selectClashProxy(
          'GLOBAL',
          selectedProxy['name'],
        );
        if (result) {
          Logger.info('成功应用Clash代理: ${selectedProxy['name']}');
        } else {
          Logger.error('应用Clash代理失败: ${selectedProxy['name']}');
        }
      } else {
        Logger.info('未找到已选中的Clash代理');
      }
    } catch (e) {
      Logger.error('为Clash配置应用已选中代理时出错: $e');
    }
  }

  // 断开Clash
  Future<void> disconnectClash() async {
    try {
      await _vpnManager.disconnectClash();
      setClashConnected(false);
      Logger.info('Clash已断开连接');
    } catch (e) {
      Logger.error('断开Clash失败: $e');
      // 通知UI显示错误
    }
  }

  // 连接Shadowsocks
  Future<bool> connectShadowsocks(VPNConfig config) async {
    try {
      final result = await _vpnManager.connectShadowsocks(config);
      if (result) {
        setShadowsocksConnected(true);
        Logger.info('Shadowsocks连接成功');
      } else {
        Logger.error('Shadowsocks连接失败');
      }
      return result;
    } catch (e) {
      Logger.error('连接Shadowsocks失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 断开Shadowsocks
  Future<void> disconnectShadowsocks() async {
    try {
      await _vpnManager.disconnectShadowsocks();
      setShadowsocksConnected(false);
      Logger.info('Shadowsocks已断开连接');
    } catch (e) {
      Logger.error('断开Shadowsocks失败: $e');
      // 通知UI显示错误
    }
  }

  // 连接V2Ray
  Future<bool> connectV2Ray(VPNConfig config) async {
    try {
      final result = await _vpnManager.connectV2Ray(config);
      if (result) {
        setV2RayConnected(true);
        Logger.info('V2Ray连接成功');
      } else {
        Logger.error('V2Ray连接失败');
      }
      return result;
    } catch (e) {
      Logger.error('连接V2Ray失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 断开V2Ray
  Future<void> disconnectV2Ray() async {
    try {
      await _vpnManager.disconnectV2Ray();
      setV2RayConnected(false);
      Logger.info('V2Ray已断开连接');
    } catch (e) {
      Logger.error('断开V2Ray失败: $e');
      // 通知UI显示错误
    }
  }

  // 连接HTTP代理
  Future<bool> connectHTTPProxy(VPNConfig config) async {
    try {
      final result = await _vpnManager.connectHTTPProxy(config);
      if (result) {
        setHTTPProxyConnected(true);
        Logger.info('HTTP代理连接成功');
      } else {
        Logger.error('HTTP代理连接失败');
      }
      return result;
    } catch (e) {
      Logger.error('连接HTTP代理失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 断开HTTP代理
  Future<void> disconnectHTTPProxy() async {
    try {
      await _vpnManager.disconnectHTTPProxy();
      setHTTPProxyConnected(false);
      Logger.info('HTTP代理已断开连接');
    } catch (e) {
      Logger.error('断开HTTP代理失败: $e');
      // 通知UI显示错误
    }
  }

  // 连接SOCKS5代理
  Future<bool> connectSOCKS5Proxy(VPNConfig config) async {
    try {
      final result = await _vpnManager.connectSOCKS5Proxy(config);
      if (result) {
        setSOCKS5ProxyConnected(true);
        Logger.info('SOCKS5代理连接成功');
      } else {
        Logger.error('SOCKS5代理连接失败');
      }
      return result;
    } catch (e) {
      Logger.error('连接SOCKS5代理失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 断开SOCKS5代理
  Future<void> disconnectSOCKS5Proxy() async {
    try {
      await _vpnManager.disconnectSOCKS5Proxy();
      setSOCKS5ProxyConnected(false);
      Logger.info('SOCKS5代理已断开连接');
    } catch (e) {
      Logger.error('断开SOCKS5代理失败: $e');
      // 通知UI显示错误
    }
  }

  // 更新Clash订阅
  Future<bool> updateClashSubscription(VPNConfig config) async {
    try {
      final result = await _vpnManager.updateClashSubscription(config);
      if (result) {
        Logger.info('Clash订阅更新成功');
      } else {
        Logger.error('Clash订阅更新失败');
      }
      return result;
    } catch (e) {
      Logger.error('更新Clash订阅失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 更新Shadowsocks订阅
  Future<bool> updateShadowsocksSubscription(VPNConfig config) async {
    try {
      final result = await _vpnManager.updateShadowsocksSubscription(config);
      if (result) {
        Logger.info('Shadowsocks订阅更新成功');
      } else {
        Logger.error('Shadowsocks订阅更新失败');
      }
      return result;
    } catch (e) {
      Logger.error('更新Shadowsocks订阅失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 更新V2Ray订阅
  Future<bool> updateV2RaySubscription(VPNConfig config) async {
    try {
      final result = await _vpnManager.updateV2RaySubscription(config);
      if (result) {
        Logger.info('V2Ray订阅更新成功');
      } else {
        Logger.error('V2Ray订阅更新失败');
      }
      return result;
    } catch (e) {
      Logger.error('更新V2Ray订阅失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 通用订阅更新方法
  Future<bool> updateSubscription(VPNConfig config) async {
    try {
      bool result = false;

      switch (config.type) {
        case VPNType.clash:
          result = await updateClashSubscription(config);
          break;
        case VPNType.shadowsocks:
          result = await updateShadowsocksSubscription(config);
          break;
        case VPNType.v2ray:
          result = await updateV2RaySubscription(config);
          break;
        default:
          Logger.error('不支持的订阅更新类型: ${config.type}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(
              navigatorKey.currentContext!,
            ).showSnackBar(const SnackBar(content: Text('该代理类型不支持订阅更新')));
          });
          result = false;
      }

      return result;
    } catch (e) {
      Logger.error('更新${config.type}订阅失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 配置智能路由
  Future<bool> configureRouting() async {
    try {
      // 获取所有配置以获取强制路由规则
      final configs = await ConfigManager.loadConfigs();
      final List<RoutingRule> forcedRules = [];

      // 收集所有启用的强制路由规则
      for (var config in configs) {
        forcedRules.addAll(config.routingRules.where((rule) => rule.isEnabled));
      }

      final result = await _vpnManager.configureRouting(
        internalDomains: _internalDomains,
        externalDomains: _externalDomains,
      );
      if (result) {
        Logger.info('路由配置成功');
      } else {
        Logger.error('路由配置失败');
      }
      return result;
    } catch (e) {
      Logger.error('配置路由失败: $e');
      // 通知UI显示错误
      return false;
    }
  }

  // 启用路由
  Future<void> enableRouting() async {
    try {
      await _vpnManager.enableRouting();
      setIsRunning(true);
      Logger.info('路由已启用');
    } catch (e) {
      Logger.error('启用路由失败: $e');
      // 通知UI显示错误
    }
  }

  // 禁用路由
  Future<void> disableRouting() async {
    try {
      await _vpnManager.disableRouting();
      setIsRunning(false);
      Logger.info('路由已禁用');
    } catch (e) {
      Logger.error('禁用路由失败: $e');
      // 通知UI显示错误
    }
  }

  // 启用所有路由规则
  void enableAllRoutingRules() {
    final List<RoutingRule> updatedRules = _routingRules.map((rule) {
      return RoutingRule(
        pattern: rule.pattern,
        routeType: rule.routeType,
        isEnabled: true, // 将所有规则设置为启用
        configId: rule.configId,
      );
    }).toList();

    _routingRules = updatedRules;
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
  }

  // 禁用所有路由规则
  void disableAllRoutingRules() {
    final List<RoutingRule> updatedRules = _routingRules.map((rule) {
      return RoutingRule(
        pattern: rule.pattern,
        routeType: rule.routeType,
        isEnabled: false, // 将所有规则设置为禁用
        configId: rule.configId,
      );
    }).toList();

    _routingRules = updatedRules;
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
  }

  // 获取指定ID的配置
  Future<VPNConfig?> getConfigById(String id) async {
    try {
      return await ConfigManager.getConfig(id);
    } catch (e) {
      Logger.error('获取配置失败: $e');
      return null;
    }
  }

  // 获取Clash代理列表
  Future<Map<String, dynamic>?> getClashProxies() async {
    try {
      return await _vpnManager.getClashProxies();
    } catch (e) {
      Logger.error('获取Clash代理列表失败: $e');
      return null;
    }
  }

  // 加载代理列表
  Future<void> loadProxies() async {
    setIsLoadingProxies(true);

    try {
      // 获取当前选中的配置
      final configs = await ConfigManager.loadConfigs();
      // 使用_selectedConfig而不是currentConfig来获取当前选中的配置
      final currentConfig = configs.firstWhere(
        (config) => config.id == _selectedConfig,
        orElse: () => configs.first,
      );

      // 检查是否已缓存该配置的代理列表
      if (_proxiesByConfig.containsKey(currentConfig.id)) {
        _proxies = _proxiesByConfig[currentConfig.id]!;
        setIsLoadingProxies(false);
        notifyListeners();
        return;
      }

      // 根据配置类型加载相应的代理列表
      List<Map<String, dynamic>> proxies = [];

      // 只有Clash、Shadowsocks和V2Ray三种类型支持代理列表
      if (currentConfig.type == VPNType.clash ||
          currentConfig.type == VPNType.shadowsocks ||
          currentConfig.type == VPNType.v2ray) {
        switch (currentConfig.type) {
          case VPNType.clash:
            final proxiesData = await getClashProxies();
            if (proxiesData != null && proxiesData.containsKey('proxies')) {
              // 解析Clash代理数据
              (proxiesData['proxies'] as Map<String, dynamic>).forEach((
                name,
                proxy,
              ) {
                if (proxy is Map<String, dynamic>) {
                  // 检查是否已存在该代理的状态
                  Map<String, dynamic>? existingProxy;
                  for (var p in _proxies) {
                    if (p['name'] == name) {
                      existingProxy = p;
                      break;
                    }
                  }

                  proxies.add({
                    'name': name,
                    'type': proxy['type'] ?? 'unknown',
                    'latency': existingProxy?['latency'] ?? -2, // -2表示未测试
                    'isSelected': existingProxy?['isSelected'] ?? false,
                  });
                }
              });
            }
            break;

          case VPNType.shadowsocks:
            // 获取Shadowsocks代理列表
            final shadowsocksProxies = await getShadowsocksProxies();
            // 保留原有代理的状态
            for (var proxy in shadowsocksProxies) {
              // 检查是否已存在该代理的状态
              Map<String, dynamic>? existingProxy;
              for (var p in _proxies) {
                if (p['name'] == proxy['name']) {
                  existingProxy = p;
                  break;
                }
              }

              proxies.add({
                'name': proxy['name'],
                'type': proxy['type'] ?? 'shadowsocks',
                'latency':
                    existingProxy?['latency'] ??
                    proxy['latency'] ??
                    -2, // -2表示未测试
                'isSelected':
                    existingProxy?['isSelected'] ??
                    proxy['isSelected'] ??
                    false,
              });
            }
            break;

          case VPNType.v2ray:
            // 获取V2Ray代理列表
            final v2rayProxies = await getV2RayProxies();
            // 保留原有代理的状态
            for (var proxy in v2rayProxies) {
              // 检查是否已存在该代理的状态
              Map<String, dynamic>? existingProxy;
              for (var p in _proxies) {
                if (p['name'] == proxy['name']) {
                  existingProxy = p;
                  break;
                }
              }

              proxies.add({
                'name': proxy['name'],
                'type': proxy['type'] ?? 'v2ray',
                'latency':
                    existingProxy?['latency'] ??
                    proxy['latency'] ??
                    -2, // -2表示未测试
                'isSelected':
                    existingProxy?['isSelected'] ??
                    proxy['isSelected'] ??
                    false,
              });
            }
            break;

          default:
            // 不应该到达这里，因为已经检查了类型
            proxies = [];
        }
      } else {
        // 其他类型的代理源不支持代理列表
        proxies = [];
      }

      setProxies(proxies);
    } catch (e) {
      Logger.error('加载代理列表失败: $e');
      setProxies([]); // 出错时清空代理列表
    } finally {
      setIsLoadingProxies(false);
    }
  }

  // 获取Shadowsocks代理列表
  Future<List<Map<String, dynamic>>> getShadowsocksProxies() async {
    try {
      // 获取当前选中的配置
      final configs = await ConfigManager.loadConfigs();
      final currentConfig = configs.firstWhere(
        (config) => config.id == _selectedConfig,
        orElse: () => configs.first,
      );

      // 检查配置是否为Shadowsocks类型
      if (currentConfig.type != VPNType.shadowsocks) {
        return [];
      }

      List<Map<String, dynamic>> proxies = [];

      // 如果是订阅链接，从订阅获取代理列表
      if (currentConfig.configPath.startsWith('http')) {
        proxies = await _vpnManager.getShadowsocksProxiesFromSubscription(
          currentConfig.configPath,
        );
      } else {
        // 如果是本地配置文件，从VPNManager获取代理列表
        proxies = await _vpnManager.getShadowsocksProxies();
      }

      // 保留原有代理的状态
      for (var i = 0; i < proxies.length; i++) {
        // 检查是否已存在该代理的状态
        Map<String, dynamic>? existingProxy;
        for (var p in _proxies) {
          if (p['name'] == proxies[i]['name']) {
            existingProxy = p;
            break;
          }
        }

        if (existingProxy != null) {
          proxies[i] = Map<String, dynamic>.from(proxies[i])
            ..['latency'] = existingProxy['latency']
            ..['isSelected'] = existingProxy['isSelected'];
        }
      }

      return proxies;
    } catch (e) {
      Logger.error('获取Shadowsocks代理列表失败: $e');
      return [];
    }
  }

  // 获取V2Ray代理列表
  Future<List<Map<String, dynamic>>> getV2RayProxies() async {
    try {
      // 获取当前选中的配置
      final configs = await ConfigManager.loadConfigs();
      final currentConfig = configs.firstWhere(
        (config) => config.id == _selectedConfig,
        orElse: () => configs.first,
      );

      // 检查配置是否为V2Ray类型
      if (currentConfig.type != VPNType.v2ray) {
        return [];
      }

      List<Map<String, dynamic>> proxies = [];

      // 如果是订阅链接，从订阅获取代理列表
      if (currentConfig.configPath.startsWith('http')) {
        proxies = await _vpnManager.getV2RayProxiesFromSubscription(
          currentConfig.configPath,
        );
      } else {
        // 如果是本地配置文件，从VPNManager获取代理列表
        proxies = await _vpnManager.getV2RayProxies();
      }

      // 保留原有代理的状态
      for (var i = 0; i < proxies.length; i++) {
        // 检查是否已存在该代理的状态
        Map<String, dynamic>? existingProxy;
        for (var p in _proxies) {
          if (p['name'] == proxies[i]['name']) {
            existingProxy = p;
            break;
          }
        }

        if (existingProxy != null) {
          proxies[i] = Map<String, dynamic>.from(proxies[i])
            ..['latency'] = existingProxy['latency']
            ..['isSelected'] = existingProxy['isSelected'];
        }
      }

      return proxies;
    } catch (e) {
      Logger.error('获取V2Ray代理列表失败: $e');
      return [];
    }
  }
}
