import 'book_source.dart';

/// 导入结果
class ImportResult {
  final List<BookSource> sources;  // 导入的源列表
  final int newCount;              // 新增数量
  final int updatedCount;          // 更新数量
  final List<String> errors;       // 错误信息

  const ImportResult({
    required this.sources,
    required this.newCount,
    required this.updatedCount,
    this.errors = const [],
  });

  /// 总数
  int get totalCount => sources.length;

  /// 是否有错误
  bool get hasErrors => errors.isNotEmpty;

  /// 成功数量
  int get successCount => newCount + updatedCount;

  @override
  String toString() {
    return 'ImportResult(total: $totalCount, new: $newCount, updated: $updatedCount, errors: ${errors.length})';
  }
}
