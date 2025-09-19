import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';

/// Go代理核心统计信息小部件
/// 这个小部件只监听与Go代理核心统计信息相关的状态变化
class GoProxyStatsWidget extends StatelessWidget {
  const GoProxyStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, bool>(
      selector: (context, appState) => appState.isGoProxyRunning,
      builder: (context, isGoProxyRunning, child) {
        // 只有当Go代理核心运行时才显示统计信息
        if (!isGoProxyRunning) {
          return const SizedBox.shrink();
        }

        return Selector<AppState, String>(
          selector: (context, appState) =>
              '${appState.goProxyUploadSpeed} ${appState.goProxyDownloadSpeed}',
          builder: (context, speedInfo, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  speedInfo,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
              ],
            );
          },
        );
      },
    );
  }
}
