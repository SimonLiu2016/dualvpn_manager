import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  // 显示帮助说明对话框
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('帮助说明'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '使用指南',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('1. 主界面：显示当前连接状态和代理信息'),
                Text('2. 代理源：管理代理服务器配置'),
                Text('3. 代理列表：查看和选择可用代理'),
                Text('4. 路由：配置流量路由规则'),
                Text('5. 设置：应用配置和信息'),
                SizedBox(height: 16),
                Text(
                  '常见问题',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Q: 如何添加新的代理服务器？',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('A: 在"代理源"页面点击"+"按钮，选择相应的配置文件或手动输入服务器信息。'),
                SizedBox(height: 8),
                Text(
                  'Q: 如何切换代理？',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('A: 在"代理列表"页面选择想要使用的代理，点击连接按钮即可。'),
                SizedBox(height: 8),
                Text(
                  'Q: 如何配置路由规则？',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('A: 在"路由"页面可以添加自定义规则，控制不同流量走不同代理。'),
                SizedBox(height: 16),
                Text(
                  '技术支持',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('如有其他问题，请联系：582883825@qq.com'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 显示版权信息对话框
  void _showCopyrightDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('版权信息'),
          content: FutureBuilder<PackageInfo>(
            future: _packageInfoFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return const Text('获取版本信息失败');
              } else if (snapshot.hasData) {
                final packageInfo = snapshot.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dualvpn Manager'),
                    const SizedBox(height: 8),
                    Text('版本：v${packageInfo.version}'),
                    const SizedBox(height: 8),
                    const Text('作者：Simon'),
                    const Text('邮箱：582883825@qq.com'),
                    GestureDetector(
                      onTap: () async {
                        final Uri url = Uri.parse('https://www.v8en.com');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      child: const Text(
                        '网址：www.v8en.com',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('版权所有 © 2025 Simon'),
                    const Text('保留所有权利'),
                  ],
                );
              } else {
                return const Text('无版本信息');
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设置', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('国际化支持'),
                  subtitle: const Text('语言设置和多语言支持'),
                  onTap: () {
                    // TODO: 实现国际化设置功能
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('国际化支持功能待实现')));
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('主题设置'),
                  subtitle: const Text('深色模式、浅色模式等主题选项'),
                  onTap: () {
                    // 实现主题设置功能
                    _showThemeSettingsDialog(context);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.import_export),
                  title: const Text('配置导入/导出'),
                  subtitle: const Text('备份和恢复配置文件'),
                  onTap: () {
                    // TODO: 实现配置导入/导出功能
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('配置导入/导出功能待实现')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('帮助说明'),
                  subtitle: const Text('使用指南和常见问题'),
                  onTap: () {
                    // 实现帮助说明功能
                    _showHelpDialog(context);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('版权信息'),
                  subtitle: const Text('软件版本和授权信息'),
                  onTap: () {
                    // 实现版权信息功能
                    _showCopyrightDialog(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示主题设置对话框
  void _showThemeSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<AppState>(
          builder: (context, appState, child) {
            return AlertDialog(
              title: const Text('主题设置'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择主题模式：'),
                  const SizedBox(height: 16),
                  RadioListTile<ThemeMode>(
                    title: const Text('浅色模式'),
                    value: ThemeMode.light,
                    groupValue: appState.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        appState.setThemeMode(value);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('深色模式'),
                    value: ThemeMode.dark,
                    groupValue: appState.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        appState.setThemeMode(value);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('跟随系统'),
                    value: ThemeMode.system,
                    groupValue: appState.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        appState.setThemeMode(value);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
