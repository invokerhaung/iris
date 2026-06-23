import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';

import '../../models/book_source.dart';
import '../../models/parsed_result.dart';
import '../../store/use_source_store.dart';
import '../../utils/source_parser.dart';
import '../../utils/source_fetcher.dart';
import 'widgets/search_result_tile.dart';

/// 搜索页面
///
/// 支持：
/// - 在选定的源中搜索
/// - 显示搜索结果列表
/// - 分页加载
class SearchPage extends HookWidget {
  final String? initialKeyword;
  final BookSource? initialSource;

  const SearchPage({
    super.key,
    this.initialKeyword,
    this.initialSource,
  });

  @override
  Widget build(BuildContext context) {
    final store = useSourceStore();
    final sources = store.select(context, (s) => s.sources);

    // 搜索状态
    final searchKeyword = useState(initialKeyword ?? '');
    final searchController = useTextEditingController(text: initialKeyword ?? '');

    // 选中的源
    final selectedSource = useState<BookSource?>(initialSource);

    // 搜索结果
    final isSearching = useState(false);
    final searchResults = useState<List<ParsedBookItem>>([]);
    final currentPage = useState(1);
    final hasMore = useState(true);
    final errorMessage = useState<String?>(null);

    // 可搜索的源列表（有 searchUrl 的源）
    final searchableSources = useMemoized(() {
      return sources.where((s) =>
        s.enabled &&
        s.searchUrl != null &&
        s.searchUrl!.isNotEmpty
      ).toList();
    }, [sources]);

    // 执行搜索
    Future<void> performSearch({bool loadMore = false}) async {
      if (searchKeyword.value.isEmpty) return;
      if (selectedSource.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择一个源')),
        );
        return;
      }

      if (!loadMore) {
        currentPage.value = 1;
        searchResults.value = [];
      }

      isSearching.value = true;
      errorMessage.value = null;

      try {
        final source = selectedSource.value!;
        final parser = SourceParser(source);
        final fetcher = SourceFetcher(source);

        // 构建搜索 URL
        final url = parser.getSearchUrl(
          searchKeyword.value,
          page: currentPage.value,
        );

        // 发起请求
        final response = await fetcher.get(url);

        if (response.isSuccess) {
          // 解析搜索结果
          final results = parser.parseSearchList(response.body, url);

          if (loadMore) {
            searchResults.value = [...searchResults.value, ...results];
          } else {
            searchResults.value = results;
          }

          hasMore.value = results.length >= 20;
          currentPage.value = currentPage.value + 1;
        } else {
          errorMessage.value = '搜索失败: HTTP ${response.statusCode}';
        }
      } catch (e) {
        errorMessage.value = '搜索失败: $e';
      } finally {
        isSearching.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // 搜索框
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: '输入搜索关键词',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              searchKeyword.value = '';
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () => performSearch(),
                        ),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) => searchKeyword.value = value,
                  onSubmitted: (_) => performSearch(),
                  autofocus: true,
                ),
                const SizedBox(height: 8),

                // 源选择
                SizedBox(
                  height: 40,
                  child: searchableSources.isEmpty
                      ? const Center(child: Text('没有可用的搜索源'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: searchableSources.length,
                          itemBuilder: (context, index) {
                            final source = searchableSources[index];
                            final isSelected = selectedSource.value?.bookSourceUrl == source.bookSourceUrl;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  source.bookSourceName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : null,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    selectedSource.value = source;
                                  }
                                },
                                selectedColor: Theme.of(context).primaryColor,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(
        context,
        isSearching.value,
        searchResults.value,
        hasMore.value,
        errorMessage.value,
        () => performSearch(loadMore: true),
      ),
    );
  }

  /// 构建主体内容
  Widget _buildBody(
    BuildContext context,
    bool isSearching,
    List<ParsedBookItem> results,
    bool hasMore,
    String? errorMessage,
    VoidCallback onLoadMore,
  ) {
    // 错误
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onLoadMore,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 空状态
    if (!isSearching && results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '输入关键词开始搜索',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // 搜索结果列表
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            hasMore &&
            !isSearching) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: results.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == results.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: isSearching
                    ? const CircularProgressIndicator()
                    : const Text('加载更多...'),
              ),
            );
          }

          return SearchResultTile(
            book: results[index],
            onTap: () => _onBookTap(context, results[index]),
          );
        },
      ),
    );
  }

  /// 点击书籍
  void _onBookTap(BuildContext context, ParsedBookItem book) {
    // TODO: 跳转到详情页或播放页
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(book.name ?? '未知标题'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (book.author != null) ...[
                const Text('作者:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(book.author!),
                const SizedBox(height: 8),
              ],
              if (book.kind != null) ...[
                const Text('分类:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(book.kind!),
                const SizedBox(height: 8),
              ],
              if (book.intro != null) ...[
                const Text('简介:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(book.intro!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          if (book.bookUrl != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: 跳转到详情页
              },
              child: const Text('查看详情'),
            ),
        ],
      ),
    );
  }
}
