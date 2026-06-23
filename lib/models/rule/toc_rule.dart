import 'package:freezed_annotation/freezed_annotation.dart';

part 'toc_rule.freezed.dart';
part 'toc_rule.g.dart';

@freezed
abstract class TocRule with _$TocRule {
  const factory TocRule({
    String? preUpdateJs,      // 预更新JS
    String? chapterList,      // 章节列表规则
    String? chapterName,      // 章节名称规则
    String? chapterUrl,       // 章节URL规则
    String? formatJs,         // 格式化JS
    String? isVolume,         // 是否为卷（分组）
    String? isVip,            // 是否VIP章节
    String? isPay,            // 是否付费章节
    String? updateTime,       // 更新时间规则
    String? nextTocUrl,       // 下一页目录URL
  }) = _TocRule;

  factory TocRule.fromJson(Map<String, dynamic> json) =>
      _$TocRuleFromJson(json);
}
