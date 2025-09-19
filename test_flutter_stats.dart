import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    // 测试获取统计信息
    final url = Uri.parse('http://127.0.0.1:6162/stats');
    final client = HttpClient();
    final request = await client.getUrl(url);
    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);

    print('Status code: ${response.statusCode}');
    print('Response body: $responseBody');

    if (response.statusCode == 200) {
      final stats = jsonDecode(responseBody) as Map<String, dynamic>;
      print('Stats: $stats');
    } else {
      print('Failed to get stats: ${response.statusCode}, $responseBody');
    }

    client.close();
  } catch (e) {
    print('Error: $e');
  }
}
