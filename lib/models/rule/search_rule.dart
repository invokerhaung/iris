import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_rule.freezed.dart';
part 'search_rule.g.dart';

@freezed
abstract class SearchRule with _$SearchRule {
  const factory SearchRule({
    String? checkKeyWord,     // 校验关键字
    String? bookList,         // 书籍列表规则
    String? name,             // 书名规则
    String? author,           // 作者规则
    String? intro,            // 简介规则
    String? kind,             // 分类规则
    String? lastChapter,      // 最新章节规则
    String? updateTime,       // 更新时间规则
    String? bookUrl,          // 书籍URL规则
    String? coverUrl,         // 封面URL规则
    String? wordCount,        // 字数规则
  }) = _SearchRule;

  factory SearchRule.fromJson(Map<String, dynamic> json) =>
      _$SearchRuleFromJson(json);
}
