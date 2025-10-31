import 'package:flutter/material.dart';

/// 国际化资源管理类
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // 静态方法获取当前本地化实例
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // 定义支持的语言
  static const List<Locale> supportedLocales = [
    Locale('zh', ''), // 简体中文
    Locale('en', ''), // 英文
  ];

  // 获取本地化文本
  String get(String key) {
    final Map<String, Map<String, String>> localizedValues = {
      'zh': _chineseValues,
      'en': _englishValues,
    };

    final languageCode = locale.languageCode;
    final values = localizedValues[languageCode] ?? _chineseValues;
    return values[key] ?? key;
  }

  // 中文文本
  final Map<String, String> _chineseValues = {
    // 主界面
    'app_title': '双捷VPN管理器',
    'home_tab': '主页',
    'config_tab': '代理源',
    'proxy_list_tab': '代理列表',
    'routing_tab': '路由',
    'settings_tab': '设置',

    // 设置界面
    'settings_title': '设置',
    'language_setting': '国际化支持',
    'language_subtitle': '语言设置和多语言支持',
    'theme_setting': '主题设置',
    'theme_subtitle': '深色模式、浅色模式等主题选项',
    'import_export_setting': '配置导入/导出',
    'import_export_subtitle': '备份和恢复配置文件',
    'help_setting': '帮助说明',
    'help_subtitle': '使用指南和常见问题',
    'copyright_setting': '版权信息',
    'copyright_subtitle': '软件版本和授权信息',

    // 主题设置对话框
    'theme_dialog_title': '主题设置',
    'theme_light': '浅色模式',
    'theme_dark': '深色模式',
    'theme_system': '跟随系统',
    'theme_cancel': '取消',

    // 语言设置对话框
    'language_dialog_title': '语言设置',
    'language_select': '选择显示语言：',
    'language_chinese': '简体中文',
    'language_english': 'English',
    'language_save_hint': '语言设置已保存，重启应用后生效',

    // 帮助说明对话框
    'help_dialog_title': '帮助说明',
    'help_guide': '使用指南',
    'help_guide_1': '1. 主界面：显示当前连接状态和代理信息',
    'help_guide_2': '2. 代理源：管理代理服务器配置',
    'help_guide_3': '3. 代理列表：查看和选择可用代理',
    'help_guide_4': '4. 路由：配置流量路由规则',
    'help_guide_5': '5. 设置：应用配置和信息',
    'help_faq': '常见问题',
    'help_faq_q1': 'Q: 如何添加新的代理服务器？',
    'help_faq_a1': 'A: 在"代理源"页面点击"+"按钮，选择相应的配置文件或手动输入服务器信息。',
    'help_faq_q2': 'Q: 如何切换代理？',
    'help_faq_a2': 'A: 在"代理列表"页面选择想要使用的代理，点击连接按钮即可。',
    'help_faq_q3': 'Q: 如何配置路由规则？',
    'help_faq_a3': 'A: 在"路由"页面可以添加自定义规则，控制不同流量走不同代理。',
    'help_support': '技术支持',
    'help_contact': '如有其他问题，请联系：582883825@qq.com',
    'help_confirm': '确定',

    // 版权信息对话框
    'copyright_dialog_title': '版权信息',
    'copyright_app_name': 'Dualvpn Manager',
    'copyright_version': '版本',
    'copyright_author': '作者：Simon',
    'copyright_email': '邮箱：582883825@qq.com',
    'copyright_website': '网址：www.v8en.com',
    'copyright_rights': '版权所有 © 2025 Simon',
    'copyright_reserved': '保留所有权利',

    // 代理列表界面
    'proxy_list_title': '代理列表',
    'proxy_source_label': '选择代理源',
    'refresh_all_latency': '刷新所有延迟',
    'no_proxy_info': '暂无代理信息',
    'ensure_proxy_configured': '请确保已连接代理并配置了代理',
    'proxy_type_not_supported': '该代理类型不支持代理列表',
    'proxy_type_direct_connection': '此类型代理将直接使用配置进行连接',
    'type': '类型',
    'server': '服务器',
    'protocol': '协议',
    'latency': '延迟',
    'not_tested': '未测试',
    'testing': '测试中...',
    'connection_failed': '连接失败',
    'test_latency': '测试延迟',

    // 路由界面
    'routing_title': '路由配置',
    'routing_rules': '路由规则',
    'add_rule': '添加规则',
    'edit_rule': '编辑规则',
    'delete_rule': '删除规则',

    // 配置管理界面
    'config_title': '配置管理',
    'add_config': '添加配置',
    'edit_config': '编辑配置',
    'delete_config': '删除配置',
    'enable_config': '启用配置',
    'config': '配置',
    'path': '路径',
    'status': '状态',
    'enabled': '已启用',
    'disabled': '已禁用',
    'reload_config': '重新加载配置',
    'update_subscription': '更新订阅',
    'please_fill_config_name': '请填写配置名称',
    'please_fill_config_path_or_subscription': '请填写配置路径或订阅链接',
    'please_fill_server_address_and_port': '请填写服务器地址和端口',
    'config_added': '配置已添加',
    'config_deleted': '配置已删除',
    'latency_test_completed': '延迟测试完成',
    'reloading_openvpn_config': '正在重新加载OpenVPN配置...',
    'openvpn_config_reload_success': 'OpenVPN配置重新加载成功',
    'openvpn_config_reload_failed': 'OpenVPN配置重新加载失败',
    'config_type_not_support_subscription': '该配置类型不支持订阅更新',
    'config_not_subscription_link': '配置不是订阅链接',
    'updating_subscription': '正在更新订阅...',
    'subscription_update_success': '订阅更新成功',
    'subscription_update_failed': '订阅更新失败',
    'subscription_update_failed_check_network': '订阅更新失败，请检查网络连接和订阅链接',
    'network_connection_error': '网络连接错误，请检查网络连接',
    'ssl_certificate_error': 'SSL证书错误，请检查服务器证书',
    'tls_handshake_failed': 'TLS握手失败，请检查服务器配置',
    'subscription_link_not_exist': '订阅链接不存在，请检查链接是否正确',
    'connection_timeout': '连接超时，请稍后重试',
    'config_format_error': '配置格式错误，请检查订阅链接内容',
    'config_content_invalid': '配置内容无效，请检查订阅链接内容',
    'access_denied': '访问被拒绝，请检查订阅链接权限',
    'config_updated': '配置已更新',

    // 代理源管理界面
    'add_new_proxy_source': '添加新代理源',
    'proxy_source_name': '代理源名称',
    'proxy_type': '代理类型',
    'openvpn_config_file': 'OpenVPN (.ovpn/.conf/.tblk)',
    'clash_config_subscription': 'Clash (配置文件/订阅链接)',
    'shadowsocks_config_subscription': 'Shadowsocks (配置文件/订阅链接)',
    'shadowsocks': 'Shadowsocks',
    'v2ray_config_subscription': 'V2Ray (配置文件/订阅链接)',
    'v2ray': 'V2Ray',
    'http_proxy': 'HTTP代理',
    'socks5_proxy': 'SOCKS5代理',
    'custom_proxy': '自定义代理',
    'config_file_path': '配置文件路径',
    'config_file_path_or_subscription': '配置文件路径或订阅链接',
    'username_optional': '用户名(可选)',
    'password_optional': '密码(可选)',
    'server_address': '服务器地址',
    'port': '端口',
    'add_proxy_source': '添加代理源',
    'proxy_source_list': '代理源列表',
    'edit_proxy_source': '编辑代理源',
    'cancel': '取消',
    'save': '保存',

    // 主页界面
    'connection_status': '连接状态',
    'usage_instructions': '使用说明：',
    'instruction_1': '1. 在"代理源"页面添加并启用代理配置',
    'instruction_2': '2. 在"代理列表"页面选择具体的代理服务器',
    'instruction_3': '3. 在本页面查看已启用的代理源和选中的代理',
    'enabled_proxy_sources': '已启用代理源',
    'selected_proxies': '已选中代理',
    'go_proxy_core': 'Go代理核心',
    'no_enabled_proxy_sources': '暂无启用的代理源',
    'openvpn_label': 'OpenVPN:',
    'clash_label': 'Clash:',
    'shadowsocks_label': 'Shadowsocks:',
    'v2ray_label': 'V2Ray:',
    'http_proxy_label': 'HTTP代理:',
    'socks5_proxy_label': 'SOCKS5代理:',
    'starting': '启动中',
    'start': '启动',
    'stop': '停止',
    'go_proxy_core_stopped': 'Go代理核心已停止',
    'go_proxy_core_started': 'Go代理核心启动成功',
    'go_proxy_core_start_failed': 'Go代理核心启动失败',
    'no_selected_proxies': '暂无已选中代理',
    'connected': '已连接',
    'unknown': '未知',

    // 系统托盘菜单
    'tray_toggle_start': '启动',
    'tray_toggle_starting': '启动中...',
    'tray_toggle_stop': '停止',
    'tray_show_window': '显示主窗口',
    'tray_exit_app': '退出应用',
  };

  // 英文文本
  final Map<String, String> _englishValues = {
    // 主界面
    'app_title': 'DualVPN Manager',
    'home_tab': 'Home',
    'config_tab': 'Proxy Sources',
    'proxy_list_tab': 'Proxy List',
    'routing_tab': 'Routing',
    'settings_tab': 'Settings',

    // 设置界面
    'settings_title': 'Settings',
    'language_setting': 'Internationalization',
    'language_subtitle': 'Language settings and multilingual support',
    'theme_setting': 'Theme Settings',
    'theme_subtitle': 'Light mode, dark mode and other theme options',
    'import_export_setting': 'Import/Export Config',
    'import_export_subtitle': 'Backup and restore configuration files',
    'help_setting': 'Help',
    'help_subtitle': 'User guide and FAQ',
    'copyright_setting': 'Copyright Info',
    'copyright_subtitle': 'Software version and license information',

    // 主题设置对话框
    'theme_dialog_title': 'Theme Settings',
    'theme_light': 'Light Mode',
    'theme_dark': 'Dark Mode',
    'theme_system': 'Follow System',
    'theme_cancel': 'Cancel',

    // 语言设置对话框
    'language_dialog_title': 'Language Settings',
    'language_select': 'Select display language:',
    'language_chinese': '简体中文',
    'language_english': 'English',
    'language_save_hint':
        'Language setting saved. Restart the app to take effect.',

    // 帮助说明对话框
    'help_dialog_title': 'Help',
    'help_guide': 'User Guide',
    'help_guide_1':
        '1. Home: Display current connection status and proxy information',
    'help_guide_2': '2. Proxy Sources: Manage proxy server configurations',
    'help_guide_3': '3. Proxy List: View and select available proxies',
    'help_guide_4': '4. Routing: Configure traffic routing rules',
    'help_guide_5': '5. Settings: Application configuration and information',
    'help_faq': 'FAQ',
    'help_faq_q1': 'Q: How to add a new proxy server?',
    'help_faq_a1':
        'A: Click the "+" button on the "Proxy Sources" page, select the corresponding configuration file or manually enter server information.',
    'help_faq_q2': 'Q: How to switch proxies?',
    'help_faq_a2':
        'A: Select the proxy you want to use on the "Proxy List" page and click the connect button.',
    'help_faq_q3': 'Q: How to configure routing rules?',
    'help_faq_a3':
        'A: Custom rules can be added on the "Routing" page to control different traffic through different proxies.',
    'help_support': 'Technical Support',
    'help_contact':
        'If you have any other questions, please contact: 582883825@qq.com',
    'help_confirm': 'OK',

    // 版权信息对话框
    'copyright_dialog_title': 'Copyright Information',
    'copyright_app_name': 'Dualvpn Manager',
    'copyright_version': 'Version',
    'copyright_author': 'Author: Simon',
    'copyright_email': 'Email: 582883825@qq.com',
    'copyright_website': 'Website: www.v8en.com',
    'copyright_rights': 'Copyright © 2025 Simon',
    'copyright_reserved': 'All rights reserved',

    // 代理列表界面
    'proxy_list_title': 'Proxy List',
    'proxy_source_label': 'Select Proxy Source',
    'refresh_all_latency': 'Refresh All Latency',
    'no_proxy_info': 'No proxy information',
    'ensure_proxy_configured':
        'Please ensure that the proxy is connected and configured',
    'proxy_type_not_supported': 'This proxy type does not support proxy list',
    'proxy_type_direct_connection':
        'This type of proxy will connect directly using the configuration',
    'type': 'Type',
    'server': 'Server',
    'protocol': 'Protocol',
    'latency': 'Latency',
    'not_tested': 'Not tested',
    'testing': 'Testing...',
    'connection_failed': 'Connection failed',
    'test_latency': 'Test latency',

    // 路由界面
    'routing_title': 'Routing Configuration',
    'routing_rules': 'Routing Rules',
    'add_rule': 'Add Rule',
    'edit_rule': 'Edit Rule',
    'delete_rule': 'Delete Rule',

    // 配置管理界面
    'config_title': 'Configuration Management',
    'add_config': 'Add Configuration',
    'edit_config': 'Edit Configuration',
    'delete_config': 'Delete Configuration',
    'enable_config': 'Enable Configuration',
    'config': 'Configuration',
    'path': 'Path',
    'status': 'Status',
    'enabled': 'Enabled',
    'disabled': 'Disabled',
    'reload_config': 'Reload Configuration',
    'update_subscription': 'Update Subscription',
    'please_fill_config_name': 'Please fill in the configuration name',
    'please_fill_config_path_or_subscription':
        'Please fill in the configuration path or subscription link',
    'please_fill_server_address_and_port':
        'Please fill in the server address and port',
    'config_added': 'Configuration added',
    'config_deleted': 'Configuration deleted',
    'latency_test_completed': 'Latency test completed',
    'reloading_openvpn_config': 'Reloading OpenVPN configuration...',
    'openvpn_config_reload_success': 'OpenVPN configuration reload successful',
    'openvpn_config_reload_failed': 'OpenVPN configuration reload failed',
    'config_type_not_support_subscription':
        'This configuration type does not support subscription updates',
    'config_not_subscription_link': 'Configuration is not a subscription link',
    'updating_subscription': 'Updating subscription...',
    'subscription_update_success': 'Subscription update successful',
    'subscription_update_failed': 'Subscription update failed',
    'subscription_update_failed_check_network':
        'Subscription update failed, please check network connection and subscription link',
    'network_connection_error':
        'Network connection error, please check network connection',
    'ssl_certificate_error':
        'SSL certificate error, please check server certificate',
    'tls_handshake_failed':
        'TLS handshake failed, please check server configuration',
    'subscription_link_not_exist':
        'Subscription link does not exist, please check if the link is correct',
    'connection_timeout': 'Connection timeout, please try again later',
    'config_format_error':
        'Configuration format error, please check subscription link content',
    'config_content_invalid':
        'Configuration content invalid, please check subscription link content',
    'access_denied':
        'Access denied, please check subscription link permissions',
    'config_updated': 'Configuration updated',

    // 代理源管理界面
    'add_new_proxy_source': 'Add New Proxy Source',
    'proxy_source_name': 'Proxy Source Name',
    'proxy_type': 'Proxy Type',
    'openvpn_config_file': 'OpenVPN (.ovpn/.conf/.tblk)',
    'clash_config_subscription': 'Clash (Config File/Subscription Link)',
    'shadowsocks_config_subscription':
        'Shadowsocks (Config File/Subscription Link)',
    'shadowsocks': 'Shadowsocks',
    'v2ray_config_subscription': 'V2Ray (Config File/Subscription Link)',
    'v2ray': 'V2Ray',
    'http_proxy': 'HTTP Proxy',
    'socks5_proxy': 'SOCKS5 Proxy',
    'custom_proxy': 'Custom Proxy',
    'config_file_path': 'Config File Path',
    'config_file_path_or_subscription': 'Config File Path or Subscription Link',
    'username_optional': 'Username (Optional)',
    'password_optional': 'Password (Optional)',
    'server_address': 'Server Address',
    'port': 'Port',
    'add_proxy_source': 'Add Proxy Source',
    'proxy_source_list': 'Proxy Source List',
    'edit_proxy_source': 'Edit Proxy Source',
    'cancel': 'Cancel',
    'save': 'Save',

    // 主页界面
    'connection_status': 'Connection Status',
    'usage_instructions': 'Usage Instructions:',
    'instruction_1':
        '1. Add and enable proxy configurations on the "Proxy Sources" page',
    'instruction_2':
        '2. Select specific proxy servers on the "Proxy List" page',
    'instruction_3':
        '3. View enabled proxy sources and selected proxies on this page',
    'enabled_proxy_sources': 'Enabled Proxy Sources',
    'selected_proxies': 'Selected Proxies',
    'go_proxy_core': 'Go Proxy Core',
    'no_enabled_proxy_sources': 'No enabled proxy sources',
    'openvpn_label': 'OpenVPN:',
    'clash_label': 'Clash:',
    'shadowsocks_label': 'Shadowsocks:',
    'v2ray_label': 'V2Ray:',
    'http_proxy_label': 'HTTP Proxy:',
    'socks5_proxy_label': 'SOCKS5 Proxy:',
    'starting': 'Starting',
    'start': 'Start',
    'stop': 'Stop',
    'go_proxy_core_stopped': 'Go Proxy Core stopped',
    'go_proxy_core_started': 'Go Proxy Core started successfully',
    'go_proxy_core_start_failed': 'Go Proxy Core failed to start',
    'no_selected_proxies': 'No selected proxies',
    'connected': 'Connected',
    'unknown': 'Unknown',

    // System tray menu
    'tray_toggle_start': 'Start',
    'tray_toggle_starting': 'Starting...',
    'tray_toggle_stop': 'Stop',
    'tray_show_window': 'Show Window',
    'tray_exit_app': 'Exit App',
  };
}
