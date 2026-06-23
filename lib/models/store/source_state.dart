import 'package:freezed_annotation/freezed_annotation.dart';

import '../book_source.dart';
import '../source_subscription.dart';

part 'source_state.freezed.dart';
part 'source_state.g.dart';

/// 源管理聚合状态
///
/// 包含所有源管理相关的状态数据
/// 通过 Hive 持久化存储
@freezed
abstract class SourceState with _$SourceState {
  const factory SourceState({
    @Default([]) List<BookSource> sources,      // 完整源列表
    @Default([]) List<String> groups,            // 分组列表
    @Default(0) int sortBy,                      // 排序方式（BookSourceSort 索引）
    @Default(true) bool sortAscending,           // 排序方向（true升序，false降序）
    @Default([]) List<SourceSubscription> subscriptions, // 订阅列表
  }) = _SourceState;

  factory SourceState.fromJson(Map<String, dynamic> json) =>
      _$SourceStateFromJson(json);
}
