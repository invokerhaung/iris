import 'package:flutter_test/flutter_test.dart';
import 'package:iris/models/book_source.dart';
import 'package:iris/models/parsed_result.dart';
import 'package:iris/models/rule/search_rule.dart';
import 'package:iris/models/rule/explore_rule.dart';
import 'package:iris/models/rule/toc_rule.dart';
import 'package:iris/models/rule/content_rule.dart';
import 'package:iris/utils/source_parser.dart';

void main() {
  group('SourceParser URL Building', () {
    test('should build search URL with keyword', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        searchUrl: 'https://example.com/search?keyword={{key}}&page={{page}}',
      );

      final parser = SourceParser(source);

      expect(
        parser.getSearchUrl('测试'),
        'https://example.com/search?keyword=%E6%B5%8B%E8%AF%95&page=1',
      );
    });

    test('should build search URL with page', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        searchUrl: 'https://example.com/search?keyword={{key}}&page={{page}}',
      );

      final parser = SourceParser(source);

      expect(
        parser.getSearchUrl('测试', page: 2),
        'https://example.com/search?keyword=%E6%B5%8B%E8%AF%95&page=2',
      );
    });

    test('should build explore URL with page', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );

      final parser = SourceParser(source);

      expect(
        parser.getExploreUrl('https://example.com/explore?page={{page}}', page: 3),
        'https://example.com/explore?page=3',
      );
    });
  });

  group('SourceParser Empty Rules', () {
    test('should return empty list for null search rule', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        // 没有配置规则
      );

      final parser = SourceParser(source);
      final results = parser.parseSearchList('<html></html>', 'https://example.com');

      expect(results, isEmpty);
    });

    test('should return empty list for null explore rule', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        // 没有配置规则
      );

      final parser = SourceParser(source);
      final results = parser.parseExploreList('<html></html>', 'https://example.com');

      expect(results, isEmpty);
    });

    test('should return empty list for null toc rule', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        // 没有配置规则
      );

      final parser = SourceParser(source);
      final results = parser.parseToc('<html></html>', 'https://example.com');

      expect(results, isEmpty);
    });
  });

  group('ParsedBookItem', () {
    test('should be valid with name and url', () {
      final item = ParsedBookItem(
        name: '测试书籍',
        bookUrl: '/book/1',
      );

      expect(item.isValid, true);
    });

    test('should be invalid without name', () {
      final item = ParsedBookItem(
        bookUrl: '/book/1',
      );

      expect(item.isValid, false);
    });

    test('should be invalid without url', () {
      final item = ParsedBookItem(
        name: '测试书籍',
      );

      expect(item.isValid, false);
    });

    test('should be invalid with empty name', () {
      final item = ParsedBookItem(
        name: '',
        bookUrl: '/book/1',
      );

      expect(item.isValid, false);
    });

    test('should be invalid with empty url', () {
      final item = ParsedBookItem(
        name: '测试书籍',
        bookUrl: '',
      );

      expect(item.isValid, false);
    });
  });

  group('ParsedBookInfo', () {
    test('should have correct toString', () {
      final info = ParsedBookInfo(
        name: '测试书籍',
        author: '测试作者',
      );

      expect(info.toString(), 'ParsedBookInfo(name: 测试书籍, author: 测试作者)');
    });
  });

  group('ParsedChapter', () {
    test('should be valid with name', () {
      final chapter = ParsedChapter(
        name: '第一章',
        url: '/chapter/1',
      );

      expect(chapter.isValid, true);
    });

    test('should be invalid without name', () {
      final chapter = ParsedChapter(
        url: '/chapter/1',
      );

      expect(chapter.isValid, false);
    });

    test('should have default values', () {
      final chapter = ParsedChapter(
        name: '第一章',
      );

      expect(chapter.isVolume, false);
      expect(chapter.isVip, false);
      expect(chapter.isPay, false);
    });
  });

  group('ParsedContent', () {
    test('should have hasNextPage when url exists', () {
      final content = ParsedContent(
        title: '第一章',
        content: '正文内容',
        nextContentUrl: '/chapter/2',
      );

      expect(content.hasNextPage, true);
    });

    test('should not have hasNextPage when url is null', () {
      final content = ParsedContent(
        title: '第一章',
        content: '正文内容',
      );

      expect(content.hasNextPage, false);
    });

    test('should not have hasNextPage when url is empty', () {
      final content = ParsedContent(
        title: '第一章',
        content: '正文内容',
        nextContentUrl: '',
      );

      expect(content.hasNextPage, false);
    });
  });

  group('ParsedReview', () {
    test('should have correct toString', () {
      final review = ParsedReview(
        content: '这是一段评论内容，长度超过二十个字符的话应该被截断显示',
      );

      final str = review.toString();
      expect(str, contains('ParsedReview'));
      expect(str, contains('...'));
    });
  });
}
