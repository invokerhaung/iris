import 'package:freezed_annotation/freezed_annotation.dart';

import 'book_source.dart';
import 'book_source_type.dart';

part 'book_source_part.freezed.dart';

/// 书源轻量视图（用于列表展示）
///
/// 只包含列表展示所需的字段，避免加载完整的规则JSON
/// 提升列表滚动性能
@freezed
abstract class BookSourcePart with _$BookSourcePart {
  const BookSourcePart._();

  const factory BookSourcePart({
    required String bookSourceUrl,
    required String bookSourceName,
    String? bookSourceGroup,
    @Default(0) int bookSourceType,
    @Default(0) int customOrder,
    @Default(true) bool enabled,
    @Default(true) bool enabledExplore,
    @Default(0) int lastUpdateTime,
    @Default(180000) int respondTime,
    @Default(0) int weight,
  }) = _BookSourcePart;

  /// 从完整 BookSource 创建
  factory BookSourcePart.fromBookSource(BookSource source) {
    return BookSourcePart(
      bookSourceUrl: source.bookSourceUrl,
      bookSourceName: source.bookSourceName,
      bookSourceGroup: source.bookSourceGroup,
      bookSourceType: source.bookSourceType,
      customOrder: source.customOrder,
      enabled: source.enabled,
      enabledExplore: source.enabledExplore,
      lastUpdateTime: source.lastUpdateTime,
      respondTime: source.respondTime,
      weight: source.weight,
    );
  }

  // ========== 便捷方法 ==========

  /// 获取分组列表
  List<String> get groupList {
    if (bookSourceGroup == null || bookSourceGroup!.isEmpty) {
      return [];
    }
    return bookSourceGroup!
        .split(RegExp(r'[,;，；]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 是否属于指定分组
  bool hasGroup(String group) {
    return groupList.contains(group);
  }

  /// 源类型名称
  String get typeName => BookSourceType.getName(bookSourceType);

  /// 是否为媒体类型
  bool get isMediaType => BookSourceType.isMediaType(bookSourceType);

  /// 是否有分组
  bool get hasGroupAny => bookSourceGroup != null && bookSourceGroup!.isNotEmpty;

  /// 响应时间格式化
  String get respondTimeFormatted {
    if (respondTime >= 180000) return '超时';
    if (respondTime >= 1000) return '${(respondTime / 1000).toStringAsFixed(1)}s';
    return '${respondTime}ms';
  }

  /// 是否为活跃状态
  bool get isActive => enabled && respondTime < 180000;

  /// 是否为错误状态
  bool get isError => enabled && respondTime >= 180000;

  /// 是否为禁用状态
  bool get isDisabled => !enabled;
}
