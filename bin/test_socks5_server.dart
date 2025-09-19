import 'dart:io';
import 'package:dualvpn_manager/services/socks5_proxy_server.dart';

void main() async {
  // 创建SOCKS5代理服务器
  final server = SOCKS5ProxyServer(port: 1080);

  // 启动服务器
  print('启动SOCKS5代理服务器...');
  final result = await server.start();

  if (result) {
    print('SOCKS5代理服务器启动成功，监听端口: ${server.port}');
    print('按 Ctrl+C 停止服务器');

    // 等待用户中断
    ProcessSignal.sigint.watch().listen((signal) async {
      print('正在停止服务器...');
      await server.stop();
      print('服务器已停止');
      exit(0);
    });

    // 保持程序运行
    await Future.delayed(Duration(days: 365));
  } else {
    print('SOCKS5代理服务器启动失败');
    exit(1);
  }
}
