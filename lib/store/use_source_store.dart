import 'dart:convert';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/book_source.dart';
import '../models/book_source_part.dart';
import '../models/book_source_type.dart';
import '../models/import_result.dart';
import '../models/source_subscription.dart';
import '../models/store/source_state.dart';
import '../utils/network/network_factory.dart';
import 'persistent_store.dart';

const _boxName = 'source_state';
const _stateKey = 'state';

/// 源统计信息
class SourceStatistics {
  final int total;
  final int enabled;
  final int disabled;
  final int active;
  final int error;
  final Map<int, int> byType;

  const SourceStatistics({
    required this.total,
    required this.enabled,
    required this.disabled,
    required this.active,
    required this.error,
    required this.byType,
  });
}

class SourceStore extends PersistentStore<SourceState> {
  SourceStore() : super(const SourceState());

  // ========== 源 CRUD ==========

  /// 添加源
  ///
  /// 如果 bookSourceUrl 已存在，抛出异常
  Future<void> addSource(BookSource source) async {
    // 确保 bookSourceUrl 唯一
    if (state.sources.any((s) => s.bookSourceUrl == source.bookSourceUrl)) {
      throw Exception('源地址已存在: ${source.bookSourceUrl}');
    }

    set(state.copyWith(
      sources: [...state.sources, source],
    ));

    // 更新分组列表
    _updateGroups();

    await save(state);
  }

  /// 删除源
  Future<void> removeSource(String bookSourceUrl) async {
    set(state.copyWith(
      sources: state.sources.where((s) => s.bookSourceUrl != bookSourceUrl).toList(),
    ));

    _updateGroups();
    await save(state);
  }

  /// 批量删除源
  Future<void> removeSources(List<String> urls) async {
    final urlSet = urls.toSet();
    set(state.copyWith(
      sources: state.sources.where((s) => !urlSet.contains(s.bookSourceUrl)).toList(),
    ));

    _updateGroups();
    await save(state);
  }

  /// 更新源
  Future<void> updateSource(BookSource source) async {
    final index = state.sources.indexWhere(
      (s) => s.bookSourceUrl == source.bookSourceUrl,
    );

    if (index == -1) {
      throw Exception('源不存在: ${source.bookSourceUrl}');
    }

    final newList = List<BookSource>.from(state.sources);
    newList[index] = source;

    set(state.copyWith(sources: newList));

    _updateGroups();
    await save(state);
  }

  /// 批量更新源
  Future<void> updateSources(List<BookSource> sources) async {
    final sourceMap = {
      for (final s in sources) s.bookSourceUrl: s,
    };

    set(state.copyWith(
      sources: state.sources.map((s) {
        return sourceMap[s.bookSourceUrl] ?? s;
      }).toList(),
    ));

    _updateGroups();
    await save(state);
  }

  /// 获取单个源
  BookSource? getSource(String bookSourceUrl) {
    try {
      return state.sources.firstWhere(
        (s) => s.bookSourceUrl == bookSourceUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// 是否存在源
  bool hasSource(String bookSourceUrl) {
    return state.sources.any((s) => s.bookSourceUrl == bookSourceUrl);
  }

  /// 源总数
  int get sourceCount => state.sources.length;

  /// 更新分组列表
  void _updateGroups() {
    final allGroups = <String>{};
    for (final source in state.sources) {
      if (source.bookSourceGroup != null && source.bookSourceGroup!.isNotEmpty) {
        final groups = source.bookSourceGroup!
            .split(RegExp(r'[,;，；]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        allGroups.addAll(groups);
      }
    }

    set(state.copyWith(
      groups: allGroups.toList()..sort(),
    ));
  }

  // ========== 批量操作 ==========

  /// 批量启用/禁用源
  Future<void> enableSources(List<String> urls, bool enable) async {
    final urlSet = urls.toSet();

    set(state.copyWith(
      sources: state.sources.map((s) {
        if (urlSet.contains(s.bookSourceUrl)) {
          return s.copyWith(enabled: enable);
        }
        return s;
      }).toList(),
    ));

    await save(state);
  }

  /// 批量启用/禁用发现
  Future<void> enableExploreSources(List<String> urls, bool enable) async {
    final urlSet = urls.toSet();

    set(state.copyWith(
      sources: state.sources.map((s) {
        if (urlSet.contains(s.bookSourceUrl)) {
          return s.copyWith(enabledExplore: enable);
        }
        return s;
      }).toList(),
    ));

    await save(state);
  }

  /// 置顶选中源
  ///
  /// 将选中源的 customOrder 设为最小值 - 1
  Future<void> topSources(List<String> urls) async {
    if (urls.isEmpty) return;

    final urlSet = urls.toSet();

    // 获取当前最小排序值
    final minOrder = state.sources.isEmpty
        ? 0
        : state.sources.map((s) => s.customOrder).reduce((a, b) => a < b ? a : b);

    var index = 0;
    set(state.copyWith(
      sources: state.sources.map((s) {
        if (urlSet.contains(s.bookSourceUrl)) {
          return s.copyWith(customOrder: minOrder - 1 - index++);
        }
        return s;
      }).toList(),
    ));

    await save(state);
  }

  /// 置底选中源
  ///
  /// 将选中源的 customOrder 设为最大值 + 1
  Future<void> bottomSources(List<String> urls) async {
    if (urls.isEmpty) return;

    final urlSet = urls.toSet();

    // 获取当前最大排序值
    final maxOrder = state.sources.isEmpty
        ? 0
        : state.sources.map((s) => s.customOrder).reduce((a, b) => a > b ? a : b);

    var index = 0;
    set(state.copyWith(
      sources: state.sources.map((s) {
        if (urlSet.contains(s.bookSourceUrl)) {
          return s.copyWith(customOrder: maxOrder + 1 + index++);
        }
        return s;
      }).toList(),
    ));

    await save(state);
  }

  /// 调整排序编号
  ///
  /// 当排序编号超出范围或存在重复时，重新按 0..N 编号
  Future<void> adjustSortNumbers() async {
    final sorted = List<BookSource>.from(state.sources)
      ..sort((a, b) => a.customOrder.compareTo(b.customOrder));

    bool needsAdjust = false;

    // 检查是否超出范围
    for (final source in sorted) {
      if (source.customOrder < -99999 || source.customOrder > 99999) {
        needsAdjust = true;
        break;
      }
    }

    // 检查是否有重复
    if (!needsAdjust) {
      final orders = sorted.map((s) => s.customOrder).toSet();
      if (orders.length != sorted.length) {
        needsAdjust = true;
      }
    }

    if (needsAdjust) {
      set(state.copyWith(
        sources: List.generate(sorted.length, (i) {
          return sorted[i].copyWith(customOrder: i);
        }),
      ));
      await save(state);
    }
  }

  // ========== 分组管理 ==========

  /// 添加分组
  ///
  /// 如果分组已存在，不做任何操作
  Future<void> addGroup(String group) async {
    if (group.isEmpty) return;

    if (!state.groups.contains(group)) {
      set(state.copyWith(
        groups: [...state.groups, group]..sort(),
      ));
      await save(state);
    }
  }

  /// 删除分组
  ///
  /// 从所有源中移除该分组
  Future<void> removeGroup(String group) async {
    // 从分组列表中移除
    set(state.copyWith(
      groups: state.groups.where((g) => g != group).toList(),
    ));

    // 从所有源中移除该分组
    set(state.copyWith(
      sources: state.sources.map((s) {
        if (s.bookSourceGroup == null) return s;

        final groups = s.groupList..remove(group);
        return s.copyWith(
          bookSourceGroup: groups.isEmpty ? null : groups.join(','),
        );
      }).toList(),
    ));

    await save(state);
  }

  /// 重命名分组
  Future<void> renameGroup(String oldGroup, String newGroup) async {
    if (oldGroup.isEmpty || newGroup.isEmpty) return;
    if (oldGroup == newGroup) return;

    // 更新分组列表
    set(state.copyWith(
      groups: state.groups.map((g) => g == oldGroup ? newGroup : g).toList()..sort(),
    ));

    // 更新所有源中的分组名
    set(state.copyWith(
      sources: state.sources.map((s) {
        if (s.bookSourceGroup == null) return s;

        final groups = s.groupList.map((g) => g == oldGroup ? newGroup : g).toList();
        return s.copyWith(bookSourceGroup: groups.join(','));
      }).toList(),
    ));

    await save(state);
  }

  /// 将源添加到分组
  Future<void> addToGroup(List<String> urls, String group) async {
    if (group.isEmpty || urls.isEmpty) return;

    final urlSet = urls.toSet();

    // 确保分组存在
    await addGroup(group);

    set(state.copyWith(
      sources: state.sources.map((s) {
        if (urlSet.contains(s.bookSourceUrl)) {
          return s.addGroup(group);
        }
        return s;
      }).toList(),
    ));

    await save(state);
  }

  /// 将源从分组移除
  Future<void> removeFromGroup(List<String> urls, String group) async {
    if (group.isEmpty || urls.isEmpty) return;

    final urlSet = urls.toSet();

    set(state.copyWith(
      sources: state.sources.map((s) {
        if (urlSet.contains(s.bookSourceUrl)) {
          return s.removeGroup(group);
        }
        return s;
      }).toList(),
    ));

    _updateGroups();
    await save(state);
  }

  /// 获取所有分组
  List<String> get allGroups => state.groups;

  /// 按分组获取源
  List<BookSource> getSourcesByGroup(String group) {
    return state.sources.where((s) => s.hasGroup(group)).toList();
  }

  /// 获取无分组的源
  List<BookSource> getSourcesWithoutGroup() {
    return state.sources.where((s) => s.groupList.isEmpty).toList();
  }

  // ========== 排序 ==========

  /// 设置排序方式
  Future<void> setSortBy(int sortBy) async {
    if (state.sortBy != sortBy) {
      set(state.copyWith(sortBy: sortBy));
      await save(state);
    }
  }

  /// 切换排序方向
  Future<void> toggleSortDirection() async {
    set(state.copyWith(sortAscending: !state.sortAscending));
    await save(state);
  }

  /// 设置排序方向
  Future<void> setSortAscending(bool ascending) async {
    if (state.sortAscending != ascending) {
      set(state.copyWith(sortAscending: ascending));
      await save(state);
    }
  }

  /// 获取排序后的源列表
  ///
  /// 根据当前排序方式和方向返回排序后的源
  List<BookSource> getSortedSources() {
    final sources = List<BookSource>.from(state.sources);

    switch (state.sortBy) {
      case 0: // custom - 手动排序
        sources.sort((a, b) => a.customOrder.compareTo(b.customOrder));

      case 1: // name - 按名称
        sources.sort((a, b) => _cnCompare(a.bookSourceName, b.bookSourceName));

      case 2: // url - 按URL
        sources.sort((a, b) => a.bookSourceUrl.compareTo(b.bookSourceUrl));

      case 3: // weight - 按权重
        sources.sort((a, b) => a.weight.compareTo(b.weight));

      case 4: // update - 按更新时间
        sources.sort((a, b) => a.lastUpdateTime.compareTo(b.lastUpdateTime));

      case 5: // enable - 按启用状态
        sources.sort((a, b) {
          if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
          return _cnCompare(a.bookSourceName, b.bookSourceName);
        });

      case 6: // respond - 按响应时间
        sources.sort((a, b) => a.respondTime.compareTo(b.respondTime));
    }

    if (!state.sortAscending) {
      return sources.reversed.toList();
    }

    return sources;
  }

  /// 中文排序比较
  int _cnCompare(String a, String b) {
    // 简单的中文排序：按 Unicode 编码排序
    return a.compareTo(b);
  }

  /// 获取排序后的轻量视图列表
  List<BookSourcePart> getSortedSourceParts() {
    return getSortedSources().map(
      (s) => BookSourcePart.fromBookSource(s),
    ).toList();
  }

  // ========== 导入导出 ==========

  /// 导入源
  ///
  /// 支持以下格式：
  /// - URL：自动下载并解析
  /// - JSON 字符串（单个对象或数组）
  /// - 包含 sourceUrls 的对象
  ///
  /// [merge] 是否合并模式（true）还是替换模式（false）
  Future<ImportResult> importSources(String input, {bool merge = true}) async {
    String jsonStr = input;
    List<String> errors = [];

    // 1. 如果是URL，先下载
    if (_isUrl(input)) {
      try {
        final response = await NetworkFactory.instance.get(
          input,
          timeout: const Duration(seconds: 30),
        );
        if (response.statusCode != 200) {
          return ImportResult(
            sources: [],
            newCount: 0,
            updatedCount: 0,
            errors: ['下载失败: HTTP ${response.statusCode}'],
          );
        }
        jsonStr = response.body;
      } catch (e) {
        return ImportResult(
          sources: [],
          newCount: 0,
          updatedCount: 0,
          errors: ['下载失败: $e'],
        );
      }
    }

    // 2. 解析JSON
    List<BookSource> sources = [];
    try {
      final dynamic jsonData = jsonDecode(jsonStr);

      if (jsonData is List) {
        // JSON数组：多个源
        for (var i = 0; i < jsonData.length; i++) {
          final item = jsonData[i];
          try {
            final source = BookSource.fromJson(item as Map<String, dynamic>);
            sources.add(source);
          } catch (e) {
            errors.add('解析源失败: $e');
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        if (jsonData.containsKey('bookSourceUrl')) {
          // 单个源对象
          final source = BookSource.fromJson(jsonData);
          sources.add(source);
        } else if (jsonData.containsKey('sourceUrls')) {
          // 包含URL列表，逐个下载
          final urls = List<String>.from(jsonData['sourceUrls']);
          for (final url in urls) {
            try {
              final result = await importSources(url, merge: merge);
              sources.addAll(result.sources);
              errors.addAll(result.errors);
            } catch (e) {
              errors.add('导入URL失败 ($url): $e');
            }
          }
        } else {
          errors.add('无法识别的JSON格式');
        }
      } else {
        errors.add('无效的JSON格式');
      }
    } catch (e) {
      errors.add('JSON解析失败: $e');
    }

    if (sources.isEmpty) {
      return ImportResult(
        sources: [],
        newCount: 0,
        updatedCount: 0,
        errors: errors,
      );
    }

    // 3. 合并或替换
    int newCount = 0;
    int updatedCount = 0;

    if (merge) {
      // 按 bookSourceUrl 去重合并
      final existingMap = {
        for (final s in state.sources) s.bookSourceUrl: s,
      };

      for (final source in sources) {
        if (existingMap.containsKey(source.bookSourceUrl)) {
          // 更新已存在的源
          existingMap[source.bookSourceUrl] = source;
          updatedCount++;
        } else {
          // 添加新源
          existingMap[source.bookSourceUrl] = source;
          newCount++;
        }
      }

      set(state.copyWith(
        sources: existingMap.values.toList(),
      ));
    } else {
      // 替换模式
      newCount = sources.length;
      set(state.copyWith(sources: sources));
    }

    // 4. 调整排序编号
    await adjustSortNumbers();

    // 5. 更新分组列表
    _updateGroups();

    await save(state);

    return ImportResult(
      sources: sources,
      newCount: newCount,
      updatedCount: updatedCount,
      errors: errors,
    );
  }

  /// 导出源
  ///
  /// [urls] 指定要导出的源URL列表，null 表示导出全部
  ///
  /// 返回导出的 JSON 字符串
  Future<String> exportSources({List<String>? urls}) async {
    List<BookSource> sourcesToExport;

    if (urls != null && urls.isNotEmpty) {
      // 导出指定源
      final urlSet = urls.toSet();
      sourcesToExport = state.sources
          .where((s) => urlSet.contains(s.bookSourceUrl))
          .toList();
    } else {
      // 导出全部
      sourcesToExport = List.from(state.sources);
    }

    // 安全考虑：清除高危API标记
    sourcesToExport = sourcesToExport.map((s) =>
      s.copyWith(enableDangerousApi: false)
    ).toList();

    // 序列化为JSON
    final jsonStr = jsonEncode(
      sourcesToExport.map((s) => s.toJson()).toList(),
    );

    return jsonStr;
  }

  /// 判断是否为URL
  bool _isUrl(String str) {
    return str.startsWith('http://') || str.startsWith('https://');
  }

  // ========== 源测试 ==========

  /// 测试单个源
  ///
  /// 发起 HTTP GET 请求测试源可用性
  /// 更新 respondTime 和 lastUpdateTime
  Future<bool> testSource(String bookSourceUrl) async {
    final source = getSource(bookSourceUrl);
    if (source == null) return false;

    final stopwatch = Stopwatch()..start();

    try {
      final response = await NetworkFactory.instance.get(
        source.bookSourceUrl,
        headers: _parseHeaders(source.header),
        timeout: const Duration(seconds: 10),
      );

      stopwatch.stop();

      final success = response.statusCode >= 200 && response.statusCode < 400;

      // 更新源状态
      await updateSource(source.copyWith(
        respondTime: stopwatch.elapsedMilliseconds,
        lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
      ));

      return success;
    } catch (e) {
      stopwatch.stop();

      // 更新为超时/错误状态
      await updateSource(source.copyWith(
        respondTime: 180000, // 标记为超时
      ));

      return false;
    }
  }

  /// 测试多个源
  ///
  /// [urls] 要测试的源URL列表，null 表示测试全部
  /// [threadCount] 并发数
  Future<Map<String, bool>> testSources({
    List<String>? urls,
    int threadCount = 5,
  }) async {
    final sourcesToTest = urls != null
        ? state.sources.where((s) => urls.contains(s.bookSourceUrl)).toList()
        : state.sources;

    final results = <String, bool>{};

    // 分批并发测试
    for (var i = 0; i < sourcesToTest.length; i += threadCount) {
      final batch = sourcesToTest.skip(i).take(threadCount);
      final futures = batch.map((source) async {
        final success = await testSource(source.bookSourceUrl);
        return MapEntry(source.bookSourceUrl, success);
      });

      final batchResults = await Future.wait(futures);
      for (final entry in batchResults) {
        results[entry.key] = entry.value;
      }
    }

    return results;
  }

  /// 解析请求头
  Map<String, String>? _parseHeaders(String? header) {
    if (header == null || header.isEmpty) return null;

    try {
      final Map<String, dynamic> headerMap = jsonDecode(header);
      return headerMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return null;
    }
  }

  // ========== 查询 ==========

  /// 搜索源
  ///
  /// 按名称、URL、分组、注释搜索
  List<BookSourcePart> searchSources(String keyword) {
    if (keyword.isEmpty) return getSortedSourceParts();

    final lowerKeyword = keyword.toLowerCase();

    return getSortedSources()
        .where((s) {
          return s.bookSourceName.toLowerCase().contains(lowerKeyword) ||
              s.bookSourceUrl.toLowerCase().contains(lowerKeyword) ||
              (s.bookSourceGroup?.toLowerCase().contains(lowerKeyword) ?? false) ||
              (s.bookSourceComment?.toLowerCase().contains(lowerKeyword) ?? false);
        })
        .map((s) => BookSourcePart.fromBookSource(s))
        .toList();
  }

  /// 获取已启用的源
  List<BookSourcePart> getEnabledSources() {
    return getSortedSources()
        .where((s) => s.enabled)
        .map((s) => BookSourcePart.fromBookSource(s))
        .toList();
  }

  /// 获取已禁用的源
  List<BookSourcePart> getDisabledSources() {
    return getSortedSources()
        .where((s) => !s.enabled)
        .map((s) => BookSourcePart.fromBookSource(s))
        .toList();
  }

  /// 获取有发现URL的源
  List<BookSourcePart> getExploreSources() {
    return getSortedSources()
        .where((s) => s.enabled && s.hasExploreUrl)
        .map((s) => BookSourcePart.fromBookSource(s))
        .toList();
  }

  /// 获取有登录配置的源
  List<BookSourcePart> getLoginSources() {
    return getSortedSources()
        .where((s) => s.hasLogin)
        .map((s) => BookSourcePart.fromBookSource(s))
        .toList();
  }

  /// 获取无分组的源
  List<BookSourcePart> getNoGroupSources() {
    return getSortedSources()
        .where((s) => s.groupList.isEmpty)
        .map((s) => BookSourcePart.fromBookSource(s))
        .toList();
  }

  /// 获取错误状态的源（超时）
  List<BookSourcePart> getErrorSources() {
    return getSortedSources()
        .where((s) => s.enabled && s.respondTime >= 180000)
        .map((s) => BookSourcePart.fromBookSource(s))
        .toList();
  }

  /// 按类型筛选源
  List<BookSourcePart> getSourcesByType(int type) {
    return getSortedSources()
        .where((s) => s.bookSourceType == type)
        .map((s) => BookSourcePart.fromBookSource(s))
        .toList();
  }

  /// 按分组筛选源
  List<BookSourcePart> getSourcesByGroupFiltered(String group) {
    return getSortedSources()
        .where((s) => s.hasGroup(group))
        .map((s) => BookSourcePart.fromBookSource(s))
        .toList();
  }

  /// 获取源统计信息
  SourceStatistics getStatistics() {
    final sources = state.sources;

    return SourceStatistics(
      total: sources.length,
      enabled: sources.where((s) => s.enabled).length,
      disabled: sources.where((s) => !s.enabled).length,
      active: sources.where((s) => s.enabled && s.respondTime < 180000).length,
      error: sources.where((s) => s.enabled && s.respondTime >= 180000).length,
      byType: {
        for (final type in BookSourceType.allTypes)
          type: sources.where((s) => s.bookSourceType == type).length,
      },
    );
  }

  // ========== 订阅管理 ==========

  /// 添加订阅
  ///
  /// 按 URL 去重
  Future<void> addSubscription(SourceSubscription sub) async {
    // 检查是否已存在
    if (state.subscriptions.any((s) => s.url == sub.url)) {
      throw Exception('订阅已存在: ${sub.url}');
    }

    set(state.copyWith(
      subscriptions: [...state.subscriptions, sub],
    ));

    await save(state);
  }

  /// 删除订阅
  Future<void> removeSubscription(String url) async {
    set(state.copyWith(
      subscriptions: state.subscriptions.where((s) => s.url != url).toList(),
    ));

    await save(state);
  }

  /// 更新订阅
  Future<void> updateSubscription(String url, SourceSubscription sub) async {
    set(state.copyWith(
      subscriptions: state.subscriptions.map((s) {
        return s.url == url ? sub : s;
      }).toList(),
    ));

    await save(state);
  }

  /// 同步单个订阅
  ///
  /// 下载订阅URL的JSON，导入源（合并模式）
  Future<ImportResult> syncSubscription(String url) async {
    final index = state.subscriptions.indexWhere((s) => s.url == url);
    if (index == -1) {
      throw Exception('订阅不存在: $url');
    }

    final sub = state.subscriptions[index];

    try {
      // 导入源
      final result = await importSources(url, merge: true);

      // 更新订阅状态
      await updateSubscription(url, sub.copyWith(
        lastSyncTime: DateTime.now().millisecondsSinceEpoch,
        lastSyncSuccess: true,
        sourceCount: result.sources.length,
      ));

      return result;
    } catch (e) {
      // 更新为失败状态
      await updateSubscription(url, sub.copyWith(
        lastSyncTime: DateTime.now().millisecondsSinceEpoch,
        lastSyncSuccess: false,
      ));

      rethrow;
    }
  }

  /// 同步所有订阅
  Future<List<ImportResult>> syncAllSubscriptions() async {
    final results = <ImportResult>[];

    for (final sub in state.subscriptions) {
      try {
        final result = await syncSubscription(sub.url);
        results.add(result);
      } catch (e) {
        results.add(ImportResult(
          sources: [],
          newCount: 0,
          updatedCount: 0,
          errors: ['同步失败 (${sub.url}): $e'],
        ));
      }
    }

    return results;
  }

  /// 获取订阅列表
  List<SourceSubscription> get subscriptions => state.subscriptions;

  // ============================================================
  // Hive 持久化
  // ============================================================

  /// 从 Hive Box 加载状态
  @override
  Future<SourceState?> load() async {
    try {
      final box = await Hive.openBox(_boxName);
      final jsonStr = box.get(_stateKey) as String?;
      if (jsonStr != null) {
        return SourceState.fromJson(json.decode(jsonStr));
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 将状态保存到 Hive Box
  @override
  Future<void> save(SourceState state) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_stateKey, json.encode(state.toJson()));
    } catch (e) {
      // ignore
    }
  }
}

SourceStore useSourceStore() => create(() => SourceStore());
