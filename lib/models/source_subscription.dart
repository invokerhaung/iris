import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_subscription.freezed.dart';
part 'source_subscription.g.dart';

/// 源订阅条目
@freezed
abstract class SourceSubscription with _$SourceSubscription {
  const factory SourceSubscription({
    /// 订阅名称
    required String name,

    /// 订阅 URL（JSON 源列表地址）
    required String url,

    /// 最后同步时间（毫秒时间戳）
    @Default(0) int lastSyncTime,

    /// 最后同步结果：null=未同步, true=成功, false=失败
    bool? lastSyncSuccess,

    /// 同步到的源数量
    @Default(0) int sourceCount,

    /// 是否启用自动同步
    @Default(false) bool autoSync,
  }) = _SourceSubscription;

  factory SourceSubscription.fromJson(Map<String, dynamic> json) =>
      _$SourceSubscriptionFromJson(json);
}
