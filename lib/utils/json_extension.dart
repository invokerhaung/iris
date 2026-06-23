/// JSON 解析容错扩展方法
///
/// 类似 Kotlin/Gson 的 JsonDeserializer 容错机制：
/// - null → null
/// - Map → 解析为对象
/// - 空数组/其他类型 → null（不报错）

extension JsonParsingExtension on Map<String, dynamic> {
  /// 容错获取对象字段，失败返回 null
  ///
  /// 处理 Legado JSON 中规则字段可能是对象 {} 或空数组 [] 的情况
  T? getObjectOrNull<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final value = this[key];
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      try {
        return fromJson(value);
      } catch (e) {
        return null;
      }
    }
    // 空数组、其他类型都返回 null
    return null;
  }

  /// 容错获取整数字段
  ///
  /// 处理 JSON 中数字可能是字符串的情况（如 "1779228932770"）
  int getIntOrZero(String key) {
    final value = this[key];
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// 容错获取整数字段，带默认值
  int getIntOrDefault(String key, int defaultValue) {
    final value = this[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// 容错获取布尔字段
  bool getBoolOrFalse(String key) {
    final value = this[key];
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  /// 容错获取布尔字段，带默认值
  bool getBoolOrDefault(String key, bool defaultValue) {
    final value = this[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return defaultValue;
  }
}
