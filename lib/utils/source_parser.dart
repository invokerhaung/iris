import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../ffi/legado_ffi.dart';
import '../models/book_source.dart';
import '../models/parsed_result.dart';

/// 源规则解析器
///
/// 使用 LegadoAnalyzer FFI 引擎解析 HTML 内容，
/// 根据 BookSource 的规则配置提取书籍列表、详情、目录和正文信息。
///
/// 使用示例：
/// ```dart
/// final parser = SourceParser(source);
/// final books = parser.parseSearchList(htmlContent, 'https://example.com');
/// final info = parser.parseBookInfo(detailHtml, 'https://example.com/detail');
/// final chapters = parser.parseToc(tocHtml, 'https://example.com/toc');
/// final content = parser.parseContent(contentHtml, 'https://example.com/chapter1');
/// ```
class SourceParser {
  final BookSource source;

  SourceParser(this.source);

  // ========== 列表解析 ==========

  /// 解析搜索结果列表
  ///
  /// [content] HTML 内容
  /// [baseUrl] 基础URL（用于相对路径转换）
  List<ParsedBookItem> parseSearchList(String content, String baseUrl) {
    final rule = source.ruleSearch;
    if (rule?.bookList == null || rule!.bookList!.isEmpty) {
      return [];
    }
    return _parseBookList(content, baseUrl, rule.bookList!, rule);
  }

  /// 解析发现列表
  List<ParsedBookItem> parseExploreList(String content, String baseUrl) {
    final rule = source.ruleExplore;
    if (rule?.bookList == null || rule!.bookList!.isEmpty) {
      return [];
    }
    return _parseBookList(content, baseUrl, rule.bookList!, rule);
  }

  /// 通用列表解析
  ///
  /// [content] HTML 内容
  /// [baseUrl] 基础URL
  /// [listRule] 列表选择器规则
  /// [rule] SearchRule 或 ExploreRule
  List<ParsedBookItem> _parseBookList(
    String content,
    String baseUrl,
    String listRule,
    dynamic rule, // SearchRule 或 ExploreRule
  ) {
    final analyzer = LegadoAnalyzer();

    analyzer.setContent(content, baseUrl);

    // 获取列表元素
    final elementsJson = analyzer.getElements(listRule);

    List<String> elements;
    try {
      elements = (jsonDecode(elementsJson) as List).cast<String>();
    } catch (e) {
      elements = [];
    }

    if (elements.isEmpty) {
      analyzer.dispose();
      return [];
    }

    // 解析每个元素
    final items = <ParsedBookItem>[];
    for (var i = 0; i < elements.length; i++) {
      final element = elements[i];
      try {
        final itemAnalyzer = LegadoAnalyzer();
        itemAnalyzer.setContent(element, baseUrl);

        final item = ParsedBookItem(
          name: _extractText(itemAnalyzer, rule.name),
          author: _extractText(itemAnalyzer, rule.author),
          intro: _extractText(itemAnalyzer, rule.intro),
          kind: _extractText(itemAnalyzer, rule.kind),
          lastChapter: _extractText(itemAnalyzer, rule.lastChapter),
          updateTime: _extractText(itemAnalyzer, rule.updateTime),
          bookUrl: _extractUrl(itemAnalyzer, rule.bookUrl, baseUrl),
          coverUrl: _extractUrl(itemAnalyzer, rule.coverUrl, baseUrl),
          wordCount: _extractText(itemAnalyzer, rule.wordCount),
        );
        debugPrint('ParsedBookItem: $item');
        itemAnalyzer.dispose();

        if (item.isValid) {
          items.add(item);
        }
      } catch (e) {
        continue;
      }
    }

    analyzer.dispose();
    return items;
  }

  // ========== 详情解析 ==========

  /// 解析书籍详情
  ParsedBookInfo parseBookInfo(String content, String baseUrl) {
    final rule = source.ruleBookInfo;
    final analyzer = LegadoAnalyzer();
    analyzer.setContent(content, baseUrl);

    final info = ParsedBookInfo(
      name: _extractText(analyzer, rule?.name),
      author: _extractText(analyzer, rule?.author),
      intro: _extractText(analyzer, rule?.intro),
      kind: _extractText(analyzer, rule?.kind),
      lastChapter: _extractText(analyzer, rule?.lastChapter),
      updateTime: _extractText(analyzer, rule?.updateTime),
      coverUrl: _extractUrl(analyzer, rule?.coverUrl, baseUrl),
      tocUrl: _extractUrl(analyzer, rule?.tocUrl, baseUrl),
      wordCount: _extractText(analyzer, rule?.wordCount),
    );

    analyzer.dispose();
    return info;
  }

  // ========== 目录解析 ==========

  /// 解析目录列表
  List<ParsedChapter> parseToc(String content, String baseUrl) {
    final rule = source.ruleToc;
    if (rule?.chapterList == null || rule!.chapterList!.isEmpty) {
      return [];
    }

    final analyzer = LegadoAnalyzer();
    analyzer.setContent(content, baseUrl);

    // 获取章节列表元素
    final elementsJson = analyzer.getElements(rule.chapterList!);
    List<String> elements;
    try {
      elements = (jsonDecode(elementsJson) as List).cast<String>();
    } catch (_) {
      elements = [];
    }

    if (elements.isEmpty) {
      analyzer.dispose();
      return [];
    }

    // 解析每个章节
    final chapters = <ParsedChapter>[];
    for (final element in elements) {
      try {
        final itemAnalyzer = LegadoAnalyzer();
        itemAnalyzer.setContent(element, baseUrl);

        final chapter = ParsedChapter(
          name: _extractText(itemAnalyzer, rule.chapterName),
          url: _extractUrl(itemAnalyzer, rule.chapterUrl, baseUrl),
          isVolume: _extractBool(itemAnalyzer, rule.isVolume),
          isVip: _extractBool(itemAnalyzer, rule.isVip),
          isPay: _extractBool(itemAnalyzer, rule.isPay),
          updateTime: _extractText(itemAnalyzer, rule.updateTime),
        );

        itemAnalyzer.dispose();

        if (chapter.isValid) {
          chapters.add(chapter);
        }
      } catch (e) {
        continue;
      }
    }

    analyzer.dispose();
    return chapters;
  }

  // ========== 正文解析 ==========

  /// 解析正文内容
  ParsedContent parseContent(String content, String baseUrl) {
    final rule = source.ruleContent;
    final analyzer = LegadoAnalyzer();
    analyzer.setContent(content, baseUrl);

    final parsed = ParsedContent(
      title: _extractText(analyzer, rule?.title),
      content: _extractText(analyzer, rule?.content),
      nextContentUrl: _extractUrl(analyzer, rule?.nextContentUrl, baseUrl),
    );

    analyzer.dispose();
    return parsed;
  }

  // ========== URL构建 ==========

  /// 构建搜索URL
  ///
  /// 将 searchUrl 中的 {{key}} 和 {{page}} 替换为实际值
  String getSearchUrl(String keyword, {int page = 1}) {
    String url = source.searchUrl ?? '';
    url = url.replaceAll('{{key}}', Uri.encodeComponent(keyword));
    url = url.replaceAll('{{page}}', page.toString());
    return url;
  }

  /// 构建发现URL
  String getExploreUrl(String url, {int page = 1}) {
    String result = url;
    result = result.replaceAll('{{page}}', page.toString());
    return result;
  }

  // ========== 文本提取 ==========

  /// 提取文本
  ///
  /// 直接将规则传给 LegadoAnalyzer 解析，支持所有 Legado 规则语法：
  /// - CSS选择器: ".class", "tag"
  /// - 属性提取: "a@href", "img@src"
  /// - 文本提取: "h1@text"
  /// - 组合选择器: "body&&.list a"
  /// - 或选择器: ".class1||.class2"
  /// - 特殊选择器: "@css:selector", "@json:path", "@xpath:path"
  /// - 变量操作: "@put(key)", "@get(key)"
  String? _extractText(LegadoAnalyzer analyzer, String? rule) {
    if (rule == null || rule.isEmpty) return null;

    try {
      return analyzer.getString(rule);
    } catch (e) {
      return null;
    }
  }

  /// 提取URL（自动处理相对路径）
  String? _extractUrl(LegadoAnalyzer analyzer, String? rule, String baseUrl) {
    final text = _extractText(analyzer, rule);
    if (text == null || text.isEmpty) return null;

    // 如果已经是绝对URL，直接返回
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }

    // 处理相对路径
    try {
      final base = Uri.parse(baseUrl);
      if (text.startsWith('//')) {
        return '${base.scheme}:$text';
      } else if (text.startsWith('/')) {
        return '${base.scheme}://${base.host}$text';
      } else {
        return '${base.scheme}://${base.host}/${base.path}/$text';
      }
    } catch (_) {
      return text;
    }
  }

  /// 提取布尔值
  bool _extractBool(LegadoAnalyzer analyzer, String? rule) {
    final text = _extractText(analyzer, rule);
    if (text == null) return false;
    return text.toLowerCase() == 'true' || text == '1';
  }
}
