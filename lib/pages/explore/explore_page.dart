import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';

import '../../models/book_source.dart';
import '../../store/use_source_store.dart';
import '../search/search_page.dart';
import 'explore_show_page.dart';
import 'widgets/explore_source_tile.dart';

/// 发现页面
///
/// 展示有发现规则的书源列表，支持：
/// - 按书源名称搜索
/// - 按分组筛选
/// - 展开/收起分类标签
/// - 置顶/收藏功能
class ExplorePage extends HookWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = useSourceStore();
    final sources = store.select(context, (s) => s.sources);

    // 搜索状态
    final searchKeyword = useState('');
    final isSearchExpanded = useState(false);
    final searchController = useTextEditingController();

    // 筛选状态
    final currentGroup = useState<String?>(null);

    // 展开状态
    final expandedIndex = useState<int?>(null);

    // 置顶收藏
    final pinnedItems = useState<List<PinnedExplore>>([]);

    // 计算有发现规则的源列表
    final exploreSources = useMemoized(() {
      var result = sources.where((s) =>
        s.enabled &&
        s.enabledExplore &&
        s.exploreUrl != null &&
        s.exploreUrl!.isNotEmpty
      ).toList();

      // 搜索筛选
      if (searchKeyword.value.isNotEmpty) {
        final keyword = searchKeyword.value.toLowerCase();
        result = result.where((s) {
          // 检查是否是分组搜索
          if (keyword.startsWith('group:')) {
            final groupKeyword = keyword.substring(6);
            return s.bookSourceGroup?.toLowerCase().contains(groupKeyword) ?? false;
          }
          return s.bookSourceName.toLowerCase().contains(keyword) ||
              (s.bookSourceGroup?.toLowerCase().contains(keyword) ?? false);
        }).toList();
      }

      // 分组筛选
      if (currentGroup.value != null) {
        result = result.where((s) =>
          s.bookSourceGroup?.contains(currentGroup.value!) ?? false
        ).toList();
      }

      return result;
    }, [sources, searchKeyword.value, currentGroup.value]);

    // 获取有发现规则的源的分组
    final exploreGroups = useMemoized(() {
      final groupSet = <String>{};
      for (final source in sources) {
        if (source.enabled &&
            source.enabledExplore &&
            source.exploreUrl != null &&
            source.exploreUrl!.isNotEmpty &&
            source.bookSourceGroup != null) {
          final sourceGroups = source.bookSourceGroup!
              .split(RegExp(r'[,;，；]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          groupSet.addAll(sourceGroups);
        }
      }
      return groupSet.toList()..sort();
    }, [sources]);

    return Scaffold(
      appBar: AppBar(
        title: isSearchExpanded.value
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索书源或输入 group:分组名',
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
            : const Text('发现'),
        actions: [
          // 书源筛选按钮
          IconButton(
            icon: Icon(isSearchExpanded.value ? Icons.search_off : Icons.filter_list),
            onPressed: () {
              isSearchExpanded.value = !isSearchExpanded.value;
              if (!isSearchExpanded.value) {
                searchController.clear();
                searchKeyword.value = '';
              }
            },
          ),

          // 全局搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchPage(),
                ),
              );
            },
          ),

          // 分组筛选
          if (exploreGroups.isNotEmpty)
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list),
              tooltip: '分组筛选',
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: null,
                  child: Text('全部分组'),
                ),
                const PopupMenuDivider(),
                ...exploreGroups.map((group) => PopupMenuItem(
                  value: group,
                  child: Text(group),
                )),
              ],
              onSelected: (value) {
                currentGroup.value = value;
              },
            ),
        ],
      ),
      body: exploreSources.isEmpty
          ? _buildEmptyState()
          : _buildSourceList(
              context,
              exploreSources,
              expandedIndex,
              pinnedItems,
            ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '暂无发现内容',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            '请先添加有发现规则的书源',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  /// 构建源列表
  Widget _buildSourceList(
    BuildContext context,
    List<BookSource> sources,
    ValueNotifier<int?> expandedIndex,
    ValueNotifier<List<PinnedExplore>> pinnedItems,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        final isExpanded = expandedIndex.value == index;

        return ExploreSourceTile(
          source: source,
          isExpanded: isExpanded,
          onTap: () {
            // 切换展开状态
            expandedIndex.value = isExpanded ? null : index;
          },
          onCategoryTap: (title, url) {
            // 点击分类标签，跳转到发现列表页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExploreShowPage(
                  source: source,
                  categoryTitle: title,
                  categoryUrl: url,
                ),
              ),
            );
          },
          onPin: (title, url) {
            // 置顶/收藏
            final pinned = PinnedExplore(
              sourceUrl: source.bookSourceUrl,
              sourceName: source.bookSourceName,
              categoryName: title,
              categoryUrl: url,
            );
            final currentPinned = List<PinnedExplore>.from(pinnedItems.value);
            final existingIndex = currentPinned.indexWhere(
              (p) => p.sourceUrl == pinned.sourceUrl && p.categoryName == pinned.categoryName,
            );
            if (existingIndex >= 0) {
              currentPinned.removeAt(existingIndex);
            } else {
              currentPinned.add(pinned);
            }
            pinnedItems.value = currentPinned;
          },
          isPinned: (title, url) {
            return pinnedItems.value.any(
              (p) => p.sourceUrl == source.bookSourceUrl && p.categoryName == title,
            );
          },
        );
      },
    );
  }
}

/// 置顶收藏数据
class PinnedExplore {
  final String sourceUrl;
  final String sourceName;
  final String categoryName;
  final String categoryUrl;

  const PinnedExplore({
    required this.sourceUrl,
    required this.sourceName,
    required this.categoryName,
    required this.categoryUrl,
  });
}
