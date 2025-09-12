import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/services/openvpn_service.dart';
import 'package:dualvpn_manager/services/clash_service.dart';
import 'package:dualvpn_manager/services/shadowsocks_service.dart';
import 'package:dualvpn_manager/services/v2ray_service.dart';
import 'package:dualvpn_manager/services/http_proxy_service.dart';
import 'package:dualvpn_manager/services/socks5_proxy_service.dart';
import 'package:dualvpn_manager/utils/logger.dart';

/// 连接实例管理器
/// 用于管理多个同类型代理的连接实例
class ConnectionManager {
  // 为每种代理类型维护一个实例映射
  final Map<String, OpenVPNService> _openVPNInstances = {};
  final Map<String, ClashService> _clashInstances = {};
  final Map<String, ShadowsocksService> _shadowsocksInstances = {};
  final Map<String, V2RayService> _v2rayInstances = {};
  final Map<String, HTTPProxyService> _httpProxyInstances = {};
  final Map<String, SOCKS5ProxyService> _socks5ProxyInstances = {};

  // 获取OpenVPN服务实例
  OpenVPNService _getOpenVPNInstance(String configId) {
    if (!_openVPNInstances.containsKey(configId)) {
      _openVPNInstances[configId] = OpenVPNService();
    }
    return _openVPNInstances[configId]!;
  }

  // 获取Clash服务实例
  ClashService _getClashInstance(String configId) {
    if (!_clashInstances.containsKey(configId)) {
      _clashInstances[configId] = ClashService();
    }
    return _clashInstances[configId]!;
  }

  // 获取Shadowsocks服务实例
  ShadowsocksService _getShadowsocksInstance(String configId) {
    if (!_shadowsocksInstances.containsKey(configId)) {
      _shadowsocksInstances[configId] = ShadowsocksService();
    }
    return _shadowsocksInstances[configId]!;
  }

  // 获取V2Ray服务实例
  V2RayService _getV2RayInstance(String configId) {
    if (!_v2rayInstances.containsKey(configId)) {
      _v2rayInstances[configId] = V2RayService();
    }
    return _v2rayInstances[configId]!;
  }

  // 获取HTTP代理服务实例
  HTTPProxyService _getHTTPProxyInstance(String configId) {
    if (!_httpProxyInstances.containsKey(configId)) {
      _httpProxyInstances[configId] = HTTPProxyService();
    }
    return _httpProxyInstances[configId]!;
  }

  // 获取SOCKS5代理服务实例
  SOCKS5ProxyService _getSOCKS5ProxyInstance(String configId) {
    if (!_socks5ProxyInstances.containsKey(configId)) {
      _socks5ProxyInstances[configId] = SOCKS5ProxyService();
    }
    return _socks5ProxyInstances[configId]!;
  }

  // 连接OpenVPN
  Future<bool> connectOpenVPN(String configId, VPNConfig config) async {
    if (config.type != VPNType.openVPN) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      final service = _getOpenVPNInstance(configId);

      // 连接OpenVPN
      final result = await service.connect(config.configPath);
      return result;
    } catch (e) {
      Logger.error('连接OpenVPN失败: $e');
      rethrow;
    }
  }

  // 断开OpenVPN
  Future<void> disconnectOpenVPN(String configId) async {
    try {
      if (_openVPNInstances.containsKey(configId)) {
        final service = _openVPNInstances[configId]!;
        await service.disconnect();
        // 移除实例以释放资源
        _openVPNInstances.remove(configId);
      }
    } catch (e) {
      Logger.error('断开OpenVPN失败: $e');
      rethrow;
    }
  }

  // 连接Clash
  Future<bool> connectClash(String configId, VPNConfig config) async {
    if (config.type != VPNType.clash) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      final service = _getClashInstance(configId);
      bool result;

      // 根据配置路径判断是文件还是订阅链接
      if (config.configPath.startsWith('http')) {
        // 订阅链接
        result = await service.startWithSubscription(config.configPath);
      } else {
        // 本地配置文件
        result = await service.startWithConfig(config.configPath);
      }

      return result;
    } catch (e) {
      Logger.error('连接Clash失败: $e');
      rethrow;
    }
  }

  // 断开Clash
  Future<void> disconnectClash(String configId) async {
    try {
      if (_clashInstances.containsKey(configId)) {
        final service = _clashInstances[configId]!;
        await service.stop();
        // 移除实例以释放资源
        _clashInstances.remove(configId);
      }
    } catch (e) {
      Logger.error('断开Clash失败: $e');
      rethrow;
    }
  }

  // 连接Shadowsocks
  Future<bool> connectShadowsocks(String configId, VPNConfig config) async {
    if (config.type != VPNType.shadowsocks) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      final service = _getShadowsocksInstance(configId);
      bool result;

      // 根据配置路径判断是文件还是订阅链接
      if (config.configPath.startsWith('http')) {
        // 订阅链接
        result = await service.startWithSubscription(config.configPath);
      } else {
        // 本地配置文件
        result = await service.startWithConfig(config.configPath);
      }

      return result;
    } catch (e) {
      Logger.error('连接Shadowsocks失败: $e');
      rethrow;
    }
  }

  // 断开Shadowsocks
  Future<void> disconnectShadowsocks(String configId) async {
    try {
      if (_shadowsocksInstances.containsKey(configId)) {
        final service = _shadowsocksInstances[configId]!;
        await service.stop();
        // 移除实例以释放资源
        _shadowsocksInstances.remove(configId);
      }
    } catch (e) {
      Logger.error('断开Shadowsocks失败: $e');
      rethrow;
    }
  }

  // 连接V2Ray
  Future<bool> connectV2Ray(String configId, VPNConfig config) async {
    if (config.type != VPNType.v2ray) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      final service = _getV2RayInstance(configId);
      bool result;

      // 根据配置路径判断是文件还是订阅链接
      if (config.configPath.startsWith('http')) {
        // 订阅链接
        result = await service.startWithSubscription(config.configPath);
      } else {
        // 本地配置文件
        result = await service.startWithConfig(config.configPath);
      }

      return result;
    } catch (e) {
      Logger.error('连接V2Ray失败: $e');
      rethrow;
    }
  }

  // 断开V2Ray
  Future<void> disconnectV2Ray(String configId) async {
    try {
      if (_v2rayInstances.containsKey(configId)) {
        final service = _v2rayInstances[configId]!;
        await service.stop();
        // 移除实例以释放资源
        _v2rayInstances.remove(configId);
      }
    } catch (e) {
      Logger.error('断开V2Ray失败: $e');
      rethrow;
    }
  }

  // 连接HTTP代理
  Future<bool> connectHTTPProxy(String configId, VPNConfig config) async {
    if (config.type != VPNType.httpProxy) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      final service = _getHTTPProxyInstance(configId);

      // 解析服务器地址和端口
      final parts = config.configPath.split(':');
      if (parts.length != 2) {
        throw Exception('HTTP代理配置路径格式错误');
      }

      final server = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) {
        throw Exception('HTTP代理端口格式错误');
      }

      // 获取用户名和密码（如果有的话）
      final username = config.settings['username'] as String?;
      final password = config.settings['password'] as String?;

      // 连接HTTP代理
      final result = await service.start(
        server,
        port,
        username: username,
        password: password,
      );
      return result;
    } catch (e) {
      Logger.error('连接HTTP代理失败: $e');
      rethrow;
    }
  }

  // 断开HTTP代理
  Future<void> disconnectHTTPProxy(String configId) async {
    try {
      if (_httpProxyInstances.containsKey(configId)) {
        final service = _httpProxyInstances[configId]!;
        await service.stop();
        // 移除实例以释放资源
        _httpProxyInstances.remove(configId);
      }
    } catch (e) {
      Logger.error('断开HTTP代理失败: $e');
      rethrow;
    }
  }

  // 连接SOCKS5代理
  Future<bool> connectSOCKS5Proxy(String configId, VPNConfig config) async {
    if (config.type != VPNType.socks5) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      final service = _getSOCKS5ProxyInstance(configId);

      // 解析服务器地址和端口
      final parts = config.configPath.split(':');
      if (parts.length != 2) {
        throw Exception('SOCKS5代理配置路径格式错误');
      }

      final server = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) {
        throw Exception('SOCKS5代理端口格式错误');
      }

      // 获取用户名和密码（如果有的话）
      final username = config.settings['username'] as String?;
      final password = config.settings['password'] as String?;

      // 连接SOCKS5代理
      final result = await service.start(
        server,
        port,
        username: username,
        password: password,
      );
      return result;
    } catch (e) {
      Logger.error('连接SOCKS5代理失败: $e');
      rethrow;
    }
  }

  // 断开SOCKS5代理
  Future<void> disconnectSOCKS5Proxy(String configId) async {
    try {
      if (_socks5ProxyInstances.containsKey(configId)) {
        final service = _socks5ProxyInstances[configId]!;
        await service.stop();
        // 移除实例以释放资源
        _socks5ProxyInstances.remove(configId);
      }
    } catch (e) {
      Logger.error('断开SOCKS5代理失败: $e');
      rethrow;
    }
  }

  // 清理所有连接实例
  Future<void> cleanupAll() async {
    // 断开所有OpenVPN连接
    for (final entry in _openVPNInstances.entries) {
      try {
        await entry.value.disconnect();
      } catch (e) {
        Logger.error('断开OpenVPN失败: $e');
      }
    }
    _openVPNInstances.clear();

    // 断开所有Clash连接
    for (final entry in _clashInstances.entries) {
      try {
        await entry.value.stop();
      } catch (e) {
        Logger.error('断开Clash失败: $e');
      }
    }
    _clashInstances.clear();

    // 断开所有Shadowsocks连接
    for (final entry in _shadowsocksInstances.entries) {
      try {
        await entry.value.stop();
      } catch (e) {
        Logger.error('断开Shadowsocks失败: $e');
      }
    }
    _shadowsocksInstances.clear();

    // 断开所有V2Ray连接
    for (final entry in _v2rayInstances.entries) {
      try {
        await entry.value.stop();
      } catch (e) {
        Logger.error('断开V2Ray失败: $e');
      }
    }
    _v2rayInstances.clear();

    // 断开所有HTTP代理连接
    for (final entry in _httpProxyInstances.entries) {
      try {
        await entry.value.stop();
      } catch (e) {
        Logger.error('断开HTTP代理失败: $e');
      }
    }
    _httpProxyInstances.clear();

    // 断开所有SOCKS5代理连接
    for (final entry in _socks5ProxyInstances.entries) {
      try {
        await entry.value.stop();
      } catch (e) {
        Logger.error('断开SOCKS5代理失败: $e');
      }
    }
    _socks5ProxyInstances.clear();
  }
}
