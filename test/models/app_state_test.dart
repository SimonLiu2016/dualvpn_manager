import 'package:flutter_test/flutter_test.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/utils/tray_manager.dart';

void main() {
  setUpAll(() async {
    // 初始化测试绑定
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AppState', () {
    late AppState appState;

    setUp(() {
      appState = AppState(trayManager: DualVPNTrayManager());
    });

    test('should initialize with default values', () {
      expect(appState.openVPNConnected, false);
      expect(appState.clashConnected, false);
      expect(appState.isRunning, false);
      expect(appState.selectedConfig, '');
      expect(appState.internalDomains, isEmpty);
      expect(appState.externalDomains, isEmpty);
      expect(appState.proxies, isEmpty);
      expect(appState.isLoadingProxies, false);
    });

    test('should update OpenVPN connection status', () {
      appState.setOpenVPNConnected(true);
      expect(appState.openVPNConnected, true);

      appState.setOpenVPNConnected(false);
      expect(appState.openVPNConnected, false);
    });

    test('should update Clash connection status', () {
      appState.setClashConnected(true);
      expect(appState.clashConnected, true);

      appState.setClashConnected(false);
      expect(appState.clashConnected, false);
    });

    test('should update application running status', () {
      appState.setIsRunning(true);
      expect(appState.isRunning, true);

      appState.setIsRunning(false);
      expect(appState.isRunning, false);
    });

    test('should update selected config', () {
      appState.setSelectedConfig('test-config-id');
      expect(appState.selectedConfig, 'test-config-id');
    });

    test('should update internal domains', () {
      final domains = ['company.com', 'internal.com'];
      appState.setInternalDomains(domains);
      expect(appState.internalDomains, domains);
    });

    test('should update external domains', () {
      final domains = ['google.com', 'facebook.com'];
      appState.setExternalDomains(domains);
      expect(appState.externalDomains, domains);
    });

    test('should update proxies', () {
      final proxies = <Map<String, dynamic>>[
        {'name': 'proxy1', 'type': 'http', 'latency': 100, 'isSelected': false},
        {
          'name': 'proxy2',
          'type': 'socks5',
          'latency': 200,
          'isSelected': true,
        },
      ];
      appState.setProxies(proxies);
      expect(appState.proxies, proxies);
    });

    test('should update proxy loading status', () {
      appState.setIsLoadingProxies(true);
      expect(appState.isLoadingProxies, true);

      appState.setIsLoadingProxies(false);
      expect(appState.isLoadingProxies, false);
    });

    test('should update proxy latency', () {
      final proxies = <Map<String, dynamic>>[
        {'name': 'proxy1', 'type': 'http', 'latency': -2, 'isSelected': false},
        {'name': 'proxy2', 'type': 'socks5', 'latency': -2, 'isSelected': true},
      ];
      appState.setProxies(proxies);

      appState.updateProxyLatency('proxy1', 150);

      final updatedProxies = appState.proxies;
      expect(updatedProxies[0]['latency'], 150);
      expect(updatedProxies[1]['latency'], -2); // Should remain unchanged
    });

    test('should update proxy selection', () {
      final proxies = <Map<String, dynamic>>[
        {'name': 'proxy1', 'type': 'http', 'latency': 100, 'isSelected': false},
        {
          'name': 'proxy2',
          'type': 'socks5',
          'latency': 200,
          'isSelected': false,
        },
      ];
      appState.setProxies(proxies);

      appState.setProxySelected('proxy1', true);

      final updatedProxies = appState.proxies;
      expect(updatedProxies[0]['isSelected'], true);
      expect(updatedProxies[1]['isSelected'], false);
    });

    test('should handle proxy selection with auto-deselect', () {
      final proxies = <Map<String, dynamic>>[
        {'name': 'proxy1', 'type': 'http', 'latency': 100, 'isSelected': true},
        {
          'name': 'proxy2',
          'type': 'socks5',
          'latency': 200,
          'isSelected': false,
        },
      ];
      appState.setProxies(proxies);

      appState.setProxySelected('proxy2', true);

      final updatedProxies = appState.proxies;
      expect(updatedProxies[0]['isSelected'], false); // Should be deselected
      expect(updatedProxies[1]['isSelected'], true);
    });
  });
}
