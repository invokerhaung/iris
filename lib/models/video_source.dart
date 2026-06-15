import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_source.freezed.dart';
part 'video_source.g.dart';

enum SourceType {
  maccms,
  universal,
}

enum SourceStatus {
  active,
  inactive,
  error,
}

/// 源排序方式
enum SourceSortBy {
  weight, // 按权重
  name, // 按名称
  apiUrl, // 按 URL
  lastUpdateTime, // 按更新时间
  respondTime, // 按响应时间
  status, // 按状态
}

@freezed
abstract class VideoSource with _$VideoSource {
  const factory VideoSource({
    required String id,
    required String name,
    required String apiUrl,
    @Default(SourceType.maccms) SourceType type,
    String? jiexiUrl,
    @Default(false) bool isNsfw,
    @Default(SourceStatus.active) SourceStatus status,
    @Default('') String group,
    @Default(0) int weight,
    String? header,
    String? comment,
    @Default(0) int lastUpdateTime,
    @Default(0) int respondTime,
  }) = _VideoSource;

  factory VideoSource.fromJson(Map<String, dynamic> json) =>
      _$VideoSourceFromJson(json);
}
