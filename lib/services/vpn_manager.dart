import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/services/openvpn_service.dart';
import 'package:dualvpn_manager/services/clash_service.dart';
import 'package:dualvpn_manager/services/shadowsocks_service.dart';
import 'package:dualvpn_manager/services/v2ray_service.dart';
import 'package:dualvpn_manager/services/http_proxy_service.dart';
import 'package:dualvpn_manager/services/socks5_proxy_service.dart';
import 'package:dualvpn_manager/services/routing_service.dart';
import 'package:dualvpn_manager/services/system_proxy_manager.dart';
import 'package:dualvpn_manager/services/go_proxy_service.dart';
import 'package:dualvpn_manager/utils/logger.dart';
import 'dart:io';

class VPNManager {
  final OpenVPNService _openVPNService = OpenVPNService();
  final ClashService _clashService = ClashService();
  final ShadowsocksService _shadowsocksService = ShadowsocksService();
  final V2RayService _v2rayService = V2RayService();
  final HTTPProxyService _httpProxyService = HTTPProxyService();
  final SOCKS5ProxyService _socks5ProxyService = SOCKS5ProxyService();
  final RoutingService _routingService = RoutingService();
  final SystemProxyManager _systemProxyManager = SystemProxyManager();
  final GoProxyService _goProxyService = GoProxyService();

  static final VPNManager _instance = VPNManager._internal();
  factory VPNManager() => _instance;
  VPNManager._internal();

  bool _isConnected = false;
  VPNConfig? _currentConfig;

  bool get isConnected => _isConnected;

  bool get isOpenVPNConnected => _openVPNService.isConnected;
  bool get isClashConnected => _clashService.isConnected;
  bool get isRoutingActive => _routingService.isRoutingActive;
  bool get isGoProxyRunning => _goProxyService.isRunning;

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
    Logger.info('=== 开始连接Clash ===');
    Logger.info('配置类型: ${config.type}');
    Logger.info('配置名称: ${config.name}');

    try {
      // 检查是否是订阅类型的配置
      if (config.type == VPNType.clash && config.subscriptionUrl != null) {
        Logger.info('通过订阅URL连接: ${config.subscriptionUrl}');

        // 尝试连接并增加重试机制
        bool connected = false;
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries && !connected) {
          try {
            Logger.info('尝试连接Clash (第${retryCount + 1}次)');
            connected = await _clashService.startWithSubscription(
              config.subscriptionUrl!,
            );
            if (connected) {
              Logger.info('Clash连接成功');
              break;
            }
          } catch (e) {
            Logger.warn('Clash连接失败: $e');
            retryCount++;
            if (retryCount < maxRetries) {
              Logger.info('等待2秒后重试...');
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        }

        if (connected) {
          _isConnected = true;
          _currentConfig = config;
          Logger.info('Clash连接成功完成');
          return true;
        } else {
          Logger.error('经过$retryCount次尝试后Clash连接仍然失败');
          _isConnected = false;
          return false;
        }
      } else {
        Logger.info('使用本地配置连接');
        // 对于本地配置，我们需要启动Clash服务
        if (_currentConfig != null) {
          final success = await _clashService.startWithConfig(
            _currentConfig!.configPath,
          );
          if (success) {
            _isConnected = true;
            _currentConfig = config;
            Logger.info('Clash本地配置连接成功');
            return true;
          } else {
            Logger.error('Clash本地配置连接失败');
            _isConnected = false;
            return false;
          }
        } else {
          Logger.error('没有可用的本地配置文件');
          _isConnected = false;
          return false;
        }
      }
    } on SocketException catch (e) {
      Logger.error('网络连接错误: $e');
      _isConnected = false;
      throw Exception('网络连接错误，请检查网络连接');
    } catch (e, stackTrace) {
      Logger.error('连接Clash失败: $e\nStack trace: $stackTrace');
      _isConnected = false;
      rethrow;
    }
  }

  // 断开Clash
  Future<void> disconnectClash() async {
    try {
      // 清除系统代理设置
      await _systemProxyManager.clearSystemProxy();

      await _clashService.stop();
    } catch (e) {
      Logger.error('断开Clash失败: $e');
      rethrow;
    }
  }

  // 断开连接
  Future<void> disconnect() async {
    Logger.info('断开VPN连接');
    try {
      final clashService = ClashService();
      await clashService.stop();
      _isConnected = false;
      _currentConfig = null;
      Logger.info('VPN连接已断开');
    } catch (e) {
      Logger.error('断开连接时出错: $e');
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

      // 如果连接成功，设置系统代理
      if (result) {
        await _systemProxyManager.setSystemProxy('127.0.0.1', 1080, 1080);
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
      // 清除系统代理设置
      await _systemProxyManager.clearSystemProxy();

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

      // 如果连接成功，设置系统代理
      if (result) {
        await _systemProxyManager.setSystemProxy('127.0.0.1', 1080, 1080);
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
      // 清除系统代理设置
      await _systemProxyManager.clearSystemProxy();

      await _v2rayService.stop();
    } catch (e) {
      Logger.error('断开V2Ray失败: $e');
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

      // 如果连接成功，设置系统代理
      if (result) {
        await _systemProxyManager.setSystemProxy(server, port, port);
      }

      return result;
    } catch (e) {
      Logger.error('连接HTTP代理失败: $e');
      rethrow;
    }
  }

  // 断开HTTP代理
  Future<void> disconnectHTTPProxy() async {
    try {
      // 清除系统代理设置
      await _systemProxyManager.clearSystemProxy();

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

      // 如果连接成功，设置系统代理
      if (result) {
        await _systemProxyManager.setSystemProxy(server, port, port);
      }

      return result;
    } catch (e) {
      Logger.error('连接SOCKS5代理失败: $e');
      rethrow;
    }
  }

  // 断开SOCKS5代理
  Future<void> disconnectSOCKS5Proxy() async {
    try {
      // 清除系统代理设置
      await _systemProxyManager.clearSystemProxy();

      await _socks5ProxyService.stop();
    } catch (e) {
      Logger.error('断开SOCKS5代理失败: $e');
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
    } on SocketException catch (e) {
      Logger.error('网络连接错误: $e');
      throw Exception('网络连接错误，请检查网络连接');
    } on TlsException catch (e) {
      Logger.error('TLS/SSL错误: $e');
      throw Exception('TLS/SSL连接错误，请检查服务器证书');
    } on HandshakeException catch (e) {
      Logger.error('TLS握手错误: $e');
      throw Exception('TLS握手失败，请检查服务器配置');
    } catch (e) {
      Logger.error('更新Clash订阅失败: $e');
      if (e.toString().contains('404')) {
        throw Exception('订阅链接不存在，请检查链接是否正确');
      } else if (e.toString().contains('timeout')) {
        throw Exception('连接超时，请稍后重试');
      }
      return false;
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
    } on SocketException catch (e) {
      Logger.error('网络连接错误: $e');
      throw Exception('网络连接错误，请检查网络连接');
    } catch (e) {
      Logger.error('更新Shadowsocks订阅失败: $e');
      if (e.toString().contains('404')) {
        throw Exception('订阅链接不存在，请检查链接是否正确');
      } else if (e.toString().contains('timeout')) {
        throw Exception('连接超时，请稍后重试');
      }
      return false;
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
    } on SocketException catch (e) {
      Logger.error('网络连接错误: $e');
      throw Exception('网络连接错误，请检查网络连接');
    } catch (e) {
      Logger.error('更新V2Ray订阅失败: $e');
      if (e.toString().contains('404')) {
        throw Exception('订阅链接不存在，请检查链接是否正确');
      } else if (e.toString().contains('timeout')) {
        throw Exception('连接超时，请稍后重试');
      }
      return false;
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
      return false;
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

  // 禁用路由
  Future<void> disableRouting() async {
    try {
      await _routingService.disableRouting();
    } catch (e) {
      Logger.error('禁用路由失败: $e');
      rethrow;
    }
  }

  // 启用智能路由（设置系统代理指向我们的代理服务）
  Future<void> enableSmartRouting({
    int httpPort = 6160,
    int socksPort = 6161,
  }) async {
    try {
      // 使用正确的代理核心端口
      Logger.info(
        '启用智能路由，设置系统代理指向 127.0.0.1:$httpPort (HTTP) 和 $socksPort (SOCKS5)',
      );
      // 设置系统代理指向我们的代理服务
      await _systemProxyManager.setSystemProxy(
        '127.0.0.1',
        httpPort,
        socksPort,
      );
      Logger.info('智能路由已启用，系统代理已设置');
    } catch (e, stackTrace) {
      Logger.error('启用智能路由失败: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 禁用智能路由（清除系统代理设置）
  Future<void> disableSmartRouting() async {
    try {
      Logger.info('禁用智能路由，清除系统代理设置');
      // 清除系统代理设置
      await _systemProxyManager.clearSystemProxy();
      Logger.info('智能路由已禁用，系统代理已清除');
    } catch (e, stackTrace) {
      Logger.error('禁用智能路由失败: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 启动Go代理核心
  Future<bool> startGoProxy() async {
    try {
      Logger.info('正在启动Go代理核心...');
      final result = await _goProxyService.start();

      if (result) {
        Logger.info('Go代理核心启动成功');
        // 设置系统代理到Go代理核心端口
        // HTTP代理端口: 6160, SOCKS5代理端口: 6161
        await _systemProxyManager.setSystemProxy('127.0.0.1', 6160, 6161);

        // 初始化所有协议
        await _initializeAllProtocols();
      } else {
        Logger.error('Go代理核心启动失败');
      }

      return result;
    } catch (e) {
      Logger.error('启动Go代理核心失败: $e');
      rethrow;
    }
  }

  // 初始化所有协议
  Future<void> _initializeAllProtocols() async {
    try {
      Logger.info('开始初始化所有协议...');

      // 初始化Clash协议 (HTTP)
      final clashHttpProtocol = {
        'name': 'clash',
        'type': 'http',
        'server': '127.0.0.1',
        'port': 7890, // Clash默认HTTP端口
      };
      await _goProxyService.addProtocol(clashHttpProtocol);
      Logger.info('Clash HTTP协议初始化完成');

      // 初始化Clash协议 (SOCKS5)
      final clashSocksProtocol = {
        'name': 'clash-socks',
        'type': 'socks5',
        'server': '127.0.0.1',
        'port': 7891, // Clash默认SOCKS5端口
      };
      await _goProxyService.addProtocol(clashSocksProtocol);
      Logger.info('Clash SOCKS5协议初始化完成');

      // 初始化Shadowsocks协议
      final shadowsocksProtocol = {
        'name': 'shadowsocks',
        'type': 'socks5',
        'server': '127.0.0.1',
        'port': 1080, // Shadowsocks默认端口
      };
      await _goProxyService.addProtocol(shadowsocksProtocol);
      Logger.info('Shadowsocks协议初始化完成');

      // 初始化V2Ray协议
      final v2rayProtocol = {
        'name': 'v2ray',
        'type': 'socks5',
        'server': '127.0.0.1',
        'port': 1080, // V2Ray默认端口
      };
      await _goProxyService.addProtocol(v2rayProtocol);
      Logger.info('V2Ray协议初始化完成');

      // 初始化HTTP代理协议
      final httpProtocol = {
        'name': 'http',
        'type': 'http',
        'server': '127.0.0.1',
        'port': 8080, // HTTP代理默认端口
      };
      await _goProxyService.addProtocol(httpProtocol);
      Logger.info('HTTP代理协议初始化完成');

      // 初始化SOCKS5代理协议
      final socks5Protocol = {
        'name': 'socks5',
        'type': 'socks5',
        'server': '127.0.0.1',
        'port': 1080, // SOCKS5代理默认端口
      };
      await _goProxyService.addProtocol(socks5Protocol);
      Logger.info('SOCKS5代理协议初始化完成');

      // 初始化OpenVPN协议（直连）
      final openvpnProtocol = {'name': 'openvpn', 'type': 'direct'};
      await _goProxyService.addProtocol(openvpnProtocol);
      Logger.info('OpenVPN协议初始化完成');

      // 初始化Direct协议
      final directProtocol = {'name': 'direct', 'type': 'direct'};
      await _goProxyService.addProtocol(directProtocol);
      Logger.info('Direct协议初始化完成');

      Logger.info('所有协议初始化完成');
    } catch (e) {
      Logger.error('初始化协议时出错: $e');
    }
  }

  // 停止Go代理核心
  Future<void> stopGoProxy() async {
    try {
      Logger.info('正在停止Go代理核心...');
      await _goProxyService.stop();

      // 清除系统代理设置
      await _systemProxyManager.clearSystemProxy();

      Logger.info('Go代理核心已停止');
    } catch (e) {
      Logger.error('停止Go代理核心失败: $e');
      rethrow;
    }
  }

  /// 检查Go代理核心是否正在运行
  Future<bool> checkStatus() async {
    try {
      return await _goProxyService.checkStatus();
    } catch (e) {
      Logger.error('获取Go代理核心状态失败: $e');
      rethrow;
    }
  }

  /// 获取统计信息
  Future<Map<String, dynamic>?> getGoProxyStats() async {
    try {
      final stats = await _goProxyService.getStats();
      return stats;
    } catch (e) {
      Logger.error('获取Go代理核心统计信息失败: $e');
      return null;
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
      Logger.info('选择代理: $selector -> $proxyName');

      // 清理代理名称中的特殊字符（如emoji），只保留字母、数字、连字符和下划线
      final cleanedProxyName = proxyName.replaceAll(RegExp(r'[^\w\- ]'), '');
      Logger.info('清理后的代理名称: $cleanedProxyName');

      // 直接更新Go代理核心的路由规则，而不是连接Clash服务
      // 创建一条针对此代理的路由规则
      final List<Map<String, dynamic>> rules = [
        {
          'type': 'MATCH',
          'pattern': '',
          'proxy_source': cleanedProxyName,
          'enabled': true,
        },
      ];

      // 更新Go代理核心的路由规则
      final result = await updateGoProxyRules(rules);
      if (result) {
        Logger.info('成功选择代理: $selector -> $proxyName (清理后: $cleanedProxyName)');
      } else {
        Logger.error('选择代理失败: $selector -> $proxyName');
      }
      return result;
    } catch (e) {
      Logger.error('选择代理失败: $e');
      return false;
    }
  }

  // 更新Go代理核心路由规则
  Future<bool> updateGoProxyRules(List<Map<String, dynamic>> rules) async {
    try {
      final result = await _goProxyService.updateRules(rules);
      return result;
    } catch (e) {
      Logger.error('更新Go代理核心路由规则失败: $e');
      return false;
    }
  }

  // 获取Go代理核心路由规则
  Future<List<Map<String, dynamic>>?> getGoProxyRules() async {
    try {
      final rules = await _goProxyService.getRules();
      return rules;
    } catch (e) {
      Logger.error('获取Go代理核心路由规则失败: $e');
      return null;
    }
  }

  // 获取Go代理核心协议列表
  Future<Map<String, dynamic>?> getGoProxyProtocols() async {
    try {
      final protocols = await _goProxyService.getProtocols();
      return protocols;
    } catch (e) {
      Logger.error('获取Go代理核心协议列表失败: $e');
      return null;
    }
  }

  // 添加协议到Go代理核心
  Future<bool> addProtocolToGoProxy(Map<String, dynamic> protocolConfig) async {
    try {
      final result = await _goProxyService.addProtocol(protocolConfig);
      return result;
    } catch (e) {
      Logger.error('添加协议到Go代理核心失败: $e');
      return false;
    }
  }

  // 获取当前配置
  VPNConfig? get currentConfig => _currentConfig;
}
