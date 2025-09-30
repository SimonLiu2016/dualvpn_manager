import 'dart:io';
import 'dart:async';
import 'package:dualvpn_manager/utils/logger.dart';

/// OpenVPN配置文件解析器
class OpenVPNConfigParser {
  /// 从OpenVPN配置文件中解析remote服务器地址和端口
  static Future<OpenVPNRemoteInfo> parseRemoteInfo(String configPath) async {
    try {
      final file = File(configPath);
      if (!await file.exists()) {
        throw Exception('OpenVPN配置文件不存在: $configPath');
      }

      final lines = await file.readAsLines();
      String? server;
      int? port;
      String protocol = 'udp'; // 默认协议

      for (final line in lines) {
        final trimmedLine = line.trim();

        // 忽略注释行和空行
        if (trimmedLine.isEmpty ||
            trimmedLine.startsWith('#') ||
            trimmedLine.startsWith(';')) {
          continue;
        }

        // 解析remote指令
        if (trimmedLine.startsWith('remote ')) {
          final parts = trimmedLine.split(RegExp(r'\s+'));
          if (parts.length >= 3) {
            server = parts[1];
            port = int.tryParse(parts[2]);
          } else if (parts.length == 2) {
            server = parts[1];
            // 如果没有指定端口，使用默认端口1194
            port = 1194;
          }
        }

        // 解析proto指令
        if (trimmedLine.startsWith('proto ')) {
          final parts = trimmedLine.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            protocol = parts[1].toLowerCase();
          }
        }
      }

      if (server == null) {
        throw Exception('在配置文件中未找到remote指令');
      }

      return OpenVPNRemoteInfo(
        server: server,
        port: port ?? 1194, // 默认端口
        protocol: protocol,
      );
    } catch (e) {
      Logger.error('解析OpenVPN配置文件失败: $e');
      rethrow;
    }
  }

  /// 从OpenVPN配置文件中提取所有必要信息以构建代理信息
  static Future<OpenVPNProxyInfo> parseProxyInfo({
    required String configPath,
    required String proxyId,
    required String proxyName,
    String? username,
    String? password,
  }) async {
    try {
      final remoteInfo = await parseRemoteInfo(configPath);

      return OpenVPNProxyInfo(
        id: proxyId,
        name: proxyName,
        type: 'openvpn',
        server: remoteInfo.server,
        port: remoteInfo.port,
        config: {
          'config_path': configPath,
          if (username != null) 'username': username,
          if (password != null) 'password': password,
        },
      );
    } catch (e) {
      Logger.error('构建OpenVPN代理信息失败: $e');
      rethrow;
    }
  }
}

/// OpenVPN远程服务器信息
class OpenVPNRemoteInfo {
  final String server;
  final int port;
  final String protocol;

  OpenVPNRemoteInfo({
    required this.server,
    required this.port,
    required this.protocol,
  });

  @override
  String toString() {
    return 'OpenVPNRemoteInfo(server: $server, port: $port, protocol: $protocol)';
  }
}

/// OpenVPN代理信息
class OpenVPNProxyInfo {
  final String id;
  final String name;
  final String type;
  final String server;
  final int port;
  final Map<String, dynamic> config;

  OpenVPNProxyInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.server,
    required this.port,
    required this.config,
  });

  /// 转换为可发送到Go代理核心的JSON格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'server': server,
      'port': port,
      'config': config,
    };
  }

  @override
  String toString() {
    return 'OpenVPNProxyInfo(id: $id, name: $name, type: $type, server: $server, port: $port, config: $config)';
  }
}
