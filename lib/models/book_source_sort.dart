/// 源排序方式枚举
enum BookSourceSort {
  /// 手动排序（拖拽）
  custom('手动排序', 'custom'),

  /// 按名称排序
  name('按名称', 'name'),

  /// 按URL排序
  url('按URL', 'url'),

  /// 按权重排序
  weight('按权重', 'weight'),

  /// 按更新时间排序
  update('按更新时间', 'update'),

  /// 按启用状态排序
  enable('按启用状态', 'enable'),

  /// 按响应时间排序
  respond('按响应时间', 'respond');

  final String label;
  final String value;

  const BookSourceSort(this.label, this.value);

  /// 从值获取枚举
  static BookSourceSort fromValue(String value) {
    return BookSourceSort.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BookSourceSort.custom,
    );
  }
}
