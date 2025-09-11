import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class Logger {
  static const bool _isDebugMode = kDebugMode;
  static File? _logFile;

  static Future<void> _initLogFile() async {
    if (_logFile != null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory(path.join(directory.path, 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final now = DateTime.now();
      final fileName =
          'dualvpn_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.log';
      _logFile = File(path.join(logDir.path, fileName));
    } catch (e) {
      // 如果无法创建日志文件，继续使用控制台输出
      if (_isDebugMode) {
        debugPrint('无法初始化日志文件: $e');
      }
    }
  }

  static Future<void> _writeToFile(String level, String message) async {
    // 在测试环境中不写入文件
    if (!_isDebugMode) return;

    await _initLogFile();
    if (_logFile == null) return;

    try {
      final now = DateTime.now();
      final timestamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final logMessage = '[$timestamp] [$level] $message\n';
      await _logFile!.writeAsString(logMessage, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // 如果写入文件失败，忽略错误
      if (_isDebugMode) {
        debugPrint('写入日志文件失败: $e');
      }
    }
  }

  static void debug(String message) {
    if (_isDebugMode) {
      // 在调试模式下输出日志
      debugPrint('[DEBUG] $message');
      _writeToFile('DEBUG', message);
    }
  }

  static void info(String message) {
    // 信息日志
    debugPrint('[INFO] $message');
    _writeToFile('INFO', message);
  }

  static void error(String message) {
    // 错误日志
    debugPrint('[ERROR] $message');
    _writeToFile('ERROR', message);
  }

  static void warn(String message) {
    // 警告日志
    debugPrint('[WARN] $message');
    _writeToFile('WARN', message);
  }
}
