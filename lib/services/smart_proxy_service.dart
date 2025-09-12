import 'dart:io';
import 'dart:convert';
import 'package:dualvpn_manager/utils/logger.dart';

/// 智能代理服务
/// 负责拦截系统网络流量并根据路由规则进行转发
class SmartProxyService {
  static final SmartProxyService _instance = SmartProxyService._internal();
  factory SmartProxyService() => _instance;
  SmartProxyService._internal() : _port = 1080;

  HttpServer? _server;
  bool _isRunning = false;
  Function(String host, int port)? _routeHandler;
  int _port;

  /// 启动代理服务
  Future<bool> start() async {
    if (_isRunning) {
      Logger.warn('智能代理服务已在运行中');
      return true;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _server!.listen(_handleRequest);
      _isRunning = true;
      Logger.info('智能代理服务已启动，监听端口 $_port');
      return true;
    } catch (e) {
      Logger.error('启动智能代理服务失败: $e');
      _isRunning = false;
      return false;
    }
  }

  /// 停止代理服务
  Future<void> stop() async {
    if (!_isRunning) {
      Logger.warn('智能代理服务未在运行中');
      return;
    }

    try {
      await _server?.close();
      _server = null;
      _isRunning = false;
      Logger.info('智能代理服务已停止');
    } catch (e) {
      Logger.error('停止智能代理服务失败: $e');
    }
  }

  /// 设置路由处理器
  void setRouteHandler(Function(String host, int port) handler) {
    _routeHandler = handler;
  }

  /// 处理HTTP请求
  void _handleRequest(HttpRequest request) async {
    try {
      Logger.debug('拦截到请求: ${request.method} ${request.uri}');

      // 根据路由规则决定如何处理请求
      if (_routeHandler != null) {
        _routeHandler!(request.uri.host, request.uri.port ?? 80);
      }

      // 实现实际的请求转发逻辑
      await _forwardRequest(request);
    } catch (e) {
      Logger.error('处理请求失败: $e');
      request.response
        ..statusCode = 500
        ..write('Internal Server Error')
        ..close();
    }
  }

  /// 转发HTTP请求
  Future<void> _forwardRequest(HttpRequest request) async {
    try {
      // 创建到目标服务器的连接
      final targetSocket = await Socket.connect(
        request.uri.host,
        request.uri.port ?? 80,
      );

      // 构建HTTP请求
      final StringBuffer requestBuffer = StringBuffer();
      requestBuffer.write('${request.method} ${request.uri.path}');
      if (request.uri.query.isNotEmpty) {
        requestBuffer.write('?${request.uri.query}');
      }
      requestBuffer.write(' HTTP/${request.protocolVersion}\r\n');

      // 添加请求头
      request.headers.forEach((name, values) {
        for (var value in values) {
          requestBuffer.write('$name: $value\r\n');
        }
      });
      requestBuffer.write('\r\n');

      // 发送请求行和头部
      targetSocket.write(requestBuffer.toString());

      // 转发请求体
      await request.forEach((data) {
        targetSocket.add(data);
      });

      // 转发响应
      final response = targetSocket.asBroadcastStream();
      bool headersSent = false;
      StringBuffer headerBuffer = StringBuffer();

      await for (var data in response) {
        if (!headersSent) {
          // 收集响应头
          headerBuffer.write(utf8.decode(data, allowMalformed: true));
          final headerString = headerBuffer.toString();
          final headerEndIndex = headerString.indexOf('\r\n\r\n');

          if (headerEndIndex != -1) {
            // 响应头已完整
            headersSent = true;
            final headers = headerString.substring(0, headerEndIndex);
            final bodyStart = headerEndIndex + 4;

            // 解析响应状态行和头部
            final lines = headers.split('\r\n');
            if (lines.isNotEmpty) {
              final statusLine = lines[0];
              final statusParts = statusLine.split(' ');
              if (statusParts.length >= 2) {
                request.response.statusCode =
                    int.tryParse(statusParts[1]) ?? 200;
              }
            }

            // 转发响应头（除了连接相关的头部）
            for (int i = 1; i < lines.length; i++) {
              final line = lines[i];
              if (line.toLowerCase().startsWith('connection:') ||
                  line.toLowerCase().startsWith('transfer-encoding:')) {
                continue; // 跳过这些头部
              }
              final colonIndex = line.indexOf(':');
              if (colonIndex != -1) {
                final name = line.substring(0, colonIndex).trim();
                final value = line.substring(colonIndex + 1).trim();
                request.response.headers.set(name, value);
              }
            }

            // 发送响应头
            await request.response.flush();

            // 发送响应体的剩余部分
            if (bodyStart < headerString.length) {
              final remainingBody = headerString.substring(bodyStart);
              request.response.write(remainingBody);
            }

            // 继续转发后续数据
            continue;
          }
        }

        // 直接转发数据
        request.response.add(data);
      }

      await request.response.close();
      targetSocket.close();
    } catch (e) {
      Logger.error('转发请求失败: $e');
      request.response
        ..statusCode = 502
        ..write('Bad Gateway')
        ..close();
    }
  }

  /// 获取服务状态
  bool get isRunning => _isRunning;

  /// 获取代理端口
  int get port => _port;
}
