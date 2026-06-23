import 'package:flutter_test/flutter_test.dart';
import 'package:iris/models/book_source.dart';
import 'package:iris/models/book_source_type.dart';
import 'package:iris/models/book_source_part.dart';

void main() {
  group('BookSource', () {
    test('should create with default values', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );

      expect(source.bookSourceUrl, 'https://example.com');
      expect(source.bookSourceName, '测试源');
      expect(source.enabled, true);
      expect(source.enabledExplore, true);
      expect(source.bookSourceType, 0);
      expect(source.weight, 0);
      expect(source.respondTime, 180000);
    });

    test('should parse Legado JSON correctly', () {
      final json = {
        'bookSourceUrl': 'https://example.com',
        'bookSourceName': '示例源',
        'bookSourceGroup': '分组1,分组2',
        'bookSourceType': 4,
        'enabled': true,
        'enabledExplore': true,
        'weight': 100,
        'searchUrl': 'https://example.com/search?keyword={{key}}',
        'ruleSearch': {
          'checkKeyWord': '我的',
          'bookList': '.book-item',
          'name': 'h3@text',
          'bookUrl': 'a@href',
        },
      };

      final source = BookSource.fromJson(json);

      expect(source.bookSourceUrl, 'https://example.com');
      expect(source.bookSourceName, '示例源');
      expect(source.bookSourceGroup, '分组1,分组2');
      expect(source.bookSourceType, 4);
      expect(source.weight, 100);
      expect(source.searchUrl, 'https://example.com/search?keyword={{key}}');
      expect(source.ruleSearch, isNotNull);
      expect(source.ruleSearch!.checkKeyWord, '我的');
      expect(source.ruleSearch!.bookList, '.book-item');
    });

    test('should serialize to JSON without null fields', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );

      final json = source.toJson();

      expect(json.containsKey('bookSourceUrl'), true);
      expect(json.containsKey('bookSourceName'), true);
      expect(json.containsKey('jsLib'), false); // null 字段不包含
      expect(json.containsKey('loginUrl'), false);
    });

    test('should handle group operations', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        bookSourceGroup: '分组1,分组2',
      );

      expect(source.groupList, ['分组1', '分组2']);
      expect(source.hasGroup('分组1'), true);
      expect(source.hasGroup('分组3'), false);

      final added = source.addGroup('分组3');
      expect(added.groupList, ['分组1', '分组2', '分组3']);

      final removed = source.removeGroup('分组1');
      expect(removed.groupList, ['分组2']);
    });

    test('should format respond time', () {
      final source1 = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        respondTime: 150,
      );
      expect(source1.respondTimeFormatted, '150ms');

      final source2 = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        respondTime: 1500,
      );
      expect(source2.respondTimeFormatted, '1.5s');

      final source3 = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        respondTime: 180000,
      );
      expect(source3.respondTimeFormatted, '超时');
    });

    test('should handle explore URL', () {
      final sourceWithExplore = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        exploreUrl: 'https://example.com/explore',
      );
      expect(sourceWithExplore.hasExploreUrl, true);

      final sourceWithoutExplore = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );
      expect(sourceWithoutExplore.hasExploreUrl, false);
    });

    test('should handle search URL', () {
      final sourceWithSearch = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        searchUrl: 'https://example.com/search?keyword={{key}}',
      );
      expect(sourceWithSearch.hasSearchUrl, true);

      final sourceWithoutSearch = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );
      expect(sourceWithoutSearch.hasSearchUrl, false);
    });

    test('should handle login URL', () {
      final sourceWithLogin = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        loginUrl: 'https://example.com/login',
      );
      expect(sourceWithLogin.hasLogin, true);

      final sourceWithoutLogin = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );
      expect(sourceWithoutLogin.hasLogin, false);
    });

    test('should format last update time', () {
      final sourceNever = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        lastUpdateTime: 0,
      );
      expect(sourceNever.lastUpdateTimeFormatted, '从未更新');

      final sourceWithTime = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        lastUpdateTime: 1718563200000, // 2024-06-17 00:00:00 UTC
      );
      expect(sourceWithTime.lastUpdateTimeFormatted, contains('2024'));
    });

    test('should identify media type', () {
      final videoSource = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '视频源',
        bookSourceType: BookSourceType.video,
      );
      expect(videoSource.isMediaType, true);
      expect(videoSource.typeName, '视频');

      final textSource = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '文本源',
        bookSourceType: BookSourceType.defaultType,
      );
      expect(textSource.isMediaType, false);
      expect(textSource.typeName, '文本');
    });
  });

  group('BookSourceType', () {
    test('should return correct type names', () {
      expect(BookSourceType.getName(0), '文本');
      expect(BookSourceType.getName(1), '音频');
      expect(BookSourceType.getName(2), '图片');
      expect(BookSourceType.getName(3), '文件');
      expect(BookSourceType.getName(4), '视频');
      expect(BookSourceType.getName(5), 'RSS');
    });

    test('should identify media types', () {
      expect(BookSourceType.isMediaType(0), false);
      expect(BookSourceType.isMediaType(1), true);  // 音频
      expect(BookSourceType.isMediaType(4), true);  // 视频
    });

    test('should return all types', () {
      final allTypes = BookSourceType.allTypes;
      expect(allTypes.length, 6);
      expect(allTypes, [0, 1, 2, 3, 4, 5]);
    });

    test('should return correct icon names', () {
      expect(BookSourceType.getIconName(0), 'book');
      expect(BookSourceType.getIconName(1), 'music_note');
      expect(BookSourceType.getIconName(4), 'videocam');
    });
  });

  group('BookSourcePart', () {
    test('should create from BookSource', () {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        bookSourceGroup: '分组1',
        bookSourceType: 4,
        enabled: true,
        respondTime: 100,
      );

      final part = BookSourcePart.fromBookSource(source);

      expect(part.bookSourceUrl, source.bookSourceUrl);
      expect(part.bookSourceName, source.bookSourceName);
      expect(part.bookSourceGroup, source.bookSourceGroup);
      expect(part.bookSourceType, source.bookSourceType);
      expect(part.enabled, source.enabled);
      expect(part.respondTime, source.respondTime);
    });

    test('should identify status correctly', () {
      final active = BookSourcePart(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        enabled: true,
        respondTime: 100,
      );
      expect(active.isActive, true);
      expect(active.isError, false);
      expect(active.isDisabled, false);

      final error = BookSourcePart(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        enabled: true,
        respondTime: 180000,
      );
      expect(error.isActive, false);
      expect(error.isError, true);

      final disabled = BookSourcePart(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        enabled: false,
      );
      expect(disabled.isDisabled, true);
    });

    test('should handle group operations', () {
      final part = BookSourcePart(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        bookSourceGroup: '分组1,分组2',
      );

      expect(part.groupList, ['分组1', '分组2']);
      expect(part.hasGroup('分组1'), true);
      expect(part.hasGroup('分组3'), false);
      expect(part.hasGroupAny, true);
    });

    test('should format respond time', () {
      final part1 = BookSourcePart(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        respondTime: 150,
      );
      expect(part1.respondTimeFormatted, '150ms');

      final part2 = BookSourcePart(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        respondTime: 1500,
      );
      expect(part2.respondTimeFormatted, '1.5s');

      final part3 = BookSourcePart(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        respondTime: 180000,
      );
      expect(part3.respondTimeFormatted, '超时');
    });

    test('should identify media type', () {
      final videoPart = BookSourcePart(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '视频源',
        bookSourceType: BookSourceType.video,
      );
      expect(videoPart.isMediaType, true);
      expect(videoPart.typeName, '视频');

      final textPart = BookSourcePart(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '文本源',
        bookSourceType: BookSourceType.defaultType,
      );
      expect(textPart.isMediaType, false);
      expect(textPart.typeName, '文本');
    });
  });
}
