import 'package:freezed_annotation/freezed_annotation.dart';

part 'explore_rule.freezed.dart';
part 'explore_rule.g.dart';

@freezed
abstract class ExploreRule with _$ExploreRule {
  const factory ExploreRule({
    String? bookList,         // 发现列表规则
    String? name,             // 书名规则
    String? author,           // 作者规则
    String? intro,            // 简介规则
    String? kind,             // 分类规则
    String? lastChapter,      // 最新章节规则
    String? updateTime,       // 更新时间规则
    String? bookUrl,          // 书籍URL规则
    String? coverUrl,         // 封面URL规则
    String? wordCount,        // 字数规则
  }) = _ExploreRule;

  factory ExploreRule.fromJson(Map<String, dynamic> json) =>
      _$ExploreRuleFromJson(json);
}
