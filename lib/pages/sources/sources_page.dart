import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/source_subscription.dart';
import 'package:iris/models/video_source.dart';
import 'package:iris/pages/sources/source_edit_page.dart';
import 'package:iris/store/use_source_store.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SourcesPage extends HookWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final colorScheme = Theme.of(context).colorScheme;
    final sources =
        useSourceStore().select(context, (state) => state.sources);
    final currentSourceIndex =
        useSourceStore().select(context, (state) => state.currentSourceIndex);
    final groups =
        useSourceStore().select(context, (state) => state.groups);
    final sortBy =
        useSourceStore().select(context, (state) => state.sortBy);
    final sortAscending =
        useSourceStore().select(context, (state) => state.sortAscending);
    final subscriptions =
        useSourceStore().select(context, (state) => state.subscriptions);

    final nameController = useTextEditingController();
    final urlController = useTextEditingController();
    final selectedType = useState(SourceType.maccms);
    final selectedGroup = useState('');

    // 搜索与筛选状态
    final searchQuery = useState('');
    final filterStatus = useState<SourceStatus?>(null);
    final filterGroup = useState<String?>(null);

    // 测试状态
    final isTesting = useState(false);
    final testingIndex = useState<int?>(null);

    // 收集所有已使用的分组（含源中使用的）
    final allGroups = useMemoized(() {
      final fromSources =
          sources.map((s) => s.group).where((g) => g.isNotEmpty);
      return {...groups, ...fromSources}.toList()..sort();
    }, [sources, groups]);

    // 根据搜索和筛选条件过滤源列表
    final filteredSources = useMemoized(() {
      // 先排序
      var result = useSourceStore().getSortedSources();
      // 关键词搜索
      final query = searchQuery.value.trim().toLowerCase();
      if (query.isNotEmpty) {
        result = result.where((s) {
          return s.name.toLowerCase().contains(query) ||
              s.apiUrl.toLowerCase().contains(query) ||
              (s.comment?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
      // 状态筛选
      if (filterStatus.value != null) {
        result = result.where((s) => s.status == filterStatus.value).toList();
      }
      // 分组筛选
      if (filterGroup.value != null) {
        result = result.where((s) => s.group == filterGroup.value).toList();
      }
      return result;
    }, [
      sources,
      searchQuery.value,
      filterStatus.value,
      filterGroup.value,
      sortBy,
      sortAscending,
    ]);

    void addSource() {
      final name = nameController.text.trim();
      final url = urlController.text.trim();
      if (name.isEmpty || url.isEmpty) return;
      useSourceStore().addSource(VideoSource(
        id: '',
        name: name,
        apiUrl: url,
        type: selectedType.value,
        group: selectedGroup.value,
      ));
      nameController.clear();
      urlController.clear();
      if (selectedGroup.value.isNotEmpty &&
          !groups.contains(selectedGroup.value)) {
        useSourceStore().addGroup(selectedGroup.value);
      }
    }

    // 测试单个源
    Future<void> testSingleSource(int index) async {
      testingIndex.value = index;
      final result = await useSourceStore().testSource(index);
      testingIndex.value = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            result >= 0
                ? '${t.testSuccess} ($result ${t.ms})'
                : t.testFailed,
          ),
          duration: const Duration(seconds: 2),
        ));
      }
    }

    // 测试所有源
    Future<void> testAll() async {
      isTesting.value = true;
      await useSourceStore().testAllSources();
      isTesting.value = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t.testAllSources),
          duration: const Duration(seconds: 2),
        ));
      }
    }

    // 导出源
    Future<void> exportSources() async {
      try {
        final jsonStr = useSourceStore().exportSources();
        final dir = await getApplicationDocumentsDirectory();
        final now = DateTime.now();
        final fileName =
            'iris_sources_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(jsonStr);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${t.exportSuccess}: ${file.path}'),
            duration: const Duration(seconds: 3),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${t.exportFailed}: $e'),
            backgroundColor: colorScheme.error,
          ));
        }
      }
    }

    // 导入源
    Future<void> importSources() async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result == null || result.files.isEmpty) return;

        final file = File(result.files.first.path!);
        final jsonStr = await file.readAsString();

        if (!context.mounted) return;

        // 显示导入选项对话框
        final mode = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t.importMode),
            content: Text(jsonStr.length > 200
                ? '${jsonStr.substring(0, 200)}...'
                : jsonStr),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'merge'),
                child: Text(t.importMerge),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'replace'),
                child: Text(t.importReplace),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t.cancel),
              ),
            ],
          ),
        );

        if (mode == null || !context.mounted) return;

        final count = await useSourceStore()
            .importSources(jsonStr, merge: mode == 'merge');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t.importSuccess(count.toString())),
            duration: const Duration(seconds: 3),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${t.importFailed}: $e'),
            backgroundColor: colorScheme.error,
          ));
        }
      }
    }

    // 获取排序方式的本地化名称
    String sortLabel(SourceSortBy s) {
      switch (s) {
        case SourceSortBy.weight:
          return t.sortByWeight;
        case SourceSortBy.name:
          return t.sortByName;
        case SourceSortBy.apiUrl:
          return t.sortByUrl;
        case SourceSortBy.lastUpdateTime:
          return t.sortByUpdateTime;
        case SourceSortBy.respondTime:
          return t.sortByRespondTime;
        case SourceSortBy.status:
          return t.sortByStatus;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.sourceManagement),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current source card
          if (sources.isNotEmpty) ...[
            _SectionTitle(title: t.currentSource),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                ),
                title: Text(
                  sources[currentSourceIndex].name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  sources[currentSourceIndex].apiUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing:
                    _StatusChip(status: sources[currentSourceIndex].status),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ============================================================
          // 搜索栏
          // ============================================================
          _SectionTitle(title: t.sources),
          TextField(
            decoration: InputDecoration(
              hintText: t.searchSourceHint,
              prefixIcon: const Icon(Icons.search_rounded),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (value) => searchQuery.value = value,
          ),
          const SizedBox(height: 12),

          // ============================================================
          // 排序控制
          // ============================================================
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<SourceSortBy>(
                  initialValue: sortBy,
                  decoration: InputDecoration(
                    labelText: t.sortBy,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    prefixIcon: const Icon(Icons.sort_rounded),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: SourceSortBy.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(sortLabel(s)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) useSourceStore().setSortBy(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => useSourceStore().toggleSortDirection(),
                icon: Icon(sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded),
                tooltip: sortAscending ? t.sortAscending : t.sortDescending,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ============================================================
          // 状态筛选 Chips
          // ============================================================
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(t.all),
                selected: filterStatus.value == null,
                onSelected: (_) => filterStatus.value = null,
              ),
              FilterChip(
                label: Text(t.active),
                selected: filterStatus.value == SourceStatus.active,
                onSelected: (_) => filterStatus.value =
                    filterStatus.value == SourceStatus.active
                        ? null
                        : SourceStatus.active,
              ),
              FilterChip(
                label: Text(t.inactive),
                selected: filterStatus.value == SourceStatus.inactive,
                onSelected: (_) => filterStatus.value =
                    filterStatus.value == SourceStatus.inactive
                        ? null
                        : SourceStatus.inactive,
              ),
              FilterChip(
                label: Text(t.error),
                selected: filterStatus.value == SourceStatus.error,
                onSelected: (_) => filterStatus.value =
                    filterStatus.value == SourceStatus.error
                        ? null
                        : SourceStatus.error,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ============================================================
          // 分组筛选下拉
          // ============================================================
          if (allGroups.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: filterGroup.value,
              decoration: InputDecoration(
                labelText: t.group,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: const Icon(Icons.folder_outlined),
              ),
              borderRadius: BorderRadius.circular(12),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(t.allGroups),
                ),
                ...allGroups.map((g) => DropdownMenuItem<String?>(
                      value: g,
                      child: Text(g),
                    )),
              ],
              onChanged: (value) => filterGroup.value = value,
            ),
          const SizedBox(height: 12),

          // ============================================================
          // 批量操作栏
          // ============================================================
          if (sources.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isTesting.value ? null : testAll,
                    icon: isTesting.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check_rounded),
                    label: Text(t.testAllSources),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),

          // ============================================================
          // 源列表
          // ============================================================
          if (filteredSources.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withAlpha(128)),
                      const SizedBox(height: 12),
                      Text(
                        t.noSources,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...filteredSources.map((source) {
              final originalIndex = sources.indexOf(source);
              final isCurrent = originalIndex == currentSourceIndex;
              final isTestingThis = testingIndex.value == originalIndex;
              return Card(
                color: isCurrent
                    ? colorScheme.primaryContainer.withAlpha(64)
                    : null,
                child: ListTile(
                  leading: Icon(
                    isCurrent
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isCurrent ? colorScheme.primary : null,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(source.name)),
                      if (source.weight > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${source.weight}',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.apiUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (source.group.isNotEmpty) ...[
                            Icon(Icons.folder_outlined,
                                size: 12, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Text(
                              source.group,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (source.respondTime > 0) ...[
                            Icon(Icons.timer_outlined,
                                size: 12, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Text(
                              '${source.respondTime} ${t.ms}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusChip(status: source.status),
                      const SizedBox(width: 4),
                      if (isTestingThis)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant),
                        onSelected: (value) {
                          switch (value) {
                            case 'select':
                              useSourceStore()
                                  .updateCurrentSourceIndex(originalIndex);
                              break;
                            case 'edit':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SourceEditPage(
                                    source: source,
                                    sourceIndex: originalIndex,
                                  ),
                                ),
                              );
                              break;
                            case 'test':
                              testSingleSource(originalIndex);
                              break;
                            case 'delete':
                              useSourceStore().removeSource(source.id);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (!isCurrent)
                            PopupMenuItem(
                              value: 'select',
                              child: Text(t.selectSource),
                            ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(t.edit),
                          ),
                          PopupMenuItem(
                            value: 'test',
                            child: Text(t.testSource),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(t.deleteSource),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () =>
                      useSourceStore().updateCurrentSourceIndex(originalIndex),
                ),
              );
            }),

          const SizedBox(height: 24),

          // ============================================================
          // 添加源表单
          // ============================================================
          _SectionTitle(title: t.addSource),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: t.sourceName,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: t.sourceApiUrl,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SourceType>(
                    initialValue: selectedType.value,
                    decoration: InputDecoration(
                      labelText: t.sourceType,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(
                        value: SourceType.maccms,
                        child: Text('MacCMS'),
                      ),
                      DropdownMenuItem(
                        value: SourceType.universal,
                        child: Text(t.universal),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) selectedType.value = value;
                    },
                  ),
                  const SizedBox(height: 12),
                  // 分组选择（支持从已有分组选择或输入新分组）
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return allGroups;
                      }
                      return allGroups.where((g) => g
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (value) => selectedGroup.value = value,
                    fieldViewBuilder: (context, controller, focusNode,
                        onFieldSubmitted) {
                      useEffect(() {
                        controller.text = selectedGroup.value;
                        return null;
                      }, [selectedGroup.value]);
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: t.group,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.folder_outlined),
                        ),
                        onChanged: (value) => selectedGroup.value = value,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: addSource,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(t.addSource),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ============================================================
          // 订阅管理
          // ============================================================
          _SectionTitle(title: t.subscription),
          _SubscriptionSection(
            subscriptions: subscriptions,
            t: t,
            colorScheme: colorScheme,
          ),

          const SizedBox(height: 24),

          // ============================================================
          // 导入导出
          // ============================================================
          _SectionTitle(title: '${t.importSources} / ${t.exportSources}'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: importSources,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: Text(t.importSources),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: exportSources,
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text(t.exportSources),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 80), // Bottom padding for NavigationBar
        ],
      ),
    );
  }
}

/// 订阅管理组件
class _SubscriptionSection extends HookWidget {
  const _SubscriptionSection({
    required this.subscriptions,
    required this.t,
    required this.colorScheme,
  });

  final List<SourceSubscription> subscriptions;
  final dynamic t;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isSyncing = useState(false);
    final syncingUrl = useState<String?>(null);
    final urlController = useTextEditingController();
    final nameController = useTextEditingController();

    // 添加订阅对话框
    Future<void> showAddDialog() async {
      urlController.clear();
      nameController.clear();
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.addSubscription),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: t.subscriptionName,
                  hintText: t.subscriptionNameHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: t.subscriptionUrl,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.rss_feed_rounded),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () {
                final url = urlController.text.trim();
                final name = nameController.text.trim();
                if (url.isEmpty) return;
                useSourceStore().addSubscription(SourceSubscription(
                  name: name.isEmpty ? url : name,
                  url: url,
                ));
                Navigator.pop(ctx, true);
              },
              child: Text(t.add),
            ),
          ],
        ),
      );
      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t.addSubscription),
          duration: const Duration(seconds: 1),
        ));
      }
    }

    // 同步单个订阅
    Future<void> syncOne(String url) async {
      syncingUrl.value = url;
      final count = await useSourceStore().syncSubscription(url);
      syncingUrl.value = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            count >= 0
                ? '${t.syncSuccess} ($count ${t.sources})'
                : t.syncFailed,
          ),
          duration: const Duration(seconds: 2),
        ));
      }
    }

    // 同步所有订阅
    Future<void> syncAll() async {
      isSyncing.value = true;
      await useSourceStore().syncAllSubscriptions();
      isSyncing.value = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t.syncSuccess),
          duration: const Duration(seconds: 2),
        ));
      }
    }

    // 格式化时间
    String formatTime(int timestamp) {
      if (timestamp == 0) return t.never;
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 操作按钮行
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSyncing.value ? null : syncAll,
                    icon: isSyncing.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(t.syncAllSubscriptions),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: showAddDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.addSubscription),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 订阅列表
            if (subscriptions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.rss_feed_outlined,
                          size: 36,
                          color: colorScheme.onSurfaceVariant.withAlpha(128)),
                      const SizedBox(height: 8),
                      Text(
                        t.noSubscriptions,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...subscriptions.map((sub) {
                final isSyncingThis = syncingUrl.value == sub.url;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.rss_feed_rounded,
                      color: sub.lastSyncSuccess == true
                          ? Colors.green
                          : sub.lastSyncSuccess == false
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                    ),
                    title: Text(sub.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${t.lastSync}: ${formatTime(sub.lastSyncTime)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (sub.sourceCount > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${t.sourceCount}: ${sub.sourceCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSyncingThis)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            onPressed: () => syncOne(sub.url),
                            icon: const Icon(Icons.sync_rounded, size: 20),
                            tooltip: t.syncSubscription,
                          ),
                        IconButton(
                          onPressed: () =>
                              useSourceStore().removeSubscription(sub.url),
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 20, color: colorScheme.error),
                          tooltip: t.removeSubscription,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SourceStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color color;
    String label;
    switch (status) {
      case SourceStatus.active:
        color = Colors.green;
        label = '正常'; // TODO: use l10n
        break;
      case SourceStatus.inactive:
        color = Colors.orange;
        label = '离线';
        break;
      case SourceStatus.error:
        color = colorScheme.error;
        label = '错误';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}
