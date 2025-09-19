import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    // 测试检查Go代理核心状态
    print('测试检查Go代理核心状态...');
    final statusUrl = Uri.parse('http://127.0.0.1:6162/status');
    final statusClient = HttpClient();
    final statusRequest = await statusClient.getUrl(statusUrl);
    final statusResponse = await statusRequest.close();
    final statusBody = await utf8.decodeStream(statusResponse);

    print('状态检查响应状态码: ${statusResponse.statusCode}');
    print('状态检查响应体: $statusBody');

    if (statusResponse.statusCode == 200) {
      final status = jsonDecode(statusBody) as Map<String, dynamic>;
      final isRunning = status['running'] == true;
      print('Go代理核心运行状态: $isRunning');
    }

    // 测试获取统计信息
    print('\n测试获取统计信息...');
    final statsUrl = Uri.parse('http://127.0.0.1:6162/stats');
    final statsClient = HttpClient();
    final statsRequest = await statsClient.getUrl(statsUrl);
    final statsResponse = await statsRequest.close();
    final statsBody = await utf8.decodeStream(statsResponse);

    print('统计信息响应状态码: ${statsResponse.statusCode}');
    print('统计信息响应体: $statsBody');

    if (statsResponse.statusCode == 200) {
      final stats = jsonDecode(statsBody) as Map<String, dynamic>;
      print('统计信息: $stats');
    }

    statusClient.close();
    statsClient.close();
  } catch (e) {
    print('测试过程中出错: $e');
  }
}
