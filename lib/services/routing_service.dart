import 'dart:io';
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';

class RoutingService {
  bool _isRoutingActive = false;
  // 存储已添加的路由规则，便于清除
  final List<_RouteRule> _activeRoutes = [];

  bool get isRoutingActive => _isRoutingActive;

  // 配置智能路由规则
  Future<bool> configureRouting({
    required List<String> internalDomains,
    required List<String> externalDomains,
    List<RoutingRule> forcedRules = const [],
  }) async {
    try {
      // 清除现有路由规则
      await _clearRoutingRules();

      // 为内网域名设置路由通过OpenVPN
      for (var domain in internalDomains) {
        await _addRoute(domain, 'internal');
      }

      // 为外网域名设置路由通过Clash
      for (var domain in externalDomains) {
        await _addRoute(domain, 'external');
      }

      // 添加强制路由规则
      for (var rule in forcedRules) {
        if (rule.isEnabled) {
          String routeType;
          switch (rule.routeType) {
            case RouteType.openVPN:
              routeType = 'internal';
              break;
            case RouteType.clash:
              routeType = 'external';
              break;
            case RouteType.shadowsocks:
              routeType = 'shadowsocks';
              break;
            case RouteType.v2ray:
              routeType = 'v2ray';
              break;
            case RouteType.httpProxy:
            case RouteType.socks5:
            case RouteType.custom:
              // 对于HTTP代理、SOCKS5代理和自定义代理，使用外部路由
              routeType = 'external';
              break;
          }
          await _addRoute(rule.pattern, routeType);
        }
      }

      _isRoutingActive = true;
      Logger.info('路由配置成功');
      return true;
    } catch (e) {
      Logger.error('配置路由失败: $e');
      _isRoutingActive = false;
      return false;
    }
  }

  // 添加路由规则
  Future<void> _addRoute(String pattern, String type) async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        // 在macOS/Linux上使用route命令
        String gateway = await _getGatewayForType(type);

        Process process;
        if (Platform.isMacOS) {
          Logger.debug('在macOS上添加路由: route add $pattern $gateway');
          process = await Process.start('route', ['add', pattern, gateway]);
        } else {
          Logger.debug('在Linux上添加路由: ip route add $pattern via $gateway');
          process = await Process.start('ip', [
            'route',
            'add',
            pattern,
            'via',
            gateway,
          ]);
        }

        final exitCode = await process.exitCode;
        if (exitCode == 0) {
          Logger.info('成功添加路由规则: $pattern -> $gateway');
        } else {
          Logger.warn('添加路由规则失败: $pattern -> $gateway (exit code: $exitCode)');
        }

        // 记录已添加的路由规则
        _activeRoutes.add(_RouteRule(pattern, type, gateway));
      } else if (Platform.isWindows) {
        // 在Windows上使用route命令
        String gateway = await _getGatewayForType(type);

        Logger.debug('在Windows上添加路由: route add $pattern $gateway');
        final process = await Process.start('route', ['add', pattern, gateway]);

        final exitCode = await process.exitCode;
        if (exitCode == 0) {
          Logger.info('成功添加路由规则: $pattern -> $gateway');
        } else {
          Logger.warn('添加路由规则失败: $pattern -> $gateway (exit code: $exitCode)');
        }

        // 记录已添加的路由规则
        _activeRoutes.add(_RouteRule(pattern, type, gateway));
      } else {
        Logger.warn('不支持的操作系统平台，无法添加路由规则');
      }
    } catch (e, stackTrace) {
      Logger.error('添加路由规则失败: $e\nStack trace: $stackTrace');
    }
  }

  // 清除路由规则
  Future<void> _clearRoutingRules() async {
    try {
      Logger.info('开始清除路由规则，共${_activeRoutes.length}条');

      // 清除所有已添加的路由规则
      int successCount = 0;
      int failCount = 0;

      for (var rule in _activeRoutes) {
        try {
          if (Platform.isMacOS || Platform.isLinux) {
            Process process;
            if (Platform.isMacOS) {
              Logger.debug('在macOS上删除路由: route delete ${rule.pattern}');
              process = await Process.start('route', ['delete', rule.pattern]);
            } else {
              Logger.debug('在Linux上删除路由: ip route del ${rule.pattern}');
              process = await Process.start('ip', [
                'route',
                'del',
                rule.pattern,
              ]);
            }

            final exitCode = await process.exitCode;
            if (exitCode == 0) {
              successCount++;
              Logger.debug('成功删除路由规则: ${rule.pattern}');
            } else {
              failCount++;
              Logger.warn('删除路由规则失败: ${rule.pattern} (exit code: $exitCode)');
            }
          } else if (Platform.isWindows) {
            Logger.debug('在Windows上删除路由: route delete ${rule.pattern}');
            final process = await Process.start('route', [
              'delete',
              rule.pattern,
            ]);

            final exitCode = await process.exitCode;
            if (exitCode == 0) {
              successCount++;
              Logger.debug('成功删除路由规则: ${rule.pattern}');
            } else {
              failCount++;
              Logger.warn('删除路由规则失败: ${rule.pattern} (exit code: $exitCode)');
            }
          }
        } catch (e) {
          failCount++;
          Logger.error('删除路由规则时出错: ${rule.pattern}, 错误: $e');
        }
      }

      _activeRoutes.clear();
      Logger.info('路由规则清除完成: 成功$successCount条，失败$failCount条');
    } catch (e, stackTrace) {
      Logger.error('清除路由规则失败: $e\nStack trace: $stackTrace');
    }
  }

  // 获取OpenVPN网关
  Future<String> _getOpenVPNGateway() async {
    try {
      // 尝试通过系统命令获取OpenVPN网关
      if (Platform.isMacOS || Platform.isLinux) {
        Logger.debug('尝试通过netstat获取OpenVPN网关');
        final result = await Process.run('netstat', ['-rn']);
        if (result.exitCode == 0) {
          // 解析路由表，查找OpenVPN相关的网关
          final lines = (result.stdout as String).split('\n');
          for (var line in lines) {
            if (line.contains('tun') ||
                line.contains('10.8.0.0') ||
                line.contains('10.')) {
              final parts = line.split(RegExp(r'\s+'));
              if (parts.length > 1) {
                final gateway = parts[1]; // 返回网关地址
                Logger.debug('找到OpenVPN网关: $gateway');
                return gateway;
              }
            }
          }
        } else {
          Logger.warn('执行netstat命令失败，退出码: ${result.exitCode}');
        }
      } else if (Platform.isWindows) {
        Logger.debug('尝试通过route print获取OpenVPN网关');
        final result = await Process.run('route', ['print']);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).split('\n');
          for (var line in lines) {
            if (line.contains('10.8.0.0') || line.contains('10.')) {
              final parts = line.trim().split(RegExp(r'\s+'));
              if (parts.length > 2) {
                final gateway = parts[2]; // 返回网关地址
                Logger.debug('找到OpenVPN网关: $gateway');
                return gateway;
              }
            }
          }
        } else {
          Logger.warn('执行route print命令失败，退出码: ${result.exitCode}');
        }
      }
    } catch (e, stackTrace) {
      Logger.error('获取OpenVPN网关失败: $e\nStack trace: $stackTrace');
    }
    // 如果无法动态获取，则返回默认值
    Logger.warn('无法获取OpenVPN网关，使用默认值: 10.8.0.1');
    return '10.8.0.1';
  }

  // 获取Clash网关
  Future<String> _getClashGateway() async {
    try {
      // Clash通常运行在本地，网关就是本地地址
      // 可以通过Clash API获取更准确的信息
      return '127.0.0.1';
    } catch (e) {
      Logger.error('获取Clash网关失败: $e');
      return '127.0.0.1';
    }
  }

  // 获取Shadowsocks网关
  Future<String> _getShadowsocksGateway() async {
    try {
      // Shadowsocks通常运行在本地，网关就是本地地址
      return '127.0.0.1';
    } catch (e) {
      Logger.error('获取Shadowsocks网关失败: $e');
      return '127.0.0.1';
    }
  }

  // 获取V2Ray网关
  Future<String> _getV2RayGateway() async {
    try {
      // V2Ray通常运行在本地，网关就是本地地址
      return '127.0.0.1';
    } catch (e) {
      Logger.error('获取V2Ray网关失败: $e');
      return '127.0.0.1';
    }
  }

  // 根据类型获取网关
  Future<String> _getGatewayForType(String type) async {
    switch (type) {
      case 'internal':
        return await _getOpenVPNGateway();
      case 'external':
        return await _getClashGateway();
      case 'shadowsocks':
        return await _getShadowsocksGateway();
      case 'v2ray':
        return await _getV2RayGateway();
      default:
        return '127.0.0.1';
    }
  }

  // 启用路由
  Future<void> enableRouting() async {
    // 启用路由功能
    _isRoutingActive = true;
    Logger.info('路由已启用');

    // 应用已配置的路由规则
    if (_activeRoutes.isNotEmpty) {
      Logger.info('应用已配置的路由规则');
      // 路由规则已经在_configureRouting中添加，这里只需设置状态
    }
  }

  // 禁用路由
  Future<void> disableRouting() async {
    // 禔用路由功能并清除规则
    await _clearRoutingRules();
    _isRoutingActive = false;
    Logger.info('路由已禁用');
  }
}

// 用于存储路由规则的辅助类
class _RouteRule {
  final String pattern;
  final String type;
  final String gateway;

  _RouteRule(this.pattern, this.type, this.gateway);
}
