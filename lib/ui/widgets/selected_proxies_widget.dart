import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/l10n/app_localizations_delegate.dart';

/// 已选中代理小部件
/// 这个小部件只监听与选中代理相关的状态变化
class SelectedProxiesWidget extends StatelessWidget {
  const SelectedProxiesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<AppState>().getSelectedProxies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('加载代理信息失败: ${snapshot.error}');
        }

        final selectedProxies = snapshot.data ?? [];

        if (selectedProxies.isEmpty) {
          return Text(
            localizations.get('no_selected_proxies'),
            style: TextStyle(color: Theme.of(context).hintColor),
          );
        }

        return Column(
          children: selectedProxies.map((selectedProxy) {
            final config = selectedProxy['config'] as VPNConfig;
            final proxy = selectedProxy['proxy'] as Map<String, dynamic>;

            // 获取代理类型对应的颜色和图标
            Color color;
            IconData icon;
            String typeName;

            switch (config.type) {
              case VPNType.openVPN:
                color = Colors.blue;
                icon = Icons.vpn_lock;
                typeName = localizations
                    .get('openvpn_label')
                    .replaceAll(':', '');
                break;
              case VPNType.clash:
                color = Colors.green;
                icon = Icons.shield;
                typeName = localizations.get('clash_label').replaceAll(':', '');
                break;
              case VPNType.shadowsocks:
                color = Colors.purple;
                icon = Icons.link;
                typeName = localizations
                    .get('shadowsocks_label')
                    .replaceAll(':', '');
                break;
              case VPNType.v2ray:
                color = Colors.orange;
                icon = Icons.link;
                typeName = localizations.get('v2ray_label').replaceAll(':', '');
                break;
              case VPNType.httpProxy:
                color = Colors.red;
                icon = Icons.http;
                typeName = localizations
                    .get('http_proxy_label')
                    .replaceAll(':', '');
                break;
              case VPNType.socks5:
                color = Colors.teal;
                icon = Icons.http;
                typeName = localizations
                    .get('socks5_proxy_label')
                    .replaceAll(':', '');
                break;
              default:
                color = Theme.of(context).hintColor;
                icon = Icons.help;
                typeName = localizations.get('unknown');
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$typeName - ${proxy['name']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RateInfoWidget(configType: config.type),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      localizations.get('connected'),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// 速率信息小部件
class _RateInfoWidget extends StatelessWidget {
  final VPNType configType;

  const _RateInfoWidget({required this.configType});

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, String>(
      selector: (context, appState) {
        switch (configType) {
          case VPNType.openVPN:
            return appState.openVPNRateInfo;
          case VPNType.clash:
            return appState.clashRateInfo;
          case VPNType.shadowsocks:
            return appState.shadowsocksRateInfo;
          case VPNType.v2ray:
            return appState.v2rayRateInfo;
          case VPNType.httpProxy:
            return appState.httpProxyRateInfo;
          case VPNType.socks5:
            return appState.socks5ProxyRateInfo;
          default:
            return '↑ 0 KB/s ↓ 0 KB/s';
        }
      },
      builder: (context, rateInfo, child) {
        return Text(
          rateInfo,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).hintColor,
            fontFamily: 'monospace',
          ),
        );
      },
    );
  }
}
