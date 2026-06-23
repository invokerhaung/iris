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
            color: Colors.black.withValues(alpha: 0.1),
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
