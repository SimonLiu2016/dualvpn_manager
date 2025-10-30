import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';

/// 代理列表小部件
class ProxyListWidget extends StatelessWidget {
  final Function(String proxyName) onTestLatency;
  final Function(String proxyName, bool isSelected) onProxySelected;

  const ProxyListWidget({
    super.key,
    required this.onTestLatency,
    required this.onProxySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return _ProxyListView(
          proxies: appState.proxies,
          isLoadingProxies: appState.isLoadingProxies,
          selectedConfig: appState.selectedConfig,
          onTestLatency: onTestLatency,
          onProxySelected: onProxySelected,
        );
      },
    );
  }
}

/// 代理列表视图实现
class _ProxyListView extends StatelessWidget {
  final List<Map<String, dynamic>> proxies;
  final bool isLoadingProxies;
  final String selectedConfig;
  final Function(String proxyName) onTestLatency;
  final Function(String proxyName, bool isSelected) onProxySelected;

  const _ProxyListView({
    required this.proxies,
    required this.isLoadingProxies,
    required this.selectedConfig,
    required this.onTestLatency,
    required this.onProxySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingProxies) {
      return const Center(child: CircularProgressIndicator());
    } else if (proxies.isEmpty) {
      // 检查当前选中的配置类型是否支持代理列表
      final configs = ConfigManager.loadConfigsSync();
      final currentConfig = configs.firstWhere(
        (config) => config.id == selectedConfig,
        orElse: () => configs.isNotEmpty
            ? configs.first
            : VPNConfig(
                id: '',
                name: '',
                type: VPNType.openVPN,
                configPath: '',
                settings: {},
              ),
      );

      // OpenVPN、Clash、Shadowsocks和V2Ray类型支持代理列表
      bool supportsProxyList =
          currentConfig.type == VPNType.openVPN ||
          currentConfig.type == VPNType.clash ||
          currentConfig.type == VPNType.shadowsocks ||
          currentConfig.type == VPNType.v2ray;

      if (supportsProxyList) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_off,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
              const SizedBox(height: 10),
              Text('暂无代理信息', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(
                '请确保已连接代理并配置了代理',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      } else {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                '该代理类型不支持代理列表',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              Text(
                '此类型代理将直接使用配置进行连接',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      }
    } else {
      // 显示所有代理，不管是否启用
      return Expanded(
        child: ListView.builder(
          itemCount: proxies.length,
          itemBuilder: (context, index) {
            final proxy = proxies[index];
            final latency = proxy['latency'];
            final isSelected = proxy['isSelected'] as bool;
            final proxyName = proxy['name'];
            final proxyType = proxy['type'];

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).disabledColor,
                  width: 2,
                ),
              ),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                    child: Icon(
                      latency == -2
                          ? Icons.link
                          : latency == -1
                          ? Icons.hourglass_empty
                          : Icons.link,
                      key: ValueKey<int>(latency ?? 0),
                      color: latency == -2
                          ? Theme.of(context).hintColor
                          : latency == -1
                          ? Colors.orange
                          : (latency < 0
                                ? Colors.red
                                : latency < 300
                                ? Colors.green
                                : latency < 1000
                                ? Colors.deepOrange
                                : Colors.red),
                    ),
                  ),
                  title: Text(
                    proxyName,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('类型: $proxyType'),
                      // 对于OpenVPN类型，显示服务器地址和端口
                      if (proxyType == 'openvpn' &&
                          proxy.containsKey('server') &&
                          proxy.containsKey('port')) ...[
                        Text('服务器: ${proxy['server']}:${proxy['port']}'),
                        if (proxy.containsKey('protocol'))
                          Text('协议: ${proxy['protocol']}'),
                      ]
                      // 对于其他类型，保持原有的显示方式
                      else if (latency == -2)
                        Text(
                          '未测试',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        )
                      else if (latency == -1)
                        const Text(
                          '测试中...',
                          style: TextStyle(color: Colors.orange),
                        )
                      else if (latency < 0)
                        const Text('连接失败', style: TextStyle(color: Colors.red))
                      else
                        Text(
                          '延迟: ${latency}ms',
                          style: TextStyle(
                            color: latency < 300
                                ? Colors.green
                                : latency < 1000
                                ? Colors.deepOrange
                                : Colors.red,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.speed),
                        onPressed: () => onTestLatency(proxyName),
                        tooltip: '测试延迟',
                      ),
                      // 对于OpenVPN类型，选中状态默认为选中且不可修改
                      if (proxyType == 'openvpn')
                        const Switch(
                          value: true, // OpenVPN默认选中
                          onChanged: null, // 不可修改
                        )
                      else
                        Switch(
                          value: isSelected,
                          onChanged: (value) {
                            onProxySelected(proxyName, value);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
  }
}
