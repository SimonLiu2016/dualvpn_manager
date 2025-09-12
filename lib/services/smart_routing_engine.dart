import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/utils/logger.dart';
import 'dart:io';

/// 智能路由决策引擎
/// 根据路由规则和目标地址决定使用哪个代理
class SmartRoutingEngine {
  final List<RoutingRule> _routingRules = [];
  final List<VPNConfig> _activeConfigs = [];

  // 设置路由规则
  void setRoutingRules(List<RoutingRule> rules) {
    _routingRules.clear();
    _routingRules.addAll(rules);
    Logger.info('智能路由引擎已更新路由规则，共${rules.length}条');
  }

  // 设置活动配置
  void setActiveConfigs(List<VPNConfig> configs) {
    _activeConfigs.clear();
    _activeConfigs.addAll(configs);
    Logger.info('智能路由引擎已更新活动配置，共${configs.length}个');
  }

  // 根据目标地址选择代理配置
  VPNConfig? selectProxyForDestination(String destination) {
    // 首先检查是否有匹配的路由规则
    for (final rule in _routingRules) {
      if (!rule.isEnabled) continue;

      // 检查目标地址是否匹配规则模式
      if (_matchesPattern(destination, rule.pattern)) {
        // 根据规则中的配置ID查找对应的配置
        if (rule.configId != null) {
          final config = _activeConfigs.firstWhere(
            (config) => config.id == rule.configId && config.isActive,
            orElse: () => _findConfigByType(rule.routeType),
          );
          if (config.id.isNotEmpty && config.isActive) {
            Logger.debug(
              '目标地址 $destination 匹配路由规则 ${rule.pattern}，使用代理 ${config.name}',
            );
            return config;
          }
        } else {
          // 回退到根据路由类型查找配置
          final config = _findConfigByType(rule.routeType);
          if (config.id.isNotEmpty && config.isActive) {
            Logger.debug(
              '目标地址 $destination 匹配路由规则 ${rule.pattern}，使用代理 ${config.name}',
            );
            return config;
          }
        }
      }
    }

    // 如果没有匹配的路由规则，默认不使用代理
    Logger.debug('目标地址 $destination 未匹配任何路由规则，默认不使用代理');
    return null;
  }

  // 检查目标地址是否匹配模式
  bool _matchesPattern(String destination, String pattern) {
    try {
      // 完全匹配
      if (destination == pattern) {
        return true;
      }

      // 处理IP地址范围匹配 (例如: 192.168.1.0/24)
      if (pattern.contains('/')) {
        return _matchesCIDR(destination, pattern);
      }

      // 后缀匹配（用于子域名）
      if (pattern.startsWith('*.')) {
        final domain = pattern.substring(2);
        return destination == domain || destination.endsWith('.$domain');
      }

      // 前缀匹配
      if (pattern.endsWith('*')) {
        final prefix = pattern.substring(0, pattern.length - 1);
        return destination.startsWith(prefix);
      }

      // 正则表达式匹配
      if (pattern.startsWith('/') && pattern.endsWith('/')) {
        final regexPattern = pattern.substring(1, pattern.length - 1);
        return RegExp(regexPattern).hasMatch(destination);
      }

      return false;
    } catch (e) {
      Logger.error('匹配模式时出错: $e');
      return false;
    }
  }

  // CIDR匹配 (IP地址范围匹配)
  bool _matchesCIDR(String ip, String cidr) {
    try {
      final parts = cidr.split('/');
      if (parts.length != 2) return false;

      final network = parts[0];
      final prefixLength = int.parse(parts[1]);

      final ipParts = ip.split('.').map(int.parse).toList();
      final networkParts = network.split('.').map(int.parse).toList();

      final ipInt =
          (ipParts[0] << 24) +
          (ipParts[1] << 16) +
          (ipParts[2] << 8) +
          ipParts[3];
      final networkInt =
          (networkParts[0] << 24) +
          (networkParts[1] << 16) +
          (networkParts[2] << 8) +
          networkParts[3];
      final mask = ~((1 << (32 - prefixLength)) - 1);

      return (ipInt & mask) == (networkInt & mask);
    } catch (e) {
      Logger.error('CIDR匹配时出错: $e');
      return false;
    }
  }

  // 根据路由类型查找配置
  VPNConfig _findConfigByType(RouteType routeType) {
    for (final config in _activeConfigs) {
      if (!config.isActive) continue;

      switch (routeType) {
        case RouteType.openVPN:
          if (config.type == VPNType.openVPN) return config;
          break;
        case RouteType.clash:
          if (config.type == VPNType.clash) return config;
          break;
        case RouteType.shadowsocks:
          if (config.type == VPNType.shadowsocks) return config;
          break;
        case RouteType.v2ray:
          if (config.type == VPNType.v2ray) return config;
          break;
        case RouteType.httpProxy:
          if (config.type == VPNType.httpProxy) return config;
          break;
        case RouteType.socks5:
          if (config.type == VPNType.socks5) return config;
          break;
        case RouteType.custom:
          if (config.type == VPNType.custom) return config;
          break;
      }
    }

    // 如果没有找到匹配的配置，返回空配置
    return VPNConfig(
      id: '',
      name: '未找到配置',
      type: VPNType.openVPN,
      configPath: '',
      settings: {},
    );
  }

  // 获取所有活动配置的代理信息
  List<Map<String, dynamic>> getActiveProxyInfo() {
    final List<Map<String, dynamic>> proxyInfo = [];

    for (final config in _activeConfigs) {
      if (!config.isActive) continue;

      proxyInfo.add({
        'configId': config.id,
        'configName': config.name,
        'type': config.type,
        'settings': config.settings,
      });
    }

    return proxyInfo;
  }
}
