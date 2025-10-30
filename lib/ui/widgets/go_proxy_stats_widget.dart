import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';

/// Go代理核心统计信息小部件
class GoProxyStatsWidget extends StatelessWidget {
  const GoProxyStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, String>(
      selector: (context, appState) =>
          '${appState.goProxyUploadSpeed} ${appState.goProxyDownloadSpeed}',
      builder: (context, stats, child) {
        return Text(
          stats,
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
