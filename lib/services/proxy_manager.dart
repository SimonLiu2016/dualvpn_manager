import 'package:dualvpn_manager/models/vpn_config.dart' hide RoutingRule;
import 'package:dualvpn_manager/services/smart_routing_engine.dart'
    as smart_routing_engine;
import 'package:dualvpn_manager/utils/logger.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:dualvpn_manager/services/socks5_proxy_server.dart';

/// 代理管理器
/// 负责管理多个代理的协调工作和流量转发
class ProxyManager {
  final smart_routing_engine.SmartRoutingEngine _routingEngine =
      smart_routing_engine.SmartRoutingEngine();
  final SOCKS5ProxyServer _proxyServer = SOCKS5ProxyServer();
  bool _isRunning = false;
  int _proxyPort = 1080; // 默认SOCKS5代理端口

  // 更新活动代理配置（公共方法）
  void updateActiveProxies(Map<String, VPNConfig> proxies) {
    _routingEngine.updateActiveProxies(proxies);
    _proxyServer.updateActiveProxies(proxies);
  }

  // 设置活动配置（已废弃，保留以兼容旧代码）
  void setActiveConfigs(List<VPNConfig> configs) {
    // 将活动配置转换为Map格式
    final activeProxies = <String, VPNConfig>{};
    for (final config in configs) {
      if (config.isActive) {
        activeProxies[config.id] = config;
      }
    }
    _routingEngine.updateActiveProxies(activeProxies);
    _proxyServer.updateActiveProxies(activeProxies);
  }

  // 设置路由规则
  void setRoutingRules(List<smart_routing_engine.RoutingRule> rules) {
    _routingEngine.updateRoutingRules(rules);
    _proxyServer.setRoutingRules(rules);
  }

  // 启动代理服务
  Future<bool> startProxyService() async {
    Logger.info(
      'startProxyService called, _isRunning: $_isRunning, _proxyPort: $_proxyPort',
    );

    if (_isRunning) {
      Logger.warn('代理服务已在运行中');
      return true;
    }

    try {
      Logger.info('尝试启动SOCKS5代理服务器，端口: $_proxyPort');
      // 启动SOCKS5代理服务器
      final result = await _proxyServer.start();
      _isRunning = result;

      if (result) {
        Logger.info('SOCKS5代理服务器启动成功，实际端口: ${_proxyServer.port}');
        // 更新代理端口为实际使用的端口
        _proxyPort = _proxyServer.port;
      } else {
        Logger.error('SOCKS5代理服务器启动失败');
      }

      return result;
    } catch (e, stackTrace) {
      Logger.error('启动代理服务失败: $e\nStack trace: $stackTrace');
      _isRunning = false;
      return false;
    }
  }

  // 停止代理服务
  Future<void> stopProxyService() async {
    Logger.info('stopProxyService called, _isRunning: $_isRunning');

    if (!_isRunning) {
      Logger.warn('代理服务未在运行中');
      return;
    }

    try {
      Logger.info('尝试关闭代理服务器');
      await _proxyServer.stop();
      _isRunning = false;
      Logger.info('代理服务已停止');
    } catch (e, stackTrace) {
      Logger.error('停止代理服务失败: $e\nStack trace: $stackTrace');
    }
  }

  // 获取代理服务状态
  bool get isRunning => _isRunning;

  // 设置代理端口
  void setProxyPort(int port) {
    _proxyPort = port;
  }

  // 获取代理端口
  int get proxyPort => _proxyPort;
}
