import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iris/models/book_source.dart';
import 'package:iris/store/use_source_store.dart';

void main() {
  late SourceStore store;

  setUpAll(() async {
    // 初始化 Hive 用于测试
    Hive.init('./test_hive_data');
  });

  setUp(() async {
    // 清理之前的测试数据
    try {
      final box = await Hive.openBox('source_state');
      await box.clear();
      await box.close();
    } catch (_) {}
    store = SourceStore();
  });

  tearDown(() async {
    store.dispose();
  });

  tearDownAll(() async {
    // 清理测试数据
    await Hive.deleteFromDisk();
  });

  group('SourceStore CRUD', () {
    test('should add source', () async {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );

      await store.addSource(source);

      expect(store.sourceCount, 1);
      expect(store.hasSource('https://example.com'), true);
    });

    test('should not add duplicate source', () async {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );

      await store.addSource(source);

      expect(
        () => store.addSource(source),
        throwsException,
      );
    });

    test('should remove source', () async {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );

      await store.addSource(source);
      await store.removeSource('https://example.com');

      expect(store.sourceCount, 0);
      expect(store.hasSource('https://example.com'), false);
    });

    test('should update source', () async {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );

      await store.addSource(source);

      final updated = source.copyWith(bookSourceName: '更新后的源');
      await store.updateSource(updated);

      final retrieved = store.getSource('https://example.com');
      expect(retrieved?.bookSourceName, '更新后的源');
    });

    test('should get source', () async {
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      );

      await store.addSource(source);

      final retrieved = store.getSource('https://example.com');
      expect(retrieved, isNotNull);
      expect(retrieved?.bookSourceName, '测试源');
    });

    test('should return null for non-existent source', () async {
      final retrieved = store.getSource('https://nonexistent.com');
      expect(retrieved, isNull);
    });
  });

  group('SourceStore Batch Operations', () {
    test('should enable/disable sources', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source1.com',
        bookSourceName: '源1',
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source2.com',
        bookSourceName: '源2',
      ));

      await store.enableSources(['https://source1.com'], false);

      expect(store.getSource('https://source1.com')?.enabled, false);
      expect(store.getSource('https://source2.com')?.enabled, true);
    });

    test('should enable/disable explore', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source1.com',
        bookSourceName: '源1',
      ));

      await store.enableExploreSources(['https://source1.com'], false);

      expect(store.getSource('https://source1.com')?.enabledExplore, false);
    });

    test('should top sources', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source1.com',
        bookSourceName: '源1',
        customOrder: 0,
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source2.com',
        bookSourceName: '源2',
        customOrder: 1,
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source3.com',
        bookSourceName: '源3',
        customOrder: 2,
      ));

      await store.topSources(['https://source3.com']);

      final sorted = store.getSortedSources();
      expect(sorted.first.bookSourceUrl, 'https://source3.com');
    });

    test('should bottom sources', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source1.com',
        bookSourceName: '源1',
        customOrder: 0,
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source2.com',
        bookSourceName: '源2',
        customOrder: 1,
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source3.com',
        bookSourceName: '源3',
        customOrder: 2,
      ));

      await store.bottomSources(['https://source1.com']);

      final sorted = store.getSortedSources();
      expect(sorted.last.bookSourceUrl, 'https://source1.com');
    });

    test('should batch remove sources', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source1.com',
        bookSourceName: '源1',
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source2.com',
        bookSourceName: '源2',
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source3.com',
        bookSourceName: '源3',
      ));

      await store.removeSources(['https://source1.com', 'https://source3.com']);

      expect(store.sourceCount, 1);
      expect(store.hasSource('https://source2.com'), true);
    });
  });

  group('SourceStore Groups', () {
    test('should add group', () async {
      await store.addGroup('测试分组');

      expect(store.allGroups, contains('测试分组'));
    });

    test('should add source to group', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      ));

      await store.addToGroup(['https://example.com'], '测试分组');

      final source = store.getSource('https://example.com');
      expect(source?.hasGroup('测试分组'), true);
      expect(store.allGroups, contains('测试分组'));
    });

    test('should remove group', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        bookSourceGroup: '分组1,分组2',
      ));

      await store.removeGroup('分组1');

      final source = store.getSource('https://example.com');
      expect(source?.hasGroup('分组1'), false);
      expect(source?.hasGroup('分组2'), true);
    });

    test('should rename group', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        bookSourceGroup: '旧分组',
      ));

      await store.renameGroup('旧分组', '新分组');

      final source = store.getSource('https://example.com');
      expect(source?.hasGroup('旧分组'), false);
      expect(source?.hasGroup('新分组'), true);
    });

    test('should remove source from group', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
        bookSourceGroup: '分组1,分组2',
      ));

      await store.removeFromGroup(['https://example.com'], '分组1');

      final source = store.getSource('https://example.com');
      expect(source?.hasGroup('分组1'), false);
      expect(source?.hasGroup('分组2'), true);
    });

    test('should get sources by group', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source1.com',
        bookSourceName: '源1',
        bookSourceGroup: '分组A',
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source2.com',
        bookSourceName: '源2',
        bookSourceGroup: '分组B',
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source3.com',
        bookSourceName: '源3',
        bookSourceGroup: '分组A',
      ));

      final groupASources = store.getSourcesByGroup('分组A');
      expect(groupASources.length, 2);
    });
  });

  group('SourceStore Sort', () {
    test('should sort by name', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://b.com',
        bookSourceName: 'B源',
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://a.com',
        bookSourceName: 'A源',
      ));

      await store.setSortBy(1); // name
      await store.setSortAscending(true);

      final sorted = store.getSortedSources();
      expect(sorted.first.bookSourceName, 'A源');
      expect(sorted.last.bookSourceName, 'B源');
    });

    test('should sort descending', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://a.com',
        bookSourceName: 'A源',
        weight: 10,
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://b.com',
        bookSourceName: 'B源',
        weight: 20,
      ));

      await store.setSortBy(3); // weight
      await store.setSortAscending(false);

      final sorted = store.getSortedSources();
      expect(sorted.first.weight, 20);
      expect(sorted.last.weight, 10);
    });

    test('should sort by url', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://b.com',
        bookSourceName: 'B源',
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://a.com',
        bookSourceName: 'A源',
      ));

      await store.setSortBy(2); // url
      await store.setSortAscending(true);

      final sorted = store.getSortedSources();
      expect(sorted.first.bookSourceUrl, 'https://a.com');
    });
  });

  group('SourceStore Query', () {
    test('should search sources', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '测试源',
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://other.com',
        bookSourceName: '其他源',
      ));

      final results = store.searchSources('测试');
      expect(results.length, 1);
      expect(results.first.bookSourceName, '测试源');
    });

    test('should get enabled sources', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://enabled.com',
        bookSourceName: '启用源',
        enabled: true,
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://disabled.com',
        bookSourceName: '禁用源',
        enabled: false,
      ));

      final enabled = store.getEnabledSources();
      expect(enabled.length, 1);
      expect(enabled.first.bookSourceName, '启用源');
    });

    test('should get disabled sources', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://enabled.com',
        bookSourceName: '启用源',
        enabled: true,
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://disabled.com',
        bookSourceName: '禁用源',
        enabled: false,
      ));

      final disabled = store.getDisabledSources();
      expect(disabled.length, 1);
      expect(disabled.first.bookSourceName, '禁用源');
    });

    test('should get statistics', () async {
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source1.com',
        bookSourceName: '源1',
        bookSourceType: 0,
        enabled: true,
        respondTime: 100,
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source2.com',
        bookSourceName: '源2',
        bookSourceType: 4,
        enabled: false,
      ));
      await store.addSource(BookSource(
        bookSourceUrl: 'https://source3.com',
        bookSourceName: '源3',
        bookSourceType: 0,
        enabled: true,
        respondTime: 180000,
      ));

      final stats = store.getStatistics();
      expect(stats.total, 3);
      expect(stats.enabled, 2);
      expect(stats.disabled, 1);
      expect(stats.active, 1);
      expect(stats.error, 1);
      expect(stats.byType[0], 2); // 2 个文本类型
      expect(stats.byType[4], 1); // 1 个视频类型
    });
  });
}
