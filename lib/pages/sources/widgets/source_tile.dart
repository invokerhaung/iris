import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

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
            ? const BorderSide(color: SourceStyles.selectedColor, width: 2)
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
        color: color.withValues(alpha: 0.1),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(SourceStyles.chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                    color: Colors.blue.withValues(alpha: 0.1),
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
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text('删除', style: TextStyle(color: Colors.red[700])),
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
