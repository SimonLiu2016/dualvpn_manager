import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:dualvpn_manager/l10n/app_localizations_delegate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:dualvpn_manager/utils/logger.dart';
import 'package:dualvpn_manager/services/privileged_helper_service.dart';

class SettingsScreen extends StatefulWidget {
  final AppState appState;

  const SettingsScreen({super.key, required this.appState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 添加日志管理设置的状态变量
  late int _logFileSizeLimit;
  late int _logRetentionDays;
  late bool _logAutoCleanupEnabled;
  late Future<PackageInfo> _packageInfoFuture;

  // 添加控制器作为状态变量，避免在对话框重建时丢失
  late TextEditingController _fileSizeController;
  late TextEditingController _retentionController;

  @override
  void initState() {
    super.initState();
    // 初始化日志管理设置
    _loadLogSettings();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  void dispose() {
    // 释放控制器资源
    _fileSizeController.dispose();
    _retentionController.dispose();
    super.dispose();
  }

  // 加载日志管理设置
  void _loadLogSettings() {
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      setState(() {
        _logFileSizeLimit = prefs.getInt('logFileSizeLimit') ?? 10;
        _logRetentionDays = prefs.getInt('logRetentionDays') ?? 7;
        _logAutoCleanupEnabled = prefs.getBool('logAutoCleanupEnabled') ?? true;

        // 初始化控制器
        _fileSizeController = TextEditingController(
          text: _logFileSizeLimit.toString(),
        );
        _retentionController = TextEditingController(
          text: _logRetentionDays.toString(),
        );
      });
    });
  }

  // 保存日志管理设置
  void _saveLogSettings() {
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      prefs.setInt('logFileSizeLimit', _logFileSizeLimit);
      prefs.setInt('logRetentionDays', _logRetentionDays);
      prefs.setBool('logAutoCleanupEnabled', _logAutoCleanupEnabled);
    });
  }

  // 显示日志管理对话框
  void _showLogManagementDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // 使用状态变量而不是局部变量
    int fileSizeLimit = _logFileSizeLimit;
    int retentionDays = _logRetentionDays;
    bool autoCleanupEnabled = _logAutoCleanupEnabled;

    // 更新控制器文本而不是创建新的控制器
    _fileSizeController.text = fileSizeLimit.toString();
    _retentionController.text = retentionDays.toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text(localizations.get('log_management_dialog_title')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.get('log_file_size_limit')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _fileSizeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: 'MB'),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          fileSizeLimit = int.tryParse(value) ?? fileSizeLimit;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(localizations.get('log_retention_days')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _retentionController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          retentionDays = int.tryParse(value) ?? retentionDays;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(localizations.get('auto_cleanup_enabled')),
                        const SizedBox(width: 10),
                        Switch(
                          value: autoCleanupEnabled,
                          onChanged: (value) {
                            dialogSetState(() {
                              autoCleanupEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(localizations.get('manual_cleanup')),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        // 调用日志清理功能
                        final success = await _cleanupLogs(
                          context,
                          fileSizeLimit,
                          retentionDays,
                        );
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                localizations.get('log_cleanup_success'),
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                localizations.get('log_cleanup_failed'),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(localizations.get('cleanup_now')),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(localizations.get('theme_cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    // 保存设置
                    setState(() {
                      _logFileSizeLimit = fileSizeLimit;
                      _logRetentionDays = retentionDays;
                      _logAutoCleanupEnabled = autoCleanupEnabled;
                    });
                    _saveLogSettings();
                    Navigator.of(context).pop();
                  },
                  child: Text(localizations.get('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 显示帮助说明对话框
  void _showHelpDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.get('help_dialog_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.get('help_guide'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(localizations.get('help_guide_1')),
                Text(localizations.get('help_guide_2')),
                Text(localizations.get('help_guide_3')),
                Text(localizations.get('help_guide_4')),
                Text(localizations.get('help_guide_5')),
                const SizedBox(height: 16),
                Text(
                  localizations.get('help_faq'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.get('help_faq_q1'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(localizations.get('help_faq_a1')),
                const SizedBox(height: 8),
                Text(
                  localizations.get('help_faq_q2'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(localizations.get('help_faq_a2')),
                const SizedBox(height: 8),
                Text(
                  localizations.get('help_faq_q3'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(localizations.get('help_faq_a3')),
                const SizedBox(height: 16),
                Text(
                  localizations.get('help_support'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(localizations.get('help_contact')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(localizations.get('help_confirm')),
            ),
          ],
        );
      },
    );
  }

  // 显示版权信息对话框
  void _showCopyrightDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.get('copyright_dialog_title')),
          content: FutureBuilder<PackageInfo>(
            future: _packageInfoFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Text(localizations.get('failed_to_get_version_info'));
              } else if (snapshot.hasData) {
                final packageInfo = snapshot.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.get('copyright_app_name')),
                    const SizedBox(height: 8),
                    Text(
                      '${localizations.get('copyright_version')}：v${packageInfo.version}',
                    ),
                    const SizedBox(height: 8),
                    Text(localizations.get('copyright_author')),
                    Text(localizations.get('copyright_email')),
                    GestureDetector(
                      onTap: () async {
                        final Uri url = Uri.parse('https://www.v8en.com');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      child: Text(
                        localizations.get('copyright_website'),
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(localizations.get('copyright_rights')),
                    Text(localizations.get('copyright_reserved')),
                  ],
                );
              } else {
                return Text(localizations.get('no_version_info'));
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(localizations.get('help_confirm')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.get('settings_title'),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(localizations.get('language_setting')),
                  subtitle: Text(localizations.get('language_subtitle')),
                  onTap: () {
                    // 实现国际化设置功能
                    _showLanguageSettings(context);
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
                  title: Text(localizations.get('theme_setting')),
                  subtitle: Text(localizations.get('theme_subtitle')),
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
                  leading: const Icon(Icons.description),
                  title: Text(localizations.get('log_management_setting')),
                  subtitle: Text(localizations.get('log_management_subtitle')),
                  onTap: () {
                    // 实现日志管理功能
                    _showLogManagementDialog(context);
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
                  title: Text(localizations.get('import_export_setting')),
                  subtitle: Text(localizations.get('import_export_subtitle')),
                  onTap: () {
                    // TODO: 实现配置导入/导出功能
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          localizations.get('import_export_feature_pending'),
                        ),
                      ),
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
                  title: Text(localizations.get('help_setting')),
                  subtitle: Text(localizations.get('help_subtitle')),
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
                  title: Text(localizations.get('copyright_setting')),
                  subtitle: Text(localizations.get('copyright_subtitle')),
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

  // 显示语言设置对话框
  void _showLanguageSettings(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final appState = Provider.of<AppState>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.get('language_dialog_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.get('language_select')),
              const SizedBox(height: 16),
              RadioListTile<String>(
                title: Text(localizations.get('language_chinese')),
                value: 'zh',
                groupValue: appState.language,
                onChanged: (value) {
                  if (value != null) {
                    appState.setLanguage(value);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.get('language_save_hint')),
                      ),
                    );
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(localizations.get('language_english')),
                value: 'en',
                groupValue: appState.language,
                onChanged: (value) {
                  if (value != null) {
                    appState.setLanguage(value);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.get('language_save_hint')),
                      ),
                    );
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Français'),
                value: 'fr',
                groupValue: appState.language,
                onChanged: (value) {
                  if (value != null) {
                    appState.setLanguage(value);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.get('language_save_hint')),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 显示主题设置对话框
  void _showThemeSettingsDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<AppState>(
          builder: (context, appState, child) {
            return AlertDialog(
              title: Text(localizations.get('theme_dialog_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizations.get('select_theme_mode')),
                  const SizedBox(height: 16),
                  RadioListTile<ThemeMode>(
                    title: Text(localizations.get('theme_light')),
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
                    title: Text(localizations.get('theme_dark')),
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
                    title: Text(localizations.get('theme_system')),
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
                  child: Text(localizations.get('theme_cancel')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 清理日志文件
  Future<bool> _cleanupLogs(
    BuildContext context,
    int fileSizeLimit,
    int retentionDays,
  ) async {
    try {
      // 创建特权助手服务实例
      final helperService = HelperService();

      // 首先调用macOS层清理日志，传递参数
      bool macOSCleanupSuccess = false;
      try {
        macOSCleanupSuccess =
            await const OptionalMethodChannel(
                  'dualvpn_manager/macos',
                ).invokeMethod('cleanupLogs', {
                  'fileSizeLimit': fileSizeLimit,
                  'retentionDays': retentionDays,
                })
                as bool? ??
            false;
      } catch (e) {
        Logger.error('macOS层日志清理失败: $e');
      }

      // 然后调用特权助手清理日志，传递参数
      bool helperCleanupSuccess = await helperService.cleanupLogs(
        fileSizeLimit: fileSizeLimit,
        retentionDays: retentionDays,
      );

      return macOSCleanupSuccess || helperCleanupSuccess;
    } catch (e) {
      Logger.error('日志清理失败: $e');
      return false;
    }
  }
}
