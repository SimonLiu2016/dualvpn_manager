import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dualvpn_manager/utils/logger.dart';

class V2RayService {
  Process? _process;
  bool _isConnected = false;
  String? _configPath; // 保存当前配置文件路径

  bool get isConnected => _isConnected;

  // 通过配置文件启动V2Ray
  Future<bool> startWithConfig(String configPath) async {
    try {
      // 检查配置文件是否存在
      final configFile = File(configPath);
      if (!await configFile.exists()) {
        Logger.error('V2Ray配置文件不存在: $configPath');
        throw Exception('V2Ray配置文件不存在: $configPath');
      }

      // 检查文件是否可读
      final stat = await configFile.stat();
      if ((stat.mode & 0x4000) == 0) {
        // 0x4000是文件所有者读权限位
        Logger.error('V2Ray配置文件不可读: $configPath');
        throw Exception('V2Ray配置文件不可读: $configPath');
      }

      // 检查V2Ray命令是否可用
      try {
        final result = await Process.run('which', ['v2ray']);
        if (result.exitCode != 0) {
          Logger.error('V2Ray命令未找到，请确保已安装V2Ray');
          throw Exception('V2Ray命令未找到，请确保已安装V2Ray');
        }
      } catch (e) {
        Logger.error('检查V2Ray命令失败: $e');
        throw Exception('检查V2Ray命令失败: $e');
      }

      // 保存配置文件路径
      _configPath = configPath;

      // 构建V2Ray命令
      List<String> args = [
        'run', '-c', configPath, // 指定配置文件
      ];

      // 启动V2Ray进程
      Logger.info('正在启动V2Ray进程...');
      _process = await Process.start('v2ray', args);

      // 监听进程输出
      _process!.stdout.listen(
        (data) {
          final output = utf8.decode(data);
          Logger.debug('V2Ray stdout: $output');
          if (output.contains('started') || output.contains('V2Ray')) {
            _isConnected = true;
            Logger.info('V2Ray服务已启动');
          }
        },
        onError: (Object error) {
          Logger.error('V2Ray stdout监听错误: $error');
        },
      );

      _process!.stderr.listen(
        (data) {
          final output = utf8.decode(data);
          Logger.error('V2Ray stderr: $output');
        },
        onError: (Object error) {
          Logger.error('V2Ray stderr监听错误: $error');
        },
      );

      // 等待一段时间以确定启动是否成功
      await Future.delayed(const Duration(seconds: 3));

      Logger.info('V2Ray启动${_isConnected ? '成功' : '可能失败'}');
      return _isConnected;
    } catch (e, stackTrace) {
      Logger.error('V2Ray启动失败: $e\nStack trace: $stackTrace');
      _isConnected = false;
      rethrow;
    }
  }

  // 通过订阅链接更新配置并启动
  Future<bool> startWithSubscription(String subscriptionUrl) async {
    try {
      // 下载配置文件
      final response = await http.get(
        Uri.parse(subscriptionUrl),
        headers: {
          'User-Agent':
              'ClashX/1.116.0 (com.west2online.ClashX; build:1.116.0; macOS 15.7.1) Alamofire/5.7.1',
        },
      );
      if (response.statusCode != 200) {
        Logger.error('下载V2Ray订阅配置失败: ${response.statusCode}');
        throw Exception('下载V2Ray订阅配置失败: ${response.statusCode}');
      }

      // 解析订阅内容 (V2Ray订阅通常是base64编码的URL列表)
      String configContent;
      try {
        // 尝试解码base64
        List<int> decodedBytes = base64Decode(response.body);
        configContent = utf8.decode(decodedBytes);
      } catch (e) {
        // 如果解码失败，直接使用原始内容
        configContent = response.body;
      }

      // 保存配置文件到临时目录
      final tempDir = await Directory.systemTemp.createTemp('v2ray_config');
      final configFile = File(path.join(tempDir.path, 'config.json'));
      await configFile.writeAsString(configContent);

      // 保存配置文件路径
      _configPath = configFile.path;

      // 启动V2Ray
      return await startWithConfig(configFile.path);
    } catch (e, stackTrace) {
      Logger.error('通过订阅启动V2Ray失败: $e\nStack trace: $stackTrace');
      _isConnected = false;
      rethrow;
    }
  }

  // 更新订阅
  Future<bool> updateSubscription(String subscriptionUrl) async {
    Logger.info('更新V2Ray订阅: $subscriptionUrl');

    // 添加重试机制
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    while (retryCount <= maxRetries) {
      try {
        Logger.info('尝试更新V2Ray订阅 (第${retryCount + 1}次)');

        // 下载新的配置文件
        final response = await http
            .get(
              Uri.parse(subscriptionUrl),
              headers: {
                'User-Agent':
                    'ClashX/1.116.0 (com.west2online.ClashX; build:1.116.0; macOS 15.7.1) Alamofire/5.7.1',
              },
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                Logger.error('下载V2Ray订阅配置超时');
                throw Exception('下载V2Ray订阅配置超时，请稍后重试');
              },
            );

        // 检查HTTP响应状态码
        // 2xx表示成功，3xx表示重定向，4xx和5xx表示错误
        if (response.statusCode >= 300) {
          Logger.error('下载V2Ray订阅配置失败: ${response.statusCode}');
          if (response.statusCode == 404) {
            throw Exception('订阅链接不存在，请检查链接是否正确');
          } else if (response.statusCode == 403) {
            throw Exception('访问被拒绝，请检查订阅链接权限');
          } else {
            throw Exception('下载V2Ray订阅配置失败: HTTP ${response.statusCode}');
          }
        }

        // 检查响应内容是否为空
        if (response.body.isEmpty) {
          Logger.error('下载V2Ray订阅配置失败: 响应内容为空');
          throw Exception('下载V2Ray订阅配置失败: 响应内容为空');
        }

        // 解析订阅内容
        String configContent;
        try {
          // 尝试解码base64
          List<int> decodedBytes = base64Decode(response.body);
          configContent = utf8.decode(decodedBytes);
        } catch (e) {
          // 如果解码失败，直接使用原始内容
          configContent = response.body;
        }

        // 验证配置内容是否有效
        if (configContent.trim().isEmpty) {
          Logger.error('V2Ray订阅内容为空');
          throw Exception('V2Ray订阅内容为空');
        }

        // 保存配置到现有配置文件或创建新文件
        if (_configPath != null) {
          // 保存到现有配置文件
          final configFile = File(_configPath!);
          await configFile.writeAsString(configContent);
          Logger.info('V2Ray配置已更新到: ${_configPath!}');
        } else {
          // 创建临时配置文件
          final tempDir = await Directory.systemTemp.createTemp('v2ray_config');
          final configFile = File(path.join(tempDir.path, 'config.json'));
          await configFile.writeAsString(configContent);
          _configPath = configFile.path;
          Logger.info('V2Ray配置已保存到临时文件: ${_configPath!}');
        }

        // 如果V2Ray正在运行，重新启动它以应用新配置
        if (_isConnected && _process != null) {
          Logger.info('V2Ray正在运行，重新启动以应用新配置');
          await stop();
          final result = await startWithConfig(_configPath!);
          if (!result) {
            Logger.error('V2Ray重新启动失败');
            throw Exception('V2Ray重新启动失败');
          }
          return result;
        }

        Logger.info('V2Ray订阅更新成功');
        return true;
      } on SocketException catch (e) {
        Logger.error('网络连接错误: $e');
        retryCount++;

        if (retryCount <= maxRetries) {
          Logger.info('等待${retryDelay.inSeconds}秒后重试...');
          await Future.delayed(retryDelay);
        } else {
          throw Exception('网络连接错误，请检查网络连接');
        }
      } on TlsException catch (e) {
        Logger.error('TLS/SSL错误: $e');
        retryCount++;

        if (retryCount <= maxRetries) {
          Logger.info('等待${retryDelay.inSeconds}秒后重试...');
          await Future.delayed(retryDelay);
        } else {
          throw Exception('TLS/SSL连接错误，请检查服务器证书');
        }
      } catch (e, stackTrace) {
        Logger.error('更新V2Ray订阅失败: $e\nStack trace: $stackTrace');
        // 修复：确保返回false而不是重新抛出异常，以避免UI层处理复杂化
        if (e.toString().contains('404')) {
          throw Exception('订阅链接不存在，请检查链接是否正确');
        } else if (e.toString().contains('timeout')) {
          retryCount++;

          if (retryCount <= maxRetries) {
            Logger.info('等待${retryDelay.inSeconds}秒后重试...');
            await Future.delayed(retryDelay);
            continue;
          } else {
            throw Exception('连接超时，请稍后重试');
          }
        }
        return false;
      }
    }

    // 如果所有重试都失败了
    throw Exception('更新V2Ray订阅失败，已重试$maxRetries次');
  }

  // 停止V2Ray
  Future<void> stop() async {
    try {
      if (_process != null) {
        // 尝试优雅地停止V2Ray
        _process!.kill(ProcessSignal.sigterm);

        // 等待进程结束
        await _process!.exitCode.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // 如果进程没有在10秒内结束，则强制杀死
            _process!.kill(ProcessSignal.sigkill);
            return 0;
          },
        );

        _process = null;
      }
      _isConnected = false;
      _configPath = null; // 清除配置文件路径
      Logger.info('V2Ray已停止');
    } catch (e, stackTrace) {
      Logger.error('停止V2Ray时出错: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 检查V2Ray是否正在运行
  Future<bool> checkStatus() async {
    try {
      // 在macOS/Linux上检查V2Ray进程
      final result = await Process.run('pgrep', ['v2ray']);
      return result.exitCode == 0;
    } catch (e, stackTrace) {
      Logger.error('检查V2Ray状态时出错: $e\nStack trace: $stackTrace');
      return false;
    }
  }

  // 获取V2Ray代理列表
  Future<List<Map<String, dynamic>>> getProxies() async {
    try {
      // 如果有配置文件路径，从配置文件中解析代理列表
      if (_configPath != null) {
        final configFile = File(_configPath!);
        if (await configFile.exists()) {
          final configContent = await configFile.readAsString();

          final List<Map<String, dynamic>> proxies = [];

          try {
            // 尝试解析JSON格式的配置
            final jsonConfig = json.decode(configContent);

            // 处理V2Ray配置格式
            if (jsonConfig is Map<String, dynamic>) {
              // 处理outbounds配置
              if (jsonConfig.containsKey('outbounds') &&
                  jsonConfig['outbounds'] is List) {
                final outboundsList = jsonConfig['outbounds'] as List;
                for (var i = 0; i < outboundsList.length; i++) {
                  final outbound = outboundsList[i];
                  if (outbound is Map<String, dynamic>) {
                    final name =
                        outbound['tag'] ??
                        outbound['name'] ??
                        'V2Ray Outbound ${i + 1}';
                    final protocol = outbound['protocol'] ?? 'unknown';
                    proxies.add({
                      'name': name,
                      'type': 'v2ray',
                      'protocol': protocol,
                      'latency': -2, // -2表示未测试
                      'isSelected': false,
                    });
                  }
                }
              }
            }
          } catch (e) {
            // 如果JSON解析失败，返回空列表
            Logger.warn('解析V2Ray配置文件时出错: $e');
          }

          return proxies;
        }
      }

      // 返回空列表，没有配置文件或解析失败
      return [];
    } catch (e, stackTrace) {
      Logger.error('获取V2Ray代理列表时出错: $e\nStack trace: $stackTrace');
      return [];
    }
  }

  // 从订阅链接解析代理列表
  Future<List<Map<String, dynamic>>> getProxiesFromSubscription(
    String subscriptionUrl,
  ) async {
    try {
      Logger.info('开始从订阅链接解析V2Ray代理列表: $subscriptionUrl');

      // 下载订阅内容
      final response = await http.get(
        Uri.parse(subscriptionUrl),
        headers: {
          'User-Agent':
              'ClashX/1.116.0 (com.west2online.ClashX; build:1.116.0; macOS 15.7.1) Alamofire/5.7.1',
        },
      );

      // 检查HTTP响应状态码
      if (response.statusCode >= 300) {
        Logger.error('下载V2Ray订阅失败: ${response.statusCode}');
        throw Exception('下载V2Ray订阅失败: ${response.statusCode}');
      }

      // 检查响应内容是否为空
      if (response.body.isEmpty) {
        Logger.error('下载V2Ray订阅失败: 响应内容为空');
        throw Exception('下载V2Ray订阅失败: 响应内容为空');
      }

      // 解析订阅内容
      String configContent;
      try {
        // 尝试解码base64
        List<int> decodedBytes = base64Decode(response.body);
        configContent = utf8.decode(decodedBytes);
      } catch (e) {
        // 如果解码失败，直接使用原始内容
        configContent = response.body;
      }

      // 验证配置内容是否有效
      if (configContent.trim().isEmpty) {
        Logger.error('V2Ray订阅内容为空');
        throw Exception('V2Ray订阅内容为空');
      }

      final List<Map<String, dynamic>> proxies = [];

      try {
        // 尝试解析JSON格式的配置
        final jsonConfig = json.decode(configContent);

        // 检查是否存在outbounds字段
        if (jsonConfig is Map<String, dynamic> &&
            jsonConfig.containsKey('outbounds')) {
          final outbounds = jsonConfig['outbounds'] as List?;
          if (outbounds != null) {
            for (int i = 0; i < outbounds.length; i++) {
              final outbound = outbounds[i];
              if (outbound is Map<String, dynamic>) {
                final name =
                    outbound['tag'] ??
                    outbound['name'] ??
                    'V2Ray Outbound ${i + 1}';
                final protocol = outbound['protocol'] ?? 'unknown';
                proxies.add({
                  'name': name,
                  'type': 'v2ray',
                  'protocol': protocol,
                  'latency': -2, // -2表示未测试
                  'isSelected': false,
                });
              }
            }
          }
        }
      } catch (e) {
        // 如果JSON解析失败，返回空列表
        Logger.warn('解析V2Ray配置文件时出错: $e');
      }

      return proxies;
    } catch (e, stackTrace) {
      Logger.error('获取V2Ray代理列表时出错: $e\nStack trace: $stackTrace');
      return [];
    }
  }

  // 获取指定代理的详细配置信息
  Future<Map<String, dynamic>?> getProxyDetails(String proxyName) async {
    try {
      Logger.info('获取V2Ray代理详细配置信息: $proxyName');

      // 获取代理列表
      final proxies = await getProxies();

      // 查找指定代理
      for (var proxy in proxies) {
        if (proxy['name'] == proxyName) {
          // 构建协议配置
          final protocolConfig = {
            'name': proxyName,
            'type': 'socks5', // V2Ray通过SOCKS5协议连接
            'server': proxy['server'] ?? '127.0.0.1',
            'port': proxy['port'] ?? 1080,
          };

          // 添加V2Ray特有的配置
          if (proxy.containsKey('uuid')) {
            protocolConfig['user_id'] = proxy['uuid'];
          }
          if (proxy.containsKey('alterId')) {
            protocolConfig['alter_id'] = proxy['alterId'];
          }
          if (proxy.containsKey('security')) {
            protocolConfig['security'] = proxy['security'];
          }
          if (proxy.containsKey('network')) {
            protocolConfig['network'] = proxy['network'];
          }
          if (proxy.containsKey('tls')) {
            protocolConfig['tls'] = proxy['tls'];
          }

          Logger.info('构建的协议配置: $protocolConfig');
          return protocolConfig;
        }
      }

      Logger.warn('未找到代理的详细配置信息: $proxyName');
      return null;
    } catch (e) {
      Logger.error('获取V2Ray代理详细配置信息时出错: $e');
      return null;
    }
  }
}
