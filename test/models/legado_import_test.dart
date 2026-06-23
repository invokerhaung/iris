import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris/models/book_source.dart';

void main() {
  group('Legado JSON Import Test', () {
    test('should parse real Legado JSON with String lastUpdateTime and empty array ruleBookInfo', () {
      // 用户提供的真实 Legado JSON
      final jsonStr = '''
      {
          "bookSourceComment": "Jable.TV按女优搜索播放 - 视频书源",
          "bookSourceGroup": "视频",
          "bookSourceName": "📺 Jable.TV",
          "bookSourceType": 4,
          "bookSourceUrl": "https://jable.tv",
          "customButton": false,
          "customOrder": 0,
          "enabled": true,
          "enabledCookieJar": true,
          "enabledExplore": true,
          "eventListener": false,
          "exploreUrl": "/models/{{page}}/",
          "header": "{\\"User-Agent\\":\\"Mozilla/5.0\\"}",
          "lastUpdateTime": "1779228932770",
          "respondTime": 180000,
          "ruleBookInfo": [],
          "ruleContent": {
              "content": "var hlsUrl = result;"
          },
          "ruleExplore": {
              "bookList": "class.video-img-box",
              "name": "tag.h6.title@tag.a@text"
          },
          "ruleSearch": {
              "bookList": "class.video-img-box",
              "name": "tag.h6.title@tag.a@text"
          },
          "ruleToc": {
              "chapterList": "class.video-img-box",
              "chapterName": "tag.h6.title@tag.a@text"
          },
          "searchUrl": "/search/?q={{key}}&page={{page}}",
          "weight": 0
      }
      ''';

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final source = BookSource.fromJson(json);

      // 验证基础字段
      expect(source.bookSourceUrl, 'https://jable.tv');
      expect(source.bookSourceName, '📺 Jable.TV');
      expect(source.bookSourceGroup, '视频');
      expect(source.bookSourceType, 4);
      expect(source.enabled, true);
      expect(source.weight, 0);

      // 验证 lastUpdateTime（String -> int 转换）
      expect(source.lastUpdateTime, 1779228932770);

      // 验证规则字段（空数组 -> null）
      expect(source.ruleBookInfo, isNull);

      // 验证正常规则字段
      expect(source.ruleSearch, isNotNull);
      expect(source.ruleSearch!.bookList, 'class.video-img-box');

      expect(source.ruleExplore, isNotNull);
      expect(source.ruleExplore!.bookList, 'class.video-img-box');

      expect(source.ruleToc, isNotNull);
      expect(source.ruleToc!.chapterList, 'class.video-img-box');

      expect(source.ruleContent, isNotNull);
      expect(source.ruleContent!.content, 'var hlsUrl = result;');

      // 验证可以反序列化回 JSON
      final reSerialized = source.toJson();
      expect(reSerialized['bookSourceUrl'], 'https://jable.tv');
      expect(reSerialized['lastUpdateTime'], 1779228932770);
    });

    test('should parse Legado JSON array', () {
      final jsonStr = '''
      [
        {
          "bookSourceUrl": "https://source1.com",
          "bookSourceName": "源1",
          "enabled": true,
          "lastUpdateTime": "1000000",
          "ruleBookInfo": []
        },
        {
          "bookSourceUrl": "https://source2.com",
          "bookSourceName": "源2",
          "enabled": false,
          "lastUpdateTime": 2000000,
          "ruleBookInfo": {"name": "h1@text"}
        }
      ]
      ''';

      final jsonList = jsonDecode(jsonStr) as List;
      final sources = jsonList
          .map((e) => BookSource.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(sources.length, 2);

      // 第一个源：String lastUpdateTime, 空数组 ruleBookInfo
      expect(sources[0].bookSourceUrl, 'https://source1.com');
      expect(sources[0].lastUpdateTime, 1000000);
      expect(sources[0].ruleBookInfo, isNull);

      // 第二个源：int lastUpdateTime, 对象 ruleBookInfo
      expect(sources[1].bookSourceUrl, 'https://source2.com');
      expect(sources[1].lastUpdateTime, 2000000);
      expect(sources[1].ruleBookInfo, isNotNull);
    });
  });
}
