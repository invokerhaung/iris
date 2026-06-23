import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../models/source_subscription.dart';
import '../../../store/use_source_store.dart';
import 'source_styles.dart';

/// 订阅管理对话框
class SubscriptionDialog extends HookWidget {
  const SubscriptionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final store = useSourceStore();
    final subscriptions = store.subscriptions;
    final isSyncing = useState(false);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 标题栏
            _buildHeader(context, store, isSyncing),

            const Divider(),

            // 订阅列表
            Expanded(
              child: subscriptions.isEmpty
                  ? _buildEmptyState()
                  : _buildSubscriptionList(context, store, subscriptions),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(
    BuildContext context,
    SourceStore store,
    ValueNotifier<bool> isSyncing,
  ) {
    return Row(
      children: [
        const Icon(Icons.subscriptions, size: 24),
        const SizedBox(width: 8),
        const Text(
          '订阅管理',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '添加订阅',
          onPressed: () => _showAddDialog(context, store),
        ),
        IconButton(
          icon: isSyncing.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          tooltip: '同步全部',
          onPressed: isSyncing.value
              ? null
              : () async {
                  isSyncing.value = true;
                  await store.syncAllSubscriptions();
                  isSyncing.value = false;
                },
        ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.subscriptions_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无订阅',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 添加订阅',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建订阅列表
  Widget _buildSubscriptionList(
    BuildContext context,
    SourceStore store,
    List<SourceSubscription> subscriptions,
  ) {
    return ListView.builder(
      itemCount: subscriptions.length,
      itemBuilder: (context, index) {
        final sub = subscriptions[index];
        return _SubscriptionTile(
          subscription: sub,
          onSync: () async {
            await store.syncSubscription(sub.url);
          },
          onDelete: () => _showDeleteConfirm(context, store, sub.url),
          onToggleAutoSync: (value) {
            store.updateSubscription(
              sub.url,
              sub.copyWith(autoSync: value),
            );
          },
        );
      },
    );
  }

  /// 显示添加对话框
  void _showAddDialog(BuildContext context, SourceStore store) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '订阅名称',
                hintText: '例如：我的订阅',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '订阅URL',
                hintText: 'https://example.com/sources.json',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  urlController.text.isNotEmpty) {
                store.addSubscription(SourceSubscription(
                  name: nameController.text,
                  url: urlController.text,
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  /// 显示删除确认
  void _showDeleteConfirm(BuildContext context, SourceStore store, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个订阅吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              store.removeSubscription(url);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 订阅列表项
class _SubscriptionTile extends StatelessWidget {
  final SourceSubscription subscription;
  final VoidCallback onSync;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleAutoSync;

  const _SubscriptionTile({
    required this.subscription,
    required this.onSync,
    required this.onDelete,
    required this.onToggleAutoSync,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：名称 + 状态
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subscription.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                _buildSyncButton(),
                _buildDeleteButton(),
              ],
            ),

            const SizedBox(height: 8),

            // 第二行：URL
            Text(
              subscription.url,
              style: SourceStyles.subtitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // 第三行：统计信息
            _buildInfoRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    if (subscription.lastSyncSuccess == true) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (subscription.lastSyncSuccess == false) {
      icon = Icons.error;
      color = Colors.red;
    } else {
      icon = Icons.sync_disabled;
      color = Colors.grey;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildSyncButton() {
    return IconButton(
      icon: const Icon(Icons.sync),
      tooltip: '同步',
      onPressed: onSync,
    );
  }

  Widget _buildDeleteButton() {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      tooltip: '删除',
      onPressed: onDelete,
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        // 源数量
        _buildInfoChip(
          icon: Icons.source,
          label: '${subscription.sourceCount} 个源',
        ),

        const SizedBox(width: 16),

        // 同步时间
        _buildInfoChip(
          icon: Icons.access_time,
          label: _formatTime(subscription.lastSyncTime),
        ),

        const Spacer(),

        // 自动同步开关
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('自动同步', style: TextStyle(fontSize: 12)),
            Switch(
              value: subscription.autoSync,
              onChanged: onToggleAutoSync,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: SourceStyles.subtitleStyle),
      ],
    );
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null || timestamp == 0) return '从未同步';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.month}-${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
