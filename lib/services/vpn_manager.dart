import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/services/openvpn_service.dart';
import 'package:dualvpn_manager/services/clash_service.dart';
import 'package:dualvpn_manager/services/shadowsocks_service.dart';
import 'package:dualvpn_manager/services/v2ray_service.dart';
import 'package:dualvpn_manager/services/http_proxy_service.dart';
import 'package:dualvpn_manager/services/socks5_proxy_service.dart';
import 'package:dualvpn_manager/services/routing_service.dart';
import 'package:dualvpn_manager/utils/logger.dart';

class VPNManager {
  final OpenVPNService _openVPNService = OpenVPNService();
  final ClashService _clashService = ClashService();
  final ShadowsocksService _shadowsocksService = ShadowsocksService();
  final V2RayService _v2rayService = V2RayService();
  final HTTPProxyService _httpProxyService = HTTPProxyService();
  final SOCKS5ProxyService _socks5ProxyService = SOCKS5ProxyService();
  final RoutingService _routingService = RoutingService();

  bool get isOpenVPNConnected => _openVPNService.isConnected;
  bool get isClashConnected => _clashService.isConnected;
  bool get isRoutingActive => _routingService.isRoutingActive;

  // 连接OpenVPN
  Future<bool> connectOpenVPN(VPNConfig config) async {
    if (config.type != VPNType.openVPN) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      // 如果已经连接，则先断开
      if (_openVPNService.isConnected) {
        await _openVPNService.disconnect();
      }

      // 连接OpenVPN
      final result = await _openVPNService.connect(config.configPath);
      return result;
    } catch (e) {
      Logger.error('连接OpenVPN失败: $e');
      rethrow;
    }
  }

  // 断开OpenVPN
  Future<void> disconnectOpenVPN() async {
    try {
      await _openVPNService.disconnect();
    } catch (e) {
      Logger.error('断开OpenVPN失败: $e');
      rethrow;
    }
  }

  // 连接Clash
  Future<bool> connectClash(VPNConfig config) async {
    if (config.type != VPNType.clash) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      // 如果已经连接，则先断开
      if (_clashService.isConnected) {
        await _clashService.stop();
      }

      bool result;
      // 根据配置路径判断是文件还是订阅链接
      if (config.configPath.startsWith('http')) {
        // 订阅链接
        result = await _clashService.startWithSubscription(config.configPath);
      } else {
        // 本地配置文件
        result = await _clashService.startWithConfig(config.configPath);
      }

      // 验证连接是否成功
      if (result) {
        await Future.delayed(const Duration(seconds: 1));
        result = await _clashService.verifyConnection();
      }

      return result;
    } catch (e) {
      Logger.error('连接Clash失败: $e');
      rethrow;
    }
  }

  // 断开Clash
  Future<void> disconnectClash() async {
    try {
      await _clashService.stop();
    } catch (e) {
      Logger.error('断开Clash失败: $e');
      rethrow;
    }
  }

  // 连接Shadowsocks
  Future<bool> connectShadowsocks(VPNConfig config) async {
    if (config.type != VPNType.shadowsocks) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      // 如果已经连接，则先断开
      if (_shadowsocksService.isConnected) {
        await _shadowsocksService.stop();
      }

      bool result;
      // 根据配置路径判断是文件还是订阅链接
      if (config.configPath.startsWith('http')) {
        // 订阅链接
        result = await _shadowsocksService.startWithSubscription(
          config.configPath,
        );
      } else {
        // 本地配置文件
        result = await _shadowsocksService.startWithConfig(config.configPath);
      }

      return result;
    } catch (e) {
      Logger.error('连接Shadowsocks失败: $e');
      rethrow;
    }
  }

  // 断开Shadowsocks
  Future<void> disconnectShadowsocks() async {
    try {
      await _shadowsocksService.stop();
    } catch (e) {
      Logger.error('断开Shadowsocks失败: $e');
      rethrow;
    }
  }

  // 连接V2Ray
  Future<bool> connectV2Ray(VPNConfig config) async {
    if (config.type != VPNType.v2ray) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      // 如果已经连接，则先断开
      if (_v2rayService.isConnected) {
        await _v2rayService.stop();
      }

      bool result;
      // 根据配置路径判断是文件还是订阅链接
      if (config.configPath.startsWith('http')) {
        // 订阅链接
        result = await _v2rayService.startWithSubscription(config.configPath);
      } else {
        // 本地配置文件
        result = await _v2rayService.startWithConfig(config.configPath);
      }

      return result;
    } catch (e) {
      Logger.error('连接V2Ray失败: $e');
      rethrow;
    }
  }

  // 断开V2Ray
  Future<void> disconnectV2Ray() async {
    try {
      await _v2rayService.stop();
    } catch (e) {
      Logger.error('断开V2Ray失败: $e');
      rethrow;
    }
  }

  // 更新Clash订阅
  Future<bool> updateClashSubscription(VPNConfig config) async {
    if (config.type != VPNType.clash) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    if (!config.configPath.startsWith('http')) {
      Logger.error('配置不是订阅链接');
      throw Exception('配置不是订阅链接');
    }

    try {
      final result = await _clashService.updateSubscription(config.configPath);
      return result;
    } catch (e) {
      Logger.error('更新Clash订阅失败: $e');
      rethrow;
    }
  }

  // 更新Shadowsocks订阅
  Future<bool> updateShadowsocksSubscription(VPNConfig config) async {
    if (config.type != VPNType.shadowsocks) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    if (!config.configPath.startsWith('http')) {
      Logger.error('配置不是订阅链接');
      throw Exception('配置不是订阅链接');
    }

    try {
      final result = await _shadowsocksService.updateSubscription(
        config.configPath,
      );
      return result;
    } catch (e) {
      Logger.error('更新Shadowsocks订阅失败: $e');
      rethrow;
    }
  }

  // 更新V2Ray订阅
  Future<bool> updateV2RaySubscription(VPNConfig config) async {
    if (config.type != VPNType.v2ray) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    if (!config.configPath.startsWith('http')) {
      Logger.error('配置不是订阅链接');
      throw Exception('配置不是订阅链接');
    }

    try {
      final result = await _v2rayService.updateSubscription(config.configPath);
      return result;
    } catch (e) {
      Logger.error('更新V2Ray订阅失败: $e');
      rethrow;
    }
  }

  // 连接HTTP代理
  Future<bool> connectHTTPProxy(VPNConfig config) async {
    if (config.type != VPNType.httpProxy) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      // 如果已经连接，则先断开
      if (_httpProxyService.isConnected) {
        await _httpProxyService.stop();
      }

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
      final result = await _httpProxyService.start(
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
  Future<void> disconnectHTTPProxy() async {
    try {
      await _httpProxyService.stop();
    } catch (e) {
      Logger.error('断开HTTP代理失败: $e');
      rethrow;
    }
  }

  // 连接SOCKS5代理
  Future<bool> connectSOCKS5Proxy(VPNConfig config) async {
    if (config.type != VPNType.socks5) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      // 如果已经连接，则先断开
      if (_socks5ProxyService.isConnected) {
        await _socks5ProxyService.stop();
      }

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
      final result = await _socks5ProxyService.start(
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
  Future<void> disconnectSOCKS5Proxy() async {
    try {
      await _socks5ProxyService.stop();
    } catch (e) {
      Logger.error('断开SOCKS5代理失败: $e');
      rethrow;
    }
  }

  // 通用订阅更新方法
  Future<bool> updateSubscription(VPNConfig config) async {
    if (!config.configPath.startsWith('http')) {
      Logger.error('配置不是订阅链接');
      throw Exception('配置不是订阅链接');
    }

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
          throw Exception('不支持的订阅更新类型: ${config.type}');
      }

      return result;
    } catch (e) {
      Logger.error('更新${config.type}订阅失败: $e');
      rethrow;
    }
  }

  // 配置智能路由
  Future<bool> configureRouting({
    required List<String> internalDomains,
    required List<String> externalDomains,
  }) async {
    try {
      return await _routingService.configureRouting(
        internalDomains: internalDomains,
        externalDomains: externalDomains,
      );
    } catch (e) {
      Logger.error('配置路由失败: $e');
      rethrow;
    }
  }

  // 启用路由
  Future<void> enableRouting() async {
    try {
      await _routingService.enableRouting();
    } catch (e) {
      Logger.error('启用路由失败: $e');
      rethrow;
    }
  }

  // 禔用路由
  Future<void> disableRouting() async {
    try {
      await _routingService.disableRouting();
    } catch (e) {
      Logger.error('禁用路由失败: $e');
      rethrow;
    }
  }

  // 获取OpenVPN状态
  Future<bool> getOpenVPNStatus() async {
    try {
      return await _openVPNService.checkStatus();
    } catch (e) {
      Logger.error('获取OpenVPN状态失败: $e');
      rethrow;
    }
  }

  // 获取Clash状态
  Future<Map<String, dynamic>?> getClashStatus() async {
    try {
      return await _clashService.getStatus();
    } catch (e) {
      Logger.error('获取Clash状态失败: $e');
      rethrow;
    }
  }

  // 获取Clash代理列表
  Future<Map<String, dynamic>?> getClashProxies() async {
    try {
      return await _clashService.getProxies();
    } catch (e) {
      Logger.error('获取Clash代理列表失败: $e');
      rethrow;
    }
  }

  // 获取Shadowsocks代理列表
  Future<List<Map<String, dynamic>>> getShadowsocksProxies() async {
    try {
      return await _shadowsocksService.getProxies();
    } catch (e) {
      Logger.error('获取Shadowsocks代理列表失败: $e');
      rethrow;
    }
  }

  // 从订阅链接获取Shadowsocks代理列表
  Future<List<Map<String, dynamic>>> getShadowsocksProxiesFromSubscription(
    String subscriptionUrl,
  ) async {
    try {
      return await _shadowsocksService.getProxiesFromSubscription(
        subscriptionUrl,
      );
    } catch (e) {
      Logger.error('从订阅链接获取Shadowsocks代理列表失败: $e');
      rethrow;
    }
  }

  // 获取V2Ray代理列表
  Future<List<Map<String, dynamic>>> getV2RayProxies() async {
    try {
      return await _v2rayService.getProxies();
    } catch (e) {
      Logger.error('获取V2Ray代理列表失败: $e');
      rethrow;
    }
  }

  // 从订阅链接获取V2Ray代理列表
  Future<List<Map<String, dynamic>>> getV2RayProxiesFromSubscription(
    String subscriptionUrl,
  ) async {
    try {
      return await _v2rayService.getProxiesFromSubscription(subscriptionUrl);
    } catch (e) {
      Logger.error('从订阅链接获取V2Ray代理列表失败: $e');
      rethrow;
    }
  }

  // 选择Clash代理
  Future<bool> selectClashProxy(String selector, String proxyName) async {
    try {
      final result = await _clashService.selectProxy(selector, proxyName);
      return result;
    } catch (e) {
      Logger.error('选择Clash代理失败: $e');
      return false;
    }
  }
}
