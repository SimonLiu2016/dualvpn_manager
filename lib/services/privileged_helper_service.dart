import 'dart:async';
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PrivilegedProcess {
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final Completer<int> _exitCodeCompleter = Completer<int>();

  Stream<List<int>> get stdout => _stdoutController.stream;
  Stream<List<int>> get stderr => _stderrController.stream;
  Future<int> get exitCode => _exitCodeCompleter.future;

  void addLog(String log) {
    // 解析日志（假设 PrivilegedHelper 使用 "stdout: " 和 "stderr: " 前缀）
    if (log.startsWith('stdout: ')) {
      final data = log.substring('stdout: '.length);
      _stdoutController.add(data.codeUnits);
    } else if (log.startsWith('stderr: ')) {
      final data = log.substring('stderr: '.length);
      _stderrController.add(data.codeUnits);
    }
  }

  void complete(int exitCode) {
    _exitCodeCompleter.complete(exitCode);
    _stdoutController.close();
    _stderrController.close();
  }
}

class HelperService {
  static const platform = MethodChannel('dualvpn_manager/macos');
  PrivilegedProcess? _process;

  HelperService() {
    // 设置 MethodChannel 的回调
    platform.setMethodCallHandler((call) async {
      // 不再处理日志回调，因为助手工具直接将日志写入文件
    });
  }

  Future<PrivilegedProcess> runGoProxyCore({
    required String executablePath,
    required String executableDir,
    List<String> arguments = const [],
  }) async {
    try {
      Logger.info('Starting processor for go-proxy-core...');
      _process = PrivilegedProcess();
      Logger.info('Starting go-proxy-core via privileged helper...');

      // 使用异步调用而不是阻塞调用
      unawaited(
        platform
            .invokeMethod('runGoProxyCore', {
              'executablePath': executablePath,
              'executableDir': executableDir,
              'arguments': arguments,
            })
            .then((_) {
              Logger.info('Started go-proxy-core via privileged helper');
            })
            .catchError((error) {
              Logger.error('Failed to start go-proxy-core: $error');
              _process?.complete(-1);
            }),
      );

      return _process!;
    } catch (e) {
      Logger.error('Failed to start go-proxy-core: $e');
      _process?.complete(-1);
      rethrow;
    }
  }

  Future<void> stopGoProxyCore() async {
    try {
      Logger.info('Stopping go-proxy-core via privileged helper...');
      await platform.invokeMethod('stopGoProxyCore');
      Logger.info('Stop command sent to privileged helper');
    } catch (e) {
      Logger.error('Failed to stop go-proxy-core: $e');
      rethrow;
    }
  }
}
