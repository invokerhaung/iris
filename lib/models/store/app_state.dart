import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_state.freezed.dart';
part 'app_state.g.dart';

enum PlayerBackend {
  mediaKit,
  fvp,
}

enum Repeat {
  none,
  all,
  one,
}

enum SortBy {
  name,
  size,
  lastModified,
}

enum SortOrder {
  asc,
  desc,
}

enum ScreenOrientation {
  device,
  landscape,
  portrait,
}

@freezed
abstract class AppState with _$AppState {
  const factory AppState({
    @Default(false) bool autoPlay,
    @Default(false) bool shuffle,
    @Default(Repeat.none) Repeat repeat,
    @Default(BoxFit.contain) BoxFit fit,
    @Default(1) double rate,
    @Default(80) int volume,
    @Default(false) bool isMuted,
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default('none') String preferedSubtitleLanguage,
    @Default('system') String language,
    @Default(false) bool autoCheckUpdate,
    @Default(false) bool autoResize,
    @Default(false) bool alwaysPlayFromBeginning,
    @Default(PlayerBackend.mediaKit) PlayerBackend playerBackend,
    @Default(SortBy.name) SortBy sortBy,
    @Default(SortOrder.asc) SortOrder sortOrder,
    @Default(true) bool folderFirst,
    @Default(ScreenOrientation.device) ScreenOrientation orientation,
    @Default(0) int currentTab,
    @Default(false) bool showPlayer,
    @Default(false) bool enableProxy,       // 启用代理
    @Default('127.0.0.1') String proxyHost, // 代理地址
    @Default(7890) int proxyPort,           // 代理端口
  }) = _AppState;

  factory AppState.fromJson(Map<String, dynamic> json) =>
      _$AppStateFromJson(json);
}
