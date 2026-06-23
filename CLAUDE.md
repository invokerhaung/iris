# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

IRIS — 轻量级跨平台视频播放器，基于 Flutter 构建，支持 Windows、Android、Linux、macOS、iOS。支持本地文件、WebDAV、FTP 三种存储后端，提供 Media Kit (mpv) 和 FVP (FFmpeg) 两套播放引擎。

## 常用命令

```bash
flutter pub get                                          # 安装依赖
flutter pub run build_runner build --delete-conflicting-outputs  # 生成 freezed/json_serializable 代码
flutter analyze                                          # 静态分析
flutter test                                             # 运行全部测试
flutter test test/models/book_source_test.dart           # 运行单个测试文件
flutter build windows                                    # 构建 Windows
flutter build apk --split-per-abi                        # 构建 Android APK (按 ABI 分包)
```

修改 `lib/models/store/` 下的 freezed state 类或 `lib/models/` 下的 model 类后，必须运行 `build_runner build` 重新生成代码。

## 架构

### 状态管理：flutter_zustand + flutter_hooks

全局状态通过 Zustand 风格的 store 管理（`lib/store/`），所有 widget 均为 `HookWidget`。

| Store | 持久化 | 用途 |
|---|---|---|
| `AppStore` | ✅ | 主题、语言、音量、倍速、播放器后端、代理等全局设置 |
| `PlayQueueStore` | ✅ | 播放队列和当前索引 |
| `HistoryStore` | ✅ | 播放进度历史 |
| `PlayerUiStore` | ❌ | 临时 UI 状态（全屏、拖拽、悬浮等） |
| `StorageStore` | ✅ | 存储配置、收藏、当前路径 |
| `SourceStore` | ✅ | 源管理（Legado 兼容的书源/影视源） |

持久化 store 继承 `PersistentStore<T>`（`lib/store/persistent_store.dart`），底层使用 `FlutterSecureStorage`。Widget 中通过 `useAppStore().select(context, (s) => s.field)` 读取状态片段。

### 播放器抽象

`MediaPlayer`（`lib/models/player.dart`）定义播放器接口，两个实现：
- `MediaKitPlayer`（`lib/hooks/player/use_media_kit_player.dart`）— mpv 引擎，支持 libass 字幕
- `FvpPlayer`（`lib/hooks/player/use_fvp_player.dart`）— FFmpeg 引擎，实验性

`PlayerView` 根据 `AppState.playerBackend` 切换引擎。

### 存储抽象

`Storage`（`lib/models/storages/storage.dart`）是 freezed sealed class，三种变体：
- `LocalStorage` — 本地文件系统（内置、USB、SD 卡、Windows 网络驱动器）
- `WebDAVStorage` — WebDAV 远程存储
- `FTPStorage` — FTP 远程存储

### 路由

无路由包，导航方式：
- `Navigator.push(Popup(...))` — 侧边弹出面板（自定义 `PopupRoute`）
- `showDialog` / `showModalBottomSheet` — 对话框和底部弹出
- 直接 widget 组合（Shell → PlayerView）

Shell（`lib/pages/shell/shell.dart`）使用 `NavigationBar`，4 个 tab：Files、Explore、Sources、Settings。

### 依赖注入

`provider` 仅用于将 `MediaPlayer` 实例注入 widget 树，stores 通过全局函数访问。

### FFI / Legado 兼容

`lib/ffi/` 包含 Legado 源解析的 FFI 绑定，依赖 `ffi_lib/legado_ffi.dll`。`lib/models/rule/` 下为 Legado 规则模型。

### 本地第三方包

`3rdparty/` 下有两个本地 package：
- `drives_windows` — Windows 驱动器/网络快捷方式枚举
- `media_stream` — FTP/SMB 转 HTTP 的流媒体服务器

### 代码生成

所有 state/model 类使用 `@freezed` 注解，生成文件 `*.freezed.dart` / `*.g.dart` 已 gitignore。

### 国际化

`lib/l10n/` 下 ARB 文件（`app_en.arb`、`app_zh.arb`），`l10n.yaml` 配置输出到 `lib/l10n/app_localizations.dart`。

### 全局变量

`lib/globals.dart` 存放可变全局变量（CLI 参数、初始化 URI、权限状态等）。

## CI

GitHub Actions（`.github/workflows/ci.yml`）：push 到 `main`/`develop` 或 PR 时触发，构建 Windows 和 Android 产物；push 到 `main` 时自动创建 GitHub Release。CI 固定执行 `flutter pub get && flutter pub run build_runner build --delete-conflicting-outputs` 后再构建。
