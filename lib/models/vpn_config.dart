class VPNConfig {
  final String id;
  final String name;
  final VPNType type;
  final String configPath; // 可以是文件路径、订阅链接或服务器地址
  final String? subscriptionUrl; // 订阅链接（新增字段）
  final Map<String, dynamic> settings;
  final bool isActive;
  // 添加强制路由规则列表
  final List<RoutingRule> routingRules;
  // 添加连接状态
  final ConnectionStatus connectionStatus;
  // 添加延迟信息
  final int latency; // 毫秒

  VPNConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.configPath,
    this.subscriptionUrl, // 新增字段
    required this.settings,
    this.isActive = false,
    this.routingRules = const [],
    this.connectionStatus = ConnectionStatus.disconnected,
    this.latency = -1, // -1表示未测试
  });

  // 从JSON创建VPNConfig实例
  factory VPNConfig.fromJson(Map<String, dynamic> json) {
    List<RoutingRule> rules = [];
    if (json['routingRules'] != null) {
      rules = (json['routingRules'] as List)
          .map((rule) => RoutingRule.fromJson(rule))
          .toList();
    }

    return VPNConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: VPNType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => VPNType.openVPN,
      ),
      configPath: json['configPath'] as String,
      subscriptionUrl: json['subscriptionUrl'] as String?, // 新增字段
      settings: Map<String, dynamic>.from(json['settings'] as Map),
      isActive: json['isActive'] as bool? ?? false,
      routingRules: rules,
      connectionStatus: ConnectionStatus.values.firstWhere(
        (e) => e.toString() == json['connectionStatus'],
        orElse: () => ConnectionStatus.disconnected,
      ),
      latency: json['latency'] as int? ?? -1,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'configPath': configPath,
      'subscriptionUrl': subscriptionUrl, // 新增字段
      'settings': settings,
      'isActive': isActive,
      'routingRules': routingRules.map((rule) => rule.toJson()).toList(),
      'connectionStatus': connectionStatus.toString(),
      'latency': latency,
    };
  }

  // 创建更新后的副本
  VPNConfig copyWith({
    String? id,
    String? name,
    VPNType? type,
    String? configPath,
    String? subscriptionUrl, // 新增字段
    Map<String, dynamic>? settings,
    bool? isActive,
    List<RoutingRule>? routingRules,
    ConnectionStatus? connectionStatus,
    int? latency,
  }) {
    return VPNConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      configPath: configPath ?? this.configPath,
      subscriptionUrl: subscriptionUrl ?? this.subscriptionUrl, // 新增字段
      settings: settings ?? this.settings,
      isActive: isActive ?? this.isActive,
      routingRules: routingRules ?? this.routingRules,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      latency: latency ?? this.latency,
    );
  }
}

enum VPNType {
  openVPN,
  clash,
  shadowsocks, // Shadowsocks支持
  v2ray, // V2Ray支持
  httpProxy, // HTTP代理
  socks5, // SOCKS5代理
  custom, // 自定义代理
}

// 添加一个扩展方法来检查是否支持订阅
extension VPNTypeSubscription on VPNType {
  bool get supportsSubscription {
    // 目前只有Clash、Shadowsocks和V2Ray支持订阅
    return this == VPNType.clash ||
        this == VPNType.shadowsocks ||
        this == VPNType.v2ray;
  }
}

// 连接状态枚举
enum ConnectionStatus {
  disconnected, // 已断开
  connecting, // 连接中
  connected, // 已连接
  disconnecting, // 断开中
  error, // 错误
}

// 路由规则模型
class RoutingRule {
  final String pattern; // 网址或IP地址模式
  final RouteType routeType; // 路由类型
  final bool isEnabled; // 是否启用
  final String? configId; // 关联的配置ID（新增字段）

  RoutingRule({
    required this.pattern,
    required this.routeType,
    this.isEnabled = true,
    this.configId, // 新增字段
  });

  factory RoutingRule.fromJson(Map<String, dynamic> json) {
    return RoutingRule(
      pattern: json['pattern'] as String,
      routeType: RouteType.values.firstWhere(
        (e) => e.toString() == json['routeType'],
        orElse: () => RouteType.openVPN,
      ),
      isEnabled: json['isEnabled'] as bool? ?? true,
      configId: json['configId'] as String?, // 新增字段
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pattern': pattern,
      'routeType': routeType.toString(),
      'isEnabled': isEnabled,
      'configId': configId, // 新增字段
    };
  }
}

enum RouteType { openVPN, clash, shadowsocks, v2ray, httpProxy, socks5, custom }
