import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'dart:math' as math;

void main() {
  group('订阅数据解析测试', () {
    test('查看Clash订阅数据格式', () async {
      // 使用Mock client替代实际网络请求
      final mockClient = MockClient((request) async {
        // 模拟一个简单的响应
        return http.Response('dGVzdCBkYXRh', 200); // "test data" 的base64编码
      });

      final subscriptionUrl = 'https://test.com/subscription';
      final response = await mockClient.get(Uri.parse(subscriptionUrl));

      if (response.statusCode == 200) {
        print('响应状态码: ${response.statusCode}');
        print('响应长度: ${response.body.length}');

        // 尝试解码base64
        try {
          List<int> decodedBytes = base64Decode(response.body);
          String configContent = utf8.decode(decodedBytes);
          print('解码后的数据: $configContent');
        } catch (e) {
          print('Base64解码失败: $e');
        }
      } else {
        print('请求失败，状态码: ${response.statusCode}');
      }

      // 这只是一个示例测试，实际的网络请求应该被mock
      expect(response.statusCode, 200);
    });
  });
}
