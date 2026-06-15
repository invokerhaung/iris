import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/video_source.dart';
import 'package:iris/store/use_source_store.dart';
import 'package:iris/utils/get_localizations.dart';

/// 源编辑页面
/// 基础信息 Tab：名称、URL、类型、分组、权重、NSFW 标记
/// 配置 Tab：解析地址、自定义请求头、注释
class SourceEditPage extends HookWidget {
  const SourceEditPage({super.key, required this.source, this.sourceIndex});

  final VideoSource source;
  final int? sourceIndex;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final colorScheme = Theme.of(context).colorScheme;
    final store = useSourceStore();
    final groups = store.select(context, (state) => state.groups);

    // 收集所有分组
    final allGroups = useMemoized(() {
      final fromSources = store.state.sources
          .map((s) => s.group)
          .where((g) => g.isNotEmpty);
      return {...groups, ...fromSources}.toList()..sort();
    }, [groups]);

    // 编辑状态
    final nameController = useTextEditingController(text: source.name);
    final urlController = useTextEditingController(text: source.apiUrl);
    final jiexiController = useTextEditingController(text: source.jiexiUrl ?? '');
    final headerController = useTextEditingController(
        text: source.header ?? '');
    final commentController = useTextEditingController(
        text: source.comment ?? '');
    final weightController = useTextEditingController(
        text: source.weight.toString());
    final selectedType = useState(source.type);
    final selectedGroup = useState(source.group);
    final isNsfw = useState(source.isNsfw);

    // 保存
    Future<void> save() async {
      final name = nameController.text.trim();
      final url = urlController.text.trim();
      if (name.isEmpty || url.isEmpty) return;

      final weight = int.tryParse(weightController.text.trim()) ?? 0;
      final updated = source.copyWith(
        name: name,
        apiUrl: url,
        type: selectedType.value,
        group: selectedGroup.value,
        weight: weight,
        isNsfw: isNsfw.value,
        jiexiUrl: jiexiController.text.trim().isEmpty
            ? null
            : jiexiController.text.trim(),
        header: headerController.text.trim().isEmpty
            ? null
            : headerController.text.trim(),
        comment: commentController.text.trim().isEmpty
            ? null
            : commentController.text.trim(),
      );

      await store.updateSource(updated);

      // 如果分组不在列表中，自动添加
      if (selectedGroup.value.isNotEmpty &&
          !store.state.groups.contains(selectedGroup.value)) {
        await store.addGroup(selectedGroup.value);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t.saveSuccess),
          duration: const Duration(seconds: 1),
        ));
        Navigator.pop(context);
      }
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.editSource),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.info_outline_rounded), text: t.basicInfo),
              Tab(icon: const Icon(Icons.tune_rounded), text: t.advancedConfig),
            ],
          ),
          actions: [
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check_rounded),
              label: Text(t.save),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: TabBarView(
          children: [
            // ================================================================
            // Tab 1: 基础信息
            // ================================================================
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 源名称
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: t.sourceName,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // 接口地址
                TextFormField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: t.sourceApiUrl,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link_rounded),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),

                // 源类型
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
                const SizedBox(height: 16),

                // 分组选择
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
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
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

                // 权重
                TextFormField(
                  controller: weightController,
                  decoration: InputDecoration(
                    labelText: t.weight,
                    hintText: t.weightHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.low_priority_rounded),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // NSFW 开关
                SwitchListTile(
                  title: Text(t.nsfw),
                  subtitle: Text(t.nsfwDescription),
                  value: isNsfw.value,
                  onChanged: (value) => isNsfw.value = value,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
              ],
            ),

            // ================================================================
            // Tab 2: 高级配置
            // ================================================================
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 解析地址
                TextFormField(
                  controller: jiexiController,
                  decoration: InputDecoration(
                    labelText: t.jiexiUrl,
                    hintText: t.jiexiUrlHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.extension_outlined),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),

                // 请求头
                TextFormField(
                  controller: headerController,
                  decoration: InputDecoration(
                    labelText: t.requestHeader,
                    hintText: t.requestHeaderHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.http_rounded),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                // 备注
                TextFormField(
                  controller: commentController,
                  decoration: InputDecoration(
                    labelText: t.comment,
                    hintText: t.commentHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                // 源状态信息（只读展示）
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: ${source.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${t.status}: ${source.status.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (source.respondTime > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${t.respondTime}: ${source.respondTime} ${t.ms}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (source.lastUpdateTime > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${t.last_modified}: ${DateTime.fromMillisecondsSinceEpoch(source.lastUpdateTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
