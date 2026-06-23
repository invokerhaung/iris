import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../store/use_source_store.dart';

/// 分组管理对话框
class GroupDialog extends HookWidget {
  const GroupDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final store = useSourceStore();
    final groups = store.allGroups;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 标题栏
            _buildHeader(context, store),

            const Divider(),

            // 分组列表
            Expanded(
              child: groups.isEmpty
                  ? _buildEmptyState()
                  : _buildGroupList(context, store, groups),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SourceStore store) {
    return Row(
      children: [
        const Icon(Icons.folder, size: 24),
        const SizedBox(width: 8),
        const Text(
          '分组管理',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '添加分组',
          onPressed: () => _showAddDialog(context, store),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无分组',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(
    BuildContext context,
    SourceStore store,
    List<String> groups,
  ) {
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(group),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: '重命名',
                onPressed: () => _showRenameDialog(context, store, group),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: '删除',
                onPressed: () => _showDeleteConfirm(context, store, group),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, SourceStore store) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加分组'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '分组名称',
            hintText: '输入分组名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                store.addGroup(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    SourceStore store,
    String oldName,
  ) {
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty && controller.text != oldName) {
                store.renameGroup(oldName, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    SourceStore store,
    String group,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除分组 "$group" 吗？\n该分组下的源将被移出此分组。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              store.removeGroup(group);
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
