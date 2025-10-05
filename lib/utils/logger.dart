import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class Logger {
  static const bool _isDebugMode = kDebugMode;
  static File? _logFile;
  // 添加日志过滤功能
  static String? _filterHost;

  // 设置日志过滤主机名
  static void setFilterHost(String? host) {
    _filterHost = host;
  }

  // 检查消息是否应该被过滤
  static bool _shouldLog(String message) {
    // 如果没有设置过滤器，记录所有消息
    if (_filterHost == null || _filterHost!.isEmpty) {
      return true;
    }

    // 如果设置了过滤器，只记录包含指定主机名的消息
    return message.contains(_filterHost!);
  }

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
    // 添加调试输出以确认此方法被调用
    debugPrint('尝试写入日志文件: [$level] $message');

    // 检查是否应该记录此消息
    if (!_shouldLog(message)) {
      debugPrint('消息被过滤器阻止');
      return;
    }

    await _initLogFile();
    if (_logFile == null) {
      debugPrint('日志文件未初始化');
      return;
    }

    try {
      final now = DateTime.now();
      final timestamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final logMessage = '[$timestamp] [$level] $message\n';
      await _logFile!.writeAsString(logMessage, mode: FileMode.writeOnlyAppend);
      debugPrint('成功写入日志文件');
    } catch (e) {
      // 如果写入文件失败，忽略错误
      if (_isDebugMode) {
        debugPrint('写入日志文件失败: $e');
      }
    }
  }

  static void debug(String message) {
    // 检查是否应该记录此消息
    if (!_shouldLog(message)) {
      return;
    }

    if (_isDebugMode) {
      // 在调试模式下输出日志
      debugPrint('[DEBUG] $message');
      _writeToFile('DEBUG', message);
    }
  }

  static void info(String message) {
    // 检查是否应该记录此消息
    if (!_shouldLog(message)) {
      return;
    }

    // 信息日志
    debugPrint('[INFO] $message');
    _writeToFile('INFO', message);
  }

  static void error(String message) {
    // 检查是否应该记录此消息
    if (!_shouldLog(message)) {
      return;
    }

    // 错误日志
    debugPrint('[ERROR] $message');
    _writeToFile('ERROR', message);
  }

  static void warn(String message) {
    // 检查是否应该记录此消息
    if (!_shouldLog(message)) {
      return;
    }

    // 警告日志
    debugPrint('[WARN] $message');
    _writeToFile('WARN', message);
  }
}
