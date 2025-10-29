import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dualvpn_manager/utils/logger.dart';

class ShadowsocksService {
  Process? _process;
  bool _isConnected = false;
  String? _configPath; // 保存当前配置文件路径

  bool get isConnected => _isConnected;

  // 通过配置文件启动Shadowsocks
  Future<bool> startWithConfig(String configPath) async {
    try {
      // 检查配置文件是否存在
      final configFile = File(configPath);
      if (!await configFile.exists()) {
        Logger.error('Shadowsocks配置文件不存在: $configPath');
        throw Exception('Shadowsocks配置文件不存在: $configPath');
      }

      // 检查文件是否可读
      final stat = await configFile.stat();
      if ((stat.mode & 0x4000) == 0) {
        // 0x4000是文件所有者读权限位
        Logger.error('Shadowsocks配置文件不可读: $configPath');
        throw Exception('Shadowsocks配置文件不可读: $configPath');
      }

      // 检查Shadowsocks命令是否可用
      try {
        final result = await Process.run('which', ['ss-local']);
        if (result.exitCode != 0) {
          Logger.error('Shadowsocks命令未找到，请确保已安装shadowsocks-libev');
          throw Exception('Shadowsocks命令未找到，请确保已安装shadowsocks-libev');
        }
      } catch (e) {
        Logger.error('检查Shadowsocks命令失败: $e');
        throw Exception('检查Shadowsocks命令失败: $e');
      }

      // 保存配置文件路径
      _configPath = configPath;

      // 构建Shadowsocks命令 (假设使用shadowsocks-libev的ss-local)
      List<String> args = [
        '-c', configPath, // 指定配置文件
      ];

      // 启动Shadowsocks进程
      Logger.info('正在启动Shadowsocks进程...');
      _process = await Process.start('ss-local', args);

      // 监听进程输出
      _process!.stdout.listen(
        (data) {
          final output = utf8.decode(data);
          Logger.debug('Shadowsocks stdout: $output');
          if (output.contains('listening at') ||
              output.contains('starting local')) {
            _isConnected = true;
            Logger.info('Shadowsocks服务已启动');
          }
        },
        onError: (Object error) {
          Logger.error('Shadowsocks stdout监听错误: $error');
        },
      );

      _process!.stderr.listen(
        (data) {
          final output = utf8.decode(data);
          Logger.error('Shadowsocks stderr: $output');
        },
        onError: (Object error) {
          Logger.error('Shadowsocks stderr监听错误: $error');
        },
      );

      // 等待一段时间以确定启动是否成功
      await Future.delayed(const Duration(seconds: 3));

      Logger.info('Shadowsocks启动${_isConnected ? '成功' : '可能失败'}');
      return _isConnected;
    } catch (e, stackTrace) {
      Logger.error('Shadowsocks启动失败: $e\nStack trace: $stackTrace');
      _isConnected = false;
      rethrow;
    }
  }

  // 通过订阅链接更新配置并启动
  Future<bool> startWithSubscription(String subscriptionUrl) async {
    try {
      // 下载配置文件
      final response = await http.get(Uri.parse(subscriptionUrl));
      if (response.statusCode != 200) {
        Logger.error('下载Shadowsocks订阅配置失败: ${response.statusCode}');
        throw Exception('下载Shadowsocks订阅配置失败: ${response.statusCode}');
      }

      // 解析订阅内容 (Shadowsocks订阅通常是base64编码的URL列表)
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
      final tempDir = await Directory.systemTemp.createTemp(
        'shadowsocks_config',
      );
      final configFile = File(path.join(tempDir.path, 'config.json'));
      await configFile.writeAsString(configContent);

      // 保存配置文件路径
      _configPath = configFile.path;

      // 启动Shadowsocks
      return await startWithConfig(configFile.path);
    } catch (e, stackTrace) {
      Logger.error('通过订阅启动Shadowsocks失败: $e\nStack trace: $stackTrace');
      _isConnected = false;
      rethrow;
    }
  }

  // 更新订阅配置
  Future<bool> updateSubscription(String subscriptionUrl) async {
    Logger.info('开始更新Shadowsocks订阅: $subscriptionUrl');

    // 添加重试机制
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    while (retryCount <= maxRetries) {
      try {
        Logger.info('尝试更新Shadowsocks订阅 (第${retryCount + 1}次)');

        // 下载新的配置文件
        final response = await http
            .get(Uri.parse(subscriptionUrl))
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                Logger.error('下载Shadowsocks订阅配置超时');
                throw Exception('下载Shadowsocks订阅配置超时，请稍后重试');
              },
            );

        // 检查HTTP响应状态码
        // 2xx表示成功，3xx表示重定向，4xx和5xx表示错误
        if (response.statusCode >= 300) {
          Logger.error('下载Shadowsocks订阅配置失败: ${response.statusCode}');
          if (response.statusCode == 404) {
            throw Exception('订阅链接不存在，请检查链接是否正确');
          } else if (response.statusCode == 403) {
            throw Exception('访问被拒绝，请检查订阅链接权限');
          } else {
            throw Exception('下载Shadowsocks订阅配置失败: HTTP ${response.statusCode}');
          }
        }

        // 检查响应内容是否为空
        if (response.body.isEmpty) {
          Logger.error('下载Shadowsocks订阅配置失败: 响应内容为空');
          throw Exception('下载Shadowsocks订阅配置失败: 响应内容为空');
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
          Logger.error('Shadowsocks订阅内容为空');
          throw Exception('Shadowsocks订阅内容为空');
        }

        // 检查配置内容是否看起来像有效的JSON或Shadowsocks配置
        bool isValidConfig = false;
        try {
          // 尝试解析为JSON来验证是否是有效的配置
          final jsonConfig = json.decode(configContent);
          // 检查是否包含Shadowsocks配置的关键字段
          if (jsonConfig is Map &&
              (jsonConfig.containsKey('server') ||
                  jsonConfig.containsKey('configs') ||
                  jsonConfig.containsKey('proxies'))) {
            isValidConfig = true;
          }
        } catch (e) {
          // 如果不是JSON，检查是否包含Shadowsocks URL格式
          if (configContent.contains('ss://') ||
              configContent.contains('ssr://') ||
              configContent.contains('vmess://')) {
            isValidConfig = true;
          }
        }

        // 如果配置无效，抛出异常
        if (!isValidConfig) {
          Logger.error('Shadowsocks订阅配置内容无效');
          throw Exception('Shadowsocks订阅配置内容无效');
        }

        // 检查是否有现有的配置文件路径
        if (_configPath == null) {
          Logger.info('没有找到现有的配置文件路径，创建临时配置文件');
          // 创建临时目录和配置文件
          final tempDir = await Directory.systemTemp.createTemp(
            'shadowsocks_config',
          );
          final configFile = File(path.join(tempDir.path, 'config.json'));
          await configFile.writeAsString(configContent);

          // 保存配置文件路径
          _configPath = configFile.path;

          // 如果Shadowsocks正在运行，重新启动它
          if (_isConnected && _process != null) {
            await stop();
            final result = await startWithConfig(_configPath!);
            if (!result) {
              Logger.error('Shadowsocks启动失败');
              throw Exception('Shadowsocks启动失败');
            }
            return result;
          }

          Logger.info('Shadowsocks订阅更新成功（保存到临时文件）');
          return true;
        }

        // 保存新的配置到现有文件
        final configFile = File(_configPath!);
        await configFile.writeAsString(configContent);

        // 重新启动Shadowsocks以应用新配置
        if (_isConnected && _process != null) {
          await stop();
          final result = await startWithConfig(_configPath!);
          if (!result) {
            Logger.error('Shadowsocks启动失败');
            throw Exception('Shadowsocks启动失败');
          }
          return result;
        }

        Logger.info('Shadowsocks订阅更新成功');
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
      } catch (e, stackTrace) {
        Logger.error('更新Shadowsocks订阅失败: $e\nStack trace: $stackTrace');
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
        rethrow;
      }
    }

    // 如果所有重试都失败了
    throw Exception('更新Shadowsocks订阅失败，已重试$maxRetries次');
  }

  // 停止Shadowsocks
  Future<void> stop() async {
    try {
      if (_process != null) {
        // 尝试优雅地停止Shadowsocks
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
      Logger.info('Shadowsocks已停止');
    } catch (e, stackTrace) {
      Logger.error('停止Shadowsocks时出错: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 检查Shadowsocks是否正在运行
  Future<bool> checkStatus() async {
    try {
      // 在macOS/Linux上检查Shadowsocks进程
      final result = await Process.run('pgrep', ['ss-local']);
      return result.exitCode == 0;
    } catch (e, stackTrace) {
      Logger.error('检查Shadowsocks状态时出错: $e\nStack trace: $stackTrace');
      return false;
    }
  }

  // 获取Shadowsocks代理列表
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

            // 处理不同的Shadowsocks配置格式
            if (jsonConfig is Map<String, dynamic>) {
              // 单个配置格式
              if (jsonConfig.containsKey('server') &&
                  jsonConfig.containsKey('server_port')) {
                final name =
                    jsonConfig['remarks'] ??
                    '${jsonConfig['server']}:${jsonConfig['server_port']}';
                proxies.add({
                  'name': name,
                  'type': 'shadowsocks',
                  'latency': -2, // -2表示未测试
                  'isSelected': false,
                });
              }
              // 多配置格式
              else if (jsonConfig.containsKey('configs') &&
                  jsonConfig['configs'] is List) {
                final configsList = jsonConfig['configs'] as List;
                for (var i = 0; i < configsList.length; i++) {
                  final config = configsList[i];
                  if (config is Map<String, dynamic>) {
                    final name =
                        config['remarks'] ??
                        config['server'] ??
                        'Shadowsocks Server ${i + 1}';
                    proxies.add({
                      'name': name,
                      'type': 'shadowsocks',
                      'latency': -2, // -2表示未测试
                      'isSelected': false,
                    });
                  }
                }
              }
              // Clash格式
              else if (jsonConfig.containsKey('proxies') &&
                  jsonConfig['proxies'] is List) {
                final proxiesList = jsonConfig['proxies'] as List;
                for (var i = 0; i < proxiesList.length; i++) {
                  final proxy = proxiesList[i];
                  if (proxy is Map<String, dynamic> &&
                      (proxy['type'] == 'ss' ||
                          proxy['type'] == 'shadowsocks')) {
                    final name = proxy['name'] ?? 'Shadowsocks Proxy ${i + 1}';
                    proxies.add({
                      'name': name,
                      'type': 'shadowsocks',
                      'latency': -2, // -2表示未测试
                      'isSelected': false,
                    });
                  }
                }
              }
            }
          } catch (e) {
            // 如果JSON解析失败，返回空列表
            Logger.warn('解析Shadowsocks配置文件时出错: $e');
          }

          return proxies;
        }
      }

      // 返回空列表，没有配置文件或解析失败
      return [];
    } catch (e, stackTrace) {
      Logger.error('获取Shadowsocks代理列表时出错: $e\nStack trace: $stackTrace');
      return [];
    }
  }

  // 从订阅链接解析代理列表
  Future<List<Map<String, dynamic>>> getProxiesFromSubscription(
    String subscriptionUrl,
  ) async {
    try {
      Logger.info('开始从订阅链接解析Shadowsocks代理列表: $subscriptionUrl');

      // 下载订阅内容
      final response = await http.get(Uri.parse(subscriptionUrl));

      // 检查HTTP响应状态码
      if (response.statusCode >= 300) {
        Logger.error('下载Shadowsocks订阅失败: ${response.statusCode}');
        throw Exception('下载Shadowsocks订阅失败: ${response.statusCode}');
      }

      // 检查响应内容是否为空
      if (response.body.isEmpty) {
        Logger.error('下载Shadowsocks订阅失败: 响应内容为空');
        throw Exception('下载Shadowsocks订阅失败: 响应内容为空');
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
        Logger.error('Shadowsocks订阅内容为空');
        throw Exception('Shadowsocks订阅内容为空');
      }

      final List<Map<String, dynamic>> proxies = [];

      try {
        // 尝试解析JSON格式的配置
        final jsonConfig = json.decode(configContent);

        // 处理不同的Shadowsocks配置格式
        if (jsonConfig is Map<String, dynamic>) {
          // 单个配置格式
          if (jsonConfig.containsKey('server') &&
              jsonConfig.containsKey('server_port')) {
            final name =
                jsonConfig['remarks'] ??
                '${jsonConfig['server']}:${jsonConfig['server_port']}';
            proxies.add({
              'name': name,
              'type': 'shadowsocks',
              'server': jsonConfig['server'],
              'port': jsonConfig['server_port'],
              'password': jsonConfig['password'],
              'method': jsonConfig['method'],
              'latency': -2, // -2表示未测试
              'isSelected': false,
            });
          }
          // 多配置格式
          else if (jsonConfig.containsKey('configs') &&
              jsonConfig['configs'] is List) {
            final configsList = jsonConfig['configs'] as List;
            for (var i = 0; i < configsList.length; i++) {
              final config = configsList[i];
              if (config is Map<String, dynamic>) {
                final name =
                    config['remarks'] ??
                    config['server'] ??
                    'Shadowsocks Server ${i + 1}';
                proxies.add({
                  'name': name,
                  'type': 'shadowsocks',
                  'server': config['server'],
                  'port': config['server_port'],
                  'password': config['password'],
                  'method': config['method'],
                  'latency': -2, // -2表示未测试
                  'isSelected': false,
                });
              }
            }
          }
          // Clash格式
          else if (jsonConfig.containsKey('proxies') &&
              jsonConfig['proxies'] is List) {
            final proxiesList = jsonConfig['proxies'] as List;
            for (var i = 0; i < proxiesList.length; i++) {
              final proxy = proxiesList[i];
              if (proxy is Map<String, dynamic> &&
                  (proxy['type'] == 'ss' || proxy['type'] == 'shadowsocks')) {
                final name = proxy['name'] ?? 'Shadowsocks Proxy ${i + 1}';
                proxies.add({
                  'name': name,
                  'type': 'shadowsocks',
                  'server': proxy['server'],
                  'port': proxy['port'],
                  'password': proxy['password'],
                  'method': proxy['cipher'],
                  'latency': -2, // -2表示未测试
                  'isSelected': false,
                });
              }
            }
          }
        }
      } catch (e) {
        // 如果JSON解析失败，尝试按行解析（可能是一行一个ss://链接的格式）
        final lines = configContent.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty &&
              (line.startsWith('ss://') || line.startsWith('ssr://'))) {
            // 简单解析URL格式的Shadowsocks配置
            try {
              final uri = Uri.parse(line);
              final name =
                  (uri.fragment.isNotEmpty
                      ? Uri.decodeComponent(uri.fragment)
                      : null) ??
                  uri.queryParameters['remarks'] ??
                  (uri.host.isNotEmpty
                      ? '${uri.host}:${uri.port}'
                      : 'Shadowsocks Server ${i + 1}');
              
              // 解析用户信息
              String method = 'aes-256-gcm';
              String password = '';
              if (uri.userInfo.isNotEmpty) {
                try {
                  // 尝试Base64解码用户信息
                  String paddedUserInfo = uri.userInfo;
                  final padding = 4 - (uri.userInfo.length % 4);
                  if (padding != 4) {
                    paddedUserInfo += '=' * padding;
                  }
                  final decoded = utf8.decode(base64Decode(paddedUserInfo));
                  final parts = decoded.split(':');
                  if (parts.length >= 2) {
                    method = parts[0];
                    password = parts[1];
                  }
                } catch (decodeError) {
                  // 如果解码失败，直接使用用户信息
                  final parts = uri.userInfo.split(':');
                  if (parts.length >= 2) {
                    method = parts[0];
                    password = parts[1];
                  }
                }
              }
              
              proxies.add({
                'name': name,
                'type': 'shadowsocks',
                'server': uri.host,
                'port': uri.port,
                'password': password,
                'method': method,
                'latency': -2, // -2表示未测试
                'isSelected': false,
              });
            } catch (uriError) {
              // URL解析失败，使用默认名称
              proxies.add({
                'name': 'Shadowsocks Server ${i + 1}',
                'type': 'shadowsocks',
                'latency': -2, // -2表示未测试
                'isSelected': false,
              });
            }
          }
        }
      }

      Logger.info('成功解析到 ${proxies.length} 个Shadowsocks代理');
      return proxies;
    } catch (e, stackTrace) {
      Logger.error('从订阅链接解析Shadowsocks代理列表失败: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }
  
  // 获取指定代理的详细配置信息
  Future<Map<String, dynamic>?> getProxyDetails(String proxyName) async {
    try {
      Logger.info('获取Shadowsocks代理详细配置信息: $proxyName');
      
      // 获取代理列表
      final proxies = await getProxies();
      
      // 查找指定代理
      for (var proxy in proxies) {
        if (proxy['name'] == proxyName) {
          // 构建协议配置
          final protocolConfig = {
            'name': proxyName,
            'type': 'socks5', // Shadowsocks通过SOCKS5协议连接
            'server': proxy['server'] ?? '127.0.0.1',
            'port': proxy['port'] ?? 1080,
            'password': proxy['password'],
            'method': proxy['method'] ?? 'aes-256-gcm',
          };
          
          Logger.info('构建的协议配置: $protocolConfig');
          return protocolConfig;
        }
      }
      
      Logger.warn('未找到代理的详细配置信息: $proxyName');
      return null;
    } catch (e) {
      Logger.error('获取Shadowsocks代理详细配置信息时出错: $e');
      return null;
    }
  }
}
