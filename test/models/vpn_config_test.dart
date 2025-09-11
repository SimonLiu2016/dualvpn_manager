import 'package:flutter_test/flutter_test.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';

void main() {
  group('VPNConfig', () {
    test('should create VPNConfig instance correctly', () {
      final config = VPNConfig(
        id: 'test-id',
        name: 'Test Config',
        type: VPNType.openVPN,
        configPath: '/path/to/config.ovpn',
        settings: {'key': 'value'},
      );

      expect(config.id, 'test-id');
      expect(config.name, 'Test Config');
      expect(config.type, VPNType.openVPN);
      expect(config.configPath, '/path/to/config.ovpn');
      expect(config.settings['key'], 'value');
      expect(config.isActive, false);
      expect(config.routingRules, isEmpty);
      expect(config.connectionStatus, ConnectionStatus.disconnected);
      expect(config.latency, -1);
    });

    test('should create VPNConfig from JSON correctly', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Config',
        'type': 'VPNType.openVPN',
        'configPath': '/path/to/config.ovpn',
        'settings': {'key': 'value'},
        'isActive': true,
        'connectionStatus': 'ConnectionStatus.connected',
        'latency': 100,
      };

      final config = VPNConfig.fromJson(json);

      expect(config.id, 'test-id');
      expect(config.name, 'Test Config');
      expect(config.type, VPNType.openVPN);
      expect(config.configPath, '/path/to/config.ovpn');
      expect(config.settings['key'], 'value');
      expect(config.isActive, true);
      expect(config.connectionStatus, ConnectionStatus.connected);
      expect(config.latency, 100);
    });

    test('should convert VPNConfig to JSON correctly', () {
      final config = VPNConfig(
        id: 'test-id',
        name: 'Test Config',
        type: VPNType.clash,
        configPath: '/path/to/config.yaml',
        settings: {'key': 'value'},
        isActive: true,
        connectionStatus: ConnectionStatus.connected,
        latency: 150,
      );

      final json = config.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Config');
      expect(json['type'], 'VPNType.clash');
      expect(json['configPath'], '/path/to/config.yaml');
      expect(json['settings']['key'], 'value');
      expect(json['isActive'], true);
      expect(json['connectionStatus'], 'ConnectionStatus.connected');
      expect(json['latency'], 150);
    });

    test('should create copy with updated values', () {
      final originalConfig = VPNConfig(
        id: 'test-id',
        name: 'Test Config',
        type: VPNType.openVPN,
        configPath: '/path/to/config.ovpn',
        settings: {'key': 'value'},
      );

      final updatedConfig = originalConfig.copyWith(
        name: 'Updated Config',
        isActive: true,
        latency: 200,
      );

      expect(updatedConfig.id, originalConfig.id);
      expect(updatedConfig.name, 'Updated Config');
      expect(updatedConfig.type, originalConfig.type);
      expect(updatedConfig.configPath, originalConfig.configPath);
      expect(updatedConfig.isActive, true);
      expect(updatedConfig.latency, 200);
    });
  });

  group('VPNTypeSubscription', () {
    test('should correctly identify subscription support', () {
      expect(VPNType.clash.supportsSubscription, true);
      expect(VPNType.shadowsocks.supportsSubscription, true);
      expect(VPNType.v2ray.supportsSubscription, true);
      expect(VPNType.openVPN.supportsSubscription, false);
      expect(VPNType.httpProxy.supportsSubscription, false);
      expect(VPNType.socks5.supportsSubscription, false);
      expect(VPNType.custom.supportsSubscription, false);
    });
  });

  group('RoutingRule', () {
    test('should create RoutingRule instance correctly', () {
      final rule = RoutingRule(
        pattern: 'example.com',
        routeType: RouteType.clash,
        isEnabled: true,
      );

      expect(rule.pattern, 'example.com');
      expect(rule.routeType, RouteType.clash);
      expect(rule.isEnabled, true);
    });

    test('should create RoutingRule from JSON correctly', () {
      final json = {
        'pattern': 'example.com',
        'routeType': 'RouteType.clash',
        'isEnabled': false,
      };

      final rule = RoutingRule.fromJson(json);

      expect(rule.pattern, 'example.com');
      expect(rule.routeType, RouteType.clash);
      expect(rule.isEnabled, false);
    });

    test('should convert RoutingRule to JSON correctly', () {
      final rule = RoutingRule(
        pattern: 'example.com',
        routeType: RouteType.shadowsocks,
        isEnabled: true,
      );

      final json = rule.toJson();

      expect(json['pattern'], 'example.com');
      expect(json['routeType'], 'RouteType.shadowsocks');
      expect(json['isEnabled'], true);
    });

    test('should handle configId in RoutingRule correctly', () {
      final rule = RoutingRule(
        pattern: 'example.com',
        routeType: RouteType.clash,
        isEnabled: true,
        configId: 'config_123',
      );

      expect(rule.configId, 'config_123');

      // Test JSON serialization
      final json = rule.toJson();
      expect(json['configId'], 'config_123');

      // Test JSON deserialization
      final ruleFromJson = RoutingRule.fromJson(json);
      expect(ruleFromJson.configId, 'config_123');
    });
  });
}
