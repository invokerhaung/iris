import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_source_config.freezed.dart';
part 'check_source_config.g.dart';

/// 源校验配置
@freezed
abstract class CheckSourceConfig with _$CheckSourceConfig {
  const factory CheckSourceConfig({
    @Default('我的') String keyword,        // 校验关键字
    @Default(180000) int timeout,           // 超时时间（毫秒）
    @Default(true) bool checkSearch,        // 校验搜索
    @Default(true) bool checkDiscovery,     // 校验发现
    @Default(true) bool checkInfo,          // 校验详情页
    @Default(true) bool checkCategory,      // 校验目录
    @Default(true) bool checkContent,       // 校验正文
    @Default(5) int threadCount,            // 并发数
  }) = _CheckSourceConfig;

  factory CheckSourceConfig.fromJson(Map<String, dynamic> json) =>
      _$CheckSourceConfigFromJson(json);
}
