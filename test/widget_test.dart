// 这是一个基本的Flutter widget测试。
//
// 要执行测试，请运行 `flutter test` 或在Android Studio/IntelliJ中使用Test Runner。
// 要获得有关widget测试的更多信息，请参阅 https://flutter.dev/docs/cookbook/testing/widget/introduction

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/main.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/utils/tray_manager.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 构建应用并触发帧。
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => AppState(trayManager: DualVPNTrayManager()),
        child: DualVPNApp(trayManager: DualVPNTrayManager()),
      ),
    );

    // 验证我们是否在主页面上
    expect(find.text('双捷VPN管理器'), findsOneWidget);
    expect(find.text('连接状态'), findsOneWidget);
  });
}
