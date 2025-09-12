import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/services/smart_routing_engine.dart';
import 'package:dualvpn_manager/utils/logger.dart';
import 'dart:io';
import 'dart:convert';

/// 代理管理器
/// 负责管理多个代理的协调工作和流量转发
class ProxyManager {
  final SmartRoutingEngine _routingEngine = SmartRoutingEngine();
  bool _isRunning = false;
  HttpServer? _proxyServer;
  int _proxyPort = 1080; // 默认SOCKS5代理端口

  // 设置路由规则
  void setRoutingRules(List<RoutingRule> rules) {
    _routingEngine.setRoutingRules(rules);
  }

  // 设置活动配置
  void setActiveConfigs(List<VPNConfig> configs) {
    _routingEngine.setActiveConfigs(configs);
  }

  // 启动代理服务
  Future<bool> startProxyService() async {
    if (_isRunning) {
      Logger.warn('代理服务已在运行中');
      return true;
    }

    try {
      // 启动SOCKS5代理服务器
      _proxyServer = await HttpServer.bind(InternetAddress.anyIPv4, _proxyPort);
      _isRunning = true;

      // 开始监听连接
      _proxyServer!.listen(_handleProxyRequest);

      Logger.info('SOCKS5代理服务已启动，监听端口 $_proxyPort');
      return true;
    } catch (e) {
      Logger.error('启动代理服务失败: $e');
      _isRunning = false;
      return false;
    }
  }

  // 停止代理服务
  Future<void> stopProxyService() async {
    if (!_isRunning) {
      Logger.warn('代理服务未在运行中');
      return;
    }

    try {
      await _proxyServer?.close();
      _proxyServer = null;
      _isRunning = false;
      Logger.info('代理服务已停止');
    } catch (e) {
      Logger.error('停止代理服务失败: $e');
    }
  }

  // 处理代理请求
  void _handleProxyRequest(HttpRequest request) async {
    try {
      Logger.debug('收到代理请求: ${request.uri}');

      // 根据目标地址选择代理
      final targetConfig = _routingEngine.selectProxyForDestination(
        request.uri.host,
      );

      if (targetConfig != null) {
        // 使用选定的代理转发请求
        await _forwardRequest(request, targetConfig);
      } else {
        // 没有匹配的代理，直接连接目标
        await _directConnection(request);
      }
    } catch (e) {
      Logger.error('处理代理请求失败: $e');
      _sendErrorResponse(request, 500, 'Internal Server Error');
    }
  }

  // 转发请求到指定代理
  Future<void> _forwardRequest(
    HttpRequest request,
    VPNConfig targetConfig,
  ) async {
    try {
      Logger.debug('转发请求到代理: ${targetConfig.name}');

      // 根据代理类型创建相应的连接
      switch (targetConfig.type) {
        case VPNType.openVPN:
          await _forwardToOpenVPN(request, targetConfig);
          break;
        case VPNType.clash:
          await _forwardToClash(request, targetConfig);
          break;
        case VPNType.shadowsocks:
          await _forwardToShadowsocks(request, targetConfig);
          break;
        case VPNType.v2ray:
          await _forwardToV2Ray(request, targetConfig);
          break;
        case VPNType.httpProxy:
          await _forwardToHTTPProxy(request, targetConfig);
          break;
        case VPNType.socks5:
          await _forwardToSOCKS5Proxy(request, targetConfig);
          break;
        case VPNType.custom:
          await _forwardToCustomProxy(request, targetConfig);
          break;
      }
    } catch (e) {
      Logger.error('转发请求失败: $e');
      _sendErrorResponse(request, 502, 'Bad Gateway');
    }
  }

  // 转发到OpenVPN
  Future<void> _forwardToOpenVPN(HttpRequest request, VPNConfig config) async {
    // OpenVPN通常通过TUN/TAP设备工作，这里简化处理
    await _directConnection(request);
  }

  // 转发到Clash
  Future<void> _forwardToClash(HttpRequest request, VPNConfig config) async {
    // Clash通常有自己的HTTP/SOCKS5代理端口，这里简化处理
    await _forwardToHTTPProxy(request, config);
  }

  // 转发到Shadowsocks
  Future<void> _forwardToShadowsocks(
    HttpRequest request,
    VPNConfig config,
  ) async {
    // Shadowsocks通常有自己的SOCKS5代理端口，这里简化处理
    await _forwardToSOCKS5Proxy(request, config);
  }

  // 转发到V2Ray
  Future<void> _forwardToV2Ray(HttpRequest request, VPNConfig config) async {
    // V2Ray通常有自己的HTTP/SOCKS5代理端口，这里简化处理
    await _forwardToSOCKS5Proxy(request, config);
  }

  // 转发到HTTP代理
  Future<void> _forwardToHTTPProxy(
    HttpRequest request,
    VPNConfig config,
  ) async {
    try {
      // 解析HTTP代理配置
      final parts = config.configPath.split(':');
      if (parts.length != 2) {
        throw Exception('HTTP代理配置路径格式错误');
      }

      final proxyHost = parts[0];
      final proxyPort = int.tryParse(parts[1]);
      if (proxyPort == null) {
        throw Exception('HTTP代理端口格式错误');
      }

      // 创建到HTTP代理的连接
      final proxySocket = await Socket.connect(proxyHost, proxyPort);

      // 发送CONNECT请求（如果是HTTPS）
      if (request.uri.scheme == 'https') {
        final connectRequest =
            'CONNECT ${request.uri.host}:${request.uri.port} HTTP/1.1\r\n'
            'Host: ${request.uri.host}:${request.uri.port}\r\n\r\n';
        proxySocket.write(connectRequest);

        // 读取代理响应
        final response = await proxySocket.first;
        final responseString = utf8.decode(response);

        if (!responseString.startsWith('HTTP/1.1 200')) {
          throw Exception('代理连接失败: $responseString');
        }
      }

      // 转发请求数据
      request.listen(
        (data) {
          proxySocket.add(data);
        },
        onDone: () {
          proxySocket.close();
        },
        onError: (error) {
          Logger.error('转发到HTTP代理时出错: $error');
          proxySocket.close();
        },
      );

      // 转发响应数据
      proxySocket.listen(
        (data) {
          request.response.add(data);
        },
        onDone: () {
          request.response.close();
        },
        onError: (error) {
          Logger.error('从HTTP代理接收数据时出错: $error');
          request.response.close();
        },
      );
    } catch (e) {
      Logger.error('转发到HTTP代理失败: $e');
      rethrow;
    }
  }

  // 转发到SOCKS5代理
  Future<void> _forwardToSOCKS5Proxy(
    HttpRequest request,
    VPNConfig config,
  ) async {
    try {
      // 解析SOCKS5代理配置
      final parts = config.configPath.split(':');
      if (parts.length != 2) {
        throw Exception('SOCKS5代理配置路径格式错误');
      }

      final proxyHost = parts[0];
      final proxyPort = int.tryParse(parts[1]);
      if (proxyPort == null) {
        throw Exception('SOCKS5代理端口格式错误');
      }

      // 创建到SOCKS5代理的连接
      final proxySocket = await Socket.connect(proxyHost, proxyPort);

      // 发送SOCKS5握手请求
      proxySocket.add([0x05, 0x01, 0x00]); // SOCKS5, 1种认证方法, 无认证

      // 读取握手响应
      final handshakeResponse = await proxySocket.first;
      if (handshakeResponse.length < 2 ||
          handshakeResponse[0] != 0x05 ||
          handshakeResponse[1] != 0x00) {
        throw Exception('SOCKS5握手失败');
      }

      // 发送连接请求
      final hostBytes = _encodeDomain(request.uri.host);
      final portBytes = _encodePort(request.uri.port);
      final connectRequest = [
        0x05, // SOCKS版本
        0x01, // CONNECT命令
        0x00, // 保留字段
        ...hostBytes,
        ...portBytes,
      ];
      proxySocket.add(connectRequest);

      // 读取连接响应
      final connectResponse = await proxySocket.first;
      if (connectResponse.length < 10 || connectResponse[1] != 0x00) {
        throw Exception('SOCKS5连接失败');
      }

      // 转发请求数据
      request.listen(
        (data) {
          proxySocket.add(data);
        },
        onDone: () {
          proxySocket.close();
        },
        onError: (error) {
          Logger.error('转发到SOCKS5代理时出错: $error');
          proxySocket.close();
        },
      );

      // 转发响应数据
      proxySocket.listen(
        (data) {
          request.response.add(data);
        },
        onDone: () {
          request.response.close();
        },
        onError: (error) {
          Logger.error('从SOCKS5代理接收数据时出错: $error');
          request.response.close();
        },
      );
    } catch (e) {
      Logger.error('转发到SOCKS5代理失败: $e');
      rethrow;
    }
  }

  // 转发到自定义代理
  Future<void> _forwardToCustomProxy(
    HttpRequest request,
    VPNConfig config,
  ) async {
    // 自定义代理的处理逻辑需要根据具体配置实现
    // 这里简化处理为直接连接
    await _directConnection(request);
  }

  // 直接连接目标（不使用代理）
  Future<void> _directConnection(HttpRequest request) async {
    try {
      Logger.debug('直接连接目标: ${request.uri}');

      // 创建到目标服务器的连接
      final targetSocket = await Socket.connect(
        request.uri.host,
        request.uri.port ?? 80,
      );

      // 转发请求数据
      request.listen(
        (data) {
          targetSocket.add(data);
        },
        onDone: () {
          targetSocket.close();
        },
        onError: (error) {
          Logger.error('转发到目标时出错: $error');
          targetSocket.close();
        },
      );

      // 转发响应数据
      targetSocket.listen(
        (data) {
          request.response.add(data);
        },
        onDone: () {
          request.response.close();
        },
        onError: (error) {
          Logger.error('从目标接收数据时出错: $error');
          request.response.close();
        },
      );
    } catch (e) {
      Logger.error('直接连接目标失败: $e');
      _sendErrorResponse(request, 502, 'Bad Gateway');
    }
  }

  // 发送错误响应
  void _sendErrorResponse(HttpRequest request, int statusCode, String message) {
    request.response
      ..statusCode = statusCode
      ..write(message)
      ..close();
  }

  // 编码域名
  List<int> _encodeDomain(String domain) {
    final bytes = <int>[];
    bytes.add(0x03); // 域名类型
    final domainBytes = utf8.encode(domain);
    bytes.add(domainBytes.length);
    bytes.addAll(domainBytes);
    return bytes;
  }

  // 编码端口
  List<int> _encodePort(int port) {
    return [(port >> 8) & 0xFF, port & 0xFF];
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
