import 'dart:async';

import '../models/book_source.dart';
import '../models/check_source_config.dart';
import '../models/check_result.dart';
import '../models/parsed_result.dart';
import '../store/use_source_store.dart';
import 'source_parser.dart';
import 'source_fetcher.dart';

/// 源校验器
///
/// 执行完整的源校验流程：搜索 -> 发现 -> 详情 -> 目录 -> 正文
class SourceChecker {
  final SourceStore store;
  final CheckSourceConfig config;

  SourceChecker(
    this.store, {
    CheckSourceConfig? config,
  }) : config = config ?? const CheckSourceConfig();

  /// 校验单个源
  Future<CheckResult> checkSource(BookSource source) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 1. 移除失效分组
      source = _removeInvalidGroups(source);

      // 2. 校验搜索
      if (config.checkSearch && source.hasSearchUrl) {
        source = await _checkSearch(source);
      }

      // 3. 校验发现
      if (config.checkDiscovery && source.hasExploreUrl) {
        source = await _checkDiscovery(source);
      }

      stopwatch.stop();

      // 4. 更新响应时间
      source = source.copyWith(
        respondTime: stopwatch.elapsedMilliseconds,
        lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
      );

      return CheckResult.success(source, stopwatch.elapsed);
    } on TimeoutException {
      stopwatch.stop();
      source = source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '校验超时'),
        respondTime: 180000,
      );
      return CheckResult.timeout(source);
    } catch (e) {
      stopwatch.stop();
      source = source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '网站失效'),
        respondTime: 180000,
      );
      return CheckResult.error(source, e.toString());
    }
  }

  /// 校验搜索
  Future<BookSource> _checkSearch(BookSource source) async {
    final keyword = source.ruleSearch?.checkKeyWord ?? config.keyword;
    final parser = SourceParser(source);
    final searchUrl = parser.getSearchUrl(keyword);

    // 发起搜索请求
    final fetcher = SourceFetcher(source, timeout: Duration(milliseconds: config.timeout));
    final response = await fetcher.get(searchUrl);

    if (!response.isSuccess) {
      return source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '搜索失效'),
      );
    }

    // 解析搜索结果
    final results = parser.parseSearchList(response.body, searchUrl);

    if (results.isEmpty) {
      return source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '搜索失效'),
      );
    }

    // 移除搜索失效标记
    source = _removeGroup(source, '搜索失效');

    // 校验详情/目录/正文
    if (config.checkInfo || config.checkCategory || config.checkContent) {
      source = await _checkBook(source, results.first, isSearch: true);
    }

    return source;
  }

  /// 校验发现
  Future<BookSource> _checkDiscovery(BookSource source) async {
    final exploreUrl = source.exploreUrl;
    if (exploreUrl == null || exploreUrl.isEmpty) {
      return source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '发现规则为空'),
      );
    }

    // 发起发现请求
    final fetcher = SourceFetcher(source, timeout: Duration(milliseconds: config.timeout));
    final response = await fetcher.get(exploreUrl);

    if (!response.isSuccess) {
      return source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '发现失效'),
      );
    }

    // 解析发现结果
    final parser = SourceParser(source);
    final results = parser.parseExploreList(response.body, exploreUrl);

    if (results.isEmpty) {
      return source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '发现失效'),
      );
    }

    // 移除发现失效标记
    source = _removeGroup(source, '发现失效');

    // 校验详情/目录/正文
    if (config.checkInfo || config.checkCategory || config.checkContent) {
      source = await _checkBook(source, results.first, isSearch: false);
    }

    return source;
  }

  /// 校验书籍详情/目录/正文
  Future<BookSource> _checkBook(
    BookSource source,
    ParsedBookItem book, {
    required bool isSearch,
  }) async {
    final prefix = isSearch ? '搜索' : '发现';
    final fetcher = SourceFetcher(source, timeout: Duration(milliseconds: config.timeout));

    // 校验详情
    if (config.checkInfo && book.bookUrl != null) {
      try {
        final response = await fetcher.get(book.bookUrl!);
        if (response.isSuccess) {
          final parser = SourceParser(source);
          final info = parser.parseBookInfo(response.body, book.bookUrl!);

          // 如果没有目录URL，尝试从详情页获取
          if (info.tocUrl != null && info.tocUrl!.isNotEmpty) {
            // 继续校验目录
          }
        }
      } catch (e) {
        source = source.copyWith(
          bookSourceGroup: _addGroup(source.bookSourceGroup, '$prefix详情失效'),
        );
      }
    }

    // 校验目录
    if (config.checkCategory) {
      try {
        final tocUrl = book.bookUrl ?? source.exploreUrl;
        if (tocUrl != null) {
          final response = await fetcher.get(tocUrl);
          if (response.isSuccess) {
            final parser = SourceParser(source);
            final chapters = parser.parseToc(response.body, tocUrl);

            if (chapters.isEmpty) {
              source = source.copyWith(
                bookSourceGroup: _addGroup(source.bookSourceGroup, '$prefix目录失效'),
              );
            } else {
              // 校验正文（取第一章）
              if (config.checkContent && chapters.first.url != null) {
                source = await _checkContent(source, chapters.first.url!, prefix);
              }
            }
          }
        }
      } catch (e) {
        source = source.copyWith(
          bookSourceGroup: _addGroup(source.bookSourceGroup, '$prefix目录失效'),
        );
      }
    }

    return source;
  }

  /// 校验正文
  Future<BookSource> _checkContent(
    BookSource source,
    String contentUrl,
    String prefix,
  ) async {
    try {
      final fetcher = SourceFetcher(source, timeout: Duration(milliseconds: config.timeout));
      final response = await fetcher.get(contentUrl);

      if (response.isSuccess) {
        final parser = SourceParser(source);
        final content = parser.parseContent(response.body, contentUrl);

        if (content.content == null || content.content!.isEmpty) {
          source = source.copyWith(
            bookSourceGroup: _addGroup(source.bookSourceGroup, '$prefix正文失效'),
          );
        }
      } else {
        source = source.copyWith(
          bookSourceGroup: _addGroup(source.bookSourceGroup, '$prefix正文失效'),
        );
      }
    } catch (e) {
      source = source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '$prefix正文失效'),
      );
    }

    return source;
  }

  /// 移除失效分组
  BookSource _removeInvalidGroups(BookSource source) {
    final invalidGroups = [
      '搜索失效', '发现失效', '搜索链接规则为空', '发现规则为空',
      '搜索目录失效', '发现目录失效', '搜索正文失效', '发现正文失效',
      '搜索详情失效', '发现详情失效', '校验超时', '网站失效', 'js失效',
    ];

    var groups = source.groupList;
    groups.removeWhere((g) => invalidGroups.contains(g));

    return source.copyWith(
      bookSourceGroup: groups.isEmpty ? null : groups.join(','),
    );
  }

  /// 添加分组
  String? _addGroup(String? existing, String newGroup) {
    final groups = existing?.split(RegExp(r'[,;，；]')).map((e) => e.trim()).toList() ?? [];
    if (!groups.contains(newGroup)) {
      groups.add(newGroup);
    }
    return groups.join(',');
  }

  /// 移除分组
  BookSource _removeGroup(BookSource source, String group) {
    final groups = source.groupList..remove(group);
    return source.copyWith(
      bookSourceGroup: groups.isEmpty ? null : groups.join(','),
    );
  }
}
