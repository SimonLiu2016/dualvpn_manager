import 'dart:io';
import 'dart:convert';
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:path/path.dart' as path;

class GoProxyService {
  static final GoProxyService _instance = GoProxyService._internal();
  factory GoProxyService() => _instance;
  GoProxyService._internal();

  Process? _process;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// 启动Go代理核心
  Future<bool> start() async {
    try {
      if (_isRunning) {
        Logger.info('Go代理核心已在运行中');
        return true;
      }

      // 先尝试终止任何已运行的实例
      await _killExistingProcess();

      // 获取可执行文件路径
      final executablePath = await _getProxyExecutablePath();
      if (executablePath == null) {
        Logger.error('找不到Go代理核心可执行文件');
        return false;
      }

      // 获取可执行文件所在目录
      final executableDir = path.dirname(executablePath);
      Logger.info('Go代理核心可执行文件目录: $executableDir');

      // 检查配置文件是否存在
      final configPath = path.join(executableDir, 'config.yaml');
      final configFile = File(configPath);
      if (!await configFile.exists()) {
        Logger.error('配置文件不存在: $configPath');
        // 尝试使用项目根目录下的配置文件
        final projectDir = Directory.current;
        final projectConfigPath = path.join(
          projectDir.path,
          'go-proxy-core',
          'config.yaml',
        );
        final projectConfigFile = File(projectConfigPath);
        if (await projectConfigFile.exists()) {
          Logger.info('使用项目根目录下的配置文件: $projectConfigPath');
        } else {
          Logger.error('项目根目录下也找不到配置文件: $projectConfigPath');
        }
      } else {
        Logger.info('找到配置文件: $configPath');
      }

      Logger.info('正在启动Go代理核心: $executablePath');

      // 创建日志文件
      final logFile = File('/tmp/go-proxy-core.log');
      final logSink = logFile.openWrite(mode: FileMode.writeOnlyAppend);

      // 启动进程，设置工作目录为可执行文件所在目录
      _process = await Process.start(
        executablePath,
        [],
        workingDirectory: executableDir,
      );

      // 监听标准输出并同时写入日志文件和应用日志
      _process!.stdout.listen(
        (data) {
          final output = utf8.decode(data);
          // 写入日志文件
          logSink.write(output);

          Logger.debug('Go代理核心 stdout: $output');

          // 检查是否启动成功
          if (output.contains('Proxy core started') ||
              output.contains('Starting proxy core')) {
            _isRunning = true;
            Logger.info('Go代理核心启动成功');
          }
        },
        onError: (Object error) {
          Logger.error('Go代理核心 stdout 监听错误: $error');
        },
        onDone: () {
          logSink.close();
        },
      );

      // 监听标准错误并同时写入日志文件和应用日志
      _process!.stderr.listen(
        (data) {
          final output = utf8.decode(data);
          // 写入日志文件
          logSink.write(output);

          // Logger.info('Go代理核心 stderr: $output');

          // 检查是否启动成功
          if (output.contains('Proxy core started') ||
              output.contains('Starting proxy core')) {
            _isRunning = true;
            Logger.info('Go代理核心启动成功');
          }
        },
        onError: (Object error) {
          Logger.error('Go代理核心 stderr 监听错误: $error');
        },
        onDone: () {
          logSink.close();
        },
      );

      // 等待一段时间确认启动状态
      await Future.delayed(const Duration(seconds: 5));

      // 再次检查进程是否仍在运行
      if (_process != null && _isRunning) {
        try {
          // 检查进程是否已经退出
          final exitCode = _process!.exitCode;
          if (await exitCode.timeout(
                const Duration(milliseconds: 100),
                onTimeout: () => -1,
              ) !=
              -1) {
            _isRunning = false;
            _process = null;
            Logger.error('Go代理核心在启动后意外退出');
            return false;
          }
        } catch (e) {
          // 进程仍在运行
        }
      }

      Logger.info('Go代理核心启动${_isRunning ? '成功' : '可能失败'}');
      return _isRunning;
    } catch (e, stackTrace) {
      Logger.error('启动Go代理核心失败: $e\nStack trace: $stackTrace');
      _isRunning = false;
      return false;
    }
  }

  /// 停止Go代理核心
  Future<void> stop() async {
    try {
      if (!_isRunning || _process == null) {
        Logger.info('Go代理核心未运行');
        return;
      }

      Logger.info('正在停止Go代理核心...');

      // 尝试优雅地停止进程
      _process!.kill(ProcessSignal.sigterm);

      // 等待进程结束
      await _process!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // 如果进程没有在5秒内结束，则强制杀死
          _process!.kill(ProcessSignal.sigkill);
          return 0;
        },
      );

      _process = null;
      _isRunning = false;
      Logger.info('Go代理核心已停止');
    } catch (e, stackTrace) {
      Logger.error('停止Go代理核心时出错: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  /// 更新路由规则
  Future<bool> updateRules(List<Map<String, dynamic>> rules) async {
    try {
      Logger.info('准备更新 ${rules.length} 条路由规则');

      // 添加调试日志，打印所有规则
      for (var i = 0; i < rules.length; i++) {
        final rule = rules[i];
        Logger.info(
          '规则 $i: type=${rule['type']}, pattern=${rule['pattern']}, proxy_source=${rule['proxy_source']}, enabled=${rule['enabled']}',
        );
      }

      final url = Uri.parse('http://127.0.0.1:6162/rules');
      Logger.info('向URL发送PUT请求: $url');

      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 10);

      final request = await client.putUrl(url);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      final jsonBody = jsonEncode(rules);
      Logger.info('JSON编码请求体: $jsonBody');

      // 使用utf8编码写入请求体
      request.write(jsonBody);

      Logger.info('请求头: Content-Type=${request.headers.value('Content-Type')}');

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);

      Logger.info('收到响应，状态码: ${response.statusCode}');
      Logger.info('响应体: $responseBody');

      if (response.statusCode == 200) {
        Logger.info('路由规则更新成功: $responseBody');

        // 验证规则是否已正确更新
        await Future.delayed(const Duration(milliseconds: 100));
        final verifyRules = await getRules();
        if (verifyRules != null) {
          Logger.info('验证路由规则更新，当前规则数量: ${verifyRules.length}');
          for (var i = 0; i < verifyRules.length; i++) {
            final rule = verifyRules[i];
            Logger.info(
              '验证规则 $i: type=${rule['type']}, pattern=${rule['pattern']}, proxy_source=${rule['proxy_source']}, enabled=${rule['enabled']}',
            );
          }
        }

        client.close();
        return true;
      } else {
        Logger.error('路由规则更新失败: ${response.statusCode}, $responseBody');
        client.close();
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('更新路由规则时出错: $e\nStack trace: $stackTrace');
      return false;
    }
  }

  /// 获取当前路由规则
  Future<List<Map<String, dynamic>>?> getRules() async {
    try {
      final url = Uri.parse('http://127.0.0.1:6162/rules');
      final response = await HttpClient().getUrl(url);
      final httpResponse = await response.close();
      final responseBody = await utf8.decodeStream(httpResponse);

      if (httpResponse.statusCode == 200) {
        final rules = jsonDecode(responseBody) as List;
        return rules.cast<Map<String, dynamic>>();
      } else {
        Logger.error('获取路由规则失败: ${httpResponse.statusCode}, $responseBody');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('获取路由规则时出错: $e\nStack trace: $stackTrace');
      return null;
    }
  }

  /// 添加协议
  Future<bool> addProtocol(Map<String, dynamic> protocolConfig) async {
    try {
      final url = Uri.parse('http://127.0.0.1:6162/protocols');
      Logger.info('=== 向Go代理核心发送协议添加请求 ===');
      Logger.info('请求URL: $url');
      Logger.info('协议配置: $protocolConfig');

      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 10);
      Logger.info('创建HTTP客户端');

      final request = await client.postUrl(url);
      Logger.info('创建POST请求');

      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      Logger.info('设置请求头: Content-Type=application/json; charset=utf-8');

      // 确保协议名称不包含特殊字符，创建一个清理后的版本
      final cleanedProtocolConfig = Map<String, dynamic>.from(protocolConfig);
      if (cleanedProtocolConfig.containsKey('name') &&
          cleanedProtocolConfig['name'] is String) {
        // 清理协议名称中的特殊字符（如emoji），只保留字母、数字、连字符和下划线
        final originalName = cleanedProtocolConfig['name'] as String;
        final cleanedName = originalName.replaceAll(RegExp(r'[^\w\- ]'), '');
        cleanedProtocolConfig['name'] = cleanedName;
        Logger.info('清理协议名称: $originalName -> $cleanedName');
      }

      final jsonBody = jsonEncode(cleanedProtocolConfig);
      Logger.info('JSON编码请求体: $jsonBody');

      request.write(jsonBody);
      Logger.info('写入请求体');

      Logger.info('发送请求...');
      final response = await request.close();
      Logger.info('收到响应，状态码: ${response.statusCode}');

      final responseBody = await utf8.decodeStream(response);
      Logger.info('响应体: $responseBody');

      // 关闭HttpClient
      client.close();
      Logger.info('关闭HTTP客户端');

      if (response.statusCode == 201) {
        Logger.info('协议添加成功: $responseBody');

        // 添加延迟以确保协议真正添加完成
        Logger.info('等待500毫秒确保协议添加完成');
        await Future.delayed(const Duration(milliseconds: 500));

        // 验证协议是否真的添加成功
        Logger.info('开始验证协议是否真的添加成功');
        try {
          final protocols = await getProtocols();
          if (protocols != null) {
            Logger.info('获取到协议列表: ${protocols.keys.join(', ')}');
            final protocolName = cleanedProtocolConfig['name'] as String?;
            if (protocolName != null && protocols.containsKey('protocols')) {
              final protocolList = protocols['protocols'] as Map?;
              if (protocolList != null &&
                  protocolList.containsKey(protocolName)) {
                Logger.info('验证协议 $protocolName 确实已添加到Go代理核心');
              } else {
                Logger.warn('协议 $protocolName 未在Go代理核心中找到');
                Logger.info('当前协议列表中的协议: ${protocolList?.keys.join(', ')}');
              }
            } else {
              Logger.warn('协议名称为空或协议列表不存在');
            }
          } else {
            Logger.error('无法获取协议列表');
          }
        } catch (e) {
          Logger.error('验证协议添加时出错: $e');
        }

        Logger.info('=== 协议添加流程完成 ===');
        return true;
      } else {
        Logger.error('协议添加失败: ${response.statusCode}, $responseBody');
        Logger.info('=== 协议添加流程完成（失败）===');
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('添加协议时出错: $e\nStack trace: $stackTrace');
      Logger.info('=== 协议添加流程完成（异常）===');
      return false;
    }
  }

  /// 获取协议列表
  Future<Map<String, dynamic>?> getProtocols() async {
    try {
      final url = Uri.parse('http://127.0.0.1:6162/protocols');
      final response = await HttpClient().getUrl(url);
      final httpResponse = await response.close();
      final responseBody = await utf8.decodeStream(httpResponse);

      if (httpResponse.statusCode == 200) {
        final protocols = jsonDecode(responseBody) as Map<String, dynamic>;
        return protocols;
      } else {
        Logger.error('获取协议列表失败: ${httpResponse.statusCode}, $responseBody');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('获取协议列表时出错: $e\nStack trace: $stackTrace');
      return null;
    }
  }

  /// 检查端口是否可用
  Future<bool> _checkPortAvailability(List<int> ports) async {
    try {
      for (final port in ports) {
        Socket? socket;
        try {
          socket = await Socket.connect(
            '127.0.0.1',
            port,
          ).timeout(const Duration(seconds: 1));
          // 端口被占用
          await socket.close();
          Logger.info('端口 $port 被占用');
          return false;
        } catch (e) {
          // 连接失败通常意味着端口未被占用
          // 继续检查下一个端口
          Logger.info('端口 $port 未被占用');
        }
      }
      return true;
    } catch (e) {
      // 出现异常也认为端口可用
      Logger.info('检查端口可用性时出现异常: $e');
      return true;
    }
  }

  /// 获取代理核心可执行文件路径
  Future<String?> _getProxyExecutablePath() async {
    try {
      // 首先尝试在项目目录中查找
      final projectDir = Directory.current;
      final possiblePaths = [
        path.join(projectDir.path, 'go-proxy-core', 'go-proxy-core'),
        path.join(projectDir.path, 'go-proxy-core', 'bin', 'go-proxy-core'),
        path.join(projectDir.path, 'go-proxy-core', 'dist', 'go-proxy-core'),
      ];

      for (final p in possiblePaths) {
        final file = File(p);
        if (await file.exists()) {
          Logger.info('找到代理核心可执行文件: $p');
          return p;
        }
      }

      // 尝试在应用包的Contents/Resources目录中查找（用于发布版本）
      try {
        final executable = Platform.resolvedExecutable;
        final appDir = File(executable).parent.parent; // Contents目录
        final resourcesBinPath = path.join(
          appDir.path,
          'Resources',
          'bin',
          'go-proxy-core',
        );
        final resourcesBinFile = File(resourcesBinPath);
        if (await resourcesBinFile.exists()) {
          Logger.info(
            '在应用包Contents/Resources目录中找到代理核心可执行文件: $resourcesBinPath',
          );
          return resourcesBinPath;
        }
      } catch (e) {
        Logger.warn('检查应用包Contents/Resources目录时出错: $e');
      }

      // 尝试在系统PATH中查找
      final result = await Process.run('which', ['go-proxy-core']);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        Logger.info('在系统PATH中找到代理核心可执行文件: $path');
        return path;
      }

      // 尝试查找go-proxy-core目录并构建
      final goProxyDir = Directory(path.join(projectDir.path, 'go-proxy-core'));
      if (await goProxyDir.exists()) {
        Logger.info('找到go-proxy-core目录，尝试构建...');
        final buildResult = await Process.run('go', [
          'build',
          '-o',
          'go-proxy-core',
          './cmd/main.go',
        ], workingDirectory: goProxyDir.path);

        if (buildResult.exitCode == 0) {
          final executablePath = path.join(goProxyDir.path, 'go-proxy-core');
          final file = File(executablePath);
          if (await file.exists()) {
            Logger.info('成功构建代理核心可执行文件: $executablePath');
            return executablePath;
          }
        } else {
          Logger.error('构建Go代理核心失败: ${buildResult.stderr}');
        }
      }

      Logger.error('未找到代理核心可执行文件');
      return null;
    } catch (e) {
      Logger.error('获取代理核心可执行文件路径失败: $e');
      return null;
    }
  }

  /// 终止任何已运行的Go代理核心实例
  Future<void> _killExistingProcess() async {
    try {
      // 在macOS上终止任何已运行的go-proxy-core进程
      final result = await Process.run('pkill', ['-f', 'go-proxy-core']);
      if (result.exitCode == 0) {
        Logger.info('已终止现有的Go代理核心实例');
        // 等待一段时间确保进程完全终止
        await Future.delayed(const Duration(seconds: 1));
      } else {
        Logger.info('没有找到正在运行的Go代理核心实例');
      }
    } catch (e) {
      Logger.warn('终止现有Go代理核心实例时出错: $e');
    }
  }

  /// 检查Go代理核心是否正在运行
  Future<bool> checkStatus() async {
    try {
      final url = Uri.parse('http://127.0.0.1:6162/status');
      Logger.info('检查Go代理核心状态: $url');

      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 5);

      final response = await client
          .getUrl(url)
          .timeout(const Duration(seconds: 5));
      final httpResponse = await response.close();
      final responseBody = await utf8.decodeStream(httpResponse);

      Logger.info('收到状态检查响应，状态码: ${httpResponse.statusCode}');
      Logger.info('响应体: $responseBody');

      if (httpResponse.statusCode == 200) {
        final status = jsonDecode(responseBody) as Map<String, dynamic>;
        Logger.info('Go代理核心状态检查成功: running=${status['running']}');
        client.close();
        return status['running'] == true;
      } else {
        Logger.error('检查状态失败: ${httpResponse.statusCode}, $responseBody');
        client.close();
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('检查状态时出错: $e\nStack trace: $stackTrace');
      return false;
    }
  }

  /// 获取统计信息
  Future<Map<String, dynamic>?> getStats() async {
    try {
      final url = Uri.parse('http://127.0.0.1:6162/stats');
      Logger.info('获取Go代理核心统计信息: $url');
      final response = await HttpClient().getUrl(url);
      final httpResponse = await response.close();
      final responseBody = await utf8.decodeStream(httpResponse);

      if (httpResponse.statusCode == 200) {
        final stats = jsonDecode(responseBody) as Map<String, dynamic>;
        Logger.info('获取统计信息成功: $stats');
        return stats;
      } else {
        Logger.error('获取统计信息失败: ${httpResponse.statusCode}, $responseBody');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('获取统计信息时出错: $e\nStack trace: $stackTrace');
      return null;
    }
  }

  /// 设置代理源的当前代理
  Future<bool> setCurrentProxy(
    String sourceId,
    Map<String, dynamic> proxyInfo,
  ) async {
    try {
      final url = Uri.parse(
        'http://127.0.0.1:6162/proxy-sources/$sourceId/current-proxy',
      );
      Logger.info('设置代理源 $sourceId 的当前代理: $proxyInfo');

      // 添加更详细的日志以调试代理信息
      if (proxyInfo.containsKey('config')) {
        final config = proxyInfo['config'];
        Logger.info('代理配置详情:');
        config.forEach((key, value) {
          Logger.info('  $key: $value');
        });
      }

      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 10);

      final request = await client.putUrl(url);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      final jsonBody = jsonEncode(proxyInfo);
      Logger.info('JSON编码请求体: $jsonBody');

      request.write(jsonBody);

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);

      Logger.info('收到响应，状态码: ${response.statusCode}');
      Logger.info('响应体: $responseBody');

      if (response.statusCode == 200) {
        Logger.info('设置代理源当前代理成功: $responseBody');
        client.close();
        return true;
      } else {
        Logger.error('设置代理源当前代理失败: ${response.statusCode}, $responseBody');
        client.close();
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('设置代理源当前代理时出错: $e\nStack trace: $stackTrace');
      return false;
    }
  }

  /// 添加代理源
  Future<bool> addProxySource(
    String sourceId,
    String sourceName,
    String sourceType,
    Map<String, dynamic> sourceConfig,
  ) async {
    try {
      final url = Uri.parse('http://127.0.0.1:6162/proxy-sources');
      Logger.info('添加代理源: id=$sourceId, name=$sourceName, type=$sourceType');

      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 10);

      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      final proxySourceData = {
        'id': sourceId,
        'name': sourceName,
        'type': sourceType,
        'config': sourceConfig,
      };

      final jsonBody = jsonEncode(proxySourceData);
      Logger.info('JSON编码请求体: $jsonBody');

      request.write(jsonBody);

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);

      Logger.info('收到响应，状态码: ${response.statusCode}');
      Logger.info('响应体: $responseBody');

      if (response.statusCode == 201) {
        Logger.info('添加代理源成功: $responseBody');
        client.close();
        return true;
      } else {
        Logger.error('添加代理源失败: ${response.statusCode}, $responseBody');
        client.close();
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('添加代理源时出错: $e\nStack trace: $stackTrace');
      return false;
    }
  }
}
