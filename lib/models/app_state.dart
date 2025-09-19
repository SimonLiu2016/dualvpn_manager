import 'package:flutter/material.dart';
import 'package:dualvpn_manager/services/vpn_manager.dart';
import 'package:dualvpn_manager/services/proxy_manager.dart';
import 'package:dualvpn_manager/models/vpn_config.dart' hide RoutingRule;
import 'package:dualvpn_manager/services/smart_routing_engine.dart'
    as smart_routing_engine;
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:dualvpn_manager/utils/tray_manager.dart';
import 'dart:io';
import 'dart:convert';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  final VPNManager _vpnManager = VPNManager();
  final ProxyManager _proxyManager = ProxyManager();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final DualVPNTrayManager _trayManager;

  // 添加路由规则存储键
  static const String _routingRulesKey = 'routing_rules';

  // 添加代理列表状态存储键
  static const String _proxyStatesKey = 'proxy_states';

  // 添加路由规则更新队列和锁
  bool _isUpdatingRules = false;
  final List<Future<void> Function()> _pendingRuleUpdates = [];

  AppState({required DualVPNTrayManager trayManager})
    : _trayManager = trayManager {
    Logger.info('=== 开始初始化AppState ===');
    // 设置托盘管理器的显示窗口回调函数
    _trayManager.setShowWindowCallback(_showWindow);
    // 初始化时加载路由规则
    Logger.info('开始加载路由规则...');
    _loadRoutingRules();
    Logger.info('路由规则加载完成');
    // 初始化时加载代理列表状态
    Logger.info('开始加载代理列表状态...');
    _loadProxyStates();
    Logger.info('代理列表状态加载完成');
    // 初始化时启动Go代理核心
    Logger.info('开始初始化Go代理核心...');
    _initGoProxyCore();
    Logger.info('=== AppState初始化完成 ===');
  }

  // 显示主窗口
  void _showWindow() {
    // 使用window_manager显示窗口
    windowManager.show();
    windowManager.focus();
  }

  // 应用启动后已选中的代理
  Future<void> _applySelectedProxiesAfterStartup() async {
    try {
      Logger.info('=== 开始应用启动后已选中的代理 ===');
      Logger.info('当前代理缓存数量: ${_proxiesByConfig.length}');

      // 打印所有缓存的代理状态
      _proxiesByConfig.forEach((configId, proxies) {
        Logger.info('配置 $configId 有 ${proxies.length} 个代理');
        for (var i = 0; i < proxies.length; i++) {
          final proxy = proxies[i];
          Logger.info(
            '  代理 $i: name=${proxy['name']}, latency=${proxy['latency']}, isSelected=${proxy['isSelected']}',
          );
        }
      });

      // 检查是否有任何选中的代理
      bool hasAnySelectedProxy = false;
      for (var entry in _proxiesByConfig.entries) {
        for (var proxy in entry.value) {
          if (proxy['isSelected'] == true) {
            Logger.info('找到选中的代理: ${proxy['name']} 在配置 ${entry.key} 中');
            hasAnySelectedProxy = true;
          }
        }
      }
      if (!hasAnySelectedProxy) {
        Logger.info('未找到任何选中的代理');
        Logger.info('=== 启动后已选中代理应用完成（无选中代理） ===');
        return;
      }

      // 获取所有配置
      final configs = await ConfigManager.loadConfigs();
      Logger.info('加载到 ${configs.length} 个配置');

      // 遍历所有已加载的代理配置
      for (var entry in _proxiesByConfig.entries) {
        final configId = entry.key;
        final proxies = entry.value;
        Logger.info('处理配置ID: $configId，代理数量: ${proxies.length}');

        // 查找对应的配置
        VPNConfig? config;
        try {
          config = configs.firstWhere((c) => c.id == configId);
          Logger.info(
            '找到配置: ${config.name}, 类型: ${config.type}, 是否启用: ${config.isActive}',
          );
        } catch (e) {
          Logger.warn('未找到配置ID为 $configId 的配置');
          continue;
        }

        // 检查配置是否启用
        if (!config.isActive) {
          Logger.info('配置 ${config.name} 未启用，跳过');
          continue;
        }

        // 查找已选中的代理
        Map<String, dynamic>? selectedProxy;
        try {
          selectedProxy = proxies.firstWhere(
            (proxy) => proxy['isSelected'] == true,
          );
          Logger.info('找到选中的代理: ${selectedProxy['name']}');
        } catch (e) {
          // 没有找到选中的代理
          Logger.info('配置 ${config.name} 中没有选中的代理');
          continue;
        }

        // 根据配置类型应用选中的代理
        switch (config.type) {
          case VPNType.clash:
            Logger.info(
              '应用Clash配置 ${config.name} 中选中的代理: ${selectedProxy['name']}',
            );
            // 设置当前配置为选中状态
            setSelectedConfig(configId);

            // 确保当前代理列表正确设置
            _proxies = List<Map<String, dynamic>>.from(proxies);
            Logger.info('更新当前代理列表，代理数量: ${_proxies.length}');

            // 连接Clash
            final connected = await connectClash(config);
            if (connected) {
              Logger.info('成功连接Clash配置 ${config.name}');

              // 应用选中的代理
              final result = await _vpnManager.selectClashProxy(
                'GLOBAL',
                selectedProxy['name'],
              );
              if (result) {
                Logger.info('成功应用Clash代理: ${selectedProxy['name']}');
                // 更新Clash连接状态
                setClashConnected(true);
              } else {
                Logger.error('应用Clash代理失败: ${selectedProxy['name']}');
              }
            } else {
              Logger.error('连接Clash配置 ${config.name} 失败');
            }
            break;

          case VPNType.shadowsocks:
            Logger.info(
              '应用Shadowsocks配置 ${config.name} 中选中的代理: ${selectedProxy['name']}',
            );
            // 设置当前配置为选中状态
            setSelectedConfig(configId);

            // 确保当前代理列表正确设置
            _proxies = List<Map<String, dynamic>>.from(proxies);
            Logger.info('更新当前代理列表，代理数量: ${_proxies.length}');

            // 连接Shadowsocks
            final connected = await connectShadowsocks(config);
            if (connected) {
              Logger.info('成功连接Shadowsocks配置 ${config.name}');
              // 更新Shadowsocks连接状态
              setShadowsocksConnected(true);
            } else {
              Logger.error('连接Shadowsocks配置 ${config.name} 失败');
            }
            break;

          case VPNType.v2ray:
            Logger.info(
              '应用V2Ray配置 ${config.name} 中选中的代理: ${selectedProxy['name']}',
            );
            // 设置当前配置为选中状态
            setSelectedConfig(configId);

            // 确保当前代理列表正确设置
            _proxies = List<Map<String, dynamic>>.from(proxies);
            Logger.info('更新当前代理列表，代理数量: ${_proxies.length}');

            // 连接V2Ray
            final connected = await connectV2Ray(config);
            if (connected) {
              Logger.info('成功连接V2Ray配置 ${config.name}');
              // 更新V2Ray连接状态
              setV2RayConnected(true);
            } else {
              Logger.error('连接V2Ray配置 ${config.name} 失败');
            }
            break;

          default:
            Logger.info('配置类型 ${config.type} 不支持代理列表');
        }
      }

      // 通知UI更新
      notifyListeners();
      Logger.info('=== 启动后已选中代理应用完成 ===');
    } catch (e, stackTrace) {
      Logger.error('应用启动后已选中的代理时出错: $e');
      Logger.error('Stack trace: $stackTrace');
    }
  }

  // 初始化Go代理核心
  void _initGoProxyCore() async {
    try {
      Logger.info('初始化Go代理核心...');
      // 延迟一段时间确保应用完全启动后再启动Go代理核心
      await Future.delayed(const Duration(seconds: 3));
      final result = await startGoProxy();
      if (result) {
        Logger.info('Go代理核心初始化成功');

        // 确保相关的代理已经连接
        await _ensureProxiesConnected();

        // 添加延迟确保代理连接完成
        await Future.delayed(const Duration(seconds: 2));

        // 应用已选中的代理到Clash服务
        Logger.info('开始应用启动后已选中的代理...');
        await _applySelectedProxiesAfterStartup();
        Logger.info('应用启动后已选中的代理完成');

        // 将路由规则发送到Go代理核心
        _sendRoutingRulesToGoProxy();
      } else {
        Logger.error('Go代理核心初始化失败');
      }
    } catch (e, stackTrace) {
      Logger.error('初始化Go代理核心时出错: $e');
      Logger.error('Stack trace: $stackTrace');
    }
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
  bool get isGoProxyRunning => _vpnManager.isGoProxyRunning;

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
  List<smart_routing_engine.RoutingRule> _routingRules = [];
  List<smart_routing_engine.RoutingRule> get routingRules => _routingRules;

  // 加载路由规则
  Future<void> _loadRoutingRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rulesJson = prefs.getString(_routingRulesKey);

      if (rulesJson != null && rulesJson.isNotEmpty) {
        final List<dynamic> rulesList = jsonDecode(rulesJson);
        _routingRules = rulesList
            .map(
              (rule) => smart_routing_engine.RoutingRule.fromJson(
                rule as Map<String, dynamic>,
              ),
            )
            .toList();
        Logger.info('成功加载${_routingRules.length}条路由规则');
      } else {
        _routingRules = [];
        Logger.info('未找到已保存的路由规则');
      }
      notifyListeners();

      // 将路由规则传递给Go代理核心
      _sendRoutingRulesToGoProxy();

      // 确保相关的代理已经连接
      await _ensureProxiesConnected();
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

  // 加载代理列表状态
  Future<void> _loadProxyStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? statesJson = prefs.getString(_proxyStatesKey);

      Logger.info('=== 开始加载代理状态 ===');
      Logger.info('_proxyStatesKey: $_proxyStatesKey');
      Logger.info('statesJson: $statesJson');

      if (statesJson != null && statesJson.isNotEmpty) {
        final Map<String, dynamic> statesMap = jsonDecode(statesJson);
        _proxiesByConfig.clear();

        statesMap.forEach((configId, proxiesList) {
          Logger.info('处理配置ID: $configId');
          if (proxiesList is List) {
            final List<Map<String, dynamic>> proxies = proxiesList
                .map((proxy) => proxy as Map<String, dynamic>)
                .toList();
            _proxiesByConfig[configId] = proxies;
            Logger.info('配置 $configId 有 ${proxies.length} 个代理');
            // 打印每个代理的详细信息
            for (var i = 0; i < proxies.length; i++) {
              final proxy = proxies[i];
              Logger.info(
                '  代理 $i: name=${proxy['name']}, latency=${proxy['latency']}, isSelected=${proxy['isSelected']}',
              );
            }
          } else {
            Logger.warn('配置 $configId 的代理列表格式不正确');
          }
        });

        Logger.info('成功加载${_proxiesByConfig.length}个配置的代理状态');

        // 添加调试信息：检查是否有选中的代理
        bool hasSelectedProxy = false;
        for (var entry in _proxiesByConfig.entries) {
          for (var proxy in entry.value) {
            if (proxy['isSelected'] == true) {
              Logger.info('发现选中的代理: ${proxy['name']} 在配置 ${entry.key} 中');
              hasSelectedProxy = true;
            }
          }
        }
        if (!hasSelectedProxy) {
          Logger.info('未发现任何选中的代理');
        }

        // 确保相关的代理已经连接
        await _ensureProxiesConnected();

        // 将路由规则发送到Go代理核心
        _sendRoutingRulesToGoProxy();
      } else {
        Logger.info('未找到已保存的代理状态');
      }
      Logger.info('=== 代理状态加载完成 ===');
    } catch (e, stackTrace) {
      Logger.error('加载代理状态失败: $e');
      Logger.error('Stack trace: $stackTrace');
    }
  }

  // 保存代理列表状态
  Future<void> _saveProxyStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> statesJson = {};

      _proxiesByConfig.forEach((configId, proxies) {
        statesJson[configId] = proxies;
        Logger.info('准备保存配置 $configId 的代理状态，代理数量: ${proxies.length}');
        // 打印每个代理的详细信息
        for (var i = 0; i < proxies.length; i++) {
          final proxy = proxies[i];
          Logger.info(
            '  代理 $i: name=${proxy['name']}, latency=${proxy['latency']}, isSelected=${proxy['isSelected']}',
          );
        }
      });

      final statesJsonString = jsonEncode(statesJson);
      await prefs.setString(_proxyStatesKey, statesJsonString);
      Logger.info('代理状态已保存，共${_proxiesByConfig.length}个配置');
      Logger.info('保存的数据: $statesJsonString');
    } catch (e, stackTrace) {
      Logger.error('保存代理状态失败: $e');
      Logger.error('Stack trace: $stackTrace');
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

    Logger.debug('getSelectedProxies: 处理 ${enabledConfigs.length} 个启用的配置');

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

  // 重置路由规则更新状态（用于紧急情况下的状态恢复）
  void resetRoutingUpdateState() {
    Logger.info('重置路由规则更新状态');
    _isUpdatingRules = false;
    _pendingRuleUpdates.clear();
  }

  // 获取路由规则更新状态（用于调试）
  bool get isRoutingUpdating => _isUpdatingRules;
  int get pendingRoutingUpdates => _pendingRuleUpdates.length;

  // 设置当前选中的配置
  void setSelectedConfig(String configId) {
    Logger.info('=== 设置当前选中配置 ===');
    Logger.info('新的配置ID: $configId');
    Logger.info('旧的配置ID: $_selectedConfig');

    // 保存当前代理列表
    if (_selectedConfig.isNotEmpty) {
      _proxiesByConfig[_selectedConfig] = List<Map<String, dynamic>>.from(
        _proxies,
      );
      Logger.info('保存配置 $_selectedConfig 的代理列表，代理数量: ${_proxies.length}');
      // 打印每个代理的详细信息
      for (var i = 0; i < _proxies.length; i++) {
        final proxy = _proxies[i];
        Logger.info(
          '  保存的代理 $i: name=${proxy['name']}, latency=${proxy['latency']}, isSelected=${proxy['isSelected']}',
        );
      }
    }

    _selectedConfig = configId;
    Logger.info('设置新的选中配置为: $_selectedConfig');

    // 恢复选中配置的代理列表
    if (_proxiesByConfig.containsKey(configId)) {
      _proxies = _proxiesByConfig[configId]!;
      Logger.info('从缓存恢复配置 $configId 的代理列表，代理数量: ${_proxies.length}');
      // 打印每个代理的详细信息
      for (var i = 0; i < _proxies.length; i++) {
        final proxy = _proxies[i];
        Logger.info(
          '  恢复的代理 $i: name=${proxy['name']}, latency=${proxy['latency']}, isSelected=${proxy['isSelected']}',
        );
      }
    } else {
      _proxies = [];
      Logger.info('配置 $configId 没有缓存的代理列表，初始化为空列表');
    }

    notifyListeners();
    Logger.info('=== 当前选中配置设置完成 ===');
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
  void setRoutingRules(List<smart_routing_engine.RoutingRule> rules) {
    _routingRules = rules;
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
    // 将路由规则传递给Go代理核心
    _sendRoutingRulesToGoProxy();
  }

  // 添加路由规则
  void addRoutingRule(smart_routing_engine.RoutingRule rule) {
    _routingRules.add(rule);
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
    // 将路由规则传递给Go代理核心
    _sendRoutingRulesToGoProxy();
  }

  // 删除路由规则
  void removeRoutingRule(smart_routing_engine.RoutingRule rule) {
    _routingRules.remove(rule);
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
    // 将路由规则传递给Go代理核心
    _sendRoutingRulesToGoProxy();
  }

  // 设置代理列表
  void setProxies(List<Map<String, dynamic>> proxies) {
    Logger.info('=== 设置代理列表 ===');
    Logger.info('新代理列表数量: ${proxies.length}');
    Logger.info('当前选中配置ID: $_selectedConfig');

    // 打印新代理列表的详细信息
    for (var i = 0; i < proxies.length; i++) {
      final proxy = proxies[i];
      Logger.info(
        '  新代理 $i: name=${proxy['name']}, latency=${proxy['latency']}, isSelected=${proxy['isSelected']}',
      );
    }

    _proxies = proxies;
    // 保存当前配置的代理列表
    if (_selectedConfig.isNotEmpty) {
      _proxiesByConfig[_selectedConfig] = proxies;
      Logger.info('保存配置 $_selectedConfig 的代理列表，代理数量: ${proxies.length}');
      // 保存到持久化存储
      _saveProxyStates();
    }
    notifyListeners();
    Logger.info('=== 代理列表设置完成 ===');
  }

  // 清除指定配置的代理列表缓存
  void clearProxyCache(String configId) {
    _proxiesByConfig.remove(configId);
    // 如果当前选中的配置就是被清除的配置，则清空当前代理列表
    if (_selectedConfig == configId) {
      _proxies = [];
      notifyListeners();
    }
    // 保存到持久化存储
    _saveProxyStates();
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
      // 保存到持久化存储
      _saveProxyStates();
    }
    notifyListeners();
  }

  // 设置代理选中状态
  void setProxySelected(String proxyName, bool isSelected) {
    Logger.info('=== 设置代理选中状态 ===');
    Logger.info('代理名称: $proxyName, 选中状态: $isSelected');
    Logger.info('当前代理列表数量: ${_proxies.length}');

    for (var i = 0; i < _proxies.length; i++) {
      if (_proxies[i]['name'] == proxyName) {
        Logger.info('找到代理 $proxyName 在索引 $i');
        _proxies[i] = Map<String, dynamic>.from(_proxies[i])
          ..['isSelected'] = isSelected;
        Logger.info(
          '更新代理状态: name=${_proxies[i]['name']}, isSelected=${_proxies[i]['isSelected']}',
        );

        // 如果选中了这个代理，取消其他代理的选中状态
        if (isSelected) {
          for (var j = 0; j < _proxies.length; j++) {
            if (j != i && _proxies[j]['isSelected'] == true) {
              Logger.info('取消代理 ${_proxies[j]['name']} 的选中状态');
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
      Logger.info(
        '更新配置 $_selectedConfig 的代理列表缓存，当前代理数量: ${_proxiesByConfig[_selectedConfig]?.length}',
      );
      // 保存到持久化存储
      _saveProxyStates();
    }
    notifyListeners();
    Logger.info('=== 代理选中状态设置完成 ===');
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

          // 将路由规则发送到Go代理核心
          _sendRoutingRulesToGoProxy();
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

  // 确保已选中的代理在Clash连接后能正确应用
  Future<void> ensureProxyAppliedForClash(VPNConfig config) async {
    try {
      // 如果Clash已连接，直接应用选中的代理
      if (_clashConnected) {
        await _applySelectedProxyForClash(config);
      }
    } catch (e) {
      Logger.error('确保Clash代理应用时出错: $e');
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

          // 将路由规则发送到Go代理核心
          _sendRoutingRulesToGoProxy();
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

        // 将路由规则发送到Go代理核心
        _sendRoutingRulesToGoProxy();
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

        // 将路由规则发送到Go代理核心
        _sendRoutingRulesToGoProxy();
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

        // 将路由规则发送到Go代理核心
        _sendRoutingRulesToGoProxy();
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

        // 将路由规则发送到Go代理核心
        _sendRoutingRulesToGoProxy();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(
            navigatorKey.currentContext!,
          ).showSnackBar(SnackBar(content: Text('更新Clash订阅失败: $e')));
        }
      });
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(
            navigatorKey.currentContext!,
          ).showSnackBar(SnackBar(content: Text('更新Shadowsocks订阅失败: $e')));
        }
      });
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(
            navigatorKey.currentContext!,
          ).showSnackBar(SnackBar(content: Text('更新V2Ray订阅失败: $e')));
        }
      });
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
            if (navigatorKey.currentContext != null) {
              ScaffoldMessenger.of(
                navigatorKey.currentContext!,
              ).showSnackBar(const SnackBar(content: Text('该代理类型不支持订阅更新')));
            }
          });
          result = false;
      }

      return result;
    } catch (e) {
      Logger.error('更新${config.type}订阅失败: $e');
      // 通知UI显示错误
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(
            navigatorKey.currentContext!,
          ).showSnackBar(SnackBar(content: Text('更新${config.type}订阅失败: $e')));
        }
      });
      return false;
    }
  }

  // 配置智能路由
  Future<bool> configureRouting() async {
    try {
      // 获取所有配置以获取强制路由规则
      final configs = await ConfigManager.loadConfigs();
      final List<smart_routing_engine.RoutingRule> forcedRules = [];

      // 收集所有启用的强制路由规则
      for (var config in configs) {
        // 注意：这里的config.routingRules是来自vpn_config.dart的RoutingRule
        // 我们需要将其转换为smart_routing_engine.dart中的RoutingRule
        for (var rule in config.routingRules.where((rule) => rule.isEnabled)) {
          forcedRules.add(
            smart_routing_engine.RoutingRule(
              id: rule.pattern, // 使用pattern作为ID
              pattern: rule.pattern,
              type: _convertRouteTypeToRuleType(rule.routeType),
              proxyId: rule.configId ?? '',
              isEnabled: rule.isEnabled,
            ),
          );
        }
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

  // 转换RouteType到RuleType
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
      default:
        return smart_routing_engine.RuleType.domainSuffix;
    }
  }

  // 设置活动配置到代理管理器
  void setActiveConfigs(List<VPNConfig> configs) {
    // 将活动配置转换为Map格式
    final activeProxies = <String, VPNConfig>{};
    for (final config in configs) {
      if (config.isActive) {
        activeProxies[config.id] = config;
      }
    }
    _proxyManager.updateActiveProxies(activeProxies);
  }

  // 启用路由
  Future<void> enableRouting() async {
    try {
      Logger.info('开始启用路由...');

      // 更新活动配置到代理管理器
      final configs = await ConfigManager.loadConfigs();
      Logger.info('加载配置完成，共${configs.length}个配置');
      setActiveConfigs(configs);

      // 启动本地代理服务
      Logger.info('尝试启动本地SOCKS5代理服务...');
      final proxyStarted = await _proxyManager.startProxyService();
      if (proxyStarted) {
        Logger.info('本地SOCKS5代理服务启动成功，端口: ${_proxyManager.proxyPort}');
        // 更新代理管理器的路由规则
        Logger.info('更新代理管理器的路由规则，共${_routingRules.length}条');
        _proxyManager.setRoutingRules(_routingRules);
        // 设置系统代理指向本地SOCKS5代理服务
        Logger.info(
          '设置系统代理指向本地SOCKS5代理服务 (127.0.0.1:${_proxyManager.proxyPort})',
        );
        // 更新VPNManager中的系统代理设置方法，使用实际端口
        await _vpnManager.enableSmartRouting(
          socksPort: _proxyManager.proxyPort,
        );
        Logger.info('智能路由已启用，系统代理已设置');
      } else {
        Logger.error('启动本地SOCKS5代理服务失败');
        // 通知UI显示错误
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(
            navigatorKey.currentContext!,
          ).showSnackBar(const SnackBar(content: Text('启动本地SOCKS5代理服务失败')));
        }
        return;
      }

      // 确保相关的代理已经连接并添加协议到Go代理核心
      Logger.info('确保相关代理已连接并添加协议到Go代理核心');
      await _ensureProxiesConnected();

      // 将路由规则发送到Go代理核心
      Logger.info('将路由规则发送到Go代理核心');
      _sendRoutingRulesToGoProxy();

      setIsRunning(true);
      Logger.info('路由启用完成');
      // 通知UI显示成功信息
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(
          navigatorKey.currentContext!,
        ).showSnackBar(const SnackBar(content: Text('路由已启用')));
      }
    } catch (e) {
      Logger.error('启用路由失败: $e');
      // 通知UI显示错误
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(
          navigatorKey.currentContext!,
        ).showSnackBar(SnackBar(content: Text('启用路由失败: $e')));
      }
    }
  }

  // 禁用路由
  Future<void> disableRouting() async {
    try {
      Logger.info('开始禁用路由...');

      // 清空路由规则
      Logger.info('清空路由规则');
      _proxyManager.setRoutingRules([]);

      // 停止本地代理服务
      Logger.info('停止本地代理服务');
      await _proxyManager.stopProxyService();

      // 清除系统代理设置
      Logger.info('清除系统代理设置');
      await _vpnManager.disableSmartRouting();

      setIsRunning(false);
      Logger.info('路由规则已清空，本地代理服务已停止，系统代理已清除');
    } catch (e) {
      Logger.error('清空路由规则失败: $e');
      // 通知UI显示错误
    }
  }

  // 启用所有路由规则
  void enableAllRoutingRules() {
    final List<smart_routing_engine.RoutingRule> updatedRules = _routingRules
        .map((rule) {
          return smart_routing_engine.RoutingRule(
            id: rule.id,
            pattern: rule.pattern,
            type: rule.type,
            proxyId: rule.proxyId,
            isEnabled: true, // 将所有规则设置为启用
          );
        })
        .toList();

    _routingRules = updatedRules;
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
    // 将路由规则发送到Go代理核心
    _sendRoutingRulesToGoProxy();
  }

  // 禁用所有路由规则
  void disableAllRoutingRules() {
    final List<smart_routing_engine.RoutingRule> updatedRules = _routingRules
        .map((rule) {
          return smart_routing_engine.RoutingRule(
            id: rule.id,
            pattern: rule.pattern,
            type: rule.type,
            proxyId: rule.proxyId,
            isEnabled: false, // 将所有规则设置为禁用
          );
        })
        .toList();

    _routingRules = updatedRules;
    notifyListeners();
    // 保存到持久化存储
    _saveRoutingRules();
    // 将路由规则发送到Go代理核心
    _sendRoutingRulesToGoProxy();
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
              final proxiesMap = proxiesData['proxies'];
              if (proxiesMap is Map) {
                proxiesMap.forEach((name, proxy) {
                  if (name is String) {
                    // 检查是否已存在该代理的状态
                    Map<String, dynamic>? existingProxy;
                    for (var p in _proxies) {
                      if (p['name'] == name) {
                        existingProxy = p;
                        break;
                      }
                    }

                    // 从proxy对象中提取类型信息
                    String type = 'unknown';
                    if (proxy is Map && proxy.containsKey('type')) {
                      type = proxy['type'].toString();
                    }

                    proxies.add({
                      'name': name,
                      'type': type,
                      'latency': existingProxy?['latency'] ?? -2, // -2表示未测试
                      'isSelected': existingProxy?['isSelected'] ?? false,
                    });
                  }
                });
              }
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

  // 将路由规则发送到Go代理核心
  Future<void> _sendRoutingRulesToGoProxy() async {
    // 创建更新任务
    final updateTask = () async {
      try {
        Logger.info('=== 开始发送路由规则到Go代理核心 ===');
        Logger.info('当前规则数量: ${_routingRules.length}');

        // 打印所有路由规则的详细信息
        for (var i = 0; i < _routingRules.length; i++) {
          final rule = _routingRules[i];
          Logger.info(
            '路由规则 $i: type=${rule.type}, pattern=${rule.pattern}, proxyId=${rule.proxyId}, isEnabled=${rule.isEnabled}',
          );
        }

        // 确保Go代理核心已经完全启动并准备好接收规则
        // 等待更长时间确保API服务器已启动
        Logger.info('等待Go代理核心完全启动...');
        await Future.delayed(const Duration(seconds: 5));

        // 确保相关的代理已经连接
        Logger.info('开始确保相关代理已连接...');
        await _ensureProxiesConnected();

        // 添加延迟以确保协议已添加到Go代理核心
        Logger.info('等待协议添加完成...');
        await Future.delayed(const Duration(seconds: 2));

        // 验证协议是否已正确添加到Go代理核心
        try {
          Logger.info('=== 开始验证Go代理核心协议列表 ===');
          final protocols = await _vpnManager.getGoProxyProtocols().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              Logger.error('获取Go代理核心协议列表超时');
              return null;
            },
          );
          if (protocols != null) {
            Logger.info('Go代理核心当前协议列表: ${protocols.keys.join(', ')}');
            // 打印每个协议的详细信息
            protocols.forEach((key, value) {
              Logger.info('协议 $key: $value');
            });
          } else {
            Logger.error('无法获取Go代理核心协议列表');
          }
          Logger.info('=== Go代理核心协议列表验证完成 ===');
        } catch (e) {
          Logger.error('验证Go代理核心协议列表时出错: $e');
        }

        // 获取选中的代理并打印详细信息
        Logger.info('=== 开始获取选中的代理信息 ===');
        try {
          final selectedProxies = await getSelectedProxies();
          Logger.info('找到 ${selectedProxies.length} 个选中的代理');

          for (var i = 0; i < selectedProxies.length; i++) {
            final proxyInfo = selectedProxies[i];
            final config = proxyInfo['config'] as VPNConfig;
            final proxy = proxyInfo['proxy'] as Map<String, dynamic>;

            Logger.info('选中的代理 $i:');
            Logger.info('  - 配置名称: ${config.name}');
            Logger.info('  - 配置ID: ${config.id}');
            Logger.info('  - 配置类型: ${config.type}');
            Logger.info('  - 代理名称: ${proxy['name']}');
            Logger.info('  - 代理类型: ${proxy['type']}');
            Logger.info('  - 是否选中: ${proxy['isSelected']}');

            // 测试代理的可用性
            if (config.type == VPNType.clash) {
              Logger.info('  - 正在测试Clash代理可用性...');
              try {
                final clashProxies = await _vpnManager.getClashProxies();
                if (clashProxies != null) {
                  Logger.info('  - Clash代理列表获取成功');
                  // 检查选中的代理是否在Clash代理列表中
                  final proxiesData = clashProxies['proxies'] as Map?;
                  if (proxiesData != null &&
                      proxiesData.containsKey(proxy['name'])) {
                    Logger.info('  - 选中的代理 ${proxy['name']} 在Clash代理列表中');
                  } else {
                    Logger.warn('  - 选中的代理 ${proxy['name']} 不在Clash代理列表中');
                  }
                } else {
                  Logger.warn('  - 无法获取Clash代理列表');
                }
              } catch (e) {
                Logger.error('  - 测试Clash代理可用性时出错: $e');
              }
            }
          }
        } catch (e) {
          Logger.error('获取选中的代理信息时出错: $e');
        }
        Logger.info('=== 选中的代理信息获取完成 ===');

        // 将路由规则转换为Go核心可以理解的格式
        final List<Map<String, dynamic>> goRules = [];

        // 添加默认的MATCH规则作为最后一条规则
        bool hasMatchRule = false;

        for (var rule in _routingRules) {
          // 根据proxyId获取配置信息
          final config = await ConfigManager.getConfig(rule.proxyId);
          String proxySource = 'DIRECT'; // 默认直连

          if (config != null) {
            // 根据配置类型确定代理源
            switch (config.type) {
              case VPNType.openVPN:
                proxySource = 'openvpn';
                break;
              case VPNType.clash:
                // 修复：使用与VPN管理器中一致的名称'clash'
                proxySource = 'clash';
                break;
              case VPNType.shadowsocks:
                proxySource = 'shadowsocks';
                break;
              case VPNType.v2ray:
                proxySource = 'v2ray';
                break;
              case VPNType.httpProxy:
                proxySource = 'http';
                break;
              case VPNType.socks5:
                proxySource = 'socks5';
                break;
              default:
                proxySource = 'DIRECT';
            }
          }

          // 检查是否是MATCH规则
          if (rule.type == smart_routing_engine.RuleType.finalRule) {
            hasMatchRule = true;
          }

          goRules.add({
            'type': _convertRuleTypeToGoType(rule.type),
            'pattern': rule.pattern,
            'proxy_source': proxySource,
            'enabled': rule.isEnabled,
          });
        }

        // 如果没有MATCH规则，添加一个默认的MATCH规则
        if (!hasMatchRule) {
          goRules.add({
            'type': 'MATCH',
            'pattern': '',
            'proxy_source': 'DIRECT',
            'enabled': true,
          });
        }

        // 添加调试日志
        Logger.info('准备发送 ${goRules.length} 条路由规则到Go代理核心');
        for (var i = 0; i < goRules.length; i++) {
          final rule = goRules[i];
          Logger.info(
            '规则 $i: type=${rule['type']}, pattern=${rule['pattern']}, proxy_source=${rule['proxy_source']}, enabled=${rule['enabled']}',
          );
        }

        // 发送到Go代理核心，添加超时机制
        bool result = false;
        try {
          Logger.info('开始发送路由规则到Go代理核心...');
          result = await _vpnManager
              .updateGoProxyRules(goRules)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  Logger.error('发送路由规则到Go代理核心超时');
                  return false;
                },
              );
        } catch (e) {
          Logger.error('发送路由规则到Go代理核心时出错: $e');
          result = false;
        }

        if (result) {
          Logger.info('成功将路由规则发送到Go代理核心');

          // 验证规则是否正确保存
          try {
            await Future.delayed(const Duration(milliseconds: 500));
            final verifyRules = await _vpnManager.getGoProxyRules().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                Logger.error('获取Go代理核心路由规则超时');
                return null;
              },
            );
            if (verifyRules != null) {
              Logger.info('验证路由规则: ${verifyRules.length} 条规则');
              for (var i = 0; i < verifyRules.length; i++) {
                final rule = verifyRules[i];
                Logger.info(
                  '验证规则 $i: type=${rule['type']}, pattern=${rule['pattern']}, proxy_source=${rule['proxy_source']}, enabled=${rule['enabled']}',
                );
              }
            }
          } catch (e) {
            Logger.error('验证路由规则时出错: $e');
          }
        } else {
          Logger.error('将路由规则发送到Go代理核心失败');
        }

        Logger.info('=== 路由规则发送完成 ===');
      } catch (e, stackTrace) {
        Logger.error('发送路由规则到Go代理核心时发生未捕获的异常: $e\nStack trace: $stackTrace');
      }
    };

    // 执行更新任务
    await updateTask();
  }

  // 确保相关的代理已经连接
  Future<void> _ensureProxiesConnected() async {
    try {
      // 获取所有配置
      final configs = await ConfigManager.loadConfigs();

      // 创建一个集合来跟踪已经处理过的配置ID
      final processedConfigIds = <String>{};

      // 遍历所有路由规则，确保相关的代理已经连接
      for (var rule in _routingRules) {
        // 跳过已经处理过的配置
        if (processedConfigIds.contains(rule.proxyId)) {
          continue;
        }

        // 标记为已处理
        processedConfigIds.add(rule.proxyId);

        // 根据proxyId获取配置信息
        VPNConfig config;
        try {
          config = configs.firstWhere((c) => c.id == rule.proxyId);
        } catch (e) {
          // 配置不存在
          continue;
        }

        // 如果配置不是活动的，跳过
        if (!config.isActive) {
          continue;
        }

        // 根据配置类型连接相应的代理
        switch (config.type) {
          case VPNType.clash:
            Logger.info('正在连接Clash代理: ${config.name}');
            final result = await _vpnManager.connectClash(config);
            if (result) {
              Logger.info('成功连接Clash代理: ${config.name}');

              // 添加协议到Go代理核心（如果尚未添加）
              await _addProtocolToGoProxy('clash', config);
            } else {
              Logger.error('连接Clash代理失败: ${config.name}');
            }
            break;
          case VPNType.shadowsocks:
            Logger.info('正在连接Shadowsocks代理: ${config.name}');
            final result = await _vpnManager.connectShadowsocks(config);
            if (result) {
              Logger.info('成功连接Shadowsocks代理: ${config.name}');

              // 添加协议到Go代理核心（如果尚未添加）
              await _addProtocolToGoProxy('shadowsocks', config);
            } else {
              Logger.error('连接Shadowsocks代理失败: ${config.name}');
            }
            break;
          case VPNType.v2ray:
            Logger.info('正在连接V2Ray代理: ${config.name}');
            final result = await _vpnManager.connectV2Ray(config);
            if (result) {
              Logger.info('成功连接V2Ray代理: ${config.name}');

              // 添加协议到Go代理核心（如果尚未添加）
              await _addProtocolToGoProxy('v2ray', config);
            } else {
              Logger.error('连接V2Ray代理失败: ${config.name}');
            }
            break;
          case VPNType.httpProxy:
            Logger.info('正在连接HTTP代理: ${config.name}');
            final result = await _vpnManager.connectHTTPProxy(config);
            if (result) {
              Logger.info('成功连接HTTP代理: ${config.name}');

              // 添加协议到Go代理核心（如果尚未添加）
              await _addProtocolToGoProxy('http', config);
            } else {
              Logger.error('连接HTTP代理失败: ${config.name}');
            }
            break;
          case VPNType.socks5:
            Logger.info('正在连接SOCKS5代理: ${config.name}');
            final result = await _vpnManager.connectSOCKS5Proxy(config);
            if (result) {
              Logger.info('成功连接SOCKS5代理: ${config.name}');

              // 添加协议到Go代理核心（如果尚未添加）
              await _addProtocolToGoProxy('socks5', config);
            } else {
              Logger.error('连接SOCKS5代理失败: ${config.name}');
            }
            break;
          default:
            // 对于DIRECT、OPENVPN等其他类型，不需要特殊处理
            break;
        }
      }
    } catch (e, stackTrace) {
      Logger.error('确保代理连接时出错: $e\nStack trace: $stackTrace');
    }
  }

  // 添加协议到Go代理核心
  Future<void> _addProtocolToGoProxy(
    String protocolType,
    VPNConfig config,
  ) async {
    try {
      // 检查协议是否已经添加
      final protocols = await _vpnManager.getGoProxyProtocols();
      bool protocolExists = false;

      if (protocols != null && protocols.containsKey('protocols')) {
        final protocolList = protocols['protocols'] as Map?;
        if (protocolList != null) {
          protocolExists = protocolList.containsKey(protocolType);
        }
      }

      if (!protocolExists) {
        Logger.info('正在添加$protocolType协议到Go代理核心');

        Map<String, dynamic> protocolConfig;
        switch (protocolType) {
          case 'clash':
            protocolConfig = {
              'name': 'clash',
              'type': 'http',
              'server': '127.0.0.1',
              'port': 7890, // Clash默认HTTP端口
            };
            break;
          case 'shadowsocks':
            protocolConfig = {
              'name': 'shadowsocks',
              'type': 'socks5',
              'server': '127.0.0.1',
              'port': 1080, // Shadowsocks默认端口
            };
            break;
          case 'v2ray':
            protocolConfig = {
              'name': 'v2ray',
              'type': 'socks5',
              'server': '127.0.0.1',
              'port': 1080, // V2Ray默认端口
            };
            break;
          case 'http':
            protocolConfig = {
              'name': 'http',
              'type': 'http',
              'server': '127.0.0.1',
              'port': 8080, // HTTP代理默认端口
            };
            break;
          case 'socks5':
            protocolConfig = {
              'name': 'socks5',
              'type': 'socks5',
              'server': '127.0.0.1',
              'port': 1080, // SOCKS5代理默认端口
            };
            break;
          default:
            Logger.warn('未知协议类型: $protocolType');
            return;
        }

        // 通过VPNManager添加协议
        final result = await _vpnManager.addProtocolToGoProxy(protocolConfig);
        if (result) {
          Logger.info('成功添加$protocolType协议到Go代理核心');
        } else {
          Logger.error('添加$protocolType协议到Go代理核心失败');
        }
      } else {
        Logger.info('$protocolType协议已存在于Go代理核心中');
      }
    } catch (e) {
      Logger.error('添加协议到Go代理核心时出错: $e');
    }
  }

  // 转换规则类型到Go核心可以理解的类型
  String _convertRuleTypeToGoType(smart_routing_engine.RuleType ruleType) {
    switch (ruleType) {
      case smart_routing_engine.RuleType.domain:
        return 'DOMAIN';
      case smart_routing_engine.RuleType.domainSuffix:
        return 'DOMAIN-SUFFIX';
      case smart_routing_engine.RuleType.domainKeyword:
        return 'DOMAIN-KEYWORD';
      case smart_routing_engine.RuleType.ip:
        return 'IP';
      case smart_routing_engine.RuleType.cidr:
        return 'IP-CIDR';
      case smart_routing_engine.RuleType.geoip:
        return 'GEOIP';
      case smart_routing_engine.RuleType.regexp:
        return 'REGEXP';
      case smart_routing_engine.RuleType.finalRule:
        return 'MATCH';
      default:
        return 'MATCH';
    }
  }

  // 转换代理ID到Go核心可以理解的代理源
  String _convertProxyIdToGoProxySource(String proxyId) {
    // 这个方法现在不再使用，但我们保留它以避免破坏其他代码
    // 实际的代理源转换在_sendRoutingRulesToGoProxy方法中完成
    return 'DIRECT';
  }

  // 启动Go代理核心
  Future<bool> startGoProxy() async {
    try {
      final result = await _vpnManager.startGoProxy();
      if (result) {
        _isRunning = true;
        notifyListeners();
      }
      return result;
    } catch (e) {
      Logger.error('启动Go代理核心失败: $e');
      return false;
    }
  }

  // 停止Go代理核心
  Future<void> stopGoProxy() async {
    try {
      await _vpnManager.stopGoProxy();
      _isRunning = false;
      notifyListeners();
    } catch (e) {
      Logger.error('停止Go代理核心失败: $e');
      rethrow;
    }
  }

  // 手动应用启动后已选中的代理（用于调试）
  Future<void> applySelectedProxiesManually() async {
    Logger.info('=== 手动应用选中的代理 ===');
    await _applySelectedProxiesAfterStartup();
    Logger.info('=== 手动应用选中的代理完成 ===');
  }
}
