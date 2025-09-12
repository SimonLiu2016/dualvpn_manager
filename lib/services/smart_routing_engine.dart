import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/utils/logger.dart';

/// 路由决策结果
class RouteDecision {
  final bool shouldProxy;
  final VPNConfig? proxyConfig;
  final String reason;

  RouteDecision({
    required this.shouldProxy,
    this.proxyConfig,
    required this.reason,
  });
}

/// 路由规则类型
enum RuleType {
  domain, // 域名匹配
  domainSuffix, // 域名后缀匹配
  domainKeyword, // 域名关键字匹配
  ip, // IP地址匹配
  cidr, // CIDR IP段匹配
  geoip, // 地理位置IP匹配
  regexp, // 正则表达式匹配
  finalRule, // 最终规则（匹配所有）
}

/// 路由规则
class RoutingRule {
  final String id;
  final String pattern;
  final RuleType type;
  final String proxyId; // 对应的代理配置ID
  final bool isEnabled;

  RoutingRule({
    required this.id,
    required this.pattern,
    required this.type,
    required this.proxyId,
    this.isEnabled = true,
  });

  // 从JSON创建RoutingRule实例
  factory RoutingRule.fromJson(Map<String, dynamic> json) {
    return RoutingRule(
      id: json['id'] as String,
      pattern: json['pattern'] as String,
      type: RuleType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => RuleType.domain,
      ),
      proxyId: json['proxyId'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pattern': pattern,
      'type': type.toString(),
      'proxyId': proxyId,
      'isEnabled': isEnabled,
    };
  }
}

/// 智能路由引擎
/// 负责根据路由规则决定网络请求的走向
class SmartRoutingEngine {
  Map<String, VPNConfig> _activeProxies = {};
  List<RoutingRule> _routingRules = [];
  final RouteDecision _defaultDecision = RouteDecision(
    shouldProxy: false,
    reason: '默认直连',
  );

  /// 更新活动代理配置
  void updateActiveProxies(Map<String, VPNConfig> proxies) {
    _activeProxies = Map.from(proxies);
    Logger.debug('更新活动代理配置，共${_activeProxies.length}个');
  }

  /// 更新路由规则
  void updateRoutingRules(List<RoutingRule> rules) {
    _routingRules = List.from(rules);
    Logger.debug('更新路由规则，共${_routingRules.length}条');
  }

  /// 决定路由策略
  RouteDecision decideRoute(String host) {
    try {
      // 遍历路由规则，找到第一个匹配的规则
      for (final rule in _routingRules) {
        if (!rule.isEnabled) continue;

        bool isMatch = false;
        switch (rule.type) {
          case RuleType.domain:
            isMatch = _matchDomain(host, rule.pattern);
            break;
          case RuleType.domainSuffix:
            isMatch = _matchDomainSuffix(host, rule.pattern);
            break;
          case RuleType.domainKeyword:
            isMatch = _matchDomainKeyword(host, rule.pattern);
            break;
          case RuleType.ip:
            isMatch = _matchIP(host, rule.pattern);
            break;
          case RuleType.cidr:
            isMatch = _matchCIDR(host, rule.pattern);
            break;
          case RuleType.regexp:
            isMatch = _matchRegExp(host, rule.pattern);
            break;
          case RuleType.finalRule:
            isMatch = true; // 最终规则匹配所有
            break;
          default:
            isMatch = false;
        }

        if (isMatch) {
          // 找到匹配的规则，返回对应的代理配置
          final proxyConfig = _activeProxies[rule.proxyId];
          if (proxyConfig != null) {
            return RouteDecision(
              shouldProxy: true,
              proxyConfig: proxyConfig,
              reason: '匹配规则: ${rule.pattern}',
            );
          } else {
            // 规则匹配但对应的代理不可用，继续查找其他规则
            Logger.warn('规则匹配但代理不可用: ${rule.proxyId}');
            continue;
          }
        }
      }

      // 没有匹配的规则，使用默认决策
      return _defaultDecision;
    } catch (e) {
      Logger.error('路由决策失败: $e');
      return _defaultDecision;
    }
  }

  /// 域名完全匹配
  bool _matchDomain(String host, String pattern) {
    return host.toLowerCase() == pattern.toLowerCase();
  }

  /// 域名后缀匹配
  bool _matchDomainSuffix(String host, String pattern) {
    final lowerHost = host.toLowerCase();
    final lowerPattern = pattern.toLowerCase();
    return lowerHost == lowerPattern ||
        lowerHost.endsWith('.$lowerPattern') ||
        lowerHost.endsWith(lowerPattern);
  }

  /// 域名关键字匹配
  bool _matchDomainKeyword(String host, String pattern) {
    return host.toLowerCase().contains(pattern.toLowerCase());
  }

  /// IP地址匹配
  bool _matchIP(String host, String pattern) {
    // 简化实现，实际应该解析host是否为IP地址并进行比较
    return host == pattern;
  }

  /// CIDR IP段匹配
  bool _matchCIDR(String host, String pattern) {
    // 简化实现，实际应该解析host是否在指定CIDR范围内
    return false;
  }

  /// 正则表达式匹配
  bool _matchRegExp(String host, String pattern) {
    try {
      final regExp = RegExp(pattern, caseSensitive: false);
      return regExp.hasMatch(host);
    } catch (e) {
      Logger.error('正则表达式匹配失败: $e');
      return false;
    }
  }
}
