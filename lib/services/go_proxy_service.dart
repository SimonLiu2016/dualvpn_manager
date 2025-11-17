import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:path/path.dart' as path;

class GoProxyService {
  static final GoProxyService _instance = GoProxyService._internal();
  factory GoProxyService() => _instance;
  GoProxyService._internal();

  bool _isRunning = false;
  Process? _process; // 添加进程引用

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
      final configPath = path.join(executableDir, 'Resources', 'config.yaml');
      final configFile = File(configPath);
      Logger.info('检查配置文件路径: $configPath');
      Logger.info('配置文件是否存在: ${await configFile.exists()}');

      if (!await configFile.exists()) {
        Logger.error('配置文件不存在: $configPath');
        bool configCopied = false;

        // 在沙盒环境中，尝试从应用包Resources目录复制配置文件
        try {
          final appExecutable = Platform.resolvedExecutable;
          final appDir = File(appExecutable).parent; // MacOS目录
          final resourcesDir = Directory(
            path.join(appDir.parent.path, 'Resources'),
          );
          final resourceConfigPath = path.join(
            resourcesDir.path,
            'bin',
            'Contents',
            'Resources',
            'config.yaml',
          );
          final resourceConfigFile = File(resourceConfigPath);

          if (await resourceConfigFile.exists()) {
            // 将配置文件复制到可执行文件目录
            await resourceConfigFile.copy(configPath);
            Logger.info(
              '从应用包Resources目录复制配置文件: $resourceConfigPath -> $configPath',
            );
            configCopied = true;
          }
        } catch (e) {
          Logger.warn('从应用包Resources目录复制配置文件时出错: $e');
        }

        // 如果还没有复制配置文件，尝试使用项目根目录下的配置文件
        if (!configCopied) {
          // 尝试使用项目根目录下的配置文件
          // 在沙盒环境中，使用Platform.resolvedExecutable来定位项目根目录
          final executablePath = Platform.resolvedExecutable;
          final executableDir = File(executablePath).parent;

          // 在开发环境中，可执行文件通常在项目根目录下的.dart_tool目录中
          // 我们需要向上遍历目录结构来找到项目根目录
          Directory projectDir = executableDir;
          int maxLevels = 10; // 限制遍历层级以防止无限循环

          while (maxLevels > 0) {
            // 检查当前目录是否包含go-proxy-core目录
            final goProxyDir = Directory(
              path.join(projectDir.path, 'go-proxy-core'),
            );
            if (await goProxyDir.exists()) {
              break;
            }

            // 检查当前目录是否包含pubspec.yaml文件（项目根目录标志）
            final pubspecFile = File(
              path.join(projectDir.path, 'pubspec.yaml'),
            );
            if (await pubspecFile.exists()) {
              break;
            }

            // 向上一级目录
            projectDir = projectDir.parent;
            maxLevels--;
          }

          final projectConfigPath = path.join(
            projectDir.path,
            'go-proxy-core',
            'config.yaml',
          );
          final projectConfigFile = File(projectConfigPath);
          if (await projectConfigFile.exists()) {
            Logger.info('使用项目根目录下的配置文件: $projectConfigPath');
            // 将配置文件复制到可执行文件目录
            await projectConfigFile.copy(configPath);
            Logger.info('已将配置文件复制到可执行文件目录');
            configCopied = true;
          } else {
            Logger.error('项目根目录下也找不到配置文件: $projectConfigPath');
          }
        }

        if (!configCopied) {
          Logger.error('无法找到或复制配置文件');
        }
      } else {
        Logger.info('找到配置文件: $configPath');
      }

      Logger.info('正在启动Go代理核心: $executablePath');

      // 添加调试信息
      Logger.info('检查可执行文件是否存在: ${await File(executablePath).exists()}');
      Logger.info('检查可执行文件权限: ${await File(executablePath).stat()}');

      // 确保可执行文件具有执行权限
      try {
        // 使用同步方式设置权限，确保在启动进程前完成
        final result = await Process.run('chmod', ['+x', executablePath]);
        if (result.exitCode == 0) {
          Logger.info('已设置可执行文件权限');
        } else {
          Logger.warn('设置可执行文件权限失败，退出码: ${result.exitCode}');
        }
      } catch (e) {
        Logger.warn('设置可执行文件权限时出错: $e');
      }

      // 直接启动Go代理核心进程
      _process = await Process.start(
        executablePath,
        [],
        workingDirectory: executableDir,
        includeParentEnvironment: true,
      );

      // 添加进程启动后的调试信息
      Logger.info('Go代理核心进程已启动，PID: ${_process!.pid}');

      // 监听进程输出
      _process!.stdout.transform(utf8.decoder).listen((data) {
        Logger.info('Go代理核心 stdout: $data');
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        Logger.error('Go代理核心 stderr: $data');
      });

      // 监听进程退出
      _process!.exitCode.then((code) {
        Logger.info('Go代理核心进程退出，退出码: $code');
        _isRunning = false;
      });

      // 使用非阻塞方式等待一段时间确认启动状态
      // 创建一个Completer来处理异步等待
      final completer = Completer<void>();
      Timer(const Duration(seconds: 5), () {
        completer.complete();
      });
      await completer.future;

      // 检查进程是否仍在运行
      if (_process != null) {
        try {
          // 检查进程是否已经退出
          final exitCode = _process!.exitCode;
          if (await exitCode.timeout(
                const Duration(milliseconds: 100),
                onTimeout: () => -1,
              ) !=
              -1) {
            _isRunning = false;
            Logger.error('Go代理核心在启动后意外退出');
            return false;
          }
        } catch (e) {
          // 进程仍在运行
        }
      }

      bool status = await checkStatus();

      if (status) {
        Logger.info('状态校验 go 代理核心正常');
        _isRunning = true;
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
      if (!_isRunning) {
        Logger.info('Go代理核心未运行');
        return;
      }

      Logger.info('正在停止Go代理核心...');

      // 直接终止进程
      if (_process != null) {
        _process!.kill();
        _process = null;
      }

      // 作为后备方案，终止任何残留的go-proxy-core进程
      await _killExistingProcess();

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

        // 使用非阻塞方式验证规则是否已正确更新
        final completer = Completer<void>();
        Timer(const Duration(milliseconds: 100), () {
          completer.complete();
        });
        await completer.future;
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

        // 使用非阻塞方式添加延迟以确保协议真正添加完成
        final completer = Completer<void>();
        Timer(const Duration(milliseconds: 500), () {
          completer.complete();
        });
        await completer.future;

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

  /// 获取代理核心可执行文件路径
  Future<String?> _getProxyExecutablePath() async {
    try {
      // 在沙盒环境中，直接使用固定路径
      // 根据打包脚本，Go代理核心bundle会被打包到应用包的Contents/Resources目录中
      final executablePath = Platform.resolvedExecutable;
      final appDir = File(executablePath).parent; // MacOS目录
      final bundleExecutablePath = path.join(
        appDir.parent.path,
        'Resources',
        'bin',
        'Contents',
        'MacOS',
        'go-proxy-core',
      );
      final bundleExecutableFile = File(bundleExecutablePath);

      if (await bundleExecutableFile.exists()) {
        Logger.info('在应用包Resources目录中找到代理核心bundle可执行文件: $bundleExecutablePath');
        return bundleExecutablePath;
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
      // 移除对特权助手服务的调用，直接终止进程
      Logger.info('终止现有的Go代理核心实例');

      // 在沙盒环境中，我们不能使用pkill命令
      // 如果有进程引用，直接终止它
      if (_process != null) {
        Logger.info('终止已知的Go代理核心进程');
        _process!.kill();
        // 使用非阻塞方式等待进程终止
        final completer = Completer<bool>();
        Timer(const Duration(seconds: 5), () {
          completer.complete(false); // 超时
        });

        _process!.exitCode
            .then((code) {
              if (!completer.isCompleted) {
                completer.complete(true); // 正常退出
              }
            })
            .catchError((e) {
              if (!completer.isCompleted) {
                completer.complete(false); // 错误
              }
              Logger.warn('等待进程终止时出错: $e');
            });

        final completed = await completer.future;
        if (!completed) {
          Logger.warn('等待进程终止超时');
        }
        _process = null;
      }

      // 使用更安全的方式检查是否有残留进程
      try {
        // 使用非阻塞方式检查进程，避免界面卡顿
        Process.start('pgrep', ['-f', 'go-proxy-core'])
            .then((process) async {
              final stdout = await utf8.decodeStream(process.stdout);
              final exitCode = await process.exitCode;

              if (exitCode == 0) {
                final pids = stdout.trim().split('\n');
                Logger.info('找到残留的Go代理核心进程: $pids');

                // 在沙盒环境中，我们只能终止自己启动的进程
                // 这里我们记录日志但不实际终止，因为可能没有权限
                for (final pid in pids) {
                  if (pid.isNotEmpty) {
                    Logger.info('检测到Go代理核心进程PID: $pid');
                  }
                }
              } else {
                Logger.info('没有找到残留的Go代理核心实例');
              }
            })
            .catchError((e) {
              Logger.warn('检查残留Go代理核心实例时出错: $e');
            });
      } catch (e) {
        Logger.warn('检查残留Go代理核心实例时出错: $e');
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
        status['running'] = true;
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
      final response = await HttpClient().getUrl(url);
      final httpResponse = await response.close();
      final responseBody = await utf8.decodeStream(httpResponse);

      if (httpResponse.statusCode == 200) {
        final stats = jsonDecode(responseBody) as Map<String, dynamic>;
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

  /// 获取所有代理源
  Future<Map<String, dynamic>?> getProxySources() async {
    try {
      final url = Uri.parse('http://127.0.0.1:6162/proxy-sources');
      final response = await HttpClient().getUrl(url);
      final httpResponse = await response.close();
      final responseBody = await utf8.decodeStream(httpResponse);

      if (httpResponse.statusCode == 200) {
        final proxySources = jsonDecode(responseBody) as Map<String, dynamic>;
        return proxySources;
      } else {
        Logger.error('获取代理源列表失败: ${httpResponse.statusCode}, $responseBody');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('获取代理源列表时出错: $e\nStack trace: $stackTrace');
      return null;
    }
  }

  /// 删除代理源
  Future<bool> removeProxySource(String sourceId) async {
    try {
      final url = Uri.parse('http://127.0.0.1:6162/proxy-sources/$sourceId');
      final client = HttpClient();
      final request = await client.deleteUrl(url);
      final response = await request.close();

      if (response.statusCode == 204) {
        Logger.info('删除代理源成功: $sourceId');
        client.close();
        return true;
      } else {
        Logger.error('删除代理源失败: ${response.statusCode}');
        client.close();
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('删除代理源时出错: $e\nStack trace: $stackTrace');
      return false;
    }
  }
}
