import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dualvpn_manager/utils/logger.dart';

class SOCKS5Server {
  ServerSocket? _serverSocket;
  int _port;
  bool _isRunning = false;
  Function(Socket, Uint8List)? _onConnection;

  SOCKS5Server({int port = 1080}) : _port = port;

  bool get isRunning => _isRunning;
  int get port => _port;

  // 启动SOCKS5服务器
  Future<bool> start() async {
    if (_isRunning) {
      Logger.warn('SOCKS5服务器已在运行中');
      return true;
    }

    try {
      Logger.info('尝试启动SOCKS5服务器，端口: $_port');
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;

      Logger.info('SOCKS5服务器启动成功，监听端口: $_port');

      // 开始监听连接
      _serverSocket!.listen(
        _handleConnection,
        onError: (error) {
          Logger.error('SOCKS5服务器连接错误: $error');
        },
        onDone: () {
          Logger.info('SOCKS5服务器连接监听完成');
        },
      );

      return true;
    } catch (e, stackTrace) {
      Logger.error('启动SOCKS5服务器失败: $e\nStack trace: $stackTrace');
      _isRunning = false;

      // 尝试使用其他端口
      if (_port < 1085) {
        Logger.info('尝试使用端口 ${_port + 1}');
        _port++;
        return await start();
      } else {
        Logger.error('无法绑定到任何端口');
        return false;
      }
    }
  }

  // 停止SOCKS5服务器
  Future<void> stop() async {
    if (!_isRunning) {
      Logger.warn('SOCKS5服务器未在运行中');
      return;
    }

    try {
      Logger.info('尝试关闭SOCKS5服务器');
      await _serverSocket?.close();
      _serverSocket = null;
      _isRunning = false;
      Logger.info('SOCKS5服务器已停止');
    } catch (e, stackTrace) {
      Logger.error('停止SOCKS5服务器失败: $e\nStack trace: $stackTrace');
    }
  }

  // 设置连接处理回调
  void setOnConnectionHandler(Function(Socket, Uint8List) handler) {
    _onConnection = handler;
  }

  // 处理客户端连接
  void _handleConnection(Socket clientSocket) {
    Logger.debug(
      '新的客户端连接: ${clientSocket.remoteAddress.address}:${clientSocket.remotePort}',
    );

    try {
      // 监听客户端数据
      clientSocket.listen(
        (data) {
          Logger.debug('收到客户端数据，长度: ${data.length}');
          // 调用连接处理回调
          _onConnection?.call(clientSocket, data);
        },
        onError: (error) {
          Logger.error('客户端连接错误: $error');
          clientSocket.close();
        },
        onDone: () {
          Logger.debug('客户端连接完成');
          clientSocket.close();
        },
      );
    } catch (e) {
      Logger.error('处理客户端连接失败: $e');
      clientSocket.close();
    }
  }
}
