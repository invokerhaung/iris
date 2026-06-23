import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/json_extension.dart';
import 'book_source_type.dart';
import 'rule/search_rule.dart';
import 'rule/explore_rule.dart';
import 'rule/book_info_rule.dart';
import 'rule/toc_rule.dart';
import 'rule/content_rule.dart';
import 'rule/review_rule.dart';

part 'book_source.freezed.dart';
part 'book_source.g.dart';

/// Legado 兼容的书源实体
///
/// 完全兼容 Legado BookSource JSON 格式
/// 可直接导入/导出 Legado 书源文件
@freezed
abstract class BookSource with _$BookSource {
  const BookSource._();

  @JsonSerializable(includeIfNull: false)
  const factory BookSource({
    // ========== 基础信息 ==========
    @Default('') String bookSourceUrl,      // 主键，源地址
    @Default('') String bookSourceName,      // 源名称
    String? bookSourceGroup,                 // 分组（逗号/分号分隔）
    @Default(0) int bookSourceType,          // 类型（0文本/1音频/2图片/3文件/4视频/5RSS）
    String? bookUrlPattern,                  // 详情页URL正则
    @Default(0) int customOrder,             // 手动排序编号
    @Default(true) bool enabled,             // 是否启用
    @Default(true) bool enabledExplore,      // 启用发现

    // ========== 网络配置 ==========
    String? jsLib,                           // JS库
    @Default(true) bool enabledCookieJar,    // 启用Cookie自动保存
    @Default(false) bool enableDangerousApi, // 高危API开关
    String? concurrentRate,                  // 并发率限制
    String? header,                          // 请求头（JSON或JS表达式）

    // ========== 登录相关 ==========
    String? loginUrl,                        // 登录地址
    String? loginUi,                         // 登录UI配置
    String? loginCheckJs,                    // 登录检测JS

    // ========== 元数据 ==========
    String? coverDecodeJs,                   // 封面解密JS
    String? bookSourceComment,               // 注释
    String? variableComment,                 // 变量说明
    @Default(0) int lastUpdateTime,          // 最后更新时间
    @Default(180000) int respondTime,        // 响应时间（毫秒）
    @Default(0) int weight,                  // 智能排序权重

    // ========== 发现规则 ==========
    String? exploreUrl,                      // 发现URL
    String? exploreScreen,                   // 发现筛选规则
    @Default(0) int exploreStyle,            // 发现样式（0/1/2）
    ExploreRule? ruleExplore,                // 发现规则

    // ========== 搜索规则 ==========
    String? searchUrl,                       // 搜索URL
    SearchRule? ruleSearch,                  // 搜索规则

    // ========== 内容规则 ==========
    BookInfoRule? ruleBookInfo,              // 详情规则
    TocRule? ruleToc,                        // 目录规则
    ContentRule? ruleContent,                // 正文规则
    ReviewRule? ruleReview,                  // 段评规则

    // ========== IRIS 扩展字段 ==========
    String? jiexiUrl,                        // 解析地址（视频源专用）
    @Default(false) bool isNsfw,             // NSFW标记
  }) = _BookSource;

  /// 容错的 fromJson 工厂构造函数
  ///
  /// 处理 Legado JSON 中的类型不匹配问题：
  /// - lastUpdateTime: String "1779228932770" -> int
  /// - ruleBookInfo 等: 空数组 [] -> null
  factory BookSource.fromJson(Map<String, dynamic> json) {
    // 预处理 JSON，处理类型不匹配的情况
    final processedJson = Map<String, dynamic>.from(json);

    // 处理 lastUpdateTime: String -> int
    processedJson['lastUpdateTime'] = json.getIntOrZero('lastUpdateTime');

    // 处理规则字段: 空数组 [] -> null
    final ruleFields = [
      'ruleBookInfo', 'ruleToc', 'ruleSearch',
      'ruleExplore', 'ruleContent', 'ruleReview',
    ];
    for (final field in ruleFields) {
      final value = json[field];
      if (value != null && value is! Map<String, dynamic>) {
        // 如果不是 Map（如空数组 []），设置为 null
        processedJson[field] = null;
      }
    }

    return _$BookSourceFromJson(processedJson);
  }

  /// 手动实现 toJson（自定义 fromJson 后需要手动实现）
  Map<String, dynamic> toJson() => _$BookSourceToJson(this as _BookSource);

  // ========== 便捷方法 ==========

  /// 获取分组列表
  List<String> get groupList {
    if (bookSourceGroup == null || bookSourceGroup!.isEmpty) {
      return [];
    }
    return bookSourceGroup!
        .split(RegExp(r'[,;，；]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 是否属于指定分组
  bool hasGroup(String group) {
    return groupList.contains(group);
  }

  /// 添加分组
  BookSource addGroup(String group) {
    final groups = groupList;
    if (!groups.contains(group)) {
      groups.add(group);
    }
    return copyWith(bookSourceGroup: groups.join(','));
  }

  /// 移除分组
  BookSource removeGroup(String group) {
    final groups = groupList..remove(group);
    return copyWith(bookSourceGroup: groups.isEmpty ? null : groups.join(','));
  }

  /// 是否有登录配置
  bool get hasLogin =>
      loginUrl != null && loginUrl!.isNotEmpty;

  /// 是否有发现URL
  bool get hasExploreUrl =>
      exploreUrl != null && exploreUrl!.isNotEmpty;

  /// 是否有搜索URL
  bool get hasSearchUrl =>
      searchUrl != null && searchUrl!.isNotEmpty;

  /// 源类型名称
  String get typeName => BookSourceType.getName(bookSourceType);

  /// 是否为媒体类型
  bool get isMediaType => BookSourceType.isMediaType(bookSourceType);

  /// 响应时间格式化
  String get respondTimeFormatted {
    if (respondTime >= 180000) return '超时';
    if (respondTime >= 1000) return '${(respondTime / 1000).toStringAsFixed(1)}s';
    return '${respondTime}ms';
  }

  /// 最后更新时间格式化
  String get lastUpdateTimeFormatted {
    if (lastUpdateTime == 0) return '从未更新';
    final date = DateTime.fromMillisecondsSinceEpoch(lastUpdateTime);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
