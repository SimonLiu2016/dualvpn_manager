import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:dualvpn_manager/utils/logger.dart';

class OpenVPNService {
  Process? _process;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // 连接到OpenVPN
  Future<bool> connect(
    String configPath, {
    String? username,
    String? password,
  }) async {
    try {
      // 检查配置文件是否存在
      final configFile = File(configPath);
      if (!await configFile.exists()) {
        Logger.error('OpenVPN配置文件不存在: $configPath');
        throw Exception('OpenVPN配置文件不存在: $configPath');
      }

      // 检查文件是否可读
      final stat = await configFile.stat();
      if ((stat.mode & 0x4000) == 0) {
        // 0x4000是文件所有者读权限位
        Logger.error('OpenVPN配置文件不可读: $configPath');
        throw Exception('OpenVPN配置文件不可读: $configPath');
      }

      // 检查OpenVPN命令是否可用
      try {
        final result = await Process.run('which', ['openvpn']);
        if (result.exitCode != 0) {
          Logger.error('OpenVPN命令未找到，请确保已安装OpenVPN');
          throw Exception('OpenVPN命令未找到，请确保已安装OpenVPN');
        }
      } catch (e) {
        Logger.error('检查OpenVPN命令失败: $e');
        throw Exception('检查OpenVPN命令失败: $e');
      }

      // 构建OpenVPN命令
      List<String> args = [
        '--config', configPath,
        '--daemon', // 后台运行
      ];

      // 如果提供了用户名和密码，则添加认证参数
      if (username != null && password != null) {
        // 创建临时认证文件
        final tempDir = await Directory.systemTemp.createTemp('openvpn_auth');
        final authFile = File(path.join(tempDir.path, 'auth.txt'));
        await authFile.writeAsString('$username\n$password\n');
        args.addAll(['--auth-user-pass', authFile.path]);
      }

      // 启动OpenVPN进程
      Logger.info('正在启动OpenVPN进程...');
      _process = await Process.start('openvpn', args);

      // 监听进程输出以确定连接状态
      _process!.stdout.listen(
        (data) {
          final output = utf8.decode(data);
          Logger.debug('OpenVPN stdout: $output');
          if (output.contains('Initialization Sequence Completed')) {
            _isConnected = true;
            Logger.info('OpenVPN初始化序列完成');
          }
        },
        onError: (Object error) {
          Logger.error('OpenVPN stdout监听错误: $error');
        },
      );

      _process!.stderr.listen(
        (data) {
          final output = utf8.decode(data);
          Logger.error('OpenVPN stderr: $output');
          if (output.contains('AUTH_FAILED') || output.contains('TLS Error')) {
            _isConnected = false;
            Logger.warn('OpenVPN认证失败或TLS错误');
          }
        },
        onError: (Object error) {
          Logger.error('OpenVPN stderr监听错误: $error');
        },
      );

      // 等待一段时间以确定连接是否成功
      await Future.delayed(const Duration(seconds: 5));

      Logger.info('OpenVPN连接${_isConnected ? '成功' : '可能失败'}');
      return _isConnected;
    } catch (e, stackTrace) {
      Logger.error('OpenVPN连接失败: $e\nStack trace: $stackTrace');
      _isConnected = false;
      rethrow;
    }
  }

  // 断开OpenVPN连接
  Future<void> disconnect() async {
    try {
      if (_process != null) {
        // 尝试优雅地停止OpenVPN
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
      Logger.info('OpenVPN已断开连接');
    } catch (e, stackTrace) {
      Logger.error('断开OpenVPN连接时出错: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }

  // 检查OpenVPN是否正在运行
  Future<bool> checkStatus() async {
    try {
      // 在macOS/Linux上检查OpenVPN进程
      final result = await Process.run('pgrep', ['openvpn']);
      return result.exitCode == 0;
    } catch (e, stackTrace) {
      Logger.error('检查OpenVPN状态时出错: $e\nStack trace: $stackTrace');
      return false;
    }
  }
}
