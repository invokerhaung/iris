import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../models/book_source.dart';

/// 发现页面的书源卡片组件
///
/// 支持：
/// - 显示书源名称
/// - 展开/收起分类标签
/// - 点击分类标签跳转
/// - 置顶/收藏功能
class ExploreSourceTile extends HookWidget {
  final BookSource source;
  final bool isExpanded;
  final VoidCallback onTap;
  final void Function(String title, String url) onCategoryTap;
  final void Function(String title, String url) onPin;
  final bool Function(String title, String url) isPinned;

  const ExploreSourceTile({
    super.key,
    required this.source,
    required this.isExpanded,
    required this.onTap,
    required this.onCategoryTap,
    required this.onPin,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    // 解析分类标签
    final categories = useMemoized(() {
      return _parseCategories(source.exploreUrl ?? '');
    }, [source.exploreUrl]);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          // 标题栏
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 源类型图标
                  _buildTypeIcon(),

                  const SizedBox(width: 12),

                  // 源名称
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.bookSourceName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (source.bookSourceGroup != null &&
                            source.bookSourceGroup!.isNotEmpty)
                          Text(
                            source.bookSourceGroup!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 展开/收起箭头
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.arrow_right,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 分类标签区域（展开时显示）
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildCategoryTags(context, categories),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  /// 构建类型图标
  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (source.bookSourceType) {
      case 4: // 视频
        icon = Icons.videocam;
        color = Colors.blue;
        break;
      case 1: // 音频
        icon = Icons.music_note;
        color = Colors.purple;
        break;
      case 2: // 图片
        icon = Icons.image;
        color = Colors.orange;
        break;
      default:
        icon = Icons.explore;
        color = Colors.green;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  /// 构建分类标签
  Widget _buildCategoryTags(BuildContext context, List<ExploreCategory> categories) {
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Text(
          '暂无分类',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((category) {
          final pinned = isPinned(category.title, category.url);

          return InkWell(
            onTap: () => onCategoryTap(category.title, category.url),
            onLongPress: () => onPin(category.title, category.url),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: pinned
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: pinned
                    ? Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pinned) ...[
                    Icon(
                      Icons.push_pin,
                      size: 12,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    category.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: pinned
                          ? Theme.of(context).primaryColor
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 解析分类标签
  ///
  /// exploreUrl 格式：
  /// - 单个URL: /explore/{{page}}/
  /// - 多个分类: 标题1::/url1\n标题2::/url2
  /// - 带分组: ==分组==\n标题::/url
  List<ExploreCategory> _parseCategories(String exploreUrl) {
    if (exploreUrl.isEmpty) return [];

    final categories = <ExploreCategory>[];
    final lines = exploreUrl.split('\n');

    String? currentGroup;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 检查是否是分组标题
      if (trimmed.startsWith('==') && trimmed.endsWith('==')) {
        currentGroup = trimmed.substring(2, trimmed.length - 2);
        continue;
      }

      // 解析 标题::URL 格式
      if (trimmed.contains('::')) {
        final parts = trimmed.split('::');
        if (parts.length >= 2) {
          final title = parts[0].trim();
          final url = parts.sublist(1).join('::').trim();

          categories.add(ExploreCategory(
            title: title,
            url: url,
            group: currentGroup,
          ));
        }
      } else {
        // 单个URL，使用默认标题
        categories.add(ExploreCategory(
          title: '发现',
          url: trimmed,
        ));
      }
    }

    return categories;
  }
}

/// 发现分类数据
class ExploreCategory {
  final String title;
  final String url;
  final String? group;

  const ExploreCategory({
    required this.title,
    required this.url,
    this.group,
  });
}
