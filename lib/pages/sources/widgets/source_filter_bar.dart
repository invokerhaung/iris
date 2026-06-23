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
