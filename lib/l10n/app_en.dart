/// English localization resources
class AppLocalizationsEn {
  static const Map<String, String> localizedValues = {
    // Main interface
    'app_title': 'DualVPN Manager',
    'home_tab': 'Home',
    'config_tab': 'Proxy Sources',
    'proxy_list_tab': 'Proxy List',
    'routing_tab': 'Routing',
    'settings_tab': 'Settings',

    // Settings interface
    'settings_title': 'Settings',
    'language_setting': 'Internationalization',
    'language_subtitle': 'Language settings and multilingual support',
    'theme_setting': 'Theme Settings',
    'theme_subtitle': 'Light mode, dark mode and other theme options',
    'log_management_setting': 'Log Management',
    'log_management_subtitle': 'Configure log file size and retention time',
    'import_export_setting': 'Import/Export Config',
    'import_export_subtitle': 'Backup and restore configuration files',
    'help_setting': 'Help',
    'help_subtitle': 'User guide and FAQ',
    'copyright_setting': 'Copyright Info',
    'copyright_subtitle': 'Software version and license information',
    'failed_to_get_version_info': 'Failed to get version information',
    'no_version_info': 'No version information',
    'import_export_feature_pending':
        'Import/Export feature pending implementation',
    'select_theme_mode': 'Select theme mode:',

    // Theme settings dialog
    'theme_dialog_title': 'Theme Settings',
    'theme_light': 'Light Mode',
    'theme_dark': 'Dark Mode',
    'theme_system': 'Follow System',
    'theme_cancel': 'Cancel',

    // Language settings dialog
    'language_dialog_title': 'Language Settings',
    'language_select': 'Select display language:',
    'language_chinese': '简体中文',
    'language_english': 'English',
    'language_save_hint':
        'Language setting saved. Restart the app to take effect.',

    // Help dialog
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

    // Copyright dialog
    'copyright_dialog_title': 'Copyright Information',
    'copyright_app_name': 'Dualvpn Manager',
    'copyright_version': 'Version',
    'copyright_author': 'Author: Simon',
    'copyright_email': 'Email: 582883825@qq.com',
    'copyright_website': 'Website: www.v8en.com',
    'copyright_rights': 'Copyright © 2025 Simon',
    'copyright_reserved': 'All rights reserved',

    // Proxy list interface
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
    'all_proxies_latency_test_completed': 'All proxies latency test completed',

    // Routing interface
    'routing_title': 'Routing Configuration',
    'routing_rules': 'Routing Rules',
    'add_rule': 'Add Rule',
    'edit_rule': 'Edit Rule',
    'delete_rule': 'Delete Rule',
    'specify_proxy_source_for_domain':
        'Specify proxy source for specific domain',
    'load_config_failed': 'Failed to load configuration',
    'enter_domain_example_google_com': 'Enter domain, e.g.: google.com',
    'select_proxy_source': 'Select proxy source',
    'routing_screen_rule_added': 'Routing rule added',

    // Routing rules management interface
    'routing_rules_management': 'Routing Rules Management',
    'add_new_routing_rule': 'Add New Routing Rule',
    'website_or_ip_pattern': 'Website or IP Address Pattern',
    'example_google_com_or_8_8_8_8': 'Example: google.com or 8.8.8.8',
    'select_vpn_config': 'Select VPN Configuration',
    'force_use_vpn_type': 'Force Use VPN Type',
    'enable_rule': 'Enable Rule',
    'add_routing_rule': 'Add Routing Rule',
    'existing_routing_rules': 'Existing Routing Rules',
    'no_vpn_config_please_add_config':
        'No VPN configuration, please add configuration first',
    'no_routing_rules': 'No routing rules',
    'proxy_source': 'Proxy Source',
    'please_fill_complete_info': 'Please fill in complete information',
    'routing_rule_added': 'Routing rule added',
    'routing_rule_deleted': 'Routing rule deleted',
    'force_use_openvpn': 'Force Use OpenVPN',
    'force_use_clash': 'Force Use Clash',
    'force_use_shadowsocks': 'Force Use Shadowsocks',
    'force_use_v2ray': 'Force Use V2Ray',
    'force_use_http_proxy': 'Force Use HTTP Proxy',
    'force_use_socks5_proxy': 'Force Use SOCKS5 Proxy',
    'force_use_custom_proxy': 'Force Use Custom Proxy',
    'config_not_found': 'Configuration not found',
    'vpn_type_openvpn': 'OpenVPN',
    'vpn_type_clash': 'Clash',
    'vpn_type_shadowsocks': 'Shadowsocks',
    'vpn_type_v2ray': 'V2Ray',
    'vpn_type_http_proxy': 'HTTP Proxy',
    'vpn_type_socks5_proxy': 'SOCKS5 Proxy',
    'vpn_type_custom_proxy': 'Custom Proxy',

    // Configuration management interface
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

    // Proxy source management interface
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

    // Home interface
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
  };
}
