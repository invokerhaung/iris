import 'package:flutter/material.dart';

/// 源管理样式规范
class SourceStyles {
  SourceStyles._();

  // ========== 颜色 ==========

  /// 活跃状态颜色
  static const Color activeColor = Colors.green;

  /// 禁用状态颜色
  static const Color inactiveColor = Colors.grey;

  /// 错误状态颜色
  static const Color errorColor = Colors.red;

  /// 超时状态颜色
  static const Color timeoutColor = Colors.orange;

  /// 选中状态颜色
  static const Color selectedColor = Colors.blue;

  // ========== 间距 ==========

  /// 列表项内边距
  static const double listItemPadding = 12.0;

  /// 卡片外边距
  static const double cardMarginHorizontal = 8.0;
  static const double cardMarginVertical = 4.0;

  /// 标签间距
  static const double chipSpacing = 4.0;

  /// 区域间距
  static const double sectionSpacing = 16.0;

  // ========== 文字样式 ==========

  /// 标题样式
  static const TextStyle titleStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
  );

  /// 副标题样式
  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );

  /// URL 样式
  static const TextStyle urlStyle = TextStyle(
    fontSize: 11,
    color: Colors.blue,
  );

  /// 标签样式
  static const TextStyle chipStyle = TextStyle(
    fontSize: 10,
  );

  /// 统计数字样式
  static const TextStyle statNumberStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
  );

  /// 统计标签样式
  static const TextStyle statLabelStyle = TextStyle(
    fontSize: 11,
    color: Colors.grey,
  );

  // ========== 图标大小 ==========

  /// 类型图标大小
  static const double typeIconSize = 28.0;

  /// 操作图标大小
  static const double actionIconSize = 20.0;

  /// 状态图标大小
  static const double statusIconSize = 16.0;

  // ========== 圆角 ==========

  /// 卡片圆角
  static const double cardRadius = 8.0;

  /// 标签圆角
  static const double chipRadius = 4.0;

  /// 按钮圆角
  static const double buttonRadius = 8.0;

  // ========== 阴影 ==========

  /// 卡片阴影
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  // ========== 动画 ==========

  /// 动画时长
  static const Duration animationDuration = Duration(milliseconds: 200);

  /// 长按延迟
  static const Duration longPressDelay = Duration(milliseconds: 500);
}
