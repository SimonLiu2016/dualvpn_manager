import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:dualvpn_manager/utils/openvpn_config_parser.dart';

class OpenVPNService {
  bool _isConnected = false;
  String? _configPath;
  String? _username;
  String? _password;

  bool get isConnected => _isConnected;

  // 连接到OpenVPN（通过Go代理核心，不使用外部命令）
  Future<bool> connect(
    String configPath, {
    String? username,
    String? password,
  }) async {
    try {
      Logger.info('通过Go代理核心连接OpenVPN...');

      // 保存配置信息，用于后续操作
      _configPath = configPath;
      _username = username;
      _password = password;

      // 检查配置文件是否存在
      final configFile = File(configPath);
      if (!await configFile.exists()) {
        Logger.error('OpenVPN配置文件不存在: $configPath');
        throw Exception('OpenVPN配置文件不存在: $configPath');
      }

      // 检查文件是否可读
      final stat = await configFile.stat();
      if ((stat.mode & 0x4000) == 0) {
        // 0x4000是文件所有者读权限位
        Logger.error('OpenVPN配置文件不可读: $configPath');
        throw Exception('OpenVPN配置文件不可读: $configPath');
      }

      // 解析OpenVPN配置文件获取服务器和端口信息
      final proxyInfo = await OpenVPNConfigParser.parseProxyInfo(
        configPath: configPath,
        proxyId: 'openvpn-proxy-${DateTime.now().millisecondsSinceEpoch}',
        proxyName: 'OpenVPN Proxy',
        username: username,
        password: password,
      );

      // 通过Go代理核心API设置OpenVPN代理
      // 构建请求体
      final Map<String, dynamic> requestBody = proxyInfo.toJson();

      // 发送请求到Go代理核心
      final response =
          await HttpClient().putUrl(
              Uri.parse(
                'http://127.0.0.1:6162/proxy-sources/openvpn-source/current-proxy',
              ),
            )
            ..headers.set('Content-Type', 'application/json')
            ..write(jsonEncode(requestBody));

      final httpResponse = await response.close();

      if (httpResponse.statusCode == 200) {
        _isConnected = true;
        Logger.info('OpenVPN连接成功');
        return true;
      } else {
        final responseBody = await utf8.decodeStream(httpResponse);
        Logger.error('OpenVPN连接失败: $responseBody');
        _isConnected = false;
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('OpenVPN连接失败: $e\nStack trace: $stackTrace');
      _isConnected = false;
      rethrow;
    }
  }

  // 断开OpenVPN连接
  Future<void> disconnect() async {
    try {
      // 通过Go代理核心API停止OpenVPN代理
      final response = await HttpClient().deleteUrl(
        Uri.parse(
          'http://127.0.0.1:6162/proxy-sources/openvpn-source/current-proxy',
        ),
      );

      await response.close();

      _isConnected = false;
      _configPath = null;
      _username = null;
      _password = null;

      Logger.info('OpenVPN已断开连接');
    } catch (e, stackTrace) {
      Logger.error('断开OpenVPN连接时出错: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 检查OpenVPN是否正在运行
  Future<bool> checkStatus() async {
    try {
      // 通过Go代理核心API检查OpenVPN状态
      final response = await HttpClient().getUrl(
        Uri.parse('http://127.0.0.1:6162/proxy-sources/openvpn-source'),
      );

      final httpResponse = await response.close();

      if (httpResponse.statusCode == 200) {
        final responseBody = await utf8.decodeStream(httpResponse);
        final data = jsonDecode(responseBody);

        // 检查代理源是否有当前代理
        if (data['currentProxy'] != null) {
          return true;
        }
      }

      return false;
    } catch (e, stackTrace) {
      Logger.error('检查OpenVPN状态时出错: $e\nStack trace: $stackTrace');
      return false;
    }
  }
}
