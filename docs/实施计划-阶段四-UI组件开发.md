# 阶段四：UI 组件开发 — 详细实施计划

## 一、阶段概述

| 项目 | 内容 |
|-----|------|
| **阶段目标** | 创建所有源管理相关的 UI 组件 |
| **预计时间** | 2-3 天 |
| **前置依赖** | 阶段一：数据模型，阶段二：状态管理，阶段三：解析器 |
| **后续阶段** | 阶段五：页面重构 |

---

## 二、任务清单

### 任务 4.1：创建样式规范

**目标**：定义统一的样式常量

**文件**：`lib/pages/sources/widgets/source_styles.dart`

**详细实现**：

```dart
// lib/pages/sources/widgets/source_styles.dart

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
      color: Colors.black.withOpacity(0.05),
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
```

**验收标准**：
- [ ] 样式常量定义完整
- [ ] 命名清晰易懂
- [ ] 代码无错误

---

### 任务 4.2：创建 SourceTile 列表项组件

**目标**：实现源列表项的展示和交互

**文件**：`lib/pages/sources/widgets/source_tile.dart`

**详细实现**：

```dart
// lib/pages/sources/widgets/source_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../models/book_source.dart';
import '../../../models/book_source_part.dart';
import '../../../models/book_source_type.dart';
import 'source_styles.dart';

/// 源列表项组件
///
/// 支持普通模式和多选模式
class SourceTile extends HookWidget {
  final BookSourcePart source;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?>? onSelectionChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onTest;
  final VoidCallback? onDelete;

  const SourceTile({
    super.key,
    required this.source,
    this.isSelected = false,
    this.isMultiSelectMode = false,
    this.onTap,
    this.onLongPress,
    this.onSelectionChanged,
    this.onEdit,
    this.onTest,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: SourceStyles.cardMarginHorizontal,
        vertical: SourceStyles.cardMarginVertical,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SourceStyles.cardRadius),
        side: isSelected
            ? BorderSide(color: SourceStyles.selectedColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(SourceStyles.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(SourceStyles.listItemPadding),
          child: Row(
            children: [
              // 多选模式显示复选框
              if (isMultiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: onSelectionChanged,
                    activeColor: SourceStyles.selectedColor,
                  ),
                ),

              // 源类型图标
              _buildTypeIcon(),

              const SizedBox(width: 12),

              // 主要信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：名称 + 状态标签
                    _buildTitleRow(),

                    const SizedBox(height: 4),

                    // 第二行：URL
                    _buildUrlRow(),

                    const SizedBox(height: 4),

                    // 第三行：分组 + 响应时间
                    _buildInfoRow(),
                  ],
                ),
              ),

              // 操作菜单
              if (!isMultiSelectMode) _buildPopupMenu(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建类型图标
  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (source.bookSourceType) {
      case BookSourceType.video:
        icon = Icons.videocam;
        color = Colors.blue;
        break;
      case BookSourceType.audio:
        icon = Icons.music_note;
        color = Colors.purple;
        break;
      case BookSourceType.image:
        icon = Icons.image;
        color = Colors.orange;
        break;
      case BookSourceType.file:
        icon = Icons.file_download;
        color = Colors.brown;
        break;
      case BookSourceType.rss:
        icon = Icons.rss_feed;
        color = Colors.teal;
        break;
      default:
        icon = Icons.book;
        color = Colors.green;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(SourceStyles.chipRadius),
      ),
      child: Icon(
        icon,
        color: color,
        size: SourceStyles.typeIconSize,
      ),
    );
  }

  /// 构建标题行
  Widget _buildTitleRow() {
    return Row(
      children: [
        // 源名称
        Expanded(
          child: Text(
            source.bookSourceName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: source.enabled ? null : Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(width: 8),

        // 状态标签
        _buildStatusChip(),
      ],
    );
  }

  /// 构建状态标签
  Widget _buildStatusChip() {
    Color color;
    String text;

    if (!source.enabled) {
      color = SourceStyles.inactiveColor;
      text = '禁用';
    } else if (source.isError) {
      color = SourceStyles.errorColor;
      text = '错误';
    } else if (source.isActive) {
      color = SourceStyles.activeColor;
      text = '活跃';
    } else {
      color = SourceStyles.timeoutColor;
      text = '超时';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(SourceStyles.chipRadius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建 URL 行
  Widget _buildUrlRow() {
    return Text(
      source.bookSourceUrl,
      style: SourceStyles.subtitleStyle.copyWith(fontSize: 12),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 构建信息行
  Widget _buildInfoRow() {
    return Row(
      children: [
        // 分组标签
        if (source.hasGroupAny)
          Expanded(
            child: Wrap(
              spacing: SourceStyles.chipSpacing,
              children: source.groupList.take(3).map((group) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(SourceStyles.chipRadius),
                  ),
                  child: Text(
                    group,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[700],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // 响应时间
        Text(
          source.respondTimeFormatted,
          style: TextStyle(
            fontSize: 11,
            color: source.isError ? Colors.red : Colors.grey[500],
            fontWeight: source.isError ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// 构建弹出菜单
  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: SourceStyles.actionIconSize,
        color: Colors.grey[600],
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('编辑'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'test',
          child: ListTile(
            leading: Icon(Icons.speed),
            title: Text('测试'),
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('删除', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
      ],
      onSelected: (value) {
        HapticFeedback.lightImpact();
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'test':
            onTest?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
    );
  }
}
```

**验收标准**：
- [ ] 普通模式显示正常
- [ ] 多选模式显示复选框
- [ ] 状态标签颜色正确
- [ ] 类型图标显示正确
- [ ] 分组标签显示正确
- [ ] 操作菜单功能正常

---

### 任务 4.3：创建 SourceFilterBar 筛选栏组件

**目标**：实现状态、分组、类型的筛选功能

**文件**：`lib/pages/sources/widgets/source_filter_bar.dart`

**详细实现**：

```dart
// lib/pages/sources/widgets/source_filter_bar.dart

import 'package:flutter/material.dart';

import '../../../models/book_source_type.dart';
import 'source_styles.dart';

/// 源筛选栏组件
class SourceFilterBar extends StatelessWidget {
  final int currentFilter;      // 0全部 1活跃 2禁用 3错误
  final String? currentGroup;
  final int? currentType;
  final List<String> groups;
  final ValueChanged<int> onFilterChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<int?> onTypeChanged;

  const SourceFilterBar({
    super.key,
    required this.currentFilter,
    this.currentGroup,
    this.currentType,
    required this.groups,
    required this.onFilterChanged,
    required this.onGroupChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // 状态筛选
          _buildFilterChip('全部', currentFilter == 0, () => onFilterChanged(0)),
          _buildFilterChip('活跃', currentFilter == 1, () => onFilterChanged(1)),
          _buildFilterChip('禁用', currentFilter == 2, () => onFilterChanged(2)),
          _buildFilterChip('错误', currentFilter == 3, () => onFilterChanged(3)),

          const VerticalDivider(width: 16),

          // 分组筛选
          _buildGroupDropdown(),

          const SizedBox(width: 8),

          // 类型筛选
          _buildTypeDropdown(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : null,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: SourceStyles.activeColor,
        backgroundColor: Colors.grey[100],
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildGroupDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(SourceStyles.chipRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentGroup,
          hint: const Text('分组', style: TextStyle(fontSize: 12)),
          isDense: true,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('全部分组', style: TextStyle(fontSize: 12)),
            ),
            ...groups.map((g) => DropdownMenuItem(
              value: g,
              child: Text(g, style: const TextStyle(fontSize: 12)),
            )),
          ],
          onChanged: onGroupChanged,
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(SourceStyles.chipRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: currentType,
          hint: const Text('类型', style: TextStyle(fontSize: 12)),
          isDense: true,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('全部类型', style: TextStyle(fontSize: 12)),
            ),
            ...BookSourceType.allTypes.map((type) => DropdownMenuItem(
              value: type,
              child: Text(
                BookSourceType.getName(type),
                style: const TextStyle(fontSize: 12),
              ),
            )),
          ],
          onChanged: onTypeChanged,
        ),
      ),
    );
  }
}
```

**验收标准**：
- [ ] 状态筛选正常
- [ ] 分组筛选正常
- [ ] 类型筛选正常
- [ ] 筛选状态显示正确

---

### 任务 4.4：创建 SourceBatchBar 批量操作栏组件

**目标**：实现批量操作的底部栏

**文件**：`lib/pages/sources/widgets/source_batch_bar.dart`

**详细实现**：

```dart
// lib/pages/sources/widgets/source_batch_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'source_styles.dart';

/// 批量操作栏组件
class SourceBatchBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onRevertSelection;
  final VoidCallback onDelete;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onEnableExplore;
  final VoidCallback onDisableExplore;
  final VoidCallback onTop;
  final VoidCallback onBottom;
  final VoidCallback onExport;
  final VoidCallback? onAddToGroup;

  const SourceBatchBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onRevertSelection,
    required this.onDelete,
    required this.onEnable,
    required this.onDisable,
    required this.onEnableExplore,
    required this.onDisableExplore,
    required this.onTop,
    required this.onBottom,
    required this.onExport,
    this.onAddToGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // 选中数量
              _buildSelectionInfo(),

              const VerticalDivider(width: 16),

              // 全选/反选
              _buildSelectButtons(),

              const VerticalDivider(width: 16),

              // 批量操作（可滚动）
              Expanded(child: _buildActionButtons()),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建选中信息
  Widget _buildSelectionInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$selectedCount 已选',
          style: SourceStyles.statNumberStyle.copyWith(fontSize: 16),
        ),
        Text(
          '共 $totalCount 个源',
          style: SourceStyles.statLabelStyle,
        ),
      ],
    );
  }

  /// 构建全选/反选按钮
  Widget _buildSelectButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          icon: Icons.select_all,
          tooltip: '全选',
          onPressed: onSelectAll,
        ),
        _buildIconButton(
          icon: Icons.flip,
          tooltip: '反选',
          onPressed: onRevertSelection,
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _buildActionButton(
          icon: Icons.check_circle,
          label: '启用',
          color: Colors.green,
          onPressed: onEnable,
        ),
        _buildActionButton(
          icon: Icons.block,
          label: '禁用',
          color: Colors.orange,
          onPressed: onDisable,
        ),
        _buildActionButton(
          icon: Icons.explore,
          label: '启用发现',
          color: Colors.blue,
          onPressed: onEnableExplore,
        ),
        _buildActionButton(
          icon: Icons.explore_off,
          label: '禁用发现',
          color: Colors.grey,
          onPressed: onDisableExplore,
        ),
        _buildActionButton(
          icon: Icons.vertical_align_top,
          label: '置顶',
          onPressed: () {
            HapticFeedback.lightImpact();
            onTop();
          },
        ),
        _buildActionButton(
          icon: Icons.vertical_align_bottom,
          label: '置底',
          onPressed: () {
            HapticFeedback.lightImpact();
            onBottom();
          },
        ),
        if (onAddToGroup != null)
          _buildActionButton(
            icon: Icons.folder,
            label: '分组',
            onPressed: onAddToGroup!,
          ),
        _buildActionButton(
          icon: Icons.save,
          label: '导出',
          onPressed: onExport,
        ),
        _buildActionButton(
          icon: Icons.delete,
          label: '删除',
          color: Colors.red,
          onPressed: () {
            HapticFeedback.mediumImpact();
            onDelete();
          },
        ),
      ],
    );
  }

  /// 构建图标按钮
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: SourceStyles.actionIconSize),
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(icon, color: color),
            iconSize: SourceStyles.actionIconSize,
            onPressed: onPressed,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            padding: EdgeInsets.zero,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
```

**验收标准**：
- [ ] 选中数量显示正确
- [ ] 全选/反选功能正常
- [ ] 批量操作按钮完整
- [ ] 按钮可滚动
- [ ] 触觉反馈正常

---

### 任务 4.5：创建 SourceSortMenu 排序菜单组件

**目标**：实现排序方式选择菜单

**文件**：`lib/pages/sources/widgets/source_sort_menu.dart`

**详细实现**：

```dart
// lib/pages/sources/widgets/source_sort_menu.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/book_source_sort.dart';

/// 排序菜单组件
class SourceSortMenu extends StatelessWidget {
  final BookSourceSort currentSort;
  final bool sortAscending;
  final ValueChanged<BookSourceSort> onSortChanged;
  final VoidCallback onToggleDirection;

  const SourceSortMenu({
    super.key,
    required this.currentSort,
    required this.sortAscending,
    required this.onSortChanged,
    required this.onToggleDirection,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BookSourceSort>(
      icon: const Icon(Icons.sort),
      tooltip: '排序',
      itemBuilder: (context) => [
        _buildSortItem(
          context,
          value: BookSourceSort.custom,
          icon: Icons.drag_handle,
          label: '手动排序',
        ),
        _buildSortItem(
          context,
          value: BookSourceSort.name,
          icon: Icons.sort_by_alpha,
          label: '按名称',
        ),
        _buildSortItem(
          context,
          value: BookSourceSort.url,
          icon: Icons.link,
          label: '按URL',
        ),
        _buildSortItem(
          context,
          value: BookSourceSort.weight,
          icon: Icons.fitness_center,
          label: '按权重',
        ),
        _buildSortItem(
          context,
          value: BookSourceSort.update,
          icon: Icons.update,
          label: '按更新时间',
        ),
        _buildSortItem(
          context,
          value: BookSourceSort.enable,
          icon: Icons.toggle_on,
          label: '按启用状态',
        ),
        _buildSortItem(
          context,
          value: BookSourceSort.respond,
          icon: Icons.speed,
          label: '按响应时间',
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            title: Text(sortAscending ? '升序' : '降序'),
            dense: true,
            onTap: () {
              Navigator.pop(context);
              HapticFeedback.lightImpact();
              onToggleDirection();
            },
          ),
        ),
      ],
      onSelected: (value) {
        HapticFeedback.lightImpact();
        onSortChanged(value);
      },
    );
  }

  PopupMenuItem<BookSourceSort> _buildSortItem(
    BuildContext context, {
    required BookSourceSort value,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentSort == value;

    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? Theme.of(context).primaryColor : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ],
      ),
    );
  }
}
```

**验收标准**：
- [ ] 7 种排序方式显示正常
- [ ] 当前排序方式高亮
- [ ] 升降序切换正常
- [ ] 触觉反馈正常

---

### 任务 4.6：创建 SubscriptionDialog 订阅管理对话框

**目标**：实现订阅的管理和同步

**文件**：`lib/pages/sources/widgets/subscription_dialog.dart`

**详细实现**：

```dart
// lib/pages/sources/widgets/subscription_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../models/source_subscription.dart';
import '../../../store/use_source_store.dart';
import 'source_styles.dart';

/// 订阅管理对话框
class SubscriptionDialog extends HookConsumerWidget {
  const SubscriptionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(sourceStoreProvider);
    final subscriptions = store.subscriptions;
    final isSyncing = useState(false);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 标题栏
            _buildHeader(context, store, isSyncing),

            const Divider(),

            // 订阅列表
            Expanded(
              child: subscriptions.isEmpty
                  ? _buildEmptyState()
                  : _buildSubscriptionList(context, store, subscriptions),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(
    BuildContext context,
    SourceStore store,
    ValueNotifier<bool> isSyncing,
  ) {
    return Row(
      children: [
        const Icon(Icons.subscriptions, size: 24),
        const SizedBox(width: 8),
        const Text(
          '订阅管理',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '添加订阅',
          onPressed: () => _showAddDialog(context, store),
        ),
        IconButton(
          icon: isSyncing.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          tooltip: '同步全部',
          onPressed: isSyncing.value
              ? null
              : () async {
                  isSyncing.value = true;
                  await store.syncAllSubscriptions();
                  isSyncing.value = false;
                },
        ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.subscriptions_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无订阅',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 添加订阅',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建订阅列表
  Widget _buildSubscriptionList(
    BuildContext context,
    SourceStore store,
    List<SourceSubscription> subscriptions,
  ) {
    return ListView.builder(
      itemCount: subscriptions.length,
      itemBuilder: (context, index) {
        final sub = subscriptions[index];
        return _SubscriptionTile(
          subscription: sub,
          onSync: () async {
            await store.syncSubscription(sub.url);
          },
          onDelete: () => _showDeleteConfirm(context, store, index),
          onToggleAutoSync: (value) {
            store.updateSubscription(
              index,
              sub.copyWith(autoSync: value),
            );
          },
        );
      },
    );
  }

  /// 显示添加对话框
  void _showAddDialog(BuildContext context, SourceStore store) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '订阅名称',
                hintText: '例如：我的订阅',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '订阅URL',
                hintText: 'https://example.com/sources.json',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  urlController.text.isNotEmpty) {
                store.addSubscription(SourceSubscription(
                  name: nameController.text,
                  url: urlController.text,
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  /// 显示删除确认
  void _showDeleteConfirm(BuildContext context, SourceStore store, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个订阅吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              store.removeSubscription(index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 订阅列表项
class _SubscriptionTile extends StatelessWidget {
  final SourceSubscription subscription;
  final VoidCallback onSync;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleAutoSync;

  const _SubscriptionTile({
    required this.subscription,
    required this.onSync,
    required this.onDelete,
    required this.onToggleAutoSync,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：名称 + 状态
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subscription.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                _buildSyncButton(),
                _buildDeleteButton(),
              ],
            ),

            const SizedBox(height: 8),

            // 第二行：URL
            Text(
              subscription.url,
              style: SourceStyles.subtitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // 第三行：统计信息
            _buildInfoRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    if (subscription.lastSyncSuccess == true) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (subscription.lastSyncSuccess == false) {
      icon = Icons.error;
      color = Colors.red;
    } else {
      icon = Icons.sync_disabled;
      color = Colors.grey;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildSyncButton() {
    return IconButton(
      icon: const Icon(Icons.sync),
      tooltip: '同步',
      onPressed: onSync,
    );
  }

  Widget _buildDeleteButton() {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      tooltip: '删除',
      onPressed: onDelete,
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        // 源数量
        _buildInfoChip(
          icon: Icons.source,
          label: '${subscription.sourceCount} 个源',
        ),

        const SizedBox(width: 16),

        // 同步时间
        _buildInfoChip(
          icon: Icons.access_time,
          label: _formatTime(subscription.lastSyncTime),
        ),

        const Spacer(),

        // 自动同步开关
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('自动同步', style: TextStyle(fontSize: 12)),
            Switch(
              value: subscription.autoSync,
              onChanged: onToggleAutoSync,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: SourceStyles.subtitleStyle),
      ],
    );
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null || timestamp == 0) return '从未同步';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.month}-${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
```

**验收标准**：
- [ ] 订阅列表显示正常
- [ ] 添加订阅功能正常
- [ ] 删除订阅功能正常
- [ ] 同步功能正常
- [ ] 自动同步开关正常
- [ ] 状态图标显示正确

---

### 任务 4.7：创建 GroupDialog 分组管理对话框

**目标**：实现分组的增删改查

**文件**：`lib/pages/sources/widgets/group_dialog.dart`

**详细实现**：

```dart
// lib/pages/sources/widgets/group_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../store/use_source_store.dart';

/// 分组管理对话框
class GroupDialog extends HookConsumerWidget {
  const GroupDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(sourceStoreProvider);
    final groups = store.allGroups;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 标题栏
            _buildHeader(context, store),

            const Divider(),

            // 分组列表
            Expanded(
              child: groups.isEmpty
                  ? _buildEmptyState()
                  : _buildGroupList(context, store, groups),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SourceStore store) {
    return Row(
      children: [
        const Icon(Icons.folder, size: 24),
        const SizedBox(width: 8),
        const Text(
          '分组管理',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '添加分组',
          onPressed: () => _showAddDialog(context, store),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无分组',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(
    BuildContext context,
    SourceStore store,
    List<String> groups,
  ) {
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(group),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: '重命名',
                onPressed: () => _showRenameDialog(context, store, group),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: '删除',
                onPressed: () => _showDeleteConfirm(context, store, group),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, SourceStore store) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加分组'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '分组名称',
            hintText: '输入分组名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                store.addGroup(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    SourceStore store,
    String oldName,
  ) {
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty && controller.text != oldName) {
                store.renameGroup(oldName, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    SourceStore store,
    String group,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除分组 "$group" 吗？\n该分组下的源将被移出此分组。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              store.removeGroup(group);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
```

**验收标准**：
- [ ] 分组列表显示正常
- [ ] 添加分组功能正常
- [ ] 重命名分组功能正常
- [ ] 删除分组功能正常
- [ ] 确认对话框正常

---

## 三、文件清单汇总

### 新增文件

```
lib/pages/sources/widgets/
├── source_styles.dart            # 样式规范
├── source_tile.dart              # 列表项组件
├── source_filter_bar.dart        # 筛选栏组件
├── source_batch_bar.dart         # 批量操作栏组件
├── source_sort_menu.dart         # 排序菜单组件
├── subscription_dialog.dart      # 订阅管理对话框
└── group_dialog.dart             # 分组管理对话框
```

---

## 四、依赖关系

```
任务 4.1 (样式规范)
    │
    ├──→ 任务 4.2 (SourceTile)
    │
    ├──→ 任务 4.3 (SourceFilterBar)
    │
    ├──→ 任务 4.4 (SourceBatchBar)
    │
    ├──→ 任务 4.5 (SourceSortMenu)
    │
    ├──→ 任务 4.6 (SubscriptionDialog)
    │
    └──→ 任务 4.7 (GroupDialog)
```

---

## 五、验收标准汇总

### 功能完整性

- [ ] 列表项显示完整（名称/URL/状态/类型/分组/响应时间）
- [ ] 多选模式支持（复选框/选中高亮）
- [ ] 筛选功能正常（状态/分组/类型）
- [ ] 批量操作完整（启用/禁用/置顶/置底/删除/导出）
- [ ] 排序菜单完整（7种排序/升降序）
- [ ] 订阅管理完整（添加/删除/同步/自动同步）
- [ ] 分组管理完整（添加/重命名/删除）

### UI 规范

- [ ] 样式统一
- [ ] 交互反馈正常（触觉/视觉）
- [ ] 响应式布局
- [ ] 无障碍支持

### 代码质量

- [ ] 无编译错误
- [ ] 无警告
- [ ] 代码符合规范
- [ ] 注释清晰完整

---

## 六、风险与应对

| 风险 | 影响 | 应对措施 |
|-----|------|---------|
| 组件嵌套过深 | 性能下降 | 合理拆分，使用 const |
| 状态管理复杂 | 数据不一致 | 统一使用 store |
| 手势冲突 | 交互异常 | 明确手势优先级 |
| 内存泄漏 | 应用崩溃 | 及时释放资源 |

---

## 七、检查点

### 开始前检查

- [ ] 阶段一、二、三已完成
- [ ] 状态管理可用
- [ ] 依赖包已安装

### 完成后检查

- [ ] 所有组件已创建
- [ ] 组件独立可用
- [ ] 样式统一
- [ ] 无编译错误和警告

---

*生成时间：2026-06-16*
*阶段版本：v1.0*
