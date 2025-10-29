import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:dualvpn_manager/utils/openvpn_config_parser.dart';
import 'package:dualvpn_manager/services/privileged_helper_service.dart';
import 'package:dualvpn_manager/services/go_proxy_service.dart';

class OpenVPNService {
  bool _isConnected = false;
  String? _configPath;
  String? _username;
  String? _password;
  String? _sourceId;

  bool get isConnected => _isConnected;

  // 连接到OpenVPN（通过Go代理核心，不使用外部命令）
  Future<bool> connect(
    String configPath, {
    String? sourceId, // 添加sourceId参数
    String? username,
    String? password,
  }) async {
    try {
      Logger.info(
        '通过Go代理核心连接OpenVPN..., 配置文件: $configPath, 用户名: $username, 密码: $password',
      );

      // 保存配置信息，用于后续操作
      _configPath = configPath;
      _username = username;
      _password = password;
      _sourceId = sourceId;

      // 检查配置文件是否存在
      final configFile = File(configPath);
      if (!await configFile.exists()) {
        Logger.error('OpenVPN配置文件不存在: $configPath');
        throw Exception('OpenVPN配置文件不存在: $configPath');
      }

      // 检查文件是否可读
      final stat = await configFile.stat();
      Logger.info('文件权限: ${stat.mode}');
      if ((stat.mode & 256) == 0) {
        // 0x4000是文件所有者读权限位
        Logger.error('OpenVPN配置文件不可读: $configPath');
        throw Exception('OpenVPN配置文件不可读: $configPath');
      }

      // 读取配置文件内容
      final configContent = await configFile.readAsString();

      // 解析配置文件以提取证书文件
      final certFiles = await _extractCertFiles(configPath);

      // 调用特权助手处理配置文件
      final helper = HelperService();
      final processedConfigPath = await helper.copyOpenVPNConfigFiles(
        configContent: configContent,
        certFiles: certFiles,
      );

      if (processedConfigPath == null) {
        Logger.error('特权助手处理OpenVPN配置文件失败');
        throw Exception('特权助手处理OpenVPN配置文件失败');
      }

      Logger.info('特权助手处理后的配置文件路径: $processedConfigPath');

      // 解析OpenVPN配置文件获取服务器和端口信息
      final proxyInfo = await OpenVPNConfigParser.parseProxyInfo(
        configPath: configPath,
        proxyId: 'openvpn-proxy-${DateTime.now().millisecondsSinceEpoch}',
        proxyName: 'OpenVPN Proxy',
        username: username,
        password: password,
      );

      // 更新配置路径为特权助手处理后的路径
      proxyInfo.config['processed_config_path'] = processedConfigPath;

      // 通过GoProxyService设置OpenVPN代理
      final goProxyService = GoProxyService();
      // 使用传入的sourceId参数，如果未提供则使用默认值
      final actualSourceId = sourceId ?? 'openvpn-source';
      final result = await goProxyService.setCurrentProxy(
        actualSourceId,
        proxyInfo.toJson(),
      );

      if (result) {
        _isConnected = true;
        Logger.info('OpenVPN连接成功');
        return true;
      } else {
        Logger.error('OpenVPN连接失败');
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
  Future<void> disconnect({String? sourceId}) async {
    try {
      // 通过GoProxyService停止OpenVPN代理
      final goProxyService = GoProxyService();
      // 使用传入的sourceId参数，如果未提供则使用默认值
      final actualSourceId = sourceId ?? 'openvpn-source';

      // 构建一个空的代理信息来断开连接
      final proxyInfo = {
        'id': '',
        'name': '',
        'type': 'openvpn',
        'server': '',
        'port': 0,
        'config': {},
      };

      final result = await goProxyService.setCurrentProxy(
        actualSourceId,
        proxyInfo,
      );

      if (result) {
        Logger.info('OpenVPN断开连接请求发送成功');
      } else {
        Logger.error('OpenVPN断开连接请求发送失败');
      }

      _isConnected = false;
      _configPath = null;
      _username = null;
      _password = null;
      _sourceId = null;

      Logger.info('OpenVPN已断开连接');
    } catch (e, stackTrace) {
      Logger.error('断开OpenVPN连接时出错: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  /// 提取OpenVPN配置文件中引用的证书文件
  Future<Map<String, String>> _extractCertFiles(String configPath) async {
    final certFiles = <String, String>{};
    final configFile = File(configPath);
    final configDir = configFile.parent;

    try {
      final lines = await configFile.readAsLines();

      for (final line in lines) {
        final trimmedLine = line.trim();

        // 忽略注释行和空行
        if (trimmedLine.isEmpty ||
            trimmedLine.startsWith('#') ||
            trimmedLine.startsWith(';')) {
          continue;
        }

        // 解析需要的文件指令
        for (final directive in [
          'ca',
          'cert',
          'key',
          'dh',
          'tls-auth',
          'pkcs12',
        ]) {
          if (trimmedLine.startsWith('$directive ')) {
            final parts = trimmedLine.split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final filePath = parts[1];
              // 构建完整路径
              final fullPath = path.isAbsolute(filePath)
                  ? filePath
                  : path.join(configDir.path, filePath);

              // 读取文件内容
              final certFile = File(fullPath);
              if (await certFile.exists()) {
                final content = await certFile.readAsString();
                final fileName = path.basename(filePath);
                certFiles[fileName] = content;
                Logger.info('提取证书文件: $fileName');
              } else {
                Logger.warn('证书文件不存在: $fullPath');
              }
            }
            break;
          }
        }
      }
    } catch (e) {
      Logger.error('提取证书文件时出错: $e');
    }

    return certFiles;
  }
}
