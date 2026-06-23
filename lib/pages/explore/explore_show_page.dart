import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../models/book_source.dart';
import '../../models/parsed_result.dart';
import '../../utils/source_parser.dart';
import '../../utils/source_fetcher.dart';

/// 发现列表页
///
/// 展示发现分类下的书籍列表，支持：
/// - 大图模式
/// - 网格模式
/// - 加载更多
/// - 收藏功能
class ExploreShowPage extends HookWidget {
  final BookSource source;
  final String categoryTitle;
  final String categoryUrl;

  const ExploreShowPage({
    super.key,
    required this.source,
    required this.categoryTitle,
    required this.categoryUrl,
  });

  @override
  Widget build(BuildContext context) {
    // 加载状态
    final isLoading = useState(true);
    final isLoadingMore = useState(false);
    final books = useState<List<ParsedBookItem>>([]);
    final currentPage = useState(1);
    final hasMore = useState(true);
    final errorMessage = useState<String?>(null);

    // 布局模式：0=大图, 1=网格 (Windows 上强制网格)
    final layoutMode = useState(Platform.isWindows ? 1 : 0);

    // 加载数据
    useEffect(() {
      _loadBooks(
        source: source,
        categoryUrl: categoryUrl,
        page: 1,
        books: books,
        isLoading: isLoading,
        hasMore: hasMore,
        errorMessage: errorMessage,
        currentPage: currentPage,
      );
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle),
        actions: [
          // 切换布局 (Windows 上隐藏，强制使用网格)
          if (!Platform.isWindows)
            IconButton(
              icon: Icon(layoutMode.value == 0 ? Icons.grid_view : Icons.view_agenda),
              tooltip: layoutMode.value == 0 ? '网格模式' : '大图模式',
              onPressed: () {
                layoutMode.value = layoutMode.value == 0 ? 1 : 0;
              },
            ),

          // 刷新
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              _loadBooks(
                source: source,
                categoryUrl: categoryUrl,
                page: 1,
                books: books,
                isLoading: isLoading,
                hasMore: hasMore,
                errorMessage: errorMessage,
                currentPage: currentPage,
              );
            },
          ),
        ],
      ),
      body: _buildBody(
        context,
        isLoading.value,
        books.value,
        layoutMode.value,
        hasMore.value,
        isLoadingMore.value,
        errorMessage.value,
        () {
          _loadMore(
            source: source,
            categoryUrl: categoryUrl,
            page: currentPage.value + 1,
            books: books,
            isLoadingMore: isLoadingMore,
            hasMore: hasMore,
            currentPage: currentPage,
          );
        },
      ),
    );
  }

  /// 构建主体内容
  Widget _buildBody(
    BuildContext context,
    bool isLoading,
    List<ParsedBookItem> books,
    int layoutMode,
    bool hasMore,
    bool isLoadingMore,
    String? errorMessage,
    VoidCallback onLoadMore,
  ) {
    // 加载中
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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

    // 空列表
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '暂无内容',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // 列表内容
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 滚动到底部加载更多
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            hasMore &&
            !isLoadingMore) {
          onLoadMore();
        }
        return false;
      },
      child: layoutMode == 0
          ? _buildBigLayout(context, books, hasMore, isLoadingMore)
          : _buildGridLayout(context, books, hasMore, isLoadingMore),
    );
  }

  /// 大图布局
  Widget _buildBigLayout(
    BuildContext context,
    List<ParsedBookItem> books,
    bool hasMore,
    bool isLoadingMore,
  ) {
    return ListView.builder(
      itemCount: books.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == books.length) {
          return _buildLoadMoreIndicator(isLoadingMore);
        }
        return _buildBigItem(context, books[index]);
      },
    );
  }

  /// 网格布局
  Widget _buildGridLayout(
    BuildContext context,
    List<ParsedBookItem> books,
    bool hasMore,
    bool isLoadingMore,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: books.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == books.length) {
          return _buildLoadMoreIndicator(isLoadingMore);
        }
        return _buildGridItem(context, books[index]);
      },
    );
  }

  /// 大图列表项
  Widget _buildBigItem(BuildContext context, ParsedBookItem book) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _onBookTap(context, book),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图片
            if (book.coverUrl != null && book.coverUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    book.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // 信息区域
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    book.name ?? '未知标题',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 分类/标签
                  if (book.kind != null && book.kind!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.kind!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // 最新章节
                  if (book.lastChapter != null && book.lastChapter!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '最新: ${book.lastChapter}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 网格列表项
  Widget _buildGridItem(BuildContext context, ParsedBookItem book) {
    return Card(
      child: InkWell(
        onTap: () => _onBookTap(context, book),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图片 (16:9)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: Colors.grey[200],
                ),
                child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          book.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.book, size: 32, color: Colors.grey),
                      ),
              ),
            ),

            // 标题
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  book.name ?? '未知标题',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 加载更多指示器
  Widget _buildLoadMoreIndicator(bool isLoadingMore) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: isLoadingMore
            ? const CircularProgressIndicator()
            : const Text('加载更多...'),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.author != null) Text('作者: ${book.author}'),
            if (book.kind != null) Text('分类: ${book.kind}'),
            if (book.intro != null) Text('简介: ${book.intro}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 加载书籍数据
  Future<void> _loadBooks({
    required BookSource source,
    required String categoryUrl,
    required int page,
    required ValueNotifier<List<ParsedBookItem>> books,
    required ValueNotifier<bool> isLoading,
    required ValueNotifier<bool> hasMore,
    required ValueNotifier<String?> errorMessage,
    required ValueNotifier<int> currentPage,
  }) async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final parser = SourceParser(source);
      final fetcher = SourceFetcher(source);

      // 构建URL
      String url = categoryUrl;
      if (url.contains('{{page}}')) {
        url = url.replaceAll('{{page}}', page.toString());
      }

      // 如果是相对路径，补全域名
      if (!url.startsWith('http')) {
        final baseUrl = source.bookSourceUrl;
        if (url.startsWith('/')) {
          url = '$baseUrl$url';
        } else {
          url = '$baseUrl/$url';
        }
      }

      // 发起请求
      final response = await fetcher.get(url);

      if (response.isSuccess) {
        // 解析列表
        final parsedBooks = parser.parseExploreList(response.body, url);
        books.value = parsedBooks;
        currentPage.value = page;
        hasMore.value = parsedBooks.length >= 20; // 假设每页20条
      } else {
        errorMessage.value = '请求失败: HTTP ${response.statusCode}';
      }
    } catch (e) {
      errorMessage.value = '加载失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载更多
  Future<void> _loadMore({
    required BookSource source,
    required String categoryUrl,
    required int page,
    required ValueNotifier<List<ParsedBookItem>> books,
    required ValueNotifier<bool> isLoadingMore,
    required ValueNotifier<bool> hasMore,
    required ValueNotifier<int> currentPage,
  }) async {
    if (isLoadingMore.value) return;

    isLoadingMore.value = true;

    try {
      final parser = SourceParser(source);
      final fetcher = SourceFetcher(source);

      // 构建URL
      String url = categoryUrl;
      if (url.contains('{{page}}')) {
        url = url.replaceAll('{{page}}', page.toString());
      }

      // 如果是相对路径，补全域名
      if (!url.startsWith('http')) {
        final baseUrl = source.bookSourceUrl;
        if (url.startsWith('/')) {
          url = '$baseUrl$url';
        } else {
          url = '$baseUrl/$url';
        }
      }

      // 发起请求
      final response = await fetcher.get(url);

      if (response.isSuccess) {
        // 解析列表
        final newBooks = parser.parseExploreList(response.body, url);
        books.value = [...books.value, ...newBooks];
        currentPage.value = page;
        hasMore.value = newBooks.length >= 20;
      }
    } catch (e) {
      // 加载失败，忽略
    } finally {
      isLoadingMore.value = false;
    }
  }
}
