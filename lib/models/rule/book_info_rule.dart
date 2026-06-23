import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_info_rule.freezed.dart';
part 'book_info_rule.g.dart';

@freezed
abstract class BookInfoRule with _$BookInfoRule {
  const factory BookInfoRule({
    String? init,             // 初始化规则
    String? name,             // 书名规则
    String? author,           // 作者规则
    String? intro,            // 简介规则
    String? kind,             // 分类规则
    String? lastChapter,      // 最新章节规则
    String? updateTime,       // 更新时间规则
    String? coverUrl,         // 封面URL规则
    String? tocUrl,           // 目录页URL规则
    String? wordCount,        // 字数规则
    String? canReName,        // 是否允许重命名
    String? downloadUrls,     // 下载地址规则
  }) = _BookInfoRule;

  factory BookInfoRule.fromJson(Map<String, dynamic> json) =>
      _$BookInfoRuleFromJson(json);
}
