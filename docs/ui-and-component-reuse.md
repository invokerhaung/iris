# IRIS UI 与组件复用分析

## 一、设计规范现状

### 结论：没有统一的设计规范文件

项目中**不存在**集中的设计令牌（Design Tokens）文件。没有 `constants.dart`、`tokens.dart`、`colors.dart`、`spacing.dart`、`styles.dart` 这样的文件。设计系统是最小化且分散的。

---

### 1.1 主题配置 — `lib/theme.dart`（唯一主题文件，69 行）

**种子颜色（唯一硬编码的设计色）：**
- `Color(0xFFB3BCDF)` — 一个柔和的蓝灰色，作为 `ColorScheme.fromSeed()` 的种子，同时用于亮色和暗色模式。

**主题结构：**
- `baseTheme()` 设置全局 `PopupMenuThemeData`（圆角 16、零阴影、零内边距）和 `ListTileThemeData`（圆角 12）
- `getTheme()` 构建最终的 `CustomTheme`（亮/暗一对），优先使用系统动态色，回退到种子色

**关键设计决策：**
- `useMaterial3: true` — 完全依赖 Material 3 生成的 `ColorScheme`
- 除 Google Fonts 外，无自定义 `TextTheme`
- 无自定义 `AppBarTheme`、`ButtonTheme`、`CardTheme` 等

---

### 1.2 颜色策略

**无自定义调色板**，使用两种方式：

**A. Material 3 `ColorScheme`（通过 `Theme.of(context).colorScheme`）**

常用语义色值：

| 语义色 | 用途 |
|--------|------|
| `colorScheme.primary` | 选中态、高亮 |
| `colorScheme.onSurface` | 主文本 |
| `colorScheme.onSurfaceVariant` | 次要文本、未选中项 |
| `colorScheme.surface` | 覆盖层背景 |
| `colorScheme.surfaceContainer` | 卡片背景（alpha 0.75） |
| `colorScheme.surfaceContainerHighest` | Chip 背景 |
| `colorScheme.inversePrimary` | 主色 Chip |
| `Theme.of(context).dividerColor` | 分隔线 |

**B. 硬编码 `Colors.*`（主要用于播放器暗色覆盖层）**

| 颜色 | 用途 |
|------|------|
| `Colors.black / black26 / black54 / black87` | 播放器覆盖层背景和渐变 |
| `Colors.white / white70` | 播放器暗色层上的文本/图标 |
| `Colors.transparent` | 屏障色、不可见容器 |
| `Colors.red` (alpha 0.4/0.5) | 关闭按钮 hover 态 |
| `Colors.grey` | 手势覆盖层进度条背景 |

---

### 1.3 动态色集成

**文件：** `lib/main.dart`（第 135 行）

使用 `dynamic_color` 包的 `DynamicColorBuilder`：
1. 接收系统 `lightDynamic` / `darkDynamic` `ColorScheme?`（Android 12+ Material You / Windows 强调色）
2. 有值时通过 `.harmonized()` 调和后直接使用
3. 无值时回退到 `theme.dart` 中基于种子色的 `customColorScheme`

主题模式（system/light/dark）持久化在 `AppStore` 中，通过 `MaterialApp.themeMode` 应用。

---

### 1.4 字体配置

- 全局字体：`GoogleFonts.notoSansScTextTheme()`（思源黑体简体中文）
- 无自定义字体比例尺，每个 Widget 内联定义 `TextStyle`

**常用字号模式（内联，未集中定义）：**

| 字号 | 场景 |
|------|------|
| `fontSize: 12` | Chip、控制栏标签、文件元数据 |
| `fontSize: 13` | 文件列表项 |
| `fontSize: 14` | 播放队列项、历史项 |
| `fontSize: 16` | 标题栏、倍速选择器未选中 |
| `fontSize: 20` | 倍速选择器选中、依赖项标题 |

---

### 1.5 间距与布局

**无集中间距令牌**，全部内联。常用值：

| EdgeInsets | 场景 |
|------------|------|
| `all(0)` | 弹出菜单、卡片默认 |
| `all(8)` | 对话框操作区 |
| `all(16)` | 底部弹出内容、依赖列表 |
| `fromLTRB(8, 0, 8, 0)` | Chip 水平内边距 |
| `fromLTRB(12, 0, 12, 0)` | 滑块内边距 |
| `fromLTRB(16, 4, 4, 4)` | 播放队列/历史头部 |

---

### 1.6 圆角

**无集中圆角令牌**，常用值：

| 圆角 | 场景 |
|------|------|
| `BorderRadius.circular(16)` | Card、弹出菜单、列表磁贴、播放队列、历史、文件列表、设置、存储 |
| `BorderRadius.circular(12)` | 列表磁贴主题、设置播放区 |
| `BorderRadius.circular(8)` | Chip、音频播放器封面、手势覆盖层按钮 |
| `BorderRadius.circular(4)` | 手势覆盖层内部指示器 |
| `BorderRadius.circular(30)` | 倍速选择器药丸形 |

---

### 1.7 总结

| 设计维度 | 定义位置 | 方式 |
|----------|---------|------|
| **颜色** | `theme.dart` 种子色 + Material 3 ColorScheme | 无自定义调色板，完全依赖 `ColorScheme.fromSeed()` 和系统动态色 |
| **字体** | `theme.dart` | 全局 `GoogleFonts.notoSansScTextTheme()`；无自定义字体比例 |
| **TextStyle** | 各 Widget 内联 | 无共享常量；字号/字重按 Widget 各自定义 |
| **间距** | 各 Widget 内联 | 无间距比例；ad-hoc EdgeInsets |
| **圆角** | 各 Widget 内联 + `theme.dart` | 16px 卡片/对话框，12px 列表磁贴，8px Chip/控件 |
| **主题模式** | `use_app_store.dart` → `main.dart` | 持久化在 SecureStorage，通过 `MaterialApp.themeMode` 应用 |
| **动态色** | `main.dart` | `DynamicColorBuilder` 包裹 `MaterialApp`；回退到种子色 `0xFFB3BCDF` |

---

## 二、被复用次数最多的 3 个自定义 Widget

### 2.1 Popup（`lib/widgets/popup.dart`）— 复用最多

**直接导入：** 3 个文件
**调用次数：** 13+ 次 `showPopup()` / `replacePopup()`

Popup 是整个 App 导航覆盖层系统的骨架。它是一个自定义 `PopupRoute`，从屏幕左/右边缘滑入面板。App 中每个主要功能面板都通过它显示。

**实现要点：**
- 继承 `PopupRoute<T>` 创建全屏模态路由
- 通过 `PopupDirection` 枚举从左或右滑入
- 使用 `SlideTransition` + `Curves.easeInOutCubicEmphasized` 动画（250ms）
- 支持滑动关闭（`Dismissible`）
- 监听 Escape 键关闭
- 支持桌面端窗口拖拽（`windowManager.startDragging()`）
- 响应式尺寸：屏幕宽度 ÷ 3（大）/ 2（中）/ 1（小），断点 1200px 和 720px
- 内容包裹在自定义 `Card` Widget 中实现毛玻璃效果

**调用它的文件：**
- `lib/hooks/use_keyboard.dart` — 5 次调用（Settings、History、Storages、PlayQueue、SubtitleAndAudioTrack）
- `lib/pages/player/control_bar/control_bar.dart` — 5 次调用
- `lib/models/storages/storage.dart` — 1 次调用（`replacePopup()`）

**通过 Popup 系统显示的 14 个面板 Widget（`lib/widgets/popups/`）：**

```
play_queue.dart          history.dart
storages.dart            storages_list.dart
files.dart               favorites.dart
settings/settings.dart   settings/general.dart
settings/about.dart      settings/play.dart
settings/dependencies.dart
track/subtitle_and_audio_track.dart
track/subtitle_list.dart
track/audio_track_list.dart
```

---

### 2.2 Chip（`lib/widgets/chip.dart`）— 第二复用

**直接导入：** 3 个文件
**实例化次数：** 多次（每个列表项都有）

Chip 是一个紧凑的标签 Widget，用于在列表项中显示状态徽章（播放进度百分比、字幕格式类型）。

**实现：**
- 简单的 `StatelessWidget`，参数：`text` + `primary`（bool）
- 固定高度 20px，圆角 8px
- 两种颜色模式：`primary` 使用 `inversePrimary`，默认使用 `surfaceContainerHighest`
- 加粗 12px 居中文本

**使用它的文件：**
- `lib/widgets/popups/play_queue.dart` — 每个播放队列项显示进度百分比和字幕格式 Chip
- `lib/widgets/popups/history.dart` — 历史列表项同样模式
- `lib/widgets/popups/storages/files.dart` — 文件浏览器列表项同样模式

**注意：** 这三个文件都 `hide Chip` 了 Flutter 内置 Chip 以避免命名冲突：
```dart
import 'package:flutter/material.dart' hide Chip;
```

---

### 2.3 Card（`lib/widgets/card.dart`）— 第三复用

**直接导入：** 1 个文件（`popup.dart`）
**实际影响：** App 中每个弹出面板（14+ 个面板）都被这个 Card 包裹

虽然只有一个文件直接导入，但 Card 的实际影响范围巨大——它是 Popup 系统中每个弹出面板的容器。

**实现：**
- `StatelessWidget`，参数：`child`、`padding`、`borderRadius`、`color`、`border`
- 使用 `BackdropFilter` + `ImageFilter.blur(sigmaX: 10, sigmaY: 10)` 创建**毛玻璃效果**
- 默认圆角 16px
- 背景：`surfaceContainer` 颜色，75% 不透明度
- 边框：`onSurfaceVariant` 12.5% 不透明度，1px 宽
- 使用 `Stack`：底层模糊容器 + 顶层 `Positioned.fill` 边框覆盖（通过 `IgnorePointer`）

---

### 2.4 Bottom Sheets 与 Dialogs 模式

**Bottom Sheets**（`lib/widgets/bottom_sheets/`）：1 个文件 — `show_open_link_bottom_sheet.dart`，使用 `showModalBottomSheet` + `isScrollControlled: true`

**Dialogs**（`lib/widgets/dialogs/`）：9 个文件，遵循统一模式：

```
show_folder_dialog.dart      show_ftp_dialog.dart
show_webdav_dialog.dart      show_open_link_dialog.dart
show_language_dialog.dart    show_theme_mode_dialog.dart
show_rate_dialog.dart        show_release_dialog.dart
show_orientation_dialog.dart
```

**统一模式：** 顶层 `showXxxDialog()` 异步函数 → 调用 `showDialog()` / `showModalBottomSheet()` → 包裹 `HookWidget` 类

**平台自适应：** `use_keyboard.dart` 和 `control_bar.dart` 根据平台选择：
- 桌面端 → `showOpenLinkDialog`
- 移动端 → `showOpenLinkBottomSheet`

---

## 三、列表页面实现方式

### 3.1 列表 Widget 使用总结

#### 主力列表：`ScrollablePositionedList`（scrollable_positioned_list 包 v0.3.8）

用于三个核心文件：

| 文件 | 用途 |
|------|------|
| `lib/widgets/popups/storages/files.dart` | 文件浏览器列表 |
| `lib/widgets/popups/history.dart` | 播放历史列表 |
| `lib/widgets/popups/play_queue.dart` | 播放队列列表 |

三个文件都使用 `ScrollablePositionedList.builder(...)` 并实例化四个控制器/监听器：

```dart
final itemScrollController = useMemoized(() => ItemScrollController(), []);
final scrollOffsetController = useMemoized(() => ScrollOffsetController(), []);
final itemPositionsListener = useMemoized(() => ItemPositionsListener.create(), []);
final scrollOffsetListener = useMemoized(() => ScrollOffsetListener.create(), []);
```

**为什么选它而不是 `ListView.builder`？** 因为它支持**编程式滚动到指定索引**。播放队列打开时需要跳转到当前播放项：

```dart
itemScrollController.jumpTo(
    index: currentPlayIndex - 3 < 0 ? 0 : currentPlayIndex - 1);
```

#### 次要列表：`ListView.builder`（Flutter 内置）

用于不需要编程式滚动的简单短列表：

| 文件 | 用途 |
|------|------|
| `lib/widgets/popups/storages/favorites.dart` | 收藏列表 |
| `lib/widgets/popups/storages/storages_list.dart` | 存储源列表 |
| `lib/widgets/popups/settings/dependencies.dart` | 开源许可证依赖 |

#### 固定列表：`ListView`（非 builder，用于小型固定列表）

| 文件 | 用途 |
|------|------|
| `lib/widgets/popups/track/subtitle_list.dart` | 字幕轨选择 |
| `lib/widgets/popups/track/audio_track_list.dart` | 音频轨选择 |

#### 未使用的列表 Widget

- `CustomScrollView` / `SliverList` / `SliverGrid` — **全项目零使用**

---

### 3.2 刷新机制

**无下拉刷新库**。搜索 `RefreshIndicator`、`onRefresh`、`EasyRefresh`、`SmartRefresher` 均无结果。

唯一的"刷新"机制是文件浏览器中的**手动刷新按钮**（`files.dart`）：

```dart
final refreshState = useState(false);
void refresh() => refreshState.value = !refreshState.value;

// refreshState 作为 useMemoized 的依赖，切换布尔值强制重新获取文件
final getFiles = useMemoized(
    () async => await storage.getFiles(currentPath),
    [currentPath, refreshState.value]);
```

---

### 3.3 分页 / 懒加载

**无分页或懒加载**。搜索 `pagina`、`lazy load`、`loadMore`、`hasMore`、`nextPage`、`fetchMore` 均无结果。无 `NotificationListener<ScrollNotification>` 滚动监听模式。

所有列表一次性加载全部数据：
- **文件列表**：通过 `storage.getFiles(currentPath)` 加载当前目录全部文件
- **历史列表**：从 Store 加载完整历史，截断到 100 条（`entries.sublist(0, min(entries.length, 100))`）
- **播放队列**：从 Store 一次性加载整个队列

---

### 3.4 长列表处理策略

1. **虚拟滚动（Builder 模式）**：`ScrollablePositionedList.builder` 和 `ListView.builder` 只渲染可见项（标准 Flutter 懒渲染），Widget 层面高效处理长列表
2. **无数据层分页**：所有数据一次性获取/存储在内存中
3. **历史硬上限**：历史列表限制 100 条
4. **客户端排序和过滤**：文件列表的排序和过滤通过 `useMemoized` 在获取完整列表后内存中完成，`filesSort` 工具函数处理名称/大小/日期排序（文件夹优先）
5. **状态管理**：所有列表使用 `flutter_zustand` + `flutter_hooks`（`HookWidget`、`useMemoized`、`useFuture`、`useState`、`useEffect`），通过 `store.select(context, ...)` 响应式重建

---

### 3.5 列表实现总结

| 维度 | 实现 |
|------|------|
| 主力列表 Widget | `ScrollablePositionedList.builder`（scrollable_positioned_list 0.3.8） |
| 简单/短列表 | `ListView.builder` 或普通 `ListView` |
| Sliver 列表 | 未使用 |
| 下拉刷新 | 未实现；仅文件浏览器有手动刷新按钮 |
| 分页 / 懒加载 | 未实现；所有数据一次性加载 |
| 长列表截断 | 历史限制 100 条 |
| 虚拟渲染 | 标准 Flutter Builder 模式（懒构建项） |
| 状态管理 | flutter_zustand + flutter_hooks |
| 滚动到指定项 | `ItemScrollController.jumpTo()`（播放队列使用） |
