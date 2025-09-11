import 'dart:io';
import 'dart:convert';
import 'package:dualvpn_manager/utils/logger.dart';

class SOCKS5ProxyService {
  bool _isConnected = false;
  String _server = '';
  int _port = 0;
  String? _username;
  String? _password;
  Socket? _socket;

  bool get isConnected => _isConnected;

  // 启动SOCKS5代理
  Future<bool> start(
    String server,
    int port, {
    String? username,
    String? password,
  }) async {
    try {
      _server = server;
      _port = port;
      _username = username;
      _password = password;

      // 尝试连接到SOCKS5代理服务器
      _socket = await Socket.connect(
        server,
        port,
        timeout: Duration(seconds: 10),
      );

      // 执行SOCKS5握手
      final result = await _performHandshake();
      if (result) {
        _isConnected = true;
        Logger.info('SOCKS5代理连接成功: $server:$port');
        return true;
      } else {
        await _socket?.close();
        _socket = null;
        Logger.error('SOCKS5代理握手失败: $server:$port');
        return false;
      }
    } catch (e) {
      Logger.error('启动SOCKS5代理失败: $e');
      return false;
    }
  }

  // 执行SOCKS5握手
  Future<bool> _performHandshake() async {
    try {
      // 发送SOCKS5握手请求
      // VER = 5, NMETHODS = 1, METHODS = 0 (无认证) 或 2 (用户名/密码认证)
      List<int> request = [];
      request.add(0x05); // VER

      if (_username != null && _password != null) {
        // 使用用户名/密码认证
        request.add(0x01); // NMETHODS
        request.add(0x02); // METHODS (用户名/密码)
      } else {
        // 无认证
        request.add(0x01); // NMETHODS
        request.add(0x00); // METHODS (无认证)
      }

      _socket!.add(request);
      await _socket!.flush();

      // 读取服务器响应
      final response = await _socket!.first;
      if (response.length < 2) {
        return false;
      }

      final ver = response[0];
      final method = response[1];

      if (ver != 0x05) {
        Logger.error('SOCKS5版本不匹配: $ver');
        return false;
      }

      // 如果需要用户名/密码认证
      if (method == 0x02 && _username != null && _password != null) {
        return await _performUserPassAuth();
      }

      // 检查服务器是否支持我们请求的认证方法
      if ((_username != null && _password != null && method != 0x02) ||
          (_username == null && method != 0x00)) {
        Logger.error('SOCKS5服务器不支持请求的认证方法: $method');
        return false;
      }

      return true;
    } catch (e) {
      Logger.error('SOCKS5握手失败: $e');
      return false;
    }
  }

  // 执行用户名/密码认证
  Future<bool> _performUserPassAuth() async {
    try {
      // 发送用户名/密码认证请求
      // VER = 1, ULEN = username长度, UNAME = username, PLEN = password长度, PASSWD = password
      List<int> request = [];
      request.add(0x01); // VER
      request.add(_username!.length); // ULEN
      request.addAll(utf8.encode(_username!)); // UNAME
      request.add(_password!.length); // PLEN
      request.addAll(utf8.encode(_password!)); // PASSWD

      _socket!.add(request);
      await _socket!.flush();

      // 读取认证响应
      final response = await _socket!.first;
      if (response.length < 2) {
        return false;
      }

      final ver = response[0];
      final status = response[1];

      if (ver != 0x01) {
        Logger.error('用户名/密码认证版本不匹配: $ver');
        return false;
      }

      return status == 0x00; // 0表示成功
    } catch (e) {
      Logger.error('用户名/密码认证失败: $e');
      return false;
    }
  }

  // 停止SOCKS5代理
  Future<void> stop() async {
    try {
      await _socket?.close();
      _socket = null;
      _isConnected = false;
      Logger.info('SOCKS5代理已停止');
    } catch (e) {
      Logger.error('停止SOCKS5代理失败: $e');
      rethrow;
    }
  }

  // 检查SOCKS5代理状态
  Future<bool> checkStatus() async {
    if (!_isConnected) return false;

    try {
      // 简单的状态检查：尝试发送一个最小的握手请求
      List<int> request = [];
      request.add(0x05); // VER
      request.add(0x01); // NMETHODS
      request.add(0x00); // METHODS (无认证)

      _socket!.add(request);
      await _socket!.flush();

      // 读取响应
      final response = await _socket!.first;
      if (response.length < 2) {
        _isConnected = false;
        return false;
      }

      final ver = response[0];
      if (ver != 0x05) {
        _isConnected = false;
        return false;
      }

      return true;
    } catch (e) {
      Logger.error('检查SOCKS5代理状态失败: $e');
      _isConnected = false;
      return false;
    }
  }
}
