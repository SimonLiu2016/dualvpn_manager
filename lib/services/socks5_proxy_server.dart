import 'dart:io';
import 'dart:typed_data';
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:dualvpn_manager/services/smart_routing_engine.dart';
import 'package:dualvpn_manager/models/vpn_config.dart' hide RoutingRule;

/// SOCKS5代理服务器
/// 实现真正的SOCKS5协议，监听原始TCP连接并转发流量
class SOCKS5ProxyServer {
  ServerSocket? _serverSocket;
  int _port;
  bool _isRunning = false;
  SmartRoutingEngine _routingEngine = SmartRoutingEngine();

  SOCKS5ProxyServer({int port = 1080}) : _port = port;

  bool get isRunning => _isRunning;
  int get port => _port;

  /// 启动SOCKS5代理服务器
  Future<bool> start() async {
    if (_isRunning) {
      Logger.warn('SOCKS5代理服务器已在运行中');
      return true;
    }

    // 尝试绑定到指定端口，如果失败则尝试其他端口
    int attemptPort = _port;
    while (attemptPort < _port + 10) {
      try {
        Logger.info('尝试启动SOCKS5代理服务器，端口: $attemptPort');
        _serverSocket = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          attemptPort,
        );
        _port = attemptPort; // 更新实际使用的端口
        _isRunning = true;
        Logger.info('SOCKS5代理服务器启动成功，监听端口: $_port');

        // 开始监听连接
        _serverSocket!.listen(
          _handleClientConnection,
          onError: (error) {
            Logger.error('SOCKS5代理服务器连接错误: $error');
          },
          onDone: () {
            Logger.info('SOCKS5代理服务器连接监听完成');
          },
        );

        return true;
      } catch (e, stackTrace) {
        Logger.error(
          '启动SOCKS5代理服务器失败 (端口 $attemptPort): $e\nStack trace: $stackTrace',
        );
        attemptPort++;
      }
    }

    Logger.error('无法在端口 $_port 到 ${_port + 10} 范围内启动SOCKS5代理服务器');
    _isRunning = false;
    return false;
  }

  /// 停止SOCKS5代理服务器
  Future<void> stop() async {
    if (!_isRunning) {
      Logger.warn('SOCKS5代理服务器未在运行中');
      return;
    }

    try {
      Logger.info('尝试关闭SOCKS5代理服务器');
      await _serverSocket?.close();
      _serverSocket = null;
      _isRunning = false;
      Logger.info('SOCKS5代理服务器已停止');
    } catch (e, stackTrace) {
      Logger.error('停止SOCKS5代理服务器失败: $e\nStack trace: $stackTrace');
    }
  }

  /// 处理客户端连接 - 使用单次监听避免重复监听错误
  void _handleClientConnection(Socket clientSocket) {
    Logger.debug(
      '新的客户端连接: ${clientSocket.remoteAddress.address}:${clientSocket.remotePort}',
    );

    try {
      // 使用标志跟踪连接状态
      bool handshakeCompleted = false;
      bool connectionClosed = false;

      // 创建一个包装器来安全地关闭连接
      void safeClose() {
        if (!connectionClosed) {
          connectionClosed = true;
          try {
            clientSocket.close();
          } catch (e) {
            Logger.error('关闭客户端连接时出错: $e');
          }
        }
      }

      // 监听客户端数据，但只处理一次握手
      clientSocket.listen(
        (data) {
          if (connectionClosed) return;

          if (!handshakeCompleted) {
            handshakeCompleted = true;
            _handleSOCKS5Handshake(clientSocket, data, safeClose);
          } else {
            // 握手完成后，处理连接请求
            _handleConnectionRequest(clientSocket, data, safeClose);
          }
        },
        onError: (error) {
          Logger.error('客户端连接错误: $error');
          safeClose();
        },
        onDone: () {
          Logger.debug('客户端连接完成');
          safeClose();
        },
      );
    } catch (e) {
      Logger.error('处理客户端连接失败: $e');
      try {
        clientSocket.close();
      } catch (closeError) {
        Logger.error('关闭客户端连接失败: $closeError');
      }
    }
  }

  /// 处理SOCKS5握手
  void _handleSOCKS5Handshake(
    Socket clientSocket,
    Uint8List data,
    void Function() safeClose,
  ) {
    try {
      // 检查SOCKS5版本
      if (data.length < 2 || data[0] != 0x05) {
        Logger.error('无效的SOCKS5请求');
        safeClose();
        return;
      }

      final nMethods = data[1];
      if (data.length < 2 + nMethods) {
        Logger.error('SOCKS5握手数据不完整');
        safeClose();
        return;
      }

      // 检查支持的认证方法（我们只支持无认证）
      bool noAuthSupported = false;
      for (int i = 0; i < nMethods; i++) {
        if (data[2 + i] == 0x00) {
          noAuthSupported = true;
          break;
        }
      }

      if (!noAuthSupported) {
        // 不支持的认证方法，返回错误
        try {
          clientSocket.add([0x05, 0xFF]); // VER, METHOD (无支持的方法)
          clientSocket
              .flush()
              .then((_) {
                safeClose();
              })
              .catchError((_) {
                safeClose();
              });
        } catch (e) {
          Logger.error('发送认证失败响应失败: $e');
          safeClose();
        }
        return;
      }

      // 发送握手响应（无认证）
      try {
        clientSocket.add([0x05, 0x00]); // VER, METHOD (无认证)
        clientSocket
            .flush()
            .then((_) {
              Logger.debug('SOCKS5握手成功');
            })
            .catchError((error) {
              Logger.error('发送握手响应时出错: $error');
              safeClose();
            });
      } catch (e) {
        Logger.error('发送握手响应失败: $e');
        safeClose();
        return;
      }
    } catch (e) {
      Logger.error('处理SOCKS5握手失败: $e');
      safeClose();
    }
  }

  /// 处理连接请求
  void _handleConnectionRequest(
    Socket clientSocket,
    Uint8List data,
    void Function() safeClose,
  ) {
    try {
      // 检查请求格式
      if (data.length < 4) {
        Logger.error('SOCKS5连接请求数据不完整');
        safeClose();
        return;
      }

      // 检查版本和命令
      final ver = data[0];
      final cmd = data[1];
      final atyp = data[3];

      if (ver != 0x05) {
        Logger.error('无效的SOCKS5版本');
        _sendConnectionResponse(clientSocket, 0x01, safeClose); // 一般SOCKS服务器故障
        return;
      }

      if (cmd != 0x01) {
        Logger.error('不支持的SOCKS5命令: $cmd');
        _sendConnectionResponse(clientSocket, 0x07, safeClose); // 命令不被支持
        return;
      }

      // 解析目标地址
      String? targetHost;
      int? targetPort;

      try {
        switch (atyp) {
          case 0x01: // IPv4
            if (data.length < 10) {
              throw Exception('IPv4地址数据不完整');
            }
            targetHost = '${data[4]}.${data[5]}.${data[6]}.${data[7]}';
            targetPort = (data[8] << 8) | data[9];
            break;
          case 0x03: // 域名
            if (data.length < 5) {
              throw Exception('域名地址数据不完整');
            }
            final domainLength = data[4];
            if (data.length < 5 + domainLength + 2) {
              throw Exception('域名地址数据不完整');
            }
            targetHost = String.fromCharCodes(
              data.sublist(5, 5 + domainLength),
            );
            targetPort =
                (data[5 + domainLength] << 8) | data[5 + domainLength + 1];
            break;
          case 0x04: // IPv6
            Logger.error('不支持IPv6地址');
            _sendConnectionResponse(clientSocket, 0x08, safeClose); // 地址类型不支持
            return;
          default:
            Logger.error('不支持的地址类型: $atyp');
            _sendConnectionResponse(clientSocket, 0x08, safeClose); // 地址类型不支持
            return;
        }
      } catch (e) {
        Logger.error('解析目标地址失败: $e');
        _sendConnectionResponse(clientSocket, 0x01, safeClose); // 一般SOCKS服务器故障
        return;
      }

      if (targetHost == null || targetPort == null) {
        Logger.error('无法解析目标地址');
        _sendConnectionResponse(clientSocket, 0x01, safeClose); // 一般SOCKS服务器故障
        return;
      }

      Logger.debug('目标地址: $targetHost:$targetPort');

      // 根据路由规则决定是否代理
      final routeDecision = _routingEngine.decideRoute(targetHost);
      Logger.debug(
        '路由决策结果: shouldProxy=${routeDecision.shouldProxy}, reason=${routeDecision.reason}',
      );

      // 使用异步处理避免阻塞
      Future(() async {
        if (routeDecision.shouldProxy && routeDecision.proxyConfig != null) {
          // 使用选定的代理转发连接
          await _forwardConnection(
            clientSocket,
            targetHost!,
            targetPort!,
            routeDecision.proxyConfig!,
            safeClose,
          );
        } else {
          // 直接连接目标
          await _directConnection(
            clientSocket,
            targetHost!,
            targetPort!,
            safeClose,
          );
        }
      }).catchError((error) {
        Logger.error('处理连接请求失败: $error');
        try {
          _sendConnectionResponse(
            clientSocket,
            0x01,
            safeClose,
          ); // 一般SOCKS服务器故障
        } catch (responseError) {
          Logger.error('发送连接失败响应也失败: $responseError');
        }
        safeClose();
      });
    } catch (e) {
      Logger.error('处理连接请求数据失败: $e');
      try {
        _sendConnectionResponse(clientSocket, 0x01, safeClose); // 一般SOCKS服务器故障
      } catch (responseError) {
        Logger.error('发送连接失败响应也失败: $responseError');
      }
      safeClose();
    }
  }

  /// 发送连接响应
  void _sendConnectionResponse(
    Socket clientSocket,
    int replyCode,
    void Function() safeClose,
  ) {
    try {
      // VER, REP, RSV, ATYP, BND.ADDR, BND.PORT
      final response = [
        0x05, // VER
        replyCode, // REP
        0x00, // RSV
        0x01, // ATYP (IPv4)
        0x00, 0x00, 0x00, 0x00, // BND.ADDR (0.0.0.0)
        0x00, 0x00, // BND.PORT (0)
      ];
      clientSocket.add(response);
      clientSocket.flush().catchError((error) {
        Logger.error('刷新socket时出错: $error');
        safeClose();
      });
    } catch (e) {
      Logger.error('发送连接响应失败: $e');
      safeClose();
    }
  }

  /// 直接连接到目标
  Future<void> _directConnection(
    Socket clientSocket,
    String targetHost,
    int targetPort,
    void Function() safeClose,
  ) async {
    try {
      Logger.debug('直接连接到目标: $targetHost:$targetPort');

      // 连接到目标服务器
      final targetSocket = await Socket.connect(
        targetHost,
        targetPort,
        timeout: Duration(seconds: 30),
      );

      // 发送成功响应
      _sendConnectionResponse(clientSocket, 0x00, safeClose); // 成功

      // 建立双向数据转发
      _forwardData(clientSocket, targetSocket, safeClose);
    } catch (e) {
      Logger.error('直接连接失败: $e');

      try {
        // 尝试发送错误响应，但如果失败就忽略
        _sendConnectionResponse(clientSocket, 0x05, safeClose); // 连接被拒绝
      } catch (responseError) {
        Logger.error('发送连接失败响应也失败: $responseError');
      }

      // 关闭客户端连接
      safeClose();
    }
  }

  /// 通过代理转发连接
  Future<void> _forwardConnection(
    Socket clientSocket,
    String targetHost,
    int targetPort,
    VPNConfig proxyConfig,
    void Function() safeClose,
  ) async {
    try {
      Logger.debug('通过代理转发连接: ${proxyConfig.name} ($targetHost:$targetPort)');

      // 根据代理类型创建连接
      switch (proxyConfig.type) {
        case VPNType.clash:
          await _forwardToClashProxy(
            clientSocket,
            targetHost,
            targetPort,
            proxyConfig,
            safeClose,
          );
          break;
        case VPNType.httpProxy:
          await _forwardToHTTPProxy(
            clientSocket,
            targetHost,
            targetPort,
            proxyConfig,
            safeClose,
          );
          break;
        case VPNType.socks5:
          await _forwardToSOCKS5Proxy(
            clientSocket,
            targetHost,
            targetPort,
            proxyConfig,
            safeClose,
          );
          break;
        default:
          // 对于其他类型，直接连接
          await _directConnection(
            clientSocket,
            targetHost,
            targetPort,
            safeClose,
          );
      }
    } catch (e) {
      Logger.error('代理转发连接失败: $e');
      _sendConnectionResponse(clientSocket, 0x05, safeClose); // 连接被拒绝
      safeClose();
    }
  }

  /// 转发到Clash代理
  Future<void> _forwardToClashProxy(
    Socket clientSocket,
    String targetHost,
    int targetPort,
    VPNConfig proxyConfig,
    void Function() safeClose,
  ) async {
    try {
      // Clash通常使用7890端口作为HTTP代理
      final proxySocket = await Socket.connect(
        '127.0.0.1',
        7890,
        timeout: Duration(seconds: 30),
      );

      // 发送CONNECT请求
      final connectRequest =
          'CONNECT $targetHost:$targetPort HTTP/1.1\r\n'
          'Host: $targetHost:$targetPort\r\n\r\n';
      proxySocket.write(connectRequest);

      // 读取响应
      final response = await proxySocket.first;
      final responseString = String.fromCharCodes(response);

      if (!responseString.startsWith('HTTP/1.1 200')) {
        throw Exception('Clash代理连接失败: $responseString');
      }

      // 发送成功响应给客户端
      _sendConnectionResponse(clientSocket, 0x00, safeClose); // 成功

      // 建立双向数据转发
      _forwardData(clientSocket, proxySocket, safeClose);
    } catch (e) {
      Logger.error('转发到Clash代理失败: $e');
      rethrow;
    }
  }

  /// 转发到HTTP代理
  Future<void> _forwardToHTTPProxy(
    Socket clientSocket,
    String targetHost,
    int targetPort,
    VPNConfig proxyConfig,
    void Function() safeClose,
  ) async {
    try {
      // 解析HTTP代理配置
      final parts = proxyConfig.configPath.split(':');
      if (parts.length != 2) {
        throw Exception('HTTP代理配置路径格式错误');
      }

      final proxyHost = parts[0];
      final proxyPort = int.tryParse(parts[1]);
      if (proxyPort == null) {
        throw Exception('HTTP代理端口格式错误');
      }

      final proxySocket = await Socket.connect(
        proxyHost,
        proxyPort,
        timeout: Duration(seconds: 30),
      );

      // 发送CONNECT请求
      final connectRequest =
          'CONNECT $targetHost:$targetPort HTTP/1.1\r\n'
          'Host: $targetHost:$targetPort\r\n\r\n';
      proxySocket.write(connectRequest);

      // 读取响应
      final response = await proxySocket.first;
      final responseString = String.fromCharCodes(response);

      if (!responseString.startsWith('HTTP/1.1 200')) {
        throw Exception('HTTP代理连接失败: $responseString');
      }

      // 发送成功响应给客户端
      _sendConnectionResponse(clientSocket, 0x00, safeClose); // 成功

      // 建立双向数据转发
      _forwardData(clientSocket, proxySocket, safeClose);
    } catch (e) {
      Logger.error('转发到HTTP代理失败: $e');
      rethrow;
    }
  }

  /// 转发到SOCKS5代理
  Future<void> _forwardToSOCKS5Proxy(
    Socket clientSocket,
    String targetHost,
    int targetPort,
    VPNConfig proxyConfig,
    void Function() safeClose,
  ) async {
    try {
      // 解析SOCKS5代理配置
      final parts = proxyConfig.configPath.split(':');
      if (parts.length != 2) {
        throw Exception('SOCKS5代理配置路径格式错误');
      }

      final proxyHost = parts[0];
      final proxyPort = int.tryParse(parts[1]);
      if (proxyPort == null) {
        throw Exception('SOCKS5代理端口格式错误');
      }

      final proxySocket = await Socket.connect(
        proxyHost,
        proxyPort,
        timeout: Duration(seconds: 30),
      );

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
      final hostBytes = _encodeDomain(targetHost);
      final portBytes = _encodePort(targetPort);
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

      // 发送成功响应给客户端
      _sendConnectionResponse(clientSocket, 0x00, safeClose); // 成功

      // 建立双向数据转发
      _forwardData(clientSocket, proxySocket, safeClose);
    } catch (e) {
      Logger.error('转发到SOCKS5代理失败: $e');
      rethrow;
    }
  }

  /// 建立双向数据转发
  void _forwardData(
    Socket clientSocket,
    Socket targetSocket,
    void Function() safeClose,
  ) {
    // 添加标志来跟踪连接状态
    bool clientClosed = false;
    bool targetClosed = false;

    // 创建安全关闭函数
    void safeClientClose() {
      if (!clientClosed) {
        clientClosed = true;
        try {
          clientSocket.close();
        } catch (e) {
          Logger.error('关闭客户端连接时出错: $e');
        }
      }
    }

    void safeTargetClose() {
      if (!targetClosed) {
        targetClosed = true;
        try {
          targetSocket.close();
        } catch (e) {
          Logger.error('关闭目标连接时出错: $e');
        }
      }
    }

    // 从客户端到目标服务器
    clientSocket.listen(
      (data) {
        if (!targetClosed) {
          try {
            targetSocket.add(data);
            targetSocket.flush();
          } catch (e) {
            Logger.error('转发客户端数据到目标服务器时出错: $e');
            clientClosed = true;
            targetClosed = true;
            safeClientClose();
            safeTargetClose();
          }
        }
      },
      onError: (error) {
        Logger.error('客户端连接错误: $error');
        clientClosed = true;
        if (!targetClosed) {
          targetClosed = true;
          safeTargetClose();
        }
      },
      onDone: () {
        Logger.debug('客户端连接完成');
        clientClosed = true;
        if (!targetClosed) {
          targetClosed = true;
          safeTargetClose();
        }
      },
    );

    // 从目标服务器到客户端
    targetSocket.listen(
      (data) {
        if (!clientClosed) {
          try {
            clientSocket.add(data);
            clientSocket.flush();
          } catch (e) {
            Logger.error('转发目标服务器数据到客户端时出错: $e');
            targetClosed = true;
            clientClosed = true;
            safeTargetClose();
            safeClientClose();
          }
        }
      },
      onError: (error) {
        Logger.error('目标服务器连接错误: $error');
        targetClosed = true;
        if (!clientClosed) {
          clientClosed = true;
          safeClientClose();
        }
      },
      onDone: () {
        Logger.debug('目标服务器连接完成');
        targetClosed = true;
        if (!clientClosed) {
          clientClosed = true;
          safeClientClose();
        }
      },
    );
  }

  /// 编码域名
  List<int> _encodeDomain(String domain) {
    final bytes = <int>[];
    bytes.add(0x03); // 域名类型
    final domainBytes = domain.codeUnits;
    bytes.add(domainBytes.length);
    bytes.addAll(domainBytes);
    return bytes;
  }

  /// 编码端口
  List<int> _encodePort(int port) {
    return [(port >> 8) & 0xFF, port & 0xFF];
  }

  /// 更新活动代理配置
  void updateActiveProxies(Map<String, VPNConfig> proxies) {
    _routingEngine.updateActiveProxies(proxies);
  }

  /// 设置路由规则
  void setRoutingRules(List<RoutingRule> rules) {
    _routingEngine.updateRoutingRules(rules);
  }
}
