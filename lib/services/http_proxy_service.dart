import 'dart:io';
import 'dart:convert';
import 'package:dualvpn_manager/utils/logger.dart';

class HTTPProxyService {
  bool _isConnected = false;
  String _server = '';
  int _port = 0;
  String? _username;
  String? _password;
  HttpClient? _httpClient;

  bool get isConnected => _isConnected;

  // 启动HTTP代理
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

      // 创建HTTP客户端用于测试连接
      _httpClient = HttpClient();

      // 测试连接
      final result = await _testConnection();
      if (result) {
        _isConnected = true;
        Logger.info('HTTP代理连接成功: $server:$port');
        return true;
      } else {
        Logger.error('HTTP代理连接失败: $server:$port');
        return false;
      }
    } catch (e) {
      Logger.error('启动HTTP代理失败: $e');
      return false;
    }
  }

  // 测试HTTP代理连接
  Future<bool> _testConnection() async {
    try {
      final request = await _httpClient!.getUrl(
        Uri.parse('http://www.google.com'),
      );

      // 如果提供了用户名和密码，添加基本认证
      if (_username != null && _password != null) {
        final credentials = '$_username:$_password';
        final encodedCredentials = base64Encode(utf8.encode(credentials));
        request.headers.set('Proxy-Authorization', 'Basic $encodedCredentials');
      }

      final response = await request.close();
      await response.drain(); // 读取响应内容

      return response.statusCode == 200;
    } catch (e) {
      Logger.error('测试HTTP代理连接失败: $e');
      return false;
    }
  }

  // 停止HTTP代理
  Future<void> stop() async {
    try {
      _httpClient?.close();
      _httpClient = null;
      _isConnected = false;
      Logger.info('HTTP代理已停止');
    } catch (e) {
      Logger.error('停止HTTP代理失败: $e');
      rethrow;
    }
  }

  // 检查HTTP代理状态
  Future<bool> checkStatus() async {
    if (!_isConnected) return false;

    try {
      final result = await _testConnection();
      if (!result) {
        _isConnected = false;
      }
      return result;
    } catch (e) {
      Logger.error('检查HTTP代理状态失败: $e');
      _isConnected = false;
      return false;
    }
  }
}
