import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iris/models/source_subscription.dart';
import 'package:iris/models/video_source.dart';

part 'source_state.freezed.dart';
part 'source_state.g.dart';

@freezed
abstract class SourceState with _$SourceState {
  const factory SourceState({
    @Default([]) List<VideoSource> sources,
    @Default(0) int currentSourceIndex,
    @Default([]) List<String> groups,
    @Default(SourceSortBy.weight) SourceSortBy sortBy,
    @Default(true) bool sortAscending,
    @Default([]) List<SourceSubscription> subscriptions,
  }) = _SourceState;

  factory SourceState.fromJson(Map<String, dynamic> json) =>
      _$SourceStateFromJson(json);
}
