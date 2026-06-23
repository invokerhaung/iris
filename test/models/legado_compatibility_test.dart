import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris/models/book_source.dart';

void main() {
  group('Legado JSON Compatibility', () {
    test('should import real Legado source JSON', () {
      // 真实的 Legado 书源 JSON 样本
      final legadoJson = '''
      {
        "bookSourceUrl": "https://www.biquge.com",
        "bookSourceName": "笔趣阁",
        "bookSourceGroup": "小说",
        "bookSourceType": 0,
        "enabled": true,
        "enabledExplore": true,
        "weight": 100,
        "searchUrl": "https://www.biquge.com/search?keyword={{key}}",
        "ruleSearch": {
          "checkKeyWord": "我的",
          "bookList": ".book-item",
          "name": "h3@text",
          "author": ".author@text",
          "bookUrl": "a@href",
          "coverUrl": "img@src"
        },
        "ruleBookInfo": {
          "name": "h1@text",
          "intro": ".intro@text"
        },
        "ruleToc": {
          "chapterList": ".chapter-list li",
          "chapterName": "a@text",
          "chapterUrl": "a@href"
        }
      }
      ''';

      final json = jsonDecode(legadoJson) as Map<String, dynamic>;
      final source = BookSource.fromJson(json);

      // 验证基础字段
      expect(source.bookSourceUrl, 'https://www.biquge.com');
      expect(source.bookSourceName, '笔趣阁');
      expect(source.bookSourceGroup, '小说');
      expect(source.bookSourceType, 0);
      expect(source.enabled, true);
      expect(source.weight, 100);

      // 验证搜索URL
      expect(source.searchUrl, 'https://www.biquge.com/search?keyword={{key}}');

      // 验证搜索规则
      expect(source.ruleSearch, isNotNull);
      expect(source.ruleSearch!.checkKeyWord, '我的');
      expect(source.ruleSearch!.bookList, '.book-item');
      expect(source.ruleSearch!.name, 'h3@text');

      // 验证详情规则
      expect(source.ruleBookInfo, isNotNull);
      expect(source.ruleBookInfo!.name, 'h1@text');

      // 验证目录规则
      expect(source.ruleToc, isNotNull);
      expect(source.ruleToc!.chapterList, '.chapter-list li');

      // 验证可以反序列化回 JSON
      final reSerialized = source.toJson();
      expect(reSerialized['bookSourceUrl'], 'https://www.biquge.com');
      // ruleSearch 是 SearchRule 对象，需要转换为 Map
      final ruleSearchJson = source.ruleSearch!.toJson();
      expect(ruleSearchJson['bookList'], '.book-item');
    });

    test('should import Legado array JSON', () {
      final legadoJson = '''
      [
        {
          "bookSourceUrl": "https://source1.com",
          "bookSourceName": "源1",
          "enabled": true
        },
        {
          "bookSourceUrl": "https://source2.com",
          "bookSourceName": "源2",
          "enabled": false
        }
      ]
      ''';

      final jsonList = jsonDecode(legadoJson) as List;
      final sources = jsonList
          .map((e) => BookSource.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(sources.length, 2);
      expect(sources[0].bookSourceUrl, 'https://source1.com');
      expect(sources[1].bookSourceUrl, 'https://source2.com');
      expect(sources[1].enabled, false);
    });

    test('should handle video source with IRIS extensions', () {
      final videoSourceJson = '''
      {
        "bookSourceUrl": "https://video.example.com",
        "bookSourceName": "视频源",
        "bookSourceType": 4,
        "enabled": true,
        "jiexiUrl": "https://jiexi.example.com",
        "isNsfw": false
      }
      ''';

      final json = jsonDecode(videoSourceJson) as Map<String, dynamic>;
      final source = BookSource.fromJson(json);

      expect(source.bookSourceUrl, 'https://video.example.com');
      expect(source.bookSourceType, 4);
      expect(source.jiexiUrl, 'https://jiexi.example.com');
      expect(source.isNsfw, false);

      // 验证可以反序列化回 JSON
      final reSerialized = source.toJson();
      expect(reSerialized['jiexiUrl'], 'https://jiexi.example.com');
      expect(reSerialized['isNsfw'], false);
    });

    test('should handle all rule types', () {
      final fullSourceJson = '''
      {
        "bookSourceUrl": "https://full.example.com",
        "bookSourceName": "完整源",
        "enabled": true,
        "ruleSearch": {
          "checkKeyWord": "测试",
          "bookList": ".list",
          "name": ".name@text",
          "author": ".author@text"
        },
        "ruleExplore": {
          "bookList": ".explore-list",
          "name": ".title@text"
        },
        "ruleBookInfo": {
          "init": "@js:init()",
          "name": "h1@text",
          "intro": ".intro@text"
        },
        "ruleToc": {
          "chapterList": ".chapters li",
          "chapterName": "a@text",
          "chapterUrl": "a@href"
        },
        "ruleContent": {
          "content": ".content",
          "title": "h2@text",
          "nextContentUrl": ".next@href"
        },
        "ruleReview": {
          "reviewUrl": "/reviews",
          "contentRule": ".review-content@text"
        }
      }
      ''';

      final json = jsonDecode(fullSourceJson) as Map<String, dynamic>;
      final source = BookSource.fromJson(json);

      expect(source.ruleSearch, isNotNull);
      expect(source.ruleExplore, isNotNull);
      expect(source.ruleBookInfo, isNotNull);
      expect(source.ruleToc, isNotNull);
      expect(source.ruleContent, isNotNull);
      expect(source.ruleReview, isNotNull);

      // 验证可以反序列化回 JSON
      final reSerialized = source.toJson();
      // 规则对象需要单独转换为 JSON
      expect(source.ruleSearch!.toJson()['bookList'], '.list');
      expect(source.ruleExplore!.toJson()['bookList'], '.explore-list');
      expect(source.ruleContent!.toJson()['content'], '.content');
    });

    test('should handle null fields gracefully', () {
      final minimalJson = '''
      {
        "bookSourceUrl": "https://minimal.example.com",
        "bookSourceName": "最小源"
      }
      ''';

      final json = jsonDecode(minimalJson) as Map<String, dynamic>;
      final source = BookSource.fromJson(json);

      expect(source.bookSourceUrl, 'https://minimal.example.com');
      expect(source.bookSourceName, '最小源');
      expect(source.enabled, true); // 默认值
      expect(source.ruleSearch, isNull);
      expect(source.ruleExplore, isNull);

      // 验证可以反序列化回 JSON
      final reSerialized = source.toJson();
      expect(reSerialized.containsKey('ruleSearch'), false); // null 字段不包含
    });
  });
}
