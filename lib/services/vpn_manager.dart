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
        await _openVPNService.disconnect(sourceId: config.id);
      }

      // 通过OpenVPNService连接，它会处理特权助手相关逻辑
      // 传递用户名和密码以及sourceId
      final result = await _openVPNService.connect(
        config.configPath,
        sourceId: config.id, // 传递sourceId参数
        username: config.settings['username'] as String?,
        password: config.settings['password'] as String?,
      );
      return result;
    } catch (e) {
      Logger.error('连接OpenVPN失败: $e');
      rethrow;
    }
  }

  // 断开OpenVPN
  Future<void> disconnectOpenVPN() async {
    try {
      // 注意：在这里我们没有config对象，所以无法传递sourceId
      // 这种情况下会使用默认的sourceId 'openvpn-source'
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
      } else if (config.configPath.startsWith('http')) {
        // 处理配置路径是订阅链接的情况
        Logger.info('通过订阅链接连接: ${config.configPath}');

        // 尝试连接并增加重试机制
        bool connected = false;
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries && !connected) {
          try {
            Logger.info('尝试连接Clash (第${retryCount + 1}次)');
            connected = await _clashService.startWithSubscription(
              config.configPath,
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
        if (config.configPath.isNotEmpty) {
          final success = await _clashService.startWithConfig(
            config.configPath,
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
          Logger.error('没有可用的本地配置文件路径');
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

  // 更新OpenVPN订阅
  Future<bool> updateOpenVPNSubscription(VPNConfig config) async {
    if (config.type != VPNType.openVPN) {
      Logger.error('配置类型不匹配');
      throw Exception('配置类型不匹配');
    }

    try {
      // 对于OpenVPN，"更新订阅"实际上是重新加载配置文件
      Logger.info('更新OpenVPN配置: ${config.name}');

      // 这里可以添加任何需要的OpenVPN配置更新逻辑
      // 目前我们只是返回成功，因为OpenVPN配置通常是本地文件
      Logger.info('OpenVPN配置更新完成');
      return true;
    } catch (e) {
      Logger.error('更新OpenVPN配置失败: $e');
      return false;
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
      if (e.toString().contains('404')) {
        throw Exception('订阅链接不存在，请检查链接是否正确');
      } else if (e.toString().contains('timeout')) {
        throw Exception('连接超时，请稍后重试');
      }
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
        final proxyResult = await _systemProxyManager.setSystemProxy(
          '127.0.0.1',
          6160,
          6161,
        );
        if (proxyResult) {
          Logger.info('系统代理设置成功');
        } else {
          Logger.error('系统代理设置失败');
        }

        // 协议应该在Go代理核心启动时自动初始化，无需手动添加
      } else {
        Logger.error('Go代理核心启动失败');
      }

      return result;
    } catch (e) {
      Logger.error('启动Go代理核心失败: $e');
      rethrow;
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

      // 获取Clash代理列表以获取代理详细信息
      final clashProxies = await getClashProxies();
      if (clashProxies == null || !clashProxies.containsKey('proxies')) {
        Logger.error('无法获取Clash代理列表');
        return false;
      }

      final proxiesData = clashProxies['proxies'] as Map?;
      if (proxiesData == null || !proxiesData.containsKey(cleanedProxyName)) {
        Logger.error('未找到指定的代理: $cleanedProxyName');
        return false;
      }

      final proxyData = proxiesData[cleanedProxyName] as Map?;
      if (proxyData == null) {
        Logger.error('代理数据为空: $cleanedProxyName');
        return false;
      }

      // 构造代理信息
      final proxyInfo = {
        'id': cleanedProxyName,
        'name': cleanedProxyName,
        'type': proxyData['type'] ?? 'http',
        'server': proxyData['server'] ?? '127.0.0.1',
        'port': proxyData['port'] ?? 7890,
        'config': <String, dynamic>{},
      };

      // 添加协议特定配置
      if (proxyData.containsKey('cipher')) {
        proxyInfo['config']['cipher'] = proxyData['cipher'];
      }
      if (proxyData.containsKey('password')) {
        proxyInfo['config']['password'] = proxyData['password'];
      }
      if (proxyData.containsKey('method')) {
        proxyInfo['config']['method'] = proxyData['method'];
      }
      if (proxyData.containsKey('uuid')) {
        proxyInfo['config']['uuid'] = proxyData['uuid'];
      }
      if (proxyData.containsKey('network')) {
        proxyInfo['config']['network'] = proxyData['network'];
      }
      if (proxyData.containsKey('tls')) {
        proxyInfo['config']['tls'] = proxyData['tls'];
      }

      // 设置clash代理源的当前代理
      final result = await setProxySourceCurrentProxy('clash', proxyInfo);
      if (result) {
        Logger.info('成功设置Clash代理源的当前代理: $cleanedProxyName');

        // 更新路由规则以使用新的代理
        final rules = [
          {
            'type': 'MATCH',
            'pattern': '',
            'proxy_source': 'clash', // 使用clash代理源而不是具体的代理名称
            'enabled': true,
          },
        ];

        final rulesResult = await updateGoProxyRules(rules);
        if (rulesResult) {
          Logger.info('成功更新路由规则以使用clash代理源');
        } else {
          Logger.error('更新路由规则失败');
        }

        return rulesResult;
      } else {
        Logger.error('设置Clash代理源当前代理失败: $selector -> $proxyName');
        return false;
      }
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

  // 设置代理源的当前代理
  Future<bool> setProxySourceCurrentProxy(
    String sourceId,
    Map<String, dynamic> proxyInfo,
  ) async {
    try {
      final result = await _goProxyService.setCurrentProxy(sourceId, proxyInfo);
      return result;
    } catch (e) {
      Logger.error('设置代理源当前代理失败: $e');
      return false;
    }
  }

  // 添加代理源
  Future<bool> addProxySource(
    String sourceId,
    String sourceName,
    String sourceType,
    Map<String, dynamic> sourceConfig,
  ) async {
    try {
      final result = await _goProxyService.addProxySource(
        sourceId,
        sourceName,
        sourceType,
        sourceConfig,
      );
      return result;
    } catch (e) {
      Logger.error('添加代理源失败: $e');
      return false;
    }
  }

  // 获取所有代理源
  Future<Map<String, dynamic>?> getGoProxySources() async {
    try {
      final sources = await _goProxyService.getProxySources();
      return sources;
    } catch (e) {
      Logger.error('获取Go代理核心代理源列表失败: $e');
      return null;
    }
  }

  // 删除代理源
  Future<bool> removeProxySource(String sourceId) async {
    try {
      final result = await _goProxyService.removeProxySource(sourceId);
      return result;
    } catch (e) {
      Logger.error('删除代理源失败: $e');
      return false;
    }
  }

  // 获取当前配置
  VPNConfig? get currentConfig => _currentConfig;
}
