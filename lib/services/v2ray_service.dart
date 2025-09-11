import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
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
      final response = await http.get(Uri.parse(subscriptionUrl));
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

  // 更新订阅配置
  Future<bool> updateSubscription(String subscriptionUrl) async {
    try {
      Logger.info('开始更新V2Ray订阅: $subscriptionUrl');

      // 下载新的配置文件
      final response = await http.get(Uri.parse(subscriptionUrl));

      // 检查HTTP响应状态码
      // 2xx表示成功，3xx表示重定向，4xx和5xx表示错误
      if (response.statusCode >= 300) {
        Logger.error('下载V2Ray订阅配置失败: ${response.statusCode}');
        throw Exception('下载V2Ray订阅配置失败: ${response.statusCode}');
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
        Logger.error('V2Ray订阅配置内容为空');
        throw Exception('V2Ray订阅配置内容为空');
      }

      // 检查配置内容是否看起来像有效的JSON或V2Ray配置
      bool isValidConfig = false;
      try {
        // 尝试解析为JSON来验证是否是有效的配置
        final jsonConfig = json.decode(configContent);
        // 检查是否包含V2Ray配置的关键字段
        if (jsonConfig is Map &&
            (jsonConfig.containsKey('inbounds') ||
                jsonConfig.containsKey('outbounds') ||
                jsonConfig.containsKey('routing'))) {
          isValidConfig = true;
        }
      } catch (e) {
        // 如果不是JSON，检查是否包含V2Ray URL格式
        if (configContent.contains('vmess://') ||
            configContent.contains('vless://') ||
            configContent.contains('trojan://')) {
          isValidConfig = true;
        }
      }

      // 如果配置无效，抛出异常
      if (!isValidConfig) {
        Logger.error('V2Ray订阅配置内容无效');
        throw Exception('V2Ray订阅配置内容无效');
      }

      // 检查是否有现有的配置文件路径
      if (_configPath == null) {
        Logger.info('没有找到现有的配置文件路径，创建临时配置文件');
        // 创建临时目录和配置文件
        final tempDir = await Directory.systemTemp.createTemp('v2ray_config');
        final configFile = File(path.join(tempDir.path, 'config.json'));
        await configFile.writeAsString(configContent);

        // 保存配置文件路径
        _configPath = configFile.path;

        // 如果V2Ray正在运行，重新启动它
        if (_isConnected && _process != null) {
          await stop();
          final result = await startWithConfig(_configPath!);
          if (!result) {
            Logger.error('V2Ray启动失败');
            throw Exception('V2Ray启动失败');
          }
          return result;
        }

        Logger.info('V2Ray订阅更新成功（保存到临时文件）');
        return true;
      }

      // 保存新的配置到现有文件
      final configFile = File(_configPath!);
      await configFile.writeAsString(configContent);

      // 重新启动V2Ray以应用新配置
      if (_isConnected && _process != null) {
        await stop();
        final result = await startWithConfig(_configPath!);
        if (!result) {
          Logger.error('V2Ray启动失败');
          throw Exception('V2Ray启动失败');
        }
        return result;
      }

      Logger.info('V2Ray订阅更新成功');
      return true;
    } catch (e, stackTrace) {
      Logger.error('更新V2Ray订阅失败: $e\nStack trace: $stackTrace');
      rethrow;
    }
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
      // 返回空列表，V2Ray本身不提供API来获取代理列表
      // 代理列表应该从配置文件中解析
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
      final response = await http.get(Uri.parse(subscriptionUrl));

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
        // 如果JSON解析失败，尝试按行解析（可能是一行一个vmess://链接的格式）
        final lines = configContent.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty &&
              (line.startsWith('vmess://') ||
                  line.startsWith('vless://') ||
                  line.startsWith('trojan://'))) {
            // 简单解析URL格式的V2Ray配置
            try {
              // V2Ray链接通常是base64编码的JSON
              final uri = Uri.parse(line);
              final name =
                  (uri.fragment.isNotEmpty
                      ? Uri.decodeComponent(uri.fragment)
                      : null) ??
                  uri.queryParameters['remarks'] ??
                  'V2Ray Server ${i + 1}';
              proxies.add({
                'name': name,
                'type': 'v2ray',
                'latency': -2, // -2表示未测试
                'isSelected': false,
              });
            } catch (uriError) {
              // URL解析失败，使用默认名称
              proxies.add({
                'name': 'V2Ray Server ${i + 1}',
                'type': 'v2ray',
                'latency': -2, // -2表示未测试
                'isSelected': false,
              });
            }
          }
        }
      }

      Logger.info('成功解析到 ${proxies.length} 个V2Ray代理');
      return proxies;
    } catch (e, stackTrace) {
      Logger.error('从订阅链接解析V2Ray代理列表失败: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }
}
