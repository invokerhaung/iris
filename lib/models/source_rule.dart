import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_rule.freezed.dart';
part 'source_rule.g.dart';

/// 源解析规则
///
/// 定义如何从 HTML 中提取视频列表、详情和播放信息。
/// 选择器语法参考 Legado：
///   - CSS 选择器: `.list-item a`
///   - 属性提取: `a@href`、`img@src`
///   - 文本提取: `h1@text`
///   - 组合选择器: `body&&.list a` （从 body 开始，取 .list 下的 a）
///   - 文本子串: `@css:.title@text##前缀##后缀`（截取中间部分）
@freezed
abstract class SourceRule with _$SourceRule {
  const factory SourceRule({
    // ================================================================
    // 列表页规则（首页/分类页）
    // ================================================================

    /// 列表项选择器，如 `.video-list li`、`body&&.list-item`
    @Default('') String ruleList,

    /// 视频名称选择器（相对于列表项），如 `a@text`、`.title@text`
    @Default('') String ruleName,

    /// 视频链接选择器，如 `a@href`、`.link@href`
    @Default('') String ruleUrl,

    /// 封面图选择器，如 `img@src`、`.cover img@src`
    @Default('') String ruleCover,

    /// 年份选择器，如 `.year@text`
    @Default('') String ruleYear,

    /// 地区选择器，如 `.area@text`
    @Default('') String ruleArea,

    /// 类型/分类选择器，如 `.type@text`
    @Default('') String ruleType,

    /// 评分选择器，如 `.score@text`
    @Default('') String ruleScore,

    // ================================================================
    // 详情页规则
    // ================================================================

    /// 详情页简介选择器，如 `.detail-intro@text`
    @Default('') String ruleDetailDesc,

    /// 详情页播放列表容器选择器，如 `.play-list`
    @Default('') String ruleDetailPlayList,

    /// 播放项名称选择器，如 `a@text`
    @Default('') String ruleDetailPlayName,

    /// 播放项链接选择器，如 `a@href`
    @Default('') String ruleDetailPlayUrl,

    // ================================================================
    // 搜索规则（可选，为空时复用列表规则）
    // ================================================================

    /// 搜索 URL 模板，用 `{keyword}` 作为关键词占位符
    /// 如 `https://example.com/search?wd={keyword}`
    @Default('') String ruleSearchUrl,

    /// 搜索结果列表选择器（为空时复用 ruleList）
    @Default('') String ruleSearchList,

    // ================================================================
    // 解析配置
    // ================================================================

    /// 是否使用 WebView 渲染页面（适用于需要 JS 渲染的页面）
    @Default(false) bool useWebView,

    /// 自定义请求头（JSON 格式）
    String? customHeaders,

    /// 自定义 Cookie
    String? cookie,
  }) = _SourceRule;

  factory SourceRule.fromJson(Map<String, dynamic> json) =>
      _$SourceRuleFromJson(json);
}
