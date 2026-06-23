import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';

import '../../models/book_source.dart';
import '../../models/book_source_part.dart';
import '../../models/book_source_sort.dart';
import '../../store/use_source_store.dart';
import 'source_edit_page.dart';
import 'widgets/source_tile.dart';
import 'widgets/source_filter_bar.dart';
import 'widgets/source_batch_bar.dart';
import 'widgets/source_sort_menu.dart';
import 'widgets/subscription_dialog.dart';
import 'widgets/group_dialog.dart';

/// 源管理主页面
class SourcesPage extends HookWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = useSourceStore();
    final sources = store.select(context, (s) => s.sources);
    final groups = store.select(context, (s) => s.groups);

    // 多选状态
    final selectedUrls = useState<Set<String>>({});
    final isMultiSelectMode = useState(false);

    // 筛选状态
    final currentFilter = useState(0); // 0全部 1活跃 2禁用 3错误
    final currentGroup = useState<String?>(null);
    final currentType = useState<int?>(null);
    final searchKeyword = useState('');

    // 搜索控制器
    final searchController = useTextEditingController();
    final isSearchExpanded = useState(false);

    // 计算筛选后的源列表
    final filteredSources = useMemoized(() {
      var sourceParts = store.getSortedSourceParts();

      // 搜索筛选
      if (searchKeyword.value.isNotEmpty) {
        sourceParts = store.searchSources(searchKeyword.value);
      }

      // 状态筛选
      switch (currentFilter.value) {
        case 1: // 活跃
          sourceParts = sourceParts.where((s) => s.isActive).toList();
          break;
        case 2: // 禁用
          sourceParts = sourceParts.where((s) => s.isDisabled).toList();
          break;
        case 3: // 错误
          sourceParts = sourceParts.where((s) => s.isError).toList();
          break;
      }

      // 分组筛选
      if (currentGroup.value != null) {
        sourceParts = sourceParts.where((s) => s.hasGroup(currentGroup.value!)).toList();
      }

      // 类型筛选
      if (currentType.value != null) {
        sourceParts = sourceParts.where((s) => s.bookSourceType == currentType.value).toList();
      }

      return sourceParts;
    }, [
      sources,
      currentFilter.value,
      currentGroup.value,
      currentType.value,
      searchKeyword.value,
      store.select(context, (s) => s.sortBy),
      store.select(context, (s) => s.sortAscending),
    ]);

    return Scaffold(
      appBar: _buildAppBar(
        context,
        store,
        isMultiSelectMode,
        selectedUrls,
        isSearchExpanded,
        searchController,
        searchKeyword,
      ),
      body: Column(
        children: [
          // 筛选栏
          if (!isMultiSelectMode.value)
            SourceFilterBar(
              currentFilter: currentFilter.value,
              currentGroup: currentGroup.value,
              currentType: currentType.value,
              groups: groups,
              onFilterChanged: (value) => currentFilter.value = value,
              onGroupChanged: (value) => currentGroup.value = value,
              onTypeChanged: (value) => currentType.value = value,
            ),

          // 源列表
          Expanded(
            child: _buildSourceList(
              context,
              store,
              filteredSources,
              isMultiSelectMode,
              selectedUrls,
            ),
          ),
        ],
      ),

      // 批量操作栏
      bottomNavigationBar: isMultiSelectMode.value
          ? SourceBatchBar(
              selectedCount: selectedUrls.value.length,
              totalCount: filteredSources.length,
              onSelectAll: () {
                selectedUrls.value = filteredSources
                    .map((s) => s.bookSourceUrl)
                    .toSet();
              },
              onRevertSelection: () {
                final allUrls = filteredSources
                    .map((s) => s.bookSourceUrl)
                    .toSet();
                selectedUrls.value = allUrls.difference(selectedUrls.value);
              },
              onDelete: () => _batchDelete(context, store, selectedUrls),
              onEnable: () => _batchEnable(store, selectedUrls, true),
              onDisable: () => _batchEnable(store, selectedUrls, false),
              onEnableExplore: () => _batchEnableExplore(store, selectedUrls, true),
              onDisableExplore: () => _batchEnableExplore(store, selectedUrls, false),
              onTop: () => _batchTop(store, selectedUrls),
              onBottom: () => _batchBottom(store, selectedUrls),
              onExport: () => _batchExport(context, store, selectedUrls),
              onAddToGroup: () => _showAddToGroupDialog(context, store, selectedUrls),
            )
          : null,

      // FAB
      floatingActionButton: isMultiSelectMode.value
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddSourceDialog(context, store),
              child: const Icon(Icons.add),
            ),
    );
  }

  /// 构建 AppBar
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    SourceStore store,
    ValueNotifier<bool> isMultiSelectMode,
    ValueNotifier<Set<String>> selectedUrls,
    ValueNotifier<bool> isSearchExpanded,
    TextEditingController searchController,
    ValueNotifier<String> searchKeyword,
  ) {
    return AppBar(
      title: isMultiSelectMode.value
          ? Text('已选 ${selectedUrls.value.length} 项')
          : isSearchExpanded.value
              ? TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '搜索源...',
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        searchController.clear();
                        searchKeyword.value = '';
                        isSearchExpanded.value = false;
                      },
                    ),
                  ),
                  onChanged: (value) => searchKeyword.value = value,
                )
              : const Text('源管理'),
      leading: isMultiSelectMode.value
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                isMultiSelectMode.value = false;
                selectedUrls.value = {};
              },
            )
          : null,
      actions: [
        if (!isMultiSelectMode.value) ...[
          // 搜索按钮
          IconButton(
            icon: Icon(isSearchExpanded.value ? Icons.search_off : Icons.search),
            onPressed: () {
              isSearchExpanded.value = !isSearchExpanded.value;
              if (!isSearchExpanded.value) {
                searchController.clear();
                searchKeyword.value = '';
              }
            },
          ),

          // 排序菜单
          SourceSortMenu(
            currentSort: BookSourceSort.values[store.select(context, (s) => s.sortBy)],
            sortAscending: store.select(context, (s) => s.sortAscending),
            onSortChanged: (sort) => store.setSortBy(sort.index),
            onToggleDirection: () => store.toggleSortDirection(),
          ),

          // 更多菜单
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('添加源'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'test_all',
                child: ListTile(
                  leading: Icon(Icons.speed),
                  title: Text('测试全部'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text('导入'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('导出'),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'group',
                child: ListTile(
                  leading: Icon(Icons.folder),
                  title: Text('分组管理'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'subscription',
                child: ListTile(
                  leading: Icon(Icons.subscriptions),
                  title: Text('订阅管理'),
                  dense: true,
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'add':
                  _showAddSourceDialog(context, store);
                  break;
                case 'test_all':
                  _testAllSources(context, store);
                  break;
                case 'import':
                  _importSources(context, store);
                  break;
                case 'export':
                  _exportSources(context, store);
                  break;
                case 'group':
                  _showGroupDialog(context);
                  break;
                case 'subscription':
                  _showSubscriptionDialog(context);
                  break;
              }
            },
          ),
        ],
      ],
    );
  }

  /// 构建源列表
  Widget _buildSourceList(
    BuildContext context,
    SourceStore store,
    List<BookSourcePart> sources,
    ValueNotifier<bool> isMultiSelectMode,
    ValueNotifier<Set<String>> selectedUrls,
  ) {
    if (sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.source_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无源', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('点击右下角 + 添加源', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      );
    }

    // 手动排序模式使用 ReorderableListView
    if (store.select(context, (s) => s.sortBy) == BookSourceSort.custom.index) {
      return ReorderableListView.builder(
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex--;
          final source = sources[oldIndex];
          store.updateSource(
            store.getSource(source.bookSourceUrl)!.copyWith(
              customOrder: newIndex,
            ),
          );
          store.adjustSortNumbers();
        },
        itemCount: sources.length,
        itemBuilder: (context, index) {
          final source = sources[index];
          return SourceTile(
            key: ValueKey(source.bookSourceUrl),
            source: source,
            isSelected: selectedUrls.value.contains(source.bookSourceUrl),
            isMultiSelectMode: isMultiSelectMode.value,
            onTap: () => _handleTap(
              context,
              store,
              source,
              isMultiSelectMode,
              selectedUrls,
            ),
            onLongPress: () => _handleLongPress(
              source,
              isMultiSelectMode,
              selectedUrls,
            ),
            onSelectionChanged: (value) {
              final newSet = Set<String>.from(selectedUrls.value);
              if (value == true) {
                newSet.add(source.bookSourceUrl);
              } else {
                newSet.remove(source.bookSourceUrl);
              }
              selectedUrls.value = newSet;
              if (newSet.isEmpty) {
                isMultiSelectMode.value = false;
              }
            },
            onEdit: () => _editSource(context, source),
            onTest: () => _testSource(context, store, source),
            onDelete: () => _deleteSource(context, store, source),
          );
        },
      );
    }

    // 其他排序模式使用 ListView
    return ListView.builder(
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        return SourceTile(
          key: ValueKey(source.bookSourceUrl),
          source: source,
          isSelected: selectedUrls.value.contains(source.bookSourceUrl),
          isMultiSelectMode: isMultiSelectMode.value,
          onTap: () => _handleTap(
            context,
            store,
            source,
            isMultiSelectMode,
            selectedUrls,
          ),
          onLongPress: () => _handleLongPress(
            source,
            isMultiSelectMode,
            selectedUrls,
          ),
          onSelectionChanged: (value) {
            final newSet = Set<String>.from(selectedUrls.value);
            if (value == true) {
              newSet.add(source.bookSourceUrl);
            } else {
              newSet.remove(source.bookSourceUrl);
            }
            selectedUrls.value = newSet;
            if (newSet.isEmpty) {
              isMultiSelectMode.value = false;
            }
          },
          onEdit: () => _editSource(context, source),
          onTest: () => _testSource(context, store, source),
          onDelete: () => _deleteSource(context, store, source),
        );
      },
    );
  }

  // ========== 交互处理 ==========

  void _handleTap(
    BuildContext context,
    SourceStore store,
    BookSourcePart source,
    ValueNotifier<bool> isMultiSelectMode,
    ValueNotifier<Set<String>> selectedUrls,
  ) {
    if (isMultiSelectMode.value) {
      // 多选模式：切换选中状态
      final newSet = Set<String>.from(selectedUrls.value);
      if (newSet.contains(source.bookSourceUrl)) {
        newSet.remove(source.bookSourceUrl);
      } else {
        newSet.add(source.bookSourceUrl);
      }
      selectedUrls.value = newSet;
      if (newSet.isEmpty) {
        isMultiSelectMode.value = false;
      }
    } else {
      // 普通模式：进入编辑
      _editSource(context, source);
    }
  }

  void _handleLongPress(
    BookSourcePart source,
    ValueNotifier<bool> isMultiSelectMode,
    ValueNotifier<Set<String>> selectedUrls,
  ) {
    HapticFeedback.mediumImpact();
    isMultiSelectMode.value = true;
    selectedUrls.value = {source.bookSourceUrl};
  }

  // ========== 源操作 ==========

  void _editSource(BuildContext context, BookSourcePart source) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SourceEditPage(
          bookSourceUrl: source.bookSourceUrl,
        ),
      ),
    );
  }

  Future<void> _testSource(
    BuildContext context,
    SourceStore store,
    BookSourcePart source,
  ) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(content: Text('正在测试: ${source.bookSourceName}')),
    );

    final success = await store.testSource(source.bookSourceUrl);

    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(success ? '测试成功' : '测试失败'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _deleteSource(
    BuildContext context,
    SourceStore store,
    BookSourcePart source,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${source.bookSourceName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await store.removeSource(source.bookSourceUrl);
    }
  }

  // ========== 批量操作 ==========

  Future<void> _batchDelete(
    BuildContext context,
    SourceStore store,
    ValueNotifier<Set<String>> selectedUrls,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${selectedUrls.value.length} 个源吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await store.removeSources(selectedUrls.value.toList());
      selectedUrls.value = {};
    }
  }

  Future<void> _batchEnable(
    SourceStore store,
    ValueNotifier<Set<String>> selectedUrls,
    bool enable,
  ) async {
    await store.enableSources(selectedUrls.value.toList(), enable);
  }

  Future<void> _batchEnableExplore(
    SourceStore store,
    ValueNotifier<Set<String>> selectedUrls,
    bool enable,
  ) async {
    await store.enableExploreSources(selectedUrls.value.toList(), enable);
  }

  Future<void> _batchTop(
    SourceStore store,
    ValueNotifier<Set<String>> selectedUrls,
  ) async {
    await store.topSources(selectedUrls.value.toList());
  }

  Future<void> _batchBottom(
    SourceStore store,
    ValueNotifier<Set<String>> selectedUrls,
  ) async {
    await store.bottomSources(selectedUrls.value.toList());
  }

  Future<void> _batchExport(
    BuildContext context,
    SourceStore store,
    ValueNotifier<Set<String>> selectedUrls,
  ) async {
    await store.exportSources(urls: selectedUrls.value.toList());
    // TODO: 保存到文件
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出成功')),
      );
    }
  }

  void _showAddToGroupDialog(
    BuildContext context,
    SourceStore store,
    ValueNotifier<Set<String>> selectedUrls,
  ) {
    final groupController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加到分组'),
        content: TextField(
          controller: groupController,
          decoration: const InputDecoration(
            labelText: '分组名称',
            hintText: '输入或选择分组',
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
              if (groupController.text.isNotEmpty) {
                store.addToGroup(selectedUrls.value.toList(), groupController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  // ========== 全局操作 ==========

  void _showAddSourceDialog(BuildContext context, SourceStore store) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final groupController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '源名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '源地址',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: groupController,
              decoration: const InputDecoration(
                labelText: '分组（可选）',
                hintText: '多个分组用逗号分隔',
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
              if (nameController.text.isNotEmpty && urlController.text.isNotEmpty) {
                store.addSource(BookSource(
                  bookSourceUrl: urlController.text,
                  bookSourceName: nameController.text,
                  bookSourceGroup: groupController.text.isNotEmpty
                      ? groupController.text
                      : null,
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

  Future<void> _testAllSources(BuildContext context, SourceStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('测试全部'),
        content: Text('确定要测试全部 ${store.sourceCount} 个源吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final results = await store.testSources();
      final successCount = results.values.where((v) => v).length;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('测试完成: $successCount/${results.length} 成功')),
        );
      }
    }
  }

  Future<void> _importSources(BuildContext context, SourceStore store) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('从URL导入'),
              onTap: () {
                Navigator.pop(context);
                _showImportUrlDialog(context, store);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('从文件导入'),
              onTap: () {
                Navigator.pop(context);
                _importFromFile(context, store);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImportUrlDialog(BuildContext context, SourceStore store) {
    final urlController = TextEditingController();
    final isLoading = ValueNotifier(false);

    showDialog(
      context: context,
      builder: (dialogContext) => ValueListenableBuilder<bool>(
        valueListenable: isLoading,
        builder: (context, loading, _) => AlertDialog(
          title: const Text('从URL导入'),
          content: loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在导入...'),
                  ],
                )
              : TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    hintText: 'https://example.com/sources.json',
                    border: OutlineInputBorder(),
                  ),
                ),
          actions: loading
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (urlController.text.isNotEmpty) {
                        isLoading.value = true;
                        try {
                          final result = await store.importSources(urlController.text);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.hasErrors
                                    ? '导入完成: ${result.newCount} 新源, ${result.updatedCount} 更新, ${result.errors.length} 错误'
                                    : '导入成功: ${result.newCount} 个新源, ${result.updatedCount} 个更新'),
                                backgroundColor: result.hasErrors ? Colors.orange : Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          isLoading.value = false;
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('导入失败: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('导入'),
                  ),
                ],
        ),
      ),
    );
  }

  Future<void> _importFromFile(BuildContext context, SourceStore store) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      if (file.path == null) {
        return;
      }

      final content = await file.xFile.readAsString();
      final importResult = await store.importSources(content);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(importResult.hasErrors
                ? '导入完成: ${importResult.newCount} 新源, ${importResult.updatedCount} 更新, ${importResult.errors.length} 错误'
                : '导入成功: ${importResult.newCount} 个新源, ${importResult.updatedCount} 个更新'),
            backgroundColor: importResult.hasErrors ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportSources(BuildContext context, SourceStore store) async {
    await store.exportSources();
    // TODO: 保存到文件
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出成功')),
      );
    }
  }

  void _showGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const GroupDialog(),
    );
  }

  void _showSubscriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SubscriptionDialog(),
    );
  }
}
