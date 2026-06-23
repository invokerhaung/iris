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
