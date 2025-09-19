import 'dart:io';
import 'package:dualvpn_manager/utils/logger.dart';

/// 系统代理管理器
/// 负责在不同操作系统上设置和清除系统代理
class SystemProxyManager {
  static final SystemProxyManager _instance = SystemProxyManager._internal();
  factory SystemProxyManager() => _instance;
  SystemProxyManager._internal();

  /// 设置系统代理
  Future<bool> setSystemProxy(String host, int httpPort, int socksPort) async {
    Logger.info(
      'setSystemProxy called: host=$host, httpPort=$httpPort, socksPort=$socksPort',
    );
    try {
      if (Platform.isMacOS) {
        Logger.info('检测到macOS系统，调用_macOSProxy设置');
        return await _setMacOSProxy(host, httpPort, socksPort);
      } else if (Platform.isWindows) {
        Logger.info('检测到Windows系统，调用_windowsProxy设置');
        return await _setWindowsProxy(host, httpPort, socksPort);
      } else if (Platform.isLinux) {
        Logger.info('检测到Linux系统，调用_linuxProxy设置');
        return await _setLinuxProxy(host, httpPort, socksPort);
      } else {
        Logger.error('不支持的操作系统平台');
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('设置系统代理失败: $e\nStack trace: $stackTrace');
      return false;
    }
  }

  /// 清除系统代理
  Future<bool> clearSystemProxy() async {
    Logger.info('clearSystemProxy called');
    try {
      if (Platform.isMacOS) {
        Logger.info('检测到macOS系统，调用_macOSProxy清除');
        return await _clearMacOSProxy();
      } else if (Platform.isWindows) {
        Logger.info('检测到Windows系统，调用_windowsProxy清除');
        return await _clearWindowsProxy();
      } else if (Platform.isLinux) {
        Logger.info('检测到Linux系统，调用_linuxProxy清除');
        return await _clearLinuxProxy();
      } else {
        Logger.error('不支持的操作系统平台');
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('清除系统代理失败: $e\nStack trace: $stackTrace');
      return false;
    }
  }

  /// 设置macOS系统代理
  Future<bool> _setMacOSProxy(String host, int httpPort, int socksPort) async {
    Logger.info(
      '_setMacOSProxy called: host=$host, httpPort=$httpPort, socksPort=$socksPort',
    );
    try {
      // 设置HTTP代理
      Logger.info('设置HTTP代理: networksetup -setwebproxy Wi-Fi $host $httpPort');
      final httpResult = await Process.run('networksetup', [
        '-setwebproxy',
        'Wi-Fi',
        host,
        '$httpPort',
      ]);

      Logger.info(
        'HTTP代理设置结果: exitCode=${httpResult.exitCode}, stdout=${httpResult.stdout}, stderr=${httpResult.stderr}',
      );
      if (httpResult.exitCode != 0) {
        Logger.error('设置HTTP代理失败: ${httpResult.stderr}');
        return false;
      }

      // 设置HTTPS代理
      Logger.info(
        '设置HTTPS代理: networksetup -setsecurewebproxy Wi-Fi $host $httpPort',
      );
      final httpsResult = await Process.run('networksetup', [
        '-setsecurewebproxy',
        'Wi-Fi',
        host,
        '$httpPort',
      ]);

      Logger.info(
        'HTTPS代理设置结果: exitCode=${httpsResult.exitCode}, stdout=${httpsResult.stdout}, stderr=${httpsResult.stderr}',
      );
      if (httpsResult.exitCode != 0) {
        Logger.error('设置HTTPS代理失败: ${httpsResult.stderr}');
        return false;
      }

      // 设置SOCKS代理
      Logger.info(
        '设置SOCKS代理: networksetup -setsocksfirewallproxy Wi-Fi $host $socksPort',
      );
      final socksResult = await Process.run('networksetup', [
        '-setsocksfirewallproxy',
        'Wi-Fi',
        host,
        '$socksPort',
      ]);

      Logger.info(
        'SOCKS代理设置结果: exitCode=${socksResult.exitCode}, stdout=${socksResult.stdout}, stderr=${socksResult.stderr}',
      );
      if (socksResult.exitCode != 0) {
        Logger.error('设置SOCKS代理失败: ${socksResult.stderr}');
        return false;
      }

      // 启用HTTP代理
      Logger.info('启用HTTP代理: networksetup -setwebproxystate Wi-Fi on');
      final enableHttpResult = await Process.run('networksetup', [
        '-setwebproxystate',
        'Wi-Fi',
        'on',
      ]);

      Logger.info(
        '启用HTTP代理结果: exitCode=${enableHttpResult.exitCode}, stdout=${enableHttpResult.stdout}, stderr=${enableHttpResult.stderr}',
      );
      if (enableHttpResult.exitCode != 0) {
        Logger.error('启用HTTP代理失败: ${enableHttpResult.stderr}');
        return false;
      }

      // 启用HTTPS代理
      Logger.info('启用HTTPS代理: networksetup -setsecurewebproxystate Wi-Fi on');
      final enableHttpsResult = await Process.run('networksetup', [
        '-setsecurewebproxystate',
        'Wi-Fi',
        'on',
      ]);

      Logger.info(
        '启用HTTPS代理结果: exitCode=${enableHttpsResult.exitCode}, stdout=${enableHttpsResult.stdout}, stderr=${enableHttpsResult.stderr}',
      );
      if (enableHttpsResult.exitCode != 0) {
        Logger.error('启用HTTPS代理失败: ${enableHttpsResult.stderr}');
        return false;
      }

      // 启用SOCKS代理
      Logger.info(
        '启用SOCKS代理: networksetup -setsocksfirewallproxystate Wi-Fi on',
      );
      final enableSocksResult = await Process.run('networksetup', [
        '-setsocksfirewallproxystate',
        'Wi-Fi',
        'on',
      ]);

      Logger.info(
        '启用SOCKS代理结果: exitCode=${enableSocksResult.exitCode}, stdout=${enableSocksResult.stdout}, stderr=${enableSocksResult.stderr}',
      );
      if (enableSocksResult.exitCode != 0) {
        Logger.error('启用SOCKS代理失败: ${enableSocksResult.stderr}');
        return false;
      }

      Logger.info('macOS系统代理设置成功');
      return true;
    } catch (e, stackTrace) {
      Logger.error('设置macOS系统代理失败: $e\nStack trace: $stackTrace');
      return false;
    }
  }

  /// 清除macOS系统代理
  Future<bool> _clearMacOSProxy() async {
    Logger.info('_clearMacOSProxy called');
    try {
      // 禁用HTTP代理
      Logger.info('禁用HTTP代理: networksetup -setwebproxystate Wi-Fi off');
      final disableHttpResult = await Process.run('networksetup', [
        '-setwebproxystate',
        'Wi-Fi',
        'off',
      ]);

      Logger.info(
        '禁用HTTP代理结果: exitCode=${disableHttpResult.exitCode}, stdout=${disableHttpResult.stdout}, stderr=${disableHttpResult.stderr}',
      );
      if (disableHttpResult.exitCode != 0) {
        Logger.error('禁用HTTP代理失败: ${disableHttpResult.stderr}');
        return false;
      }

      // 禔用HTTPS代理
      Logger.info('禁用HTTPS代理: networksetup -setsecurewebproxystate Wi-Fi off');
      final disableHttpsResult = await Process.run('networksetup', [
        '-setsecurewebproxystate',
        'Wi-Fi',
        'off',
      ]);

      Logger.info(
        '禁用HTTPS代理结果: exitCode=${disableHttpsResult.exitCode}, stdout=${disableHttpsResult.stdout}, stderr=${disableHttpsResult.stderr}',
      );
      if (disableHttpsResult.exitCode != 0) {
        Logger.error('禁用HTTPS代理失败: ${disableHttpsResult.stderr}');
        return false;
      }

      // 禔用SOCKS代理
      Logger.info(
        '禁用SOCKS代理: networksetup -setsocksfirewallproxystate Wi-Fi off',
      );
      final disableSocksResult = await Process.run('networksetup', [
        '-setsocksfirewallproxystate',
        'Wi-Fi',
        'off',
      ]);

      Logger.info(
        '禁用SOCKS代理结果: exitCode=${disableSocksResult.exitCode}, stdout=${disableSocksResult.stdout}, stderr=${disableSocksResult.stderr}',
      );
      if (disableSocksResult.exitCode != 0) {
        Logger.error('禁用SOCKS代理失败: ${disableSocksResult.stderr}');
        return false;
      }

      Logger.info('macOS系统代理清除成功');
      return true;
    } catch (e, stackTrace) {
      Logger.error('清除macOS系统代理失败: $e\nStack trace: $stackTrace');
      return false;
    }
  }

  /// 设置Windows系统代理
  Future<bool> _setWindowsProxy(
    String host,
    int httpPort,
    int socksPort,
  ) async {
    try {
      final regPath =
          'HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings';

      // 启用代理
      final enableResult = await Process.run('reg', [
        'add',
        regPath,
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '1',
        '/f',
      ]);

      if (enableResult.exitCode != 0) {
        Logger.error('启用Windows代理失败: ${enableResult.stderr}');
        return false;
      }

      // 设置代理服务器
      final serverResult = await Process.run('reg', [
        'add',
        regPath,
        '/v',
        'ProxyServer',
        '/t',
        'REG_SZ',
        '/d',
        '$host:$httpPort',
        '/f',
      ]);

      if (serverResult.exitCode != 0) {
        Logger.error('设置Windows HTTP代理服务器失败: ${serverResult.stderr}');
        return false;
      }

      // 设置SOCKS代理服务器
      final socksResult = await Process.run('reg', [
        'add',
        regPath,
        '/v',
        'ProxyOverride',
        '/t',
        'REG_SZ',
        '/d',
        'localhost;127.0.0.1',
        '/f',
      ]);

      if (socksResult.exitCode != 0) {
        Logger.error('设置Windows SOCKS代理失败: ${socksResult.stderr}');
        return false;
      }

      Logger.info('Windows系统代理设置成功');
      return true;
    } catch (e) {
      Logger.error('设置Windows系统代理失败: $e');
      return false;
    }
  }

  /// 清除Windows系统代理
  Future<bool> _clearWindowsProxy() async {
    try {
      final regPath =
          'HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings';

      // 禔用代理
      final disableResult = await Process.run('reg', [
        'add',
        regPath,
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '0',
        '/f',
      ]);

      if (disableResult.exitCode != 0) {
        Logger.error('禁用Windows代理失败: ${disableResult.stderr}');
        return false;
      }

      Logger.info('Windows系统代理清除成功');
      return true;
    } catch (e) {
      Logger.error('清除Windows系统代理失败: $e');
      return false;
    }
  }

  /// 设置Linux系统代理
  Future<bool> _setLinuxProxy(String host, int httpPort, int socksPort) async {
    try {
      // 设置代理模式为manual
      final modeResult = await Process.run('gsettings', [
        'set',
        'org.gnome.system.proxy',
        'mode',
        'manual',
      ]);

      if (modeResult.exitCode != 0) {
        Logger.error('设置Linux代理模式失败: ${modeResult.stderr}');
        return false;
      }

      // 设置HTTP代理主机
      final httpHostResult = await Process.run('gsettings', [
        'set',
        'org.gnome.system.proxy.http',
        'host',
        host,
      ]);

      if (httpHostResult.exitCode != 0) {
        Logger.error('设置Linux HTTP代理主机失败: ${httpHostResult.stderr}');
        return false;
      }

      // 设置HTTP代理端口
      final httpPortResult = await Process.run('gsettings', [
        'set',
        'org.gnome.system.proxy.http',
        'port',
        '$httpPort',
      ]);

      if (httpPortResult.exitCode != 0) {
        Logger.error('设置Linux HTTP代理端口失败: ${httpPortResult.stderr}');
        return false;
      }

      // 设置HTTPS代理主机
      final httpsHostResult = await Process.run('gsettings', [
        'set',
        'org.gnome.system.proxy.https',
        'host',
        host,
      ]);

      if (httpsHostResult.exitCode != 0) {
        Logger.error('设置Linux HTTPS代理主机失败: ${httpsHostResult.stderr}');
        return false;
      }

      // 设置HTTPS代理端口
      final httpsPortResult = await Process.run('gsettings', [
        'set',
        'org.gnome.system.proxy.https',
        'port',
        '$httpPort',
      ]);

      if (httpsPortResult.exitCode != 0) {
        Logger.error('设置Linux HTTPS代理端口失败: ${httpsPortResult.stderr}');
        return false;
      }

      // 设置SOCKS代理主机
      final socksHostResult = await Process.run('gsettings', [
        'set',
        'org.gnome.system.proxy.socks',
        'host',
        host,
      ]);

      if (socksHostResult.exitCode != 0) {
        Logger.error('设置Linux SOCKS代理主机失败: ${socksHostResult.stderr}');
        return false;
      }

      // 设置SOCKS代理端口
      final socksPortResult = await Process.run('gsettings', [
        'set',
        'org.gnome.system.proxy.socks',
        'port',
        '$socksPort',
      ]);

      if (socksPortResult.exitCode != 0) {
        Logger.error('设置Linux SOCKS代理端口失败: ${socksPortResult.stderr}');
        return false;
      }

      Logger.info('Linux系统代理设置成功');
      return true;
    } catch (e) {
      Logger.error('设置Linux系统代理失败: $e');
      return false;
    }
  }

  /// 清除Linux系统代理
  Future<bool> _clearLinuxProxy() async {
    try {
      // 设置代理模式为none
      final modeResult = await Process.run('gsettings', [
        'set',
        'org.gnome.system.proxy',
        'mode',
        'none',
      ]);

      if (modeResult.exitCode != 0) {
        Logger.error('清除Linux代理模式失败: ${modeResult.stderr}');
        return false;
      }

      Logger.info('Linux系统代理清除成功');
      return true;
    } catch (e) {
      Logger.error('清除Linux系统代理失败: $e');
      return false;
    }
  }
}
