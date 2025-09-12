import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dualvpn_manager/utils/logger.dart';

class ClashService {
  Process? _process;
  bool _isConnected = false;
  final String _apiUrl = 'http://127.0.0.1:9090'; // Clash默认API地址
  String? _configPath; // 保存当前配置文件路径

  bool get isConnected => _isConnected;

  // 通过配置文件启动Clash
  Future<bool> startWithConfig(String configPath) async {
    try {
      // 检查配置文件是否存在
      final configFile = File(configPath);
      if (!await configFile.exists()) {
        Logger.error('Clash配置文件不存在: $configPath');
        throw Exception('Clash配置文件不存在: $configPath');
      }

      // 检查文件是否可读
      final stat = await configFile.stat();
      if ((stat.mode & 0x4000) == 0) {
        // 0x4000是文件所有者读权限位
        Logger.error('Clash配置文件不可读: $configPath');
        throw Exception('Clash配置文件不可读: $configPath');
      }

      // 检查Clash命令是否可用
      try {
        final result = await Process.run('which', ['clash']);
        if (result.exitCode != 0) {
          Logger.error('Clash命令未找到，请确保已安装Clash');
          throw Exception('Clash命令未找到，请确保已安装Clash');
        }
      } catch (e) {
        Logger.error('检查Clash命令失败: $e');
        throw Exception('检查Clash命令失败: $e');
      }

      // 保存配置文件路径
      _configPath = configPath;

      // 构建Clash命令
      List<String> args = [
        '-f', configPath, // 指定配置文件
        '-d', path.dirname(configPath), // 指定工作目录
      ];

      // 启动Clash进程
      Logger.info('正在启动Clash进程...');
      _process = await Process.start('clash', args);

      // 监听进程输出
      _process!.stdout.listen(
        (data) {
          final output = utf8.decode(data);
          Logger.debug('Clash stdout: $output');
          // 更宽松的连接成功判断条件
          if (output.contains('HTTP') && output.contains('listening') ||
              output.contains('RESTful') && output.contains('listening') ||
              output.contains('Clash') ||
              output.contains('start') ||
              output.contains('initial')) {
            _isConnected = true;
            Logger.info('Clash服务已启动');
          }
        },
        onError: (Object error) {
          Logger.error('Clash stdout监听错误: $error');
        },
      );

      _process!.stderr.listen(
        (data) {
          final output = utf8.decode(data);
          Logger.error('Clash stderr: $output');
          // 即使stderr有输出，也可能是正常启动信息
          if (output.contains('HTTP') && output.contains('listening') ||
              output.contains('RESTful') && output.contains('listening')) {
            _isConnected = true;
            Logger.info('Clash服务已启动');
          }
        },
        onError: (Object error) {
          Logger.error('Clash stderr监听错误: $error');
        },
      );

      // 等待一段时间以确定启动是否成功
      await Future.delayed(const Duration(seconds: 5));

      Logger.info('Clash启动${_isConnected ? '成功' : '可能失败'}');
      return _isConnected;
    } catch (e, stackTrace) {
      Logger.error('Clash启动失败: $e\nStack trace: $stackTrace');
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
        Logger.error('下载订阅配置失败: ${response.statusCode}');
        throw Exception('下载订阅配置失败: ${response.statusCode}');
      }

      // 保存配置文件到临时目录
      final tempDir = await Directory.systemTemp.createTemp('clash_config');
      final configFile = File(path.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(response.body);

      // 保存配置文件路径
      _configPath = configFile.path;

      // 启动Clash
      return await startWithConfig(configFile.path);
    } catch (e, stackTrace) {
      Logger.error('通过订阅启动Clash失败: $e\nStack trace: $stackTrace');
      _isConnected = false;
      rethrow;
    }
  }

  // 更新订阅配置
  Future<bool> updateSubscription(String subscriptionUrl) async {
    try {
      Logger.info('开始更新Clash订阅: $subscriptionUrl');

      // 下载新的配置文件
      final response = await http.get(Uri.parse(subscriptionUrl));
      if (response.statusCode != 200) {
        Logger.error('下载订阅配置失败: ${response.statusCode}');
        throw Exception('下载订阅配置失败: ${response.statusCode}');
      }

      // 尝试解码响应内容（某些订阅可能返回base64编码的数据）
      String configContent = response.body;
      try {
        // 尝试解码base64
        List<int> decodedBytes = base64Decode(configContent);
        configContent = utf8.decode(decodedBytes);
        Logger.debug('成功解码base64订阅内容');
      } catch (decodeError) {
        // 如果解码失败，假设内容已经是纯文本YAML格式
        Logger.debug('订阅内容不是base64编码，使用原始内容');
      }

      // 检查是否有现有的配置文件路径
      if (_configPath == null) {
        Logger.info('没有找到现有的配置文件路径，创建临时配置文件');
        // 创建临时目录和配置文件
        final tempDir = await Directory.systemTemp.createTemp('clash_config');
        final configFile = File(path.join(tempDir.path, 'config.yaml'));
        await configFile.writeAsString(configContent);

        // 保存配置文件路径
        _configPath = configFile.path;

        // 如果Clash正在运行，重新启动它
        if (_isConnected && _process != null) {
          await stop();
          return await startWithConfig(_configPath!);
        }

        Logger.info('Clash订阅更新成功（保存到临时文件）');
        return true;
      }

      // 保存新的配置到现有文件
      final configFile = File(_configPath!);
      await configFile.writeAsString(configContent);

      // 重新加载配置（通过API）
      final reloadUrl = '$_apiUrl/configs?force=true';
      final reloadResponse = await http.put(Uri.parse(reloadUrl));

      if (reloadResponse.statusCode == 204) {
        Logger.info('Clash订阅更新成功');
        return true;
      } else {
        Logger.error('重新加载配置失败: ${reloadResponse.statusCode}');
        // 如果API重新加载失败，尝试重启Clash
        if (_isConnected && _process != null) {
          await stop();
          return await startWithConfig(_configPath!);
        }
        return false;
      }
    } on SocketException catch (e) {
      Logger.error('网络连接错误: $e');
      throw Exception('网络连接错误，请检查网络连接或订阅URL是否有效');
    } on http.ClientException catch (e) {
      Logger.error('HTTP客户端错误: $e');
      throw Exception('HTTP客户端错误，请检查订阅URL是否有效');
    } catch (e, stackTrace) {
      Logger.error('更新Clash订阅失败: $e\nStack trace: $stackTrace');
      throw Exception('更新Clash订阅失败: $e');
    }
  }

  // 停止Clash
  Future<void> stop() async {
    try {
      if (_process != null) {
        // 尝试优雅地停止Clash
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
      Logger.info('Clash已停止');
    } catch (e, stackTrace) {
      Logger.error('停止Clash时出错: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 设置代理模式
  Future<bool> setProxyMode(String mode) async {
    try {
      final url = '$_apiUrl/configs';
      final response = await http.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mode': mode}), // 'global', 'rule', 'direct'
      );

      if (response.statusCode == 204) {
        Logger.info('代理模式设置成功: $mode');
        return true;
      } else {
        Logger.error('设置代理模式失败: ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('设置代理模式失败: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 选择代理节点
  Future<bool> selectProxy(String selector, String proxy) async {
    try {
      final url = '$_apiUrl/proxies/$selector';
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': proxy}),
      );

      if (response.statusCode == 204) {
        Logger.info('代理节点选择成功: $selector -> $proxy');
        return true;
      } else {
        Logger.error('选择代理节点失败: ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('选择代理节点失败: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 获取Clash状态
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final url = '$_apiUrl/traffic';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.debug('获取Clash状态成功');
        return data;
      } else {
        Logger.error('获取Clash状态失败: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('获取Clash状态失败: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 获取代理列表
  Future<Map<String, dynamic>?> getProxies() async {
    try {
      final url = '$_apiUrl/proxies';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.debug('获取代理列表成功');
        return data;
      } else {
        Logger.error('获取代理列表失败: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('获取代理列表失败: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 确保Clash服务正常运行并可访问
  Future<bool> verifyConnection() async {
    try {
      // 尝试获取状态以验证连接
      final status = await getStatus();
      if (status != null) {
        Logger.info('Clash连接验证成功');
        return true;
      } else {
        Logger.warn('Clash连接验证失败：无法获取状态');
        return false;
      }
    } catch (e) {
      Logger.error('Clash连接验证失败: $e');
      return false;
    }
  }
}
