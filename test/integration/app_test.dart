import 'package:flutter_test/flutter_test.dart';
import 'package:dualvpn_manager/main.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/utils/tray_manager.dart';

void main() {
  group('App Integration', () {
    testWidgets('should render main screen', (WidgetTester tester) async {
      // 构建应用并触发帧。
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (context) => AppState(trayManager: DualVPNTrayManager()),
          child: DualVPNApp(trayManager: DualVPNTrayManager()),
        ),
      );

      // 使用简单的pump而不是pumpAndSettle避免超时
      await tester.pump();

      // 验证基本元素存在
      expect(find.text('双捷VPN管理器'), findsOneWidget);
    });
  });
}
