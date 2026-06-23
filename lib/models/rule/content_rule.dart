import 'package:freezed_annotation/freezed_annotation.dart';

part 'content_rule.freezed.dart';
part 'content_rule.g.dart';

@freezed
abstract class ContentRule with _$ContentRule {
  const factory ContentRule({
    String? content,          // 正文内容规则
    String? title,            // 标题规则
    String? nextContentUrl,   // 下一页正文URL
    String? webJs,            // WebView JS注入
    String? sourceRegex,      // 源正则匹配
    String? replaceRegex,     // 替换规则
    String? imageStyle,       // 图片样式
    String? imageDecode,      // 图片解密JS
    String? payAction,        // 购买操作
    String? lrcRule,          // LRC歌词规则
    String? musicCover,       // 音乐封面规则
    String? shouldOverrideUrlLoading, // 拦截跳转
  }) = _ContentRule;

  factory ContentRule.fromJson(Map<String, dynamic> json) =>
      _$ContentRuleFromJson(json);
}
