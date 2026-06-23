import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/store/use_app_store.dart';

/// 网络设置
class Network extends HookWidget {
  const Network({super.key});

  @override
  Widget build(BuildContext context) {
    final appStore = useAppStore();
    final enableProxy = appStore.select(context, (s) => s.enableProxy);
    final proxyHost = appStore.select(context, (s) => s.proxyHost);
    final proxyPort = appStore.select(context, (s) => s.proxyPort);

    final hostController = useTextEditingController(text: proxyHost);
    final portController = useTextEditingController(text: proxyPort.toString());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 代理设置标题
        const Text(
          '代理设置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '配置代理服务器以访问需要代理的网站',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),

        // 启用代理开关
        SwitchListTile(
          title: const Text('启用代理'),
          subtitle: const Text('通过代理服务器发送网络请求'),
          value: enableProxy,
          onChanged: (value) {
            appStore.updateEnableProxy(value);
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(height: 16),

        // 代理地址
        TextFormField(
          controller: hostController,
          decoration: const InputDecoration(
            labelText: '代理地址',
            hintText: '127.0.0.1',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.dns_outlined),
          ),
          enabled: enableProxy,
          onChanged: (value) {
            appStore.updateProxyHost(value);
          },
        ),
        const SizedBox(height: 16),

        // 代理端口
        TextFormField(
          controller: portController,
          decoration: const InputDecoration(
            labelText: '代理端口',
            hintText: '7890',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.numbers),
          ),
          keyboardType: TextInputType.number,
          enabled: enableProxy,
          onChanged: (value) {
            final port = int.tryParse(value);
            if (port != null) {
              appStore.updateProxyPort(port);
            }
          },
        ),
        const SizedBox(height: 24),

        // 常见代理软件端口提示
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '常见代理软件端口',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildProxyHint('Clash', '7890'),
                _buildProxyHint('V2Ray', '10809'),
                _buildProxyHint('Shadowsocks', '1080'),
                _buildProxyHint('SSR', '1080'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 测试代理按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: enableProxy
                ? () async {
                    // TODO: 测试代理连接
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('代理测试功能开发中...')),
                    );
                  }
                : null,
            icon: const Icon(Icons.network_check),
            label: const Text('测试代理连接'),
          ),
        ),
      ],
    );
  }

  /// 构建代理提示
  Widget _buildProxyHint(String name, String port) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$name:',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            port,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
