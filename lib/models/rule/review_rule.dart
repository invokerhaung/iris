import 'package:freezed_annotation/freezed_annotation.dart';

part 'review_rule.freezed.dart';
part 'review_rule.g.dart';

@freezed
abstract class ReviewRule with _$ReviewRule {
  const factory ReviewRule({
    String? reviewUrl,        // 段评URL
    String? avatarRule,       // 头像规则
    String? contentRule,      // 内容规则
    String? postTimeRule,     // 发布时间规则
    String? reviewQuoteUrl,   // 回复URL
    String? voteUpUrl,        // 点赞URL
    String? voteDownUrl,      // 点踩URL
    String? postReviewUrl,    // 发送回复URL
    String? postQuoteUrl,     // 发送回复段评URL
    String? deleteUrl,        // 删除URL
  }) = _ReviewRule;

  factory ReviewRule.fromJson(Map<String, dynamic> json) =>
      _$ReviewRuleFromJson(json);
}
