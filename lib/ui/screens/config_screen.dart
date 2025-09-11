import 'package:flutter/material.dart';
import 'package:dualvpn_manager/models/vpn_config.dart';
import 'package:dualvpn_manager/utils/config_manager.dart';
import 'package:provider/provider.dart';
import 'package:dualvpn_manager/models/app_state.dart';
import 'dart:math' as dart_math;

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  List<VPNConfig> configs = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 添加编辑状态的控制器
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editPathController = TextEditingController();
  final TextEditingController _editServerController = TextEditingController();
  final TextEditingController _editPortController = TextEditingController();
  final TextEditingController _editUsernameController = TextEditingController();
  final TextEditingController _editPasswordController = TextEditingController();

  VPNType _selectedType = VPNType.openVPN;
  VPNType _editSelectedType = VPNType.openVPN;
  bool _showAdvancedSettings = false;
  VPNConfig? _editingConfig; // 当前正在编辑的配置

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  // 加载配置列表
  void _loadConfigs() async {
    final loadedConfigs = await ConfigManager.loadConfigs();
    // 确保在组件仍然挂载时更新状态
    if (mounted) {
      setState(() {
        configs = loadedConfigs;
      });
    }
  }

  // 添加新配置
  void _addConfig() async {
    if (_nameController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请填写配置名称')));
      }
      return;
    }

    // 根据类型构建配置路径和设置
    String configPath = '';
    Map<String, dynamic> settings = {};

    if (_selectedType == VPNType.openVPN ||
        _selectedType == VPNType.clash ||
        _selectedType.supportsSubscription) {
      // 对于OpenVPN、Clash和支持订阅的类型，使用路径或订阅链接
      if (_pathController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请填写配置路径或订阅链接')));
        }
        return;
      }
      configPath = _pathController.text;
    } else {
      // 对于其他类型，使用服务器地址和端口
      if (_serverController.text.isEmpty || _portController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请填写服务器地址和端口')));
        }
        return;
      }
      configPath = '${_serverController.text}:${_portController.text}';
      settings['server'] = _serverController.text;
      settings['port'] = int.tryParse(_portController.text) ?? 0;
      settings['username'] = _usernameController.text;
      settings['password'] = _passwordController.text;
    }

    final newConfig = VPNConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      type: _selectedType,
      configPath: configPath,
      settings: settings,
    );

    await ConfigManager.addConfig(newConfig);
    _loadConfigs();

    // 清空输入框
    _nameController.clear();
    _pathController.clear();
    _serverController.clear();
    _portController.clear();
    _usernameController.clear();
    _passwordController.clear();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配置已添加')));
    }
  }

  // 删除配置
  void _deleteConfig(String id) async {
    await ConfigManager.deleteConfig(id);
    _loadConfigs();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配置已删除')));
    }
  }

  // 测试连接延迟
  void _testLatency(VPNConfig config) async {
    // 模拟延迟测试
    if (mounted) {
      // 更新配置状态为测试中
      final updatedConfigs = configs.map((c) {
        if (c.id == config.id) {
          return c.copyWith(connectionStatus: ConnectionStatus.connecting);
        }
        return c;
      }).toList();

      setState(() {
        configs = updatedConfigs;
      });

      // 模拟网络延迟测试
      await Future.delayed(const Duration(seconds: 1));

      // 生成随机延迟值(10-1500ms)以测试颜色显示
      final random = dart_math.Random();
      final latency = 10 + random.nextInt(1491); // 10 to 1500

      // 更新配置状态和延迟
      final finalConfigs = updatedConfigs.map((c) {
        if (c.id == config.id) {
          return c.copyWith(
            connectionStatus: ConnectionStatus.disconnected,
            latency: latency,
          );
        }
        return c;
      }).toList();

      setState(() {
        configs = finalConfigs;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('延迟测试完成: ${latency}ms')));
    }
  }

  // 更新订阅(仅适用于支持订阅的代理类型)
  void _updateSubscription(VPNConfig config) async {
    if (!config.type.supportsSubscription) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该配置类型不支持订阅更新')));
      }
      return;
    }

    if (!config.configPath.startsWith('http')) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置不是订阅链接')));
      }
      return;
    }

    if (mounted) {
      // 显示更新中的提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在更新订阅...')));
    }

    try {
      // 通过AppState调用订阅更新功能
      final appState = Provider.of<AppState>(context, listen: false);
      final result = await appState.updateSubscription(config);

      if (mounted) {
        if (result) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('订阅更新成功')));

          // 更新配置列表以显示最新状态
          _loadConfigs();

          // 清除AppState中的代理列表缓存并重新加载
          // 这样可以确保代理列表显示最新的订阅内容
          appState.clearProxyCache(config.id); // 清除指定配置的代理列表缓存
          if (appState.selectedConfig == config.id) {
            // 如果当前选中的配置就是更新的配置，则重新加载代理列表
            appState.loadProxies();
          }
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('订阅更新失败')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('订阅更新失败: $e')));
      }
    }
  }

  // 编辑配置
  void _editConfig(VPNConfig config) {
    setState(() {
      _editingConfig = config;
      _editNameController.text = config.name;
      _editSelectedType = config.type;
      _editPathController.text = config.configPath;

      // 如果是服务器类型配置，解析服务器信息
      if (config.type != VPNType.openVPN &&
          config.type != VPNType.clash &&
          !config.type.supportsSubscription) {
        final parts = config.configPath.split(':');
        if (parts.length == 2) {
          _editServerController.text = parts[0];
          _editPortController.text = parts[1];
        }
        _editUsernameController.text =
            config.settings['username']?.toString() ?? '';
        _editPasswordController.text =
            config.settings['password']?.toString() ?? '';
      }
    });

    // 显示编辑对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('编辑代理源'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _editNameController,
                  decoration: const InputDecoration(labelText: '代理源名称'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<VPNType>(
                  value: _editSelectedType,
                  decoration: const InputDecoration(labelText: '代理类型'),
                  items: VPNType.values.map((type) {
                    String label;
                    switch (type) {
                      case VPNType.openVPN:
                        label = 'OpenVPN (.ovpn/.conf/.tblk)';
                        break;
                      case VPNType.clash:
                        label = 'Clash (配置文件/订阅链接)';
                        break;
                      case VPNType.shadowsocks:
                        label = type.supportsSubscription
                            ? 'Shadowsocks (配置文件/订阅链接)'
                            : 'Shadowsocks';
                        break;
                      case VPNType.v2ray:
                        label = type.supportsSubscription
                            ? 'V2Ray (配置文件/订阅链接)'
                            : 'V2Ray';
                        break;
                      case VPNType.httpProxy:
                        label = 'HTTP代理';
                        break;
                      case VPNType.socks5:
                        label = 'SOCKS5代理';
                        break;
                      case VPNType.custom:
                        label = '自定义代理';
                        break;
                    }
                    return DropdownMenuItem(value: type, child: Text(label));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _editSelectedType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                // 根据类型显示不同的输入字段
                if (_editSelectedType == VPNType.openVPN ||
                    _editSelectedType == VPNType.clash ||
                    _editSelectedType.supportsSubscription)
                  TextField(
                    controller: _editPathController,
                    decoration: InputDecoration(
                      labelText: _editSelectedType == VPNType.openVPN
                          ? '配置文件路径'
                          : _editSelectedType.supportsSubscription
                          ? '配置文件路径或订阅链接'
                          : '配置文件路径',
                    ),
                  )
                else
                  Column(
                    children: [
                      TextField(
                        controller: _editServerController,
                        decoration: const InputDecoration(labelText: '服务器地址'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _editPortController,
                        decoration: const InputDecoration(labelText: '端口'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _editUsernameController,
                        decoration: const InputDecoration(labelText: '用户名(可选)'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _editPasswordController,
                        decoration: const InputDecoration(labelText: '密码(可选)'),
                        obscureText: true,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _editingConfig = null;
                });
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveEditedConfig();
                Navigator.of(context).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // 保存编辑后的配置
  void _saveEditedConfig() async {
    if (_editNameController.text.isEmpty || _editingConfig == null) {
      return;
    }

    // 根据类型构建配置路径和设置
    String configPath = '';
    Map<String, dynamic> settings = {};

    if (_editSelectedType == VPNType.openVPN ||
        _editSelectedType == VPNType.clash ||
        _editSelectedType.supportsSubscription) {
      // 对于OpenVPN、Clash和支持订阅的类型，使用路径或订阅链接
      if (_editPathController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请填写配置路径或订阅链接')));
        }
        return;
      }
      configPath = _editPathController.text;
    } else {
      // 对于其他类型，使用服务器地址和端口
      if (_editServerController.text.isEmpty ||
          _editPortController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请填写服务器地址和端口')));
        }
        return;
      }
      configPath = '${_editServerController.text}:${_editPortController.text}';
      settings['server'] = _editServerController.text;
      settings['port'] = int.tryParse(_editPortController.text) ?? 0;
      settings['username'] = _editUsernameController.text;
      settings['password'] = _editPasswordController.text;
    }

    final updatedConfig = _editingConfig!.copyWith(
      name: _editNameController.text,
      type: _editSelectedType,
      configPath: configPath,
      settings: settings,
    );

    await ConfigManager.updateConfig(updatedConfig);
    _loadConfigs();

    // 如果当前有AppState实例，清除该配置的代理缓存
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.clearProxyCache(updatedConfig.id); // 清除该配置的代理列表缓存
    } catch (e) {
      // 如果无法获取AppState，忽略错误
    }

    // 清空编辑状态
    setState(() {
      _editingConfig = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配置已更新')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('代理源管理'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // 添加测试按钮
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              // 显示所有配置的调试信息
              String debugInfo = '配置数量: ${configs.length}\n';
              for (var i = 0; i < configs.length; i++) {
                final config = configs[i];
                debugInfo +=
                    '配置 $i: ${config.name}, 类型: ${config.type}, 路径: ${config.configPath}\n';
                debugInfo +=
                    '  是否显示更新按钮: ${config.type == VPNType.clash && config.configPath.startsWith('http')}\n';
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(debugInfo)));
            },
            tooltip: '调试信息',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 添加配置表单
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '添加新代理源',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '代理源名称',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<VPNType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: '代理类型',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: VPNType.values.map((type) {
                          String label;
                          switch (type) {
                            case VPNType.openVPN:
                              label = 'OpenVPN (.ovpn/.conf/.tblk)';
                              break;
                            case VPNType.clash:
                              label = 'Clash (配置文件/订阅链接)';
                              break;
                            case VPNType.shadowsocks:
                              label = type.supportsSubscription
                                  ? 'Shadowsocks (配置文件/订阅链接)'
                                  : 'Shadowsocks';
                              break;
                            case VPNType.v2ray:
                              label = type.supportsSubscription
                                  ? 'V2Ray (配置文件/订阅链接)'
                                  : 'V2Ray';
                              break;
                            case VPNType.httpProxy:
                              label = 'HTTP代理';
                              break;
                            case VPNType.socks5:
                              label = 'SOCKS5代理';
                              break;
                            case VPNType.custom:
                              label = '自定义代理';
                              break;
                          }
                          return DropdownMenuItem(
                            value: type,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // 根据类型显示不同的输入字段
                      if (_selectedType == VPNType.openVPN ||
                          _selectedType == VPNType.clash ||
                          _selectedType.supportsSubscription)
                        TextField(
                          controller: _pathController,
                          decoration: InputDecoration(
                            labelText: _selectedType == VPNType.openVPN
                                ? '配置文件路径'
                                : _selectedType.supportsSubscription
                                ? '配置文件路径或订阅链接'
                                : '配置文件路径',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.file_present),
                          ),
                        )
                      else
                        Column(
                          children: [
                            TextField(
                              controller: _serverController,
                              decoration: const InputDecoration(
                                labelText: '服务器地址',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.dns),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _portController,
                              decoration: const InputDecoration(
                                labelText: '端口',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.portrait),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: '用户名(可选)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: '密码(可选)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock),
                              ),
                              obscureText: true,
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addConfig,
                          icon: const Icon(Icons.add),
                          label: const Text('添加代理源'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 配置列表
              const Text(
                '代理源列表',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: configs.length,
                itemBuilder: (context, index) {
                  final config = configs[index];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: config.isActive ? Colors.blue : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: child,
                                );
                              },
                          child: Icon(
                            _getIconForType(config.type),
                            key: ValueKey<ConnectionStatus>(
                              config.connectionStatus,
                            ),
                            color: _getStatusColor(config.connectionStatus),
                          ),
                        ),
                        title: Text(
                          config.name,
                          style: TextStyle(
                            fontWeight: config.isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_getTypeLabel(config.type)),
                            if (config.latency >= 0)
                              Text(
                                '延迟: ${config.latency}ms',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: config.latency < 300
                                      ? Colors.green
                                      : config.latency < 1000
                                      ? Colors.deepOrange
                                      : Colors.red,
                                ),
                              ),
                            // 调试信息：显示配置路径
                            Text(
                              '路径: ${config.configPath}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            // 显示启用状态
                            Text(
                              config.isActive ? '状态: 已启用' : '状态: 已禁用',
                              style: TextStyle(
                                fontSize: 12,
                                color: config.isActive
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 测试延迟按钮
                            IconButton(
                              icon: const Icon(Icons.speed),
                              onPressed: () => _testLatency(config),
                              tooltip: '测试延迟',
                            ),
                            // 订阅更新按钮(仅适用于支持订阅的代理类型)
                            if (config.type.supportsSubscription &&
                                config.configPath.startsWith('http'))
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => _updateSubscription(config),
                                tooltip: '更新订阅',
                              ),
                            // 编辑按钮
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editConfig(config),
                              tooltip: '编辑配置',
                            ),
                            // 使用Switch并正确设置value参数
                            Switch(
                              value: config.isActive,
                              onChanged: (value) {
                                // 更新配置状态
                                _updateConfigStatus(config, value);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteConfig(config.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 获取类型的图标
  IconData _getIconForType(VPNType type) {
    switch (type) {
      case VPNType.openVPN:
        return Icons.vpn_lock;
      case VPNType.clash:
        return Icons.shield;
      case VPNType.shadowsocks:
      case VPNType.v2ray:
        return Icons.link;
      case VPNType.httpProxy:
      case VPNType.socks5:
        return Icons.http;
      case VPNType.custom:
        return Icons.settings;
    }
  }

  // 获取类型标签
  String _getTypeLabel(VPNType type) {
    switch (type) {
      case VPNType.openVPN:
        return 'OpenVPN';
      case VPNType.clash:
        return 'Clash';
      case VPNType.shadowsocks:
        return 'Shadowsocks';
      case VPNType.v2ray:
        return 'V2Ray';
      case VPNType.httpProxy:
        return 'HTTP代理';
      case VPNType.socks5:
        return 'SOCKS5代理';
      case VPNType.custom:
        return '自定义代理';
    }
  }

  // 获取状态颜色
  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
      case ConnectionStatus.disconnecting:
        return Colors.orange;
      case ConnectionStatus.error:
        return Colors.red;
      case ConnectionStatus.disconnected:
        return Colors.grey;
    }
  }

  // 更新配置状态
  void _updateConfigStatus(VPNConfig config, bool isActive) async {
    // 创建更新后的配置对象
    final updatedConfig = config.copyWith(isActive: isActive);

    // 更新配置
    await ConfigManager.updateConfig(updatedConfig);
    _loadConfigs();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('配置已${isActive ? '启用' : '禁用'}')));
    }
  }
}
