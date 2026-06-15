import 'dart:convert';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:iris/models/source_subscription.dart';
import 'package:iris/models/store/source_state.dart';
import 'package:iris/models/video_source.dart';
import 'package:iris/store/persistent_store.dart';
import 'package:iris/utils/logger.dart';
import 'package:uuid/uuid.dart';

const _boxName = 'source_state';
const _stateKey = 'state';

class SourceStore extends PersistentStore<SourceState> {
  SourceStore() : super(SourceState());

  VideoSource? get currentSource =>
      state.sources.isEmpty ? null : state.sources[state.currentSourceIndex];

  Future<void> addSource(VideoSource source) async {
    final newSource = source.id.isEmpty
        ? source.copyWith(id: const Uuid().v4())
        : source;
    set(state.copyWith(sources: [...state.sources, newSource]));
    await save(state);
  }

  Future<void> removeSource(String id) async {
    final newSources = state.sources.where((s) => s.id != id).toList();
    final newIndex = state.currentSourceIndex >= newSources.length
        ? (newSources.isEmpty ? 0 : newSources.length - 1)
        : state.currentSourceIndex;
    set(state.copyWith(sources: newSources, currentSourceIndex: newIndex));
    await save(state);
  }

  Future<void> updateSource(VideoSource source) async {
    final newSources =
        state.sources.map((s) => s.id == source.id ? source : s).toList();
    set(state.copyWith(sources: newSources));
    await save(state);
  }

  Future<void> updateCurrentSourceIndex(int index) async {
    if (index >= 0 && index < state.sources.length) {
      set(state.copyWith(currentSourceIndex: index));
      await save(state);
    }
  }

  // ============================================================
  // 分组管理
  // ============================================================

  /// 添加分组（自动去重）
  Future<void> addGroup(String group) async {
    if (group.isEmpty || state.groups.contains(group)) return;
    set(state.copyWith(groups: [...state.groups, group]));
    await save(state);
  }

  /// 删除分组，并清空属于该分组的源的 group 字段
  Future<void> removeGroup(String group) async {
    final newGroups = state.groups.where((g) => g != group).toList();
    final newSources = state.sources.map((s) {
      if (s.group == group) return s.copyWith(group: '');
      return s;
    }).toList();
    set(state.copyWith(groups: newGroups, sources: newSources));
    await save(state);
  }

  /// 重命名分组，同步更新所有关联的源
  Future<void> renameGroup(String oldName, String newName) async {
    if (oldName.isEmpty || newName.isEmpty || oldName == newName) return;
    final newGroups =
        state.groups.map((g) => g == oldName ? newName : g).toList();
    final newSources = state.sources.map((s) {
      if (s.group == oldName) return s.copyWith(group: newName);
      return s;
    }).toList();
    set(state.copyWith(groups: newGroups, sources: newSources));
    await save(state);
  }

  /// 获取所有已使用的分组（从源列表中收集，含未在 groups 列表中的）
  List<String> get allGroups {
    final fromSources =
        state.sources.map((s) => s.group).where((g) => g.isNotEmpty);
    return {...state.groups, ...fromSources}.toList()..sort();
  }

  /// 按分组筛选源
  List<VideoSource> getSourcesByGroup(String group) {
    if (group.isEmpty) return state.sources;
    return state.sources.where((s) => s.group == group).toList();
  }

  // ================================================================
  // 排序
  // ================================================================

  /// 更新排序方式
  void setSortBy(SourceSortBy sortBy) {
    set(state.copyWith(sortBy: sortBy));
  }

  /// 切换排序方向
  void toggleSortDirection() {
    set(state.copyWith(sortAscending: !state.sortAscending));
  }

  /// 根据当前排序设置对源列表排序
  List<VideoSource> getSortedSources() {
    final sorted = List<VideoSource>.from(state.sources);
    sorted.sort((a, b) {
      int cmp;
      switch (state.sortBy) {
        case SourceSortBy.weight:
          cmp = a.weight.compareTo(b.weight);
          break;
        case SourceSortBy.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SourceSortBy.apiUrl:
          cmp = a.apiUrl.toLowerCase().compareTo(b.apiUrl.toLowerCase());
          break;
        case SourceSortBy.lastUpdateTime:
          cmp = a.lastUpdateTime.compareTo(b.lastUpdateTime);
          break;
        case SourceSortBy.respondTime:
          cmp = a.respondTime.compareTo(b.respondTime);
          break;
        case SourceSortBy.status:
          cmp = a.status.index.compareTo(b.status.index);
          break;
      }
      return state.sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  // ================================================================
  // 源导入导出
  // ================================================================

  /// 导出所有源为 JSON 字符串
  String exportSources() {
    final exportData = {
      'version': 1,
      'exportTime': DateTime.now().toIso8601String(),
      'sources': state.sources.map((s) => s.toJson()).toList(),
      'groups': state.groups,
    };
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// 从 JSON 字符串导入源，返回成功导入的数量
  /// [merge] 为 true 时合并已有源，为 false 时替换全部
  Future<int> importSources(String jsonStr, {bool merge = true}) async {
    try {
      final data = json.decode(jsonStr);
      List<VideoSource> imported;
      List<String> importedGroups = [];

      // 兼容两种格式：完整导出格式 或 纯数组
      if (data is Map<String, dynamic> && data.containsKey('sources')) {
        imported = (data['sources'] as List)
            .map((e) => VideoSource.fromJson(e as Map<String, dynamic>))
            .toList();
        if (data['groups'] is List) {
          importedGroups = List<String>.from(data['groups'] as List);
        }
      } else if (data is List) {
        imported = data
            .map((e) => VideoSource.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        logger('Import error: invalid format');
        return 0;
      }

      if (merge) {
        // 合并模式：添加不存在的源（按 apiUrl 去重）
        final existingUrls = state.sources.map((s) => s.apiUrl).toSet();
        int count = 0;
        for (final source in imported) {
          if (!existingUrls.contains(source.apiUrl)) {
            await addSource(source);
            existingUrls.add(source.apiUrl);
            count++;
          }
        }
        // 合并分组
        final newGroups = importedGroups
            .where((g) => !state.groups.contains(g))
            .toList();
        if (newGroups.isNotEmpty) {
          set(state.copyWith(groups: [...state.groups, ...newGroups]));
        }
        return count;
      } else {
        // 替换模式
        set(state.copyWith(
          sources: imported,
          groups: importedGroups,
          currentSourceIndex: 0,
        ));
        return imported.length;
      }
    } catch (e) {
      logger('Import sources error: $e');
      return 0;
    }
  }

  // ================================================================
  // 源测试
  // ================================================================

  /// 测试单个源，返回响应时间（毫秒），失败返回 -1
  Future<int> testSource(int index) async {
    if (index < 0 || index >= state.sources.length) return -1;
    final source = state.sources[index];
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(source.apiUrl);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );
      stopwatch.stop();
      final respondTime = stopwatch.elapsedMilliseconds;

      final newStatus =
          response.statusCode == 200 ? SourceStatus.active : SourceStatus.error;

      final updated = source.copyWith(
        status: newStatus,
        respondTime: respondTime,
        lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
      );
      _updateSourceAt(index, updated);
      return respondTime;
    } catch (e) {
      stopwatch.stop();
      final updated = source.copyWith(
        status: SourceStatus.error,
        respondTime: -1,
        lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
      );
      _updateSourceAt(index, updated);
      logger('Test source error [${source.name}]: $e');
      return -1;
    }
  }

  /// 测试所有源，返回每个源的测试结果
  Future<Map<int, int>> testAllSources() async {
    final results = <int, int>{};
    for (int i = 0; i < state.sources.length; i++) {
      results[i] = await testSource(i);
    }
    return results;
  }

  /// 内部方法：更新指定位置的源
  void _updateSourceAt(int index, VideoSource updated) {
    final newSources = List<VideoSource>.from(state.sources);
    newSources[index] = updated;
    set(state.copyWith(sources: newSources));
  }

  // ================================================================
  // 订阅管理
  // ================================================================

  /// 添加订阅
  Future<void> addSubscription(SourceSubscription sub) async {
    // 去重：同一 URL 不重复添加
    if (state.subscriptions.any((s) => s.url == sub.url)) return;
    set(state.copyWith(subscriptions: [...state.subscriptions, sub]));
    await save(state);
  }

  /// 删除订阅
  Future<void> removeSubscription(String url) async {
    final newSubs = state.subscriptions.where((s) => s.url != url).toList();
    set(state.copyWith(subscriptions: newSubs));
    await save(state);
  }

  /// 更新订阅
  Future<void> updateSubscription(
      String url, SourceSubscription updated) async {
    final newSubs = state.subscriptions
        .map((s) => s.url == url ? updated : s)
        .toList();
    set(state.copyWith(subscriptions: newSubs));
    await save(state);
  }

  /// 同步单个订阅，返回导入的源数量，失败返回 -1
  Future<int> syncSubscription(String url) async {
    final index = state.subscriptions.indexWhere((s) => s.url == url);
    if (index < 0) return -1;

    final sub = state.subscriptions[index];
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        _updateSubscriptionResult(index, sub, false, 0);
        return -1;
      }

      final count = await importSources(response.body, merge: true);
      _updateSubscriptionResult(index, sub, true, count);
      return count;
    } catch (e) {
      _updateSubscriptionResult(index, sub, false, 0);
      logger('Sync subscription error [$url]: $e');
      return -1;
    }
  }

  /// 同步所有订阅
  Future<Map<String, int>> syncAllSubscriptions() async {
    final results = <String, int>{};
    for (final sub in state.subscriptions) {
      results[sub.url] = await syncSubscription(sub.url);
    }
    return results;
  }

  /// 更新订阅同步结果
  void _updateSubscriptionResult(
      int index, SourceSubscription sub, bool success, int count) {
    final updated = sub.copyWith(
      lastSyncTime: DateTime.now().millisecondsSinceEpoch,
      lastSyncSuccess: success,
      sourceCount: success ? count : sub.sourceCount,
    );
    final newSubs = List<SourceSubscription>.from(state.subscriptions);
    newSubs[index] = updated;
    set(state.copyWith(subscriptions: newSubs));
  }

  // ============================================================
  // Hive 持久化
  // ============================================================

  /// 从 Hive Box 加载状态
  @override
  Future<SourceState?> load() async {
    logger('Loading SourceState from Hive');
    try {
      final box = await Hive.openBox(_boxName);
      final jsonStr = box.get(_stateKey) as String?;
      if (jsonStr != null) {
        return SourceState.fromJson(json.decode(jsonStr));
      }
    } catch (e) {
      logger('Error loading SourceState: $e');
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
      logger('Error saving SourceState: $e');
    }
  }
}

SourceStore useSourceStore() => create(() => SourceStore());
