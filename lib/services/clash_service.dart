import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';
import '../models/vpn_config.dart';

class ClashService {
  static final ClashService _instance = ClashService._internal();
  factory ClashService() => _instance;
  ClashService._internal();

  bool _isConnected = false;
  String? _currentConfig;
  Process? _process; // 添加进程变量
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
        '-d', path.dirname(configPath), // 指定配置文件目录
        '-f', path.basename(configPath), // 指定配置文件名
      ];

      // 启动Clash进程
      Logger.info('正在启动Clash进程...');
      _process = await Process.start('clash', args);

      // 监听进程输出
      _process!.stdout.listen(
        (data) {
          final output = utf8.decode(data);
          Logger.debug('Clash stdout: $output');
          if (output.contains('HTTP proxy listening') ||
              output.contains('SOCKS5 proxy listening')) {
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
        },
        onError: (Object error) {
          Logger.error('Clash stderr监听错误: $error');
        },
      );

      // 等待一段时间以确定启动是否成功
      await Future.delayed(const Duration(seconds: 3));

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
    Logger.info('=== 开始通过订阅启动Clash ===');
    Logger.info('订阅URL: $subscriptionUrl');

    try {
      // 下载配置文件
      Logger.info('开始下载订阅配置');

      // 尝试多次连接以应对临时网络问题
      http.Response? response;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          Logger.info('尝试连接 (第${retryCount + 1}次)');

          // 添加请求头以模拟浏览器请求
          final client = http.Client();
          final request = http.Request('GET', Uri.parse(subscriptionUrl));
          request.headers['User-Agent'] =
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
          request.headers['Accept'] =
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8';

          Logger.info('发送HTTP请求...');
          final streamedResponse = await client
              .send(request)
              .timeout(
                Duration(seconds: 30),
                onTimeout: () {
                  Logger.error('下载订阅配置超时');
                  throw Exception('下载订阅配置超时');
                },
              );

          response = await http.Response.fromStream(streamedResponse);
          client.close();

          if (response.statusCode == 200) {
            Logger.info('成功下载配置，状态码: ${response.statusCode}');
            break;
          } else {
            Logger.warn('请求失败，状态码: ${response.statusCode}，重试中...');
            retryCount++;
            await Future.delayed(Duration(seconds: 2));
          }
        } catch (e) {
          Logger.warn('连接失败: $e，重试中...');
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }

      if (retryCount >= maxRetries || response == null) {
        Logger.error('经过$retryCount次尝试后仍然无法下载配置');
        // 根据错误类型提供更具体的错误信息
        if (retryCount >= maxRetries) {
          throw Exception(
            '无法下载订阅配置，可能是网络问题或服务器配置问题。请检查：\n1. 网络连接是否正常\n2. 订阅链接是否有效\n3. 服务器TLS证书是否有效',
          );
        } else {
          throw Exception('无法下载订阅配置，请检查网络连接或订阅URL是否有效');
        }
      }

      if (response.statusCode != 200) {
        Logger.error('下载配置失败，状态码: ${response.statusCode}');
        throw Exception('下载配置失败，状态码: ${response.statusCode}');
      }

      // 解析配置
      Logger.info('解析订阅配置');
      final config = response.body;

      // 验证配置是否为有效的YAML格式
      if (!_isValidYaml(config)) {
        Logger.error('配置不是有效的YAML格式');
        // 尝试Base64解码
        try {
          final decoded = utf8.decode(base64Decode(config));
          if (_isValidYaml(decoded)) {
            Logger.info('配置是Base64编码的YAML，已解码');
            _currentConfig = decoded;
          } else {
            throw Exception('配置不是有效的YAML格式');
          }
        } catch (e) {
          Logger.error('配置解码失败: $e');
          throw Exception('配置不是有效的YAML格式且无法解码');
        }
      } else {
        _currentConfig = config;
      }

      // 保存配置文件到临时目录
      final tempDir = await Directory.systemTemp.createTemp('clash_config');
      final configFile = File(path.join(tempDir.path, 'config.yaml'));
      await configFile.writeAsString(_currentConfig!);

      // 保存配置文件路径
      _configPath = configFile.path;

      // 启动Clash
      Logger.info('启动Clash服务');
      final success = await startWithConfig(_configPath!);

      if (success) {
        _isConnected = true;
        Logger.info('Clash服务启动成功');
      } else {
        _isConnected = false;
        Logger.error('Clash服务启动失败');
      }

      return success;
    } on SocketException catch (e) {
      Logger.error('网络连接错误: $e');
      throw Exception('网络连接错误，请检查网络连接或订阅URL是否有效');
    } on TlsException catch (e) {
      Logger.error('TLS/SSL错误: $e');
      throw Exception('TLS/SSL连接错误，可能是服务器证书配置问题。错误信息: ${e.message}');
    } on HandshakeException catch (e) {
      Logger.error('TLS握手错误: $e');
      throw Exception('TLS握手失败，服务器可能配置有误。错误信息: ${e.message}');
    } catch (e, stackTrace) {
      Logger.error('通过订阅启动Clash失败: $e\nStack trace: $stackTrace');
      _isConnected = false;
      rethrow;
    }
  }

  // 验证YAML格式的简单检查
  bool _isValidYaml(String content) {
    // 简单检查是否包含YAML的基本特征
    return content.trim().startsWith('{') ||
        content.trim().startsWith('proxies:') ||
        content.trim().startsWith('Proxy:') ||
        content.contains(':') ||
        content.contains('\n');
  }

  // 启动Clash核心
  Future<bool> _startClash(String config) async {
    try {
      Logger.info('发送配置到Clash核心');

      // 这里应该实现与Clash核心的通信逻辑
      // 暂时返回true模拟成功
      return true;
    } catch (e) {
      Logger.error('启动Clash核心失败: $e');
      return false;
    }
  }

  // 停止Clash
  Future<void> stop() async {
    Logger.info('停止Clash服务');
    _isConnected = false;
    _currentConfig = null;

    // 停止Clash进程
    if (_process != null) {
      _process!.kill();
      _process = null;
    }
  }

  // 更新订阅
  Future<bool> updateSubscription(String subscriptionUrl) async {
    Logger.info('更新Clash订阅: $subscriptionUrl');
    try {
      // 下载新的配置文件
      final response = await http
          .get(Uri.parse(subscriptionUrl))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              Logger.error('下载Clash订阅配置超时');
              throw Exception('下载Clash订阅配置超时，请稍后重试');
            },
          );

      // 检查HTTP响应状态码
      if (response.statusCode >= 300) {
        Logger.error('下载Clash订阅配置失败: ${response.statusCode}');
        if (response.statusCode == 404) {
          throw Exception('订阅链接不存在，请检查链接是否正确');
        } else if (response.statusCode == 403) {
          throw Exception('访问被拒绝，请检查订阅链接权限');
        } else {
          throw Exception('下载Clash订阅配置失败: HTTP ${response.statusCode}');
        }
      }

      // 检查响应内容是否为空
      if (response.body.isEmpty) {
        Logger.error('下载Clash订阅配置失败: 响应内容为空');
        throw Exception('下载Clash订阅配置失败: 响应内容为空');
      }

      // 解析配置
      Logger.info('解析Clash订阅配置');
      String config = response.body;

      // 检查配置内容类型
      if (_isProxyLinkList(config)) {
        // 如果是代理链接列表，转换为Clash配置格式
        Logger.info('检测到代理链接列表，正在转换为Clash配置格式');
        config = _convertProxyLinksToClashConfig(config);
      } else {
        // 验证配置是否为有效的YAML格式
        if (!_isValidYaml(config)) {
          Logger.error('配置不是有效的YAML格式');
          // 尝试Base64解码
          try {
            Logger.info('尝试Base64解码配置');
            final decoded = utf8.decode(base64Decode(config));
            // 检查解码后的内容是否为代理链接列表
            if (_isProxyLinkList(decoded)) {
              Logger.info('解码后检测到代理链接列表，正在转换为Clash配置格式');
              config = _convertProxyLinksToClashConfig(decoded);
            } else if (_isValidYaml(decoded)) {
              Logger.info('配置是Base64编码的YAML，已解码');
              config = decoded;
            } else {
              Logger.error('解码后的配置仍不是有效的YAML格式');
              throw Exception('配置不是有效的YAML格式');
            }
          } catch (decodeError) {
            Logger.error('配置解码失败: $decodeError');
            throw Exception('配置不是有效的YAML格式且无法解码: $decodeError');
          }
        }
      }

      // 保存配置到现有配置文件或创建新文件
      if (_configPath != null) {
        // 保存到现有配置文件
        final configFile = File(_configPath!);
        await configFile.writeAsString(config);
        Logger.info('Clash配置已更新到: ${_configPath!}');
      } else {
        // 创建临时配置文件
        final tempDir = await Directory.systemTemp.createTemp('clash_config');
        final configFile = File(path.join(tempDir.path, 'config.yaml'));
        await configFile.writeAsString(config);
        _configPath = configFile.path;
        Logger.info('Clash配置已保存到临时文件: ${_configPath!}');
      }

      // 如果Clash正在运行，重新启动它以应用新配置
      if (_isConnected && _process != null) {
        Logger.info('Clash正在运行，重新启动以应用新配置');
        await stop();
        final result = await startWithConfig(_configPath!);
        if (!result) {
          Logger.error('Clash重新启动失败');
          throw Exception('Clash重新启动失败');
        }
        return result;
      }

      Logger.info('Clash订阅更新成功');
      return true;
    } on SocketException catch (e) {
      Logger.error('网络连接错误: $e');
      throw Exception('网络连接错误，请检查网络连接');
    } on TlsException catch (e) {
      Logger.error('TLS/SSL错误: $e');
      throw Exception('TLS/SSL连接错误，请检查服务器证书');
    } on HandshakeException catch (e) {
      Logger.error('TLS握手错误: $e');
      throw Exception('TLS握手失败，请检查服务器配置');
    } catch (e, stackTrace) {
      Logger.error('更新Clash订阅失败: $e\nStack trace: $stackTrace');
      // 修复：确保返回false而不是重新抛出异常，以避免UI层处理复杂化
      return false;
    }
  }

  // 检查是否为代理链接列表
  bool _isProxyLinkList(String content) {
    // 检查是否包含代理链接（ss://, vmess://, trojan://等）
    return content.contains('ss://') ||
        content.contains('vmess://') ||
        content.contains('trojan://') ||
        content.contains('vless://');
  }

  // 将代理链接列表转换为Clash配置格式
  String _convertProxyLinksToClashConfig(String linksContent) {
    Logger.info('开始转换代理链接列表为Clash配置');

    final lines = linksContent.split('\n');
    final proxies = <Map<String, dynamic>>[];

    Logger.info('总行数: ${lines.length}');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        Logger.debug('跳过空行: $i');
        continue;
      }

      try {
        if (trimmedLine.startsWith('ss://')) {
          Logger.debug('解析第${i + 1}行Shadowsocks链接');
          final proxy = _parseShadowsocksLink(trimmedLine);
          if (proxy != null) {
            proxies.add(proxy);
            Logger.debug('成功解析Shadowsocks代理: ${proxy['name']}');
          } else {
            Logger.warn('Shadowsocks链接解析失败: $trimmedLine');
          }
        } else if (trimmedLine.startsWith('vmess://')) {
          Logger.debug('解析第${i + 1}行Vmess链接');
          final proxy = _parseVmessLink(trimmedLine);
          if (proxy != null) {
            proxies.add(proxy);
            Logger.debug('成功解析Vmess代理: ${proxy['name']}');
          } else {
            Logger.warn('Vmess链接解析失败: $trimmedLine');
          }
        } else if (trimmedLine.startsWith('trojan://')) {
          Logger.debug('解析第${i + 1}行Trojan链接');
          final proxy = _parseTrojanLink(trimmedLine);
          if (proxy != null) {
            proxies.add(proxy);
            Logger.debug('成功解析Trojan代理: ${proxy['name']}');
          } else {
            Logger.warn('Trojan链接解析失败: $trimmedLine');
          }
        } else if (trimmedLine.startsWith('vless://')) {
          Logger.debug('解析第${i + 1}行Vless链接');
          final proxy = _parseVlessLink(trimmedLine);
          if (proxy != null) {
            proxies.add(proxy);
            Logger.debug('成功解析Vless代理: ${proxy['name']}');
          } else {
            Logger.warn('Vless链接解析失败: $trimmedLine');
          }
        } else {
          Logger.warn('第${i + 1}行未知协议链接: $trimmedLine');
        }
      } catch (e) {
        Logger.warn('解析第${i + 1}行代理链接时出错: $e, 链接: $trimmedLine');
      }
    }

    Logger.info('成功解析 ${proxies.length} 个代理');

    // 生成Clash配置
    final yamlConfig = StringBuffer();
    yamlConfig.writeln('proxies:');

    for (int i = 0; i < proxies.length; i++) {
      final proxy = proxies[i];
      yamlConfig.writeln('  - {');
      yamlConfig.writeln('      name: "${proxy['name']}",');
      yamlConfig.writeln('      type: ${proxy['type']},');
      yamlConfig.writeln('      server: ${proxy['server']},');
      yamlConfig.writeln('      port: ${proxy['port']},');

      // 添加协议特定的配置
      proxy.forEach((key, value) {
        if (key != 'name' &&
            key != 'type' &&
            key != 'server' &&
            key != 'port') {
          if (value is String) {
            yamlConfig.writeln('      $key: "$value",');
          } else {
            yamlConfig.writeln('      $key: $value,');
          }
        }
      });

      yamlConfig.writeln('    }');
    }

    // 添加基本的代理组配置
    yamlConfig.writeln('proxy-groups:');
    yamlConfig.writeln('  - name: "Proxy"');
    yamlConfig.writeln('    type: select');
    yamlConfig.writeln('    proxies:');
    for (final proxy in proxies) {
      yamlConfig.writeln('      - "${proxy['name']}"');
    }

    // 添加基本规则
    yamlConfig.writeln('rules:');
    yamlConfig.writeln('  - MATCH,Proxy');

    final result = yamlConfig.toString();
    Logger.info('生成的Clash配置长度: ${result.length}');
    return result;
  }

  // 解析Shadowsocks链接
  Map<String, dynamic>? _parseShadowsocksLink(String link) {
    try {
      // ss://base64encode(method:password)@server:port#name
      final uri = Uri.parse(link);
      final host = uri.host;
      final port = uri.port;

      // 解码用户信息
      final userInfo = uri.userInfo;
      String method, password;

      if (userInfo.contains(':')) {
        // 直接的method:password格式
        final parts = userInfo.split(':');
        method = parts[0];
        password = parts[1];
      } else {
        // Base64编码的格式
        // 修复Base64长度问题：确保长度是4的倍数
        String paddedUserInfo = userInfo;
        final padding = 4 - (userInfo.length % 4);
        if (padding != 4) {
          paddedUserInfo += '=' * padding;
        }

        try {
          final decoded = utf8.decode(base64Decode(paddedUserInfo));
          final parts = decoded.split(':');
          if (parts.length >= 2) {
            method = parts[0];
            password = parts[1];
          } else {
            Logger.error('Shadowsocks链接格式不正确，解码后: $decoded');
            return null;
          }
        } catch (decodeError) {
          Logger.error('Shadowsocks Base64解码失败: $decodeError, 链接: $link');
          return null;
        }
      }

      final name = uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : '$host:$port';

      return {
        'name': name,
        'type': 'ss',
        'server': host,
        'port': port,
        'cipher': method,
        'password': password,
      };
    } catch (e) {
      Logger.error('解析Shadowsocks链接失败: $e, 链接: $link');
      return null;
    }
  }

  // 解析Vmess链接
  Map<String, dynamic>? _parseVmessLink(String link) {
    try {
      // vmess://base64encode(json)
      final base64Part = link.substring(8); // 移除 "vmess://" 前缀
      // 修复Base64长度问题：确保长度是4的倍数
      String paddedBase64 = base64Part;
      final padding = 4 - (base64Part.length % 4);
      if (padding != 4) {
        paddedBase64 += '=' * padding;
      }

      final jsonStr = utf8.decode(base64Decode(paddedBase64));
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      final name = data['ps'] ?? '${data['add']}:${data['port']}';

      return {
        'name': name,
        'type': 'vmess',
        'server': data['add'],
        'port': data['port'],
        'uuid': data['id'],
        'alterId': data['aid'] ?? 0,
        'cipher': data['scy'] ?? 'auto',
        'network': data['net'] ?? 'tcp',
        'tls': data['tls'] == 'tls',
      };
    } catch (e) {
      Logger.error('解析Vmess链接失败: $e, 链接: $link');
      return null;
    }
  }

  // 解析Trojan链接
  Map<String, dynamic>? _parseTrojanLink(String link) {
    try {
      // trojan://password@server:port#name
      final uri = Uri.parse(link);
      final host = uri.host;
      final port = uri.port;
      final password = uri.userInfo;
      final name = uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : '$host:$port';

      return {
        'name': name,
        'type': 'trojan',
        'server': host,
        'port': port,
        'password': password,
      };
    } catch (e) {
      Logger.error('解析Trojan链接失败: $e, 链接: $link');
      return null;
    }
  }

  // 解析Vless链接
  Map<String, dynamic>? _parseVlessLink(String link) {
    try {
      // vless://uuid@server:port?parameters#name
      final uri = Uri.parse(link);
      final host = uri.host;
      final port = uri.port;
      final uuid = uri.userInfo;
      final name = uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : '$host:$port';

      // 解析查询参数
      final queryParameters = uri.queryParameters;

      final result = {
        'name': name,
        'type': 'vless',
        'server': host,
        'port': port,
        'uuid': uuid,
      };

      // 添加网络类型
      if (queryParameters.containsKey('type')) {
        result['network'] = queryParameters['type'] as String;
      }

      // 添加TLS设置
      if (queryParameters.containsKey('security')) {
        result['tls'] = queryParameters['security'] == 'tls';
      }

      return result;
    } catch (e) {
      Logger.error('解析Vless链接失败: $e, 链接: $link');
      return null;
    }
  }

  // 获取状态
  Future<Map<String, dynamic>?> getStatus() async {
    Logger.info('获取Clash状态');
    try {
      // 这里应该实现获取状态的逻辑
      // 暂时返回模拟数据
      return {'connected': _isConnected, 'config': _currentConfig != null};
    } catch (e) {
      Logger.error('获取Clash状态失败: $e');
      return null;
    }
  }

  // 获取代理列表
  Future<Map<String, dynamic>?> getProxies() async {
    Logger.info('获取Clash代理列表');
    try {
      // 检查是否有配置文件路径
      if (_configPath == null) {
        Logger.warn('没有找到Clash配置文件路径');
        return {'proxies': <String, dynamic>{}};
      }

      // 读取配置文件
      final configFile = File(_configPath!);
      if (!await configFile.exists()) {
        Logger.error('Clash配置文件不存在: ${_configPath!}');
        return {'proxies': <String, dynamic>{}};
      }

      final configContent = await configFile.readAsString();

      // 解析YAML配置文件以提取代理列表
      final proxies = _parseProxiesFromYaml(configContent);

      return {'proxies': proxies, 'connected': _isConnected};
    } catch (e) {
      Logger.error('获取Clash代理列表失败: $e');
      return {'proxies': <String, dynamic>{}};
    }
  }

  // 从YAML配置中解析代理列表
  Map<String, dynamic> _parseProxiesFromYaml(String yamlContent) {
    final proxies = <String, dynamic>{};

    try {
      // 使用正则表达式解析YAML格式的代理列表
      final proxyPattern = RegExp(
        r'-\s*\{\s*name:\s*"([^"]+)"[^}]*type:\s*([a-zA-Z0-9]+)[^}]*\}',
        multiLine: true,
        dotAll: true,
      );

      final matches = proxyPattern.allMatches(yamlContent);

      for (final match in matches) {
        if (match.groupCount >= 2) {
          final name = match.group(1)?.trim() ?? '';
          final type = match.group(2)?.trim() ?? 'unknown';

          if (name.isNotEmpty) {
            proxies[name] = {'type': type, 'name': name};
          }
        }
      }

      Logger.info('成功解析 ${proxies.length} 个代理');

      // 如果正则表达式解析失败，尝试简单的行解析
      if (proxies.isEmpty) {
        Logger.info('正则表达式解析未找到代理，尝试行解析');
        final lines = yamlContent.split('\n');
        bool inProxiesSection = false;

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();

          // 检查是否进入proxies部分
          if (line == 'proxies:') {
            inProxiesSection = true;
            continue;
          }

          // 如果在proxies部分且遇到下一个顶级部分，则退出
          if (inProxiesSection &&
              (line.startsWith('proxy-groups:') ||
                  line.startsWith('rules:') ||
                  line.startsWith('mode:'))) {
            break;
          }

          // 解析代理项
          if (inProxiesSection && line.startsWith('- {')) {
            // 查找完整的代理定义（可能跨越多行）
            String proxyDefinition = line;
            int j = i + 1;
            while (j < lines.length &&
                !lines[j].trim().startsWith('-') &&
                !lines[j].trim().startsWith('}') &&
                !lines[j].trim().startsWith('proxy-groups:') &&
                !lines[j].trim().startsWith('rules:')) {
              proxyDefinition += ' ' + lines[j].trim();
              j++;
            }

            // 解析代理名称和类型
            final nameMatch = RegExp(
              r'name:\s*"([^"]+)"',
            ).firstMatch(proxyDefinition);
            final typeMatch = RegExp(
              r'type:\s*([a-zA-Z0-9]+)',
            ).firstMatch(proxyDefinition);

            if (nameMatch != null && typeMatch != null) {
              final name = nameMatch.group(1)?.trim() ?? '';
              final type = typeMatch.group(1)?.trim() ?? 'unknown';

              if (name.isNotEmpty) {
                proxies[name] = {'type': type, 'name': name};
              }
            }
          }
        }

        Logger.info('行解析找到 ${proxies.length} 个代理');
      }
    } catch (e) {
      Logger.error('解析YAML代理列表失败: $e');
    }

    return proxies;
  }

  // 选择代理
  Future<bool> selectProxy(String selector, String proxyName) async {
    Logger.info('选择Clash代理: $selector -> $proxyName');
    try {
      // 这里应该实现选择代理的逻辑
      // 暂时返回true模拟成功
      return true;
    } catch (e) {
      Logger.error('选择Clash代理失败: $e');
      return false;
    }
  }
}
