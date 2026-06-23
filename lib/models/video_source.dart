import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iris/models/source_rule.dart';

part 'video_source.freezed.dart';
part 'video_source.g.dart';

enum SourceStatus {
  active,
  inactive,
  error,
}

/// 源排序方式
enum SourceSortBy {
  weight,
  name,
  apiUrl,
  lastUpdateTime,
  respondTime,
  status,
}

@freezed
abstract class VideoSource with _$VideoSource {
  const factory VideoSource({
    required String id,
    required String name,
    required String apiUrl,
    String? jiexiUrl,
    @Default(false) bool isNsfw,
    @Default(SourceStatus.active) SourceStatus status,
    @Default('') String group,
    @Default(0) int weight,
    String? header,
    String? comment,
    @Default(0) int lastUpdateTime,
    @Default(0) int respondTime,
    @Default(SourceRule()) SourceRule rule,
  }) = _VideoSource;

  factory VideoSource.fromJson(Map<String, dynamic> json) =>
      _$VideoSourceFromJson(json);
}
