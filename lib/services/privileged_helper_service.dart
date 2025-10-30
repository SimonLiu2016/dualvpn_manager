import 'dart:async';
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:flutter/services.dart';

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

  /// 调用特权助手处理OpenVPN配置文件
  Future<String?> copyOpenVPNConfigFiles({
    required String configContent,
    required Map<String, String> certFiles,
  }) async {
    try {
      Logger.info('Calling privileged helper to copy OpenVPN config files...');

      final result = await platform.invokeMethod('copyOpenVPNConfigFiles', {
        'configContent': configContent,
        'certFiles': certFiles,
      });

      if (result is Map) {
        final success = result['success'] as bool?;
        final errorMessage = result['errorMessage'] as String?;
        final configPath = result['configPath'] as String?;

        if (success == true && configPath != null) {
          Logger.info(
            'OpenVPN config files copied successfully to: $configPath',
          );
          return configPath;
        } else {
          Logger.error('Failed to copy OpenVPN config files: $errorMessage');
          return null;
        }
      } else {
        Logger.error('Invalid response from privileged helper');
        return null;
      }
    } catch (e) {
      Logger.error('Failed to call copyOpenVPNConfigFiles: $e');
      return null;
    }
  }

  /// 调用特权助手清理日志文件
  Future<bool> cleanupLogs({
    int fileSizeLimit = 10,
    int retentionDays = 7,
  }) async {
    try {
      Logger.info(
        'Calling privileged helper to cleanup log files with fileSizeLimit: $fileSizeLimit MB, retentionDays: $retentionDays',
      );

      final result = await platform.invokeMethod('cleanupLogs', {
        'fileSizeLimit': fileSizeLimit,
        'retentionDays': retentionDays,
      });

      if (result is bool) {
        if (result) {
          Logger.info('Log files cleanup successfully');
          return true;
        } else {
          Logger.error('Failed to cleanup log files');
          return false;
        }
      } else {
        Logger.error('Invalid response from privileged helper');
        return false;
      }
    } catch (e) {
      Logger.error('Failed to call cleanupLogs: $e');
      return false;
    }
  }
}
