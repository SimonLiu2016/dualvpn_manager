import 'dart:async';
import 'package:flutter/services.dart';

class PrivilegedProcess {
  final StreamController<List<int>> _stdoutController = StreamController<List<int>>();
  final StreamController<List<int>> _stderrController = StreamController<List<int>>();
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
    // 设置 MethodChannel 的日志回调
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onGoProxyCoreLog') {
        final log = call.arguments as String;
        _process?.addLog(log);
      }
    });
  }

  Future<PrivilegedProcess> runGoProxyCore({
    required String executablePath,
    required String executableDir,
    List<String> arguments = const [],
  }) async {
    try {
      _process = PrivilegedProcess();
      final result = await platform.invokeMethod('runGoProxyCore', {
        'executablePath': executablePath,
        'executableDir': executableDir,
        'arguments': arguments,
      });
      if (result as bool) {
        return _process!;
      } else {
        _process?.complete(-1);
        throw Exception('Failed to start go-proxy-core');
      }
    } catch (e) {
      _process?.complete(-1);
      rethrow;
    }
  }
}