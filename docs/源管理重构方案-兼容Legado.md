# IRIS 源管理重构方案 — 完全兼容 Legado

## 一、重构目标

1. **完全兼容 Legado 源格式**：直接导入 Legado 书源 JSON，无需转换
2. **保留 IRIS 视频特性**：在兼容基础上扩展视频相关字段
3. **统一规则结构**：采用 Legado 嵌套规则结构，替代现有扁平结构
4. **功能对齐**：补齐批量操作、拖拽排序、源校验等功能
5. **解析引擎不变**：继续使用 FFI (legado_ffi.dll) 进行规则解析

---

## 二、数据模型重构

### 2.1 新模型结构

```
lib/models/
├── book_source.dart              # 主实体（兼容 Legado BookSource）
├── book_source_part.dart         # 轻量视图（列表展示用）
├── rule/
│   ├── search_rule.dart          # 搜索规则
│   ├── explore_rule.dart         # 发现规则
│   ├── book_info_rule.dart       # 详情规则
│   ├── toc_rule.dart             # 目录规则（视频：播放列表）
│   ├── content_rule.dart         # 正文规则（视频：播放地址）
│   └── review_rule.dart          # 段评规则
├── book_source_type.dart         # 源类型枚举
└── store/
    └── source_state.dart         # 聚合状态
```

### 2.2 BookSource 主实体

```dart
// lib/models/book_source.dart
@freezed
class BookSource with _$BookSource {
  const BookSource._();

  @JsonSerializable(includeIfNull: false)
  const factory BookSource({
    // ========== 基础信息 ==========
    @Default('') String bookSourceUrl,      // 主键，源地址
    @Default('') String bookSourceName,      // 源名称
    String? bookSourceGroup,                 // 分组（逗号/分号分隔）
    @Default(0) int bookSourceType,          // 类型（0文本/1音频/2图片/3文件/4视频/5RSS）
    String? bookUrlPattern,                  // 详情页URL正则
    @Default(0) int customOrder,             // 手动排序编号
    @Default(true) bool enabled,             // 是否启用
    @Default(true) bool enabledExplore,      // 启用发现

    // ========== 网络配置 ==========
    String? jsLib,                           // JS库
    @Default(true) bool enabledCookieJar,    // 启用Cookie自动保存
    @Default(false) bool enableDangerousApi, // 高危API开关
    String? concurrentRate,                  // 并发率限制
    String? header,                          // 请求头（JSON或JS表达式）

    // ========== 登录相关 ==========
    String? loginUrl,                        // 登录地址
    String? loginUi,                         // 登录UI配置
    String? loginCheckJs,                    // 登录检测JS

    // ========== 元数据 ==========
    String? coverDecodeJs,                   // 封面解密JS
    String? bookSourceComment,               // 注释
    String? variableComment,                 // 变量说明
    @Default(0) int lastUpdateTime,          // 最后更新时间
    @Default(180000) int respondTime,        // 响应时间（毫秒）
    @Default(0) int weight,                  // 智能排序权重

    // ========== 发现规则 ==========
    String? exploreUrl,                      // 发现URL
    String? exploreScreen,                   // 发现筛选规则
    @Default(0) int exploreStyle,            // 发现样式
    ExploreRule? ruleExplore,                // 发现规则

    // ========== 搜索规则 ==========
    String? searchUrl,                       // 搜索URL
    SearchRule? ruleSearch,                  // 搜索规则

    // ========== 内容规则 ==========
    BookInfoRule? ruleBookInfo,              // 详情规则
    TocRule? ruleToc,                        // 目录规则
    ContentRule? ruleContent,                // 正文规则
    ReviewRule? ruleReview,                  // 段评规则

    // ========== IRIS 扩展字段 ==========
    String? jiexiUrl,                        // 解析地址（视频源专用）
    @Default(false) bool isNsfw,             // NSFW标记
  }) = _BookSource;

  factory BookSource.fromJson(Map<String, dynamic> json) =>
      _$BookSourceFromJson(json);
}
```

### 2.3 BookSourceType 枚举

```dart
// lib/models/book_source_type.dart
class BookSourceType {
  static const int defaultType = 0;  // 文本
  static const int audio = 1;        // 音频
  static const int image = 2;        // 图片
  static const int file = 3;         // 文件下载
  static const int video = 4;        // 视频
  static const int rss = 5;          // RSS订阅

  static String getName(int type) {
    switch (type) {
      case defaultType: return '文本';
      case audio: return '音频';
      case image: return '图片';
      case file: return '文件';
      case video: return '视频';
      case rss: return 'RSS';
      default: return '未知';
    }
  }
}
```

### 2.4 规则数据结构

#### SearchRule（搜索规则）

```dart
// lib/models/rule/search_rule.dart
@freezed
class SearchRule with _$SearchRule {
  const factory SearchRule({
    String? checkKeyWord,     // 校验关键字
    String? bookList,         // 书籍列表规则
    String? name,             // 书名规则
    String? author,           // 作者规则
    String? intro,            // 简介规则
    String? kind,             // 分类规则
    String? lastChapter,      // 最新章节规则
    String? updateTime,       // 更新时间规则
    String? bookUrl,          // 书籍URL规则
    String? coverUrl,         // 封面URL规则
    String? wordCount,        // 字数规则
  }) = _SearchRule;

  factory SearchRule.fromJson(Map<String, dynamic> json) =>
      _$SearchRuleFromJson(json);
}
```

#### ExploreRule（发现规则）

```dart
// lib/models/rule/explore_rule.dart
@freezed
class ExploreRule with _$ExploreRule {
  const factory ExploreRule({
    String? bookList,         // 发现列表规则
    String? name,             // 书名规则
    String? author,           // 作者规则
    String? intro,            // 简介规则
    String? kind,             // 分类规则
    String? lastChapter,      // 最新章节规则
    String? updateTime,       // 更新时间规则
    String? bookUrl,          // 书籍URL规则
    String? coverUrl,         // 封面URL规则
    String? wordCount,        // 字数规则
  }) = _ExploreRule;

  factory ExploreRule.fromJson(Map<String, dynamic> json) =>
      _$ExploreRuleFromJson(json);
}
```

#### BookInfoRule（详情规则）

```dart
// lib/models/rule/book_info_rule.dart
@freezed
class BookInfoRule with _$BookInfoRule {
  const factory BookInfoRule({
    String? init,             // 初始化规则
    String? name,             // 书名规则
    String? author,           // 作者规则
    String? intro,            // 简介规则
    String? kind,             // 分类规则
    String? lastChapter,      // 最新章节规则
    String? updateTime,       // 更新时间规则
    String? coverUrl,         // 封面URL规则
    String? tocUrl,           // 目录页URL规则
    String? wordCount,        // 字数规则
    String? canReName,        // 是否允许重命名
    String? downloadUrls,     // 下载地址规则
  }) = _BookInfoRule;

  factory BookInfoRule.fromJson(Map<String, dynamic> json) =>
      _$BookInfoRuleFromJson(json);
}
```

#### TocRule（目录规则 / 播放列表规则）

```dart
// lib/models/rule/toc_rule.dart
@freezed
class TocRule with _$TocRule {
  const factory TocRule({
    String? preUpdateJs,      // 预更新JS
    String? chapterList,      // 章节列表规则
    String? chapterName,      // 章节名称规则
    String? chapterUrl,       // 章节URL规则
    String? formatJs,         // 格式化JS
    String? isVolume,         // 是否为卷（分组）
    String? isVip,            // 是否VIP章节
    String? isPay,            // 是否付费章节
    String? updateTime,       // 更新时间规则
    String? nextTocUrl,       // 下一页目录URL
  }) = _TocRule;

  factory TocRule.fromJson(Map<String, dynamic> json) =>
      _$TocRuleFromJson(json);
}
```

#### ContentRule（正文规则 / 播放地址规则）

```dart
// lib/models/rule/content_rule.dart
@freezed
class ContentRule with _$ContentRule {
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
```

#### ReviewRule（段评规则）

```dart
// lib/models/rule/review_rule.dart
@freezed
class ReviewRule with _$ReviewRule {
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
```

### 2.5 BookSourcePart（轻量视图）

```dart
// lib/models/book_source_part.dart
@freezed
class BookSourcePart with _$BookSourcePart {
  const factory BookSourcePart({
    required String bookSourceUrl,
    required String bookSourceName,
    String? bookSourceGroup,
    @Default(0) int customOrder,
    @Default(true) bool enabled,
    @Default(true) bool enabledExplore,
    @Default(0) int lastUpdateTime,
    @Default(180000) int respondTime,
    @Default(0) int weight,
  }) = _BookSourcePart;

  // 计算属性
  const BookSourcePart._();

  bool get hasLoginUrl => false; // 需要从完整源获取
  bool get hasExploreUrl => false; // 需要从完整源获取
}
```

---

## 三、状态管理重构

### 3.1 SourceState 聚合状态

```dart
// lib/models/store/source_state.dart
@freezed
class SourceState with _$SourceState {
  const factory SourceState({
    @Default([]) List<BookSource> sources,      // 完整源列表
    @Default([]) List<String> groups,            // 分组列表
    @Default(0) int sortBy,                      // 排序方式
    @Default(true) bool sortAscending,           // 排序方向
    @Default([]) List<SourceSubscription> subscriptions, // 订阅列表
  }) = _SourceState;

  factory SourceState.fromJson(Map<String, dynamic> json) =>
      _$SourceStateFromJson(json);
}
```

### 3.2 SourceStore 重构

```dart
// lib/store/use_source_store.dart
class SourceStore extends PersistentStore<SourceState> {
  // ========== 源 CRUD ==========
  Future<void> addSource(BookSource source);
  Future<void> removeSource(String bookSourceUrl);
  Future<void> updateSource(BookSource source);
  Future<void> removeSources(List<String> urls);  // 批量删除

  // ========== 批量操作 ==========
  Future<void> enableSources(List<String> urls, bool enable);
  Future<void> enableExploreSources(List<String> urls, bool enable);
  Future<void> topSources(List<String> urls);      // 置顶
  Future<void> bottomSources(List<String> urls);   // 置底
  Future<void> exportSelectedSources(List<String> urls);

  // ========== 分组管理 ==========
  Future<void> addGroup(String group);
  Future<void> removeGroup(String group);
  Future<void> renameGroup(String oldGroup, String newGroup);
  Future<void> addToGroup(List<String> urls, String group);
  Future<void> removeFromGroup(List<String> urls, String group);
  List<String> get allGroups;
  List<BookSource> getSourcesByGroup(String group);

  // ========== 排序 ==========
  Future<void> setSortBy(int sortBy);
  Future<void> toggleSortDirection();
  List<BookSource> getSortedSources();

  // ========== 导入导出 ==========
  Future<String> exportSources({List<String>? urls});
  Future<ImportResult> importSources(String jsonStr, {bool merge = true});

  // ========== 源校验 ==========
  Future<void> testSource(String bookSourceUrl);
  Future<void> testAllSources({CheckSourceConfig? config});
  Future<void> testSources(List<String> urls, {CheckSourceConfig? config});

  // ========== 订阅管理 ==========
  Future<void> addSubscription(SourceSubscription sub);
  Future<void> removeSubscription(int index);
  Future<void> syncSubscription(String url);
  Future<void> syncAllSubscriptions();

  // ========== 查询 ==========
  List<BookSourcePart> searchSources(String keyword);
  List<BookSourcePart> getEnabledSources();
  List<BookSourcePart> getExploreSources();
  List<BookSourcePart> getLoginSources();
  List<BookSourcePart> getNoGroupSources();
}
```

---

## 四、页面重构

### 4.1 页面结构

```
lib/pages/sources/
├── sources_page.dart              # 主页面（列表/搜索/筛选/批量操作）
├── source_edit_page.dart          # 编辑页面（多Tab规则编辑）
├── source_check_page.dart         # 源校验页面（新增）
├── widgets/
│   ├── source_tile.dart           # 列表项组件
│   ├── source_filter_bar.dart     # 筛选栏组件
│   ├── source_batch_bar.dart      # 批量操作栏（新增）
│   ├── source_sort_menu.dart      # 排序菜单
│   └── subscription_dialog.dart   # 订阅管理对话框
```

### 4.2 SourcesPage 主页面

**功能清单：**

| 功能 | 状态 | 说明 |
|-----|------|------|
| 源列表展示 | ✅ 现有 | 使用 BookSourcePart 轻量视图 |
| 搜索 | ✅ 现有 | 按名称/URL/分组/注释搜索 |
| 状态筛选 | ✅ 现有 | 全部/活跃/禁用/错误 |
| 分组筛选 | ✅ 现有 | 下拉选择分组 |
| 排序 | ✅ 现有 | 7种排序方式 |
| 添加源 | ✅ 现有 | 对话框形式 |
| 编辑源 | ✅ 现有 | 跳转编辑页 |
| 删除源 | ✅ 现有 | 单个删除 |
| 测试源 | ✅ 现有 | 单个/全部测试 |
| 导入导出 | ✅ 现有 | JSON文件 |
| 订阅管理 | ✅ 现有 | 远程订阅同步 |
| **多选模式** | 🆕 新增 | 长按进入多选 |
| **全选/反选** | 🆕 新增 | 多选模式下可用 |
| **批量删除** | 🆕 新增 | 删除选中源 |
| **批量启用/禁用** | 🆕 新增 | 启用/禁用选中源 |
| **批量启用/禁用发现** | 🆕 新增 | 启用/禁用选中源的发现 |
| **置顶/置底** | 🆕 新增 | 调整选中源顺序 |
| **批量导出** | 🆕 新增 | 导出选中源 |
| **拖拽排序** | 🆕 新增 | 手动排序模式下可用 |
| **域名分组排序** | 🆕 新增 | 按域名分组显示 |

### 4.3 SourceEditPage 编辑页面

**Tab 结构：**

| Tab | 内容 | 状态 |
|-----|------|------|
| 基础信息 | URL、名称、分组、类型、启用状态、权重 | ✅ 现有 |
| 网络配置 | 请求头、并发率、Cookie、JS库 | 🆕 新增 |
| 登录配置 | 登录地址、登录UI、登录检测JS | 🆕 新增 |
| 搜索规则 | checkKeyWord、searchUrl、bookList、各字段规则 | ✅ 现有（需调整） |
| 发现规则 | exploreUrl、bookList、各字段规则 | 🆕 新增 |
| 详情规则 | init、name、author、intro、tocUrl 等 | ✅ 现有（需调整） |
| 目录规则 | chapterList、chapterName、chapterUrl、分页 | 🆕 新增 |
| 正文规则 | content、title、replaceRegex、图片样式 | 🆕 新增 |
| 其他配置 | 注释、变量说明、NSFW、解析地址 | ✅ 现有 |

### 4.4 SourceCheckPage 源校验页面（新增）

**功能：**
- 校验配置：关键字、超时时间、校验范围
- 校验进度：实时显示校验状态
- 校验结果：成功/失败/超时，自动标记失效分组
- 并发控制：可配置并发数

---

## 五、解析器重构

### 5.1 SourceParser 调整

```dart
// lib/utils/source_parser.dart
class SourceParser {
  final BookSource source;

  SourceParser(this.source);

  // ========== 列表解析 ==========
  /// 解析搜索结果列表
  List<ParsedBookItem> parseSearchList(String content, String baseUrl) {
    final rule = source.ruleSearch;
    if (rule?.bookList == null) return [];
    return _parseBookList(content, baseUrl, rule!.bookList!, rule);
  }

  /// 解析发现列表
  List<ParsedBookItem> parseExploreList(String content, String baseUrl) {
    final rule = source.ruleExplore;
    if (rule?.bookList == null) return [];
    return _parseBookList(content, baseUrl, rule!.bookList!, rule);
  }

  /// 通用列表解析
  List<ParsedBookItem> _parseBookList(
    String content,
    String baseUrl,
    String listRule,
    dynamic rule, // SearchRule 或 ExploreRule
  ) {
    final analyzer = LegadoAnalyzer();
    analyzer.setContent(content, baseUrl);

    final elements = analyzer.getElements(listRule);
    return elements.map((element) {
      final itemAnalyzer = LegadoAnalyzer();
      itemAnalyzer.setContent(element, baseUrl);

      return ParsedBookItem(
        name: _extractText(itemAnalyzer, rule.name),
        author: _extractText(itemAnalyzer, rule.author),
        intro: _extractText(itemAnalyzer, rule.intro),
        kind: _extractText(itemAnalyzer, rule.kind),
        lastChapter: _extractText(itemAnalyzer, rule.lastChapter),
        updateTime: _extractText(itemAnalyzer, rule.updateTime),
        bookUrl: _extractText(itemAnalyzer, rule.bookUrl),
        coverUrl: _extractText(itemAnalyzer, rule.coverUrl),
        wordCount: _extractText(itemAnalyzer, rule.wordCount),
      );
    }).toList();
  }

  // ========== 详情解析 ==========
  ParsedBookInfo parseBookInfo(String content, String baseUrl) {
    final rule = source.ruleBookInfo;
    final analyzer = LegadoAnalyzer();
    analyzer.setContent(content, baseUrl);

    return ParsedBookInfo(
      name: _extractText(analyzer, rule?.name),
      author: _extractText(analyzer, rule?.author),
      intro: _extractText(analyzer, rule?.intro),
      kind: _extractText(analyzer, rule?.kind),
      lastChapter: _extractText(analyzer, rule?.lastChapter),
      updateTime: _extractText(analyzer, rule?.updateTime),
      coverUrl: _extractText(analyzer, rule?.coverUrl),
      tocUrl: _extractText(analyzer, rule?.tocUrl),
      wordCount: _extractText(analyzer, rule?.wordCount),
    );
  }

  // ========== 目录解析 ==========
  List<ParsedChapter> parseToc(String content, String baseUrl) {
    final rule = source.ruleToc;
    if (rule?.chapterList == null) return [];

    final analyzer = LegadoAnalyzer();
    analyzer.setContent(content, baseUrl);

    final elements = analyzer.getElements(rule!.chapterList!);
    return elements.map((element) {
      final itemAnalyzer = LegadoAnalyzer();
      itemAnalyzer.setContent(element, baseUrl);

      return ParsedChapter(
        name: _extractText(itemAnalyzer, rule.chapterName),
        url: _extractText(itemAnalyzer, rule.chapterUrl),
        isVolume: _extractText(itemAnalyzer, rule.isVolume) == 'true',
        isVip: _extractText(itemAnalyzer, rule.isVip) == 'true',
        isPay: _extractText(itemAnalyzer, rule.isPay) == 'true',
        updateTime: _extractText(itemAnalyzer, rule.updateTime),
      );
    }).toList();
  }

  // ========== 正文解析 ==========
  ParsedContent parseContent(String content, String baseUrl) {
    final rule = source.ruleContent;
    final analyzer = LegadoAnalyzer();
    analyzer.setContent(content, baseUrl);

    return ParsedContent(
      title: _extractText(analyzer, rule?.title),
      content: _extractText(analyzer, rule?.content),
      nextContentUrl: _extractText(analyzer, rule?.nextContentUrl),
    );
  }

  // ========== 搜索URL构建 ==========
  String getSearchUrl(String keyword, {int page = 1}) {
    String url = source.searchUrl ?? '';
    url = url.replaceAll('{{key}}', Uri.encodeComponent(keyword));
    url = url.replaceAll('{{page}}', page.toString());
    return url;
  }

  // ========== 文本提取 ==========
  String? _extractText(LegadoAnalyzer analyzer, String? rule) {
    if (rule == null || rule.isEmpty) return null;

    // 处理 @ 语法
    if (rule.contains('@')) {
      final parts = rule.split('@');
      final selector = parts[0];
      final attr = parts[1];

      if (attr == 'text') {
        return analyzer.getString(selector);
      } else {
        return analyzer.getElement(selector)?.attr(attr);
      }
    }

    return analyzer.getString(rule);
  }
}
```

### 5.2 数据类定义

```dart
// lib/utils/source_parser.dart

class ParsedBookItem {
  final String? name;
  final String? author;
  final String? intro;
  final String? kind;
  final String? lastChapter;
  final String? updateTime;
  final String? bookUrl;
  final String? coverUrl;
  final String? wordCount;

  const ParsedBookItem({...});
}

class ParsedBookInfo {
  final String? name;
  final String? author;
  final String? intro;
  final String? kind;
  final String? lastChapter;
  final String? updateTime;
  final String? coverUrl;
  final String? tocUrl;
  final String? wordCount;

  const ParsedBookInfo({...});
}

class ParsedChapter {
  final String? name;
  final String? url;
  final bool isVolume;
  final bool isVip;
  final bool isPay;
  final String? updateTime;

  const ParsedChapter({...});
}

class ParsedContent {
  final String? title;
  final String? content;
  final String? nextContentUrl;

  const ParsedContent({...});
}
```

---

## 六、导入导出重构

### 6.1 导入逻辑

```dart
// lib/store/use_source_store.dart 中的导入方法

Future<ImportResult> importSources(String input, {bool merge = true}) async {
  String jsonStr = input;

  // 1. 如果是URL，先下载
  if (input.startsWith('http://') || input.startsWith('https://')) {
    final response = await http.get(Uri.parse(input));
    jsonStr = response.body;
  }

  // 2. 解析JSON
  final dynamic jsonData = jsonDecode(jsonStr);

  List<BookSource> sources = [];

  if (jsonData is List) {
    // JSON数组：多个源
    sources = jsonData.map((e) => BookSource.fromJson(e)).toList();
  } else if (jsonData is Map<String, dynamic>) {
    if (jsonData.containsKey('bookSourceUrl')) {
      // 单个源对象
      sources = [BookSource.fromJson(jsonData)];
    } else if (jsonData.containsKey('sourceUrls')) {
      // 包含URL列表，逐个下载
      final urls = List<String>.from(jsonData['sourceUrls']);
      for (final url in urls) {
        try {
          final result = await importSources(url, merge: merge);
          sources.addAll(result.sources);
        } catch (e) {
          // 记录错误但继续处理
        }
      }
    }
  }

  // 3. 合并或替换
  if (merge) {
    // 按 bookSourceUrl 去重合并
    final existingUrls = state.sources.map((s) => s.bookSourceUrl).toSet();
    final newSources = sources.where((s) => !existingUrls.contains(s.bookSourceUrl)).toList();
    final updatedSources = sources.where((s) => existingUrls.contains(s.bookSourceUrl)).toList();

    // 更新已存在的源
    for (final source in updatedSources) {
      final index = state.sources.indexWhere((s) => s.bookSourceUrl == source.bookSourceUrl);
      if (index != -1) {
        state.sources[index] = source;
      }
    }

    // 添加新源
    state.sources.addAll(newSources);
  } else {
    // 替换模式
    state.sources = sources;
  }

  // 4. 调整排序编号
  _adjustSortNumbers();

  // 5. 更新分组列表
  _updateGroups();

  await save();

  return ImportResult(
    sources: sources,
    newCount: merge ? sources.length - _getUpdatedCount(sources) : sources.length,
    updatedCount: merge ? _getUpdatedCount(sources) : 0,
  );
}
```

### 6.2 导出逻辑

```dart
Future<String> exportSources({List<String>? urls}) async {
  List<BookSource> sourcesToExport;

  if (urls != null && urls.isNotEmpty) {
    // 导出指定源
    sourcesToExport = state.sources
        .where((s) => urls.contains(s.bookSourceUrl))
        .toList();
  } else {
    // 导出全部
    sourcesToExport = List.from(state.sources);
  }

  // 安全考虑：清除高危API标记
  sourcesToExport = sourcesToExport.map((s) =>
    s.copyWith(enableDangerousApi: false)
  ).toList();

  // 序列化为JSON
  final jsonStr = jsonEncode(sourcesToExport.map((s) => s.toJson()).toList());

  // 保存到文件
  final directory = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${directory.path}/bookSource_$timestamp.json');
  await file.writeAsString(jsonStr);

  return file.path;
}
```

---

## 七、源校验重构

### 7.1 校验配置

```dart
// lib/models/check_source_config.dart
@freezed
class CheckSourceConfig with _$CheckSourceConfig {
  const factory CheckSourceConfig({
    @Default('我的') String keyword,        // 校验关键字
    @Default(180000) int timeout,           // 超时时间
    @Default(true) bool checkSearch,        // 校验搜索
    @Default(true) bool checkDiscovery,     // 校验发现
    @Default(true) bool checkInfo,          // 校验详情页
    @Default(true) bool checkCategory,      // 校验目录
    @Default(true) bool checkContent,       // 校验正文
    @Default(5) int threadCount,            // 并发数
  }) = _CheckSourceConfig;
}
```

### 7.2 校验流程

```dart
// lib/utils/source_checker.dart
class SourceChecker {
  final SourceStore store;
  final CheckSourceConfig config;

  SourceChecker(this.store, {CheckSourceConfig? config})
      : config = config ?? const CheckSourceConfig();

  Future<CheckResult> checkSource(BookSource source) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 1. 移除失效分组
      _removeInvalidGroups(source);

      // 2. 校验搜索
      if (config.checkSearch && source.searchUrl?.isNotEmpty == true) {
        await _checkSearch(source);
      }

      // 3. 校验发现
      if (config.checkDiscovery && source.exploreUrl?.isNotEmpty == true) {
        await _checkDiscovery(source);
      }

      stopwatch.stop();

      // 4. 更新响应时间
      source = source.copyWith(respondTime: stopwatch.elapsedMilliseconds);

      return CheckResult.success(source);
    } on TimeoutException {
      source = source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '校验超时'),
      );
      return CheckResult.timeout(source);
    } catch (e) {
      source = source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '网站失效'),
      );
      return CheckResult.error(source, e.toString());
    }
  }

  Future<void> _checkSearch(BookSource source) async {
    final keyword = source.ruleSearch?.checkKeyWord ?? config.keyword;
    final parser = SourceParser(source);
    final searchUrl = parser.getSearchUrl(keyword);

    // 发起搜索请求
    final response = await _fetchWithTimeout(searchUrl, source);

    // 解析搜索结果
    final results = parser.parseSearchList(response.body, searchUrl);

    if (results.isEmpty) {
      source = source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '搜索失效'),
      );
    } else {
      // 移除搜索失效标记
      source = source.copyWith(
        bookSourceGroup: _removeGroup(source.bookSourceGroup, '搜索失效'),
      );

      // 校验详情/目录/正文
      if (config.checkInfo || config.checkCategory || config.checkContent) {
        await _checkBook(source, results.first, isSearch: true);
      }
    }
  }

  Future<void> _checkDiscovery(BookSource source) async {
    // 获取第一个发现分类URL
    final exploreUrl = source.exploreUrl;
    if (exploreUrl == null || exploreUrl.isEmpty) {
      source = source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '发现规则为空'),
      );
      return;
    }

    // 发起发现请求
    final response = await _fetchWithTimeout(exploreUrl, source);

    // 解析发现结果
    final parser = SourceParser(source);
    final results = parser.parseExploreList(response.body, exploreUrl);

    if (results.isEmpty) {
      source = source.copyWith(
        bookSourceGroup: _addGroup(source.bookSourceGroup, '发现失效'),
      );
    } else {
      // 移除发现失效标记
      source = source.copyWith(
        bookSourceGroup: _removeGroup(source.bookSourceGroup, '发现失效'),
      );

      // 校验详情/目录/正文
      if (config.checkInfo || config.checkCategory || config.checkContent) {
        await _checkBook(source, results.first, isSearch: false);
      }
    }
  }

  Future<void> _checkBook(
    BookSource source,
    ParsedBookItem book, {
    required bool isSearch,
  }) async {
    final prefix = isSearch ? '搜索' : '发现';

    // 校验详情
    if (config.checkInfo && book.bookUrl != null) {
      // 详情校验逻辑...
    }

    // 校验目录
    if (config.checkCategory) {
      // 目录校验逻辑...
    }

    // 校验正文
    if (config.checkContent) {
      // 正文校验逻辑...
    }
  }
}
```

---

## 八、批量操作实现

### 8.1 多选状态管理

```dart
// lib/pages/sources/sources_page.dart

class SourcesPage extends HookWidget {
  // 多选状态
  final selectedUrls = useState<Set<String>>({});
  final isMultiSelectMode = useState(false);

  // 进入多选模式
  void enterMultiSelectMode(String url) {
    isMultiSelectMode.value = true;
    selectedUrls.value = {url};
  }

  // 退出多选模式
  void exitMultiSelectMode() {
    isMultiSelectMode.value = false;
    selectedUrls.value = {};
  }

  // 切换选中状态
  void toggleSelection(String url) {
    final newSet = Set<String>.from(selectedUrls.value);
    if (newSet.contains(url)) {
      newSet.remove(url);
      if (newSet.isEmpty) {
        exitMultiSelectMode();
        return;
      }
    } else {
      newSet.add(url);
    }
    selectedUrls.value = newSet;
  }

  // 全选
  void selectAll(List<BookSourcePart> sources) {
    selectedUrls.value = sources.map((s) => s.bookSourceUrl).toSet();
  }

  // 反选
  void revertSelection(List<BookSourcePart> sources) {
    final allUrls = sources.map((s) => s.bookSourceUrl).toSet();
    selectedUrls.value = allUrls.difference(selectedUrls.value);
  }
}
```

### 8.2 批量操作栏

```dart
// lib/pages/sources/widgets/source_batch_bar.dart

class SourceBatchBar extends StatelessWidget {
  final Set<String> selectedUrls;
  final VoidCallback onDelete;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onEnableExplore;
  final VoidCallback onDisableExplore;
  final VoidCallback onTop;
  final VoidCallback onBottom;
  final VoidCallback onExport;
  final VoidCallback onSelectAll;
  final VoidCallback onRevertSelection;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        children: [
          // 选中数量
          Text('${selectedUrls.length} 已选'),

          // 全选/反选
          IconButton(icon: Icon(Icons.select_all), onPressed: onSelectAll),
          IconButton(icon: Icon(Icons.flip), onPressed: onRevertSelection),

          // 批量操作
          IconButton(icon: Icon(Icons.delete), onPressed: onDelete),
          IconButton(icon: Icon(Icons.check_circle), onPressed: onEnable),
          IconButton(icon: Icon(Icons.block), onPressed: onDisable),
          IconButton(icon: Icon(Icons.explore), onPressed: onEnableExplore),
          IconButton(icon: Icon(Icons.explore_off), onPressed: onDisableExplore),
          IconButton(icon: Icon(Icons.vertical_align_top), onPressed: onTop),
          IconButton(icon: Icon(Icons.vertical_align_bottom), onPressed: onBottom),
          IconButton(icon: Icon(Icons.save), onPressed: onExport),
        ],
      ),
    );
  }
}
```

---

## 九、排序重构

### 9.1 排序枚举

```dart
// lib/models/book_source_sort.dart
enum BookSourceSort {
  custom,    // 手动排序
  name,      // 按名称
  url,       // 按URL
  weight,    // 按权重
  update,    // 按更新时间
  enable,    // 按启用状态
  respond,   // 按响应时间
}
```

### 9.2 排序实现

```dart
// lib/store/use_source_store.dart

List<BookSourcePart> getSortedSources() {
  final sources = _getFilteredSources();

  switch (state.sortBy) {
    case BookSourceSort.custom:
      sources.sort((a, b) => a.customOrder.compareTo(b.customOrder));
    case BookSourceSort.name:
      sources.sort((a, b) => _cnCompare(a.bookSourceName, b.bookSourceName));
    case BookSourceSort.url:
      sources.sort((a, b) => a.bookSourceUrl.compareTo(b.bookSourceUrl));
    case BookSourceSort.weight:
      sources.sort((a, b) => b.weight.compareTo(a.weight));
    case BookSourceSort.update:
      sources.sort((a, b) => b.lastUpdateTime.compareTo(a.lastUpdateTime));
    case BookSourceSort.enable:
      sources.sort((a, b) {
        if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
        return _cnCompare(a.bookSourceName, b.bookSourceName);
      });
    case BookSourceSort.respond:
      sources.sort((a, b) => a.respondTime.compareTo(b.respondTime));
  }

  if (!state.sortAscending) {
    return sources.reversed.toList();
  }

  return sources;
}
```

### 9.3 拖拽排序

```dart
// lib/pages/sources/sources_page.dart

ReorderableListView.builder(
  onReorder: (oldIndex, newIndex) {
    final sources = getSortedSources();
    final source = sources[oldIndex];

    // 更新 customOrder
    final newOrder = newIndex > oldIndex ? newIndex - 1 : newIndex;
    store.updateSource(source.copyWith(customOrder: newOrder));

    // 重新调整所有排序编号
    store.adjustSortNumbers();
  },
  itemCount: sources.length,
  itemBuilder: (context, index) {
    return SourceTile(
      key: ValueKey(sources[index].bookSourceUrl),
      source: sources[index],
    );
  },
)
```

---

## 十、国际化新增键

```json
// lib/l10n/app_zh.arb 新增
{
  "checkSource": "校验书源",
  "checkAllSources": "校验全部",
  "checkConfig": "校验配置",
  "checkKeyword": "校验关键字",
  "checkTimeout": "超时时间",
  "checkSearch": "校验搜索",
  "checkDiscovery": "校验发现",
  "checkInfo": "校验详情",
  "checkCategory": "校验目录",
  "checkContent": "校验正文",
  "threadCount": "并发数",
  "multiSelect": "多选",
  "selectAll": "全选",
  "revertSelection": "反选",
  "batchDelete": "批量删除",
  "batchEnable": "批量启用",
  "batchDisable": "批量禁用",
  "batchEnableExplore": "批量启用发现",
  "batchDisableExplore": "批量禁用发现",
  "topSource": "置顶",
  "bottomSource": "置底",
  "exportSelected": "导出选中",
  "sortByCustom": "手动排序",
  "sortByEnable": "按启用状态",
  "bookSourceType": "源类型",
  "loginConfig": "登录配置",
  "networkConfig": "网络配置",
  "exploreRule": "发现规则",
  "tocRule": "目录规则",
  "contentRule": "正文规则",
  "reviewRule": "段评规则"
}
```

---

## 十一、UI 设计规范

### 11.1 SourcesPage 主页面布局

```
┌─────────────────────────────────────────────────────────────────┐
│  AppBar                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  [←] 源管理 (128)  [🔍] [▼排序] [⋮更多]                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  FilterBar（筛选栏）                                       │  │
│  │  [全部] [活跃] [禁用] [错误] | [分组▼] | [类型▼]          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  SourceList（源列表）                                      │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │ [✓] 📺 示例源名称                    [活跃] [3ms]  │  │  │
│  │  │     https://example.com              分组1,分组2   │  │  │
│  │  │                                  [⋮] [□选择]      │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │ [ ] 📺 另一个源                      [禁用] [--]   │  │  │
│  │  │     https://example2.com             视频          │  │  │
│  │  │                                  [⋮] [□选择]      │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │  ...                                                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  BatchBar（批量操作栏）— 多选模式时显示                    │  │
│  │  [全选] [反选] [删除] [启用] [禁用] [置顶] [置底] [导出]  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  FAB（浮动按钮）— 非多选模式时显示                              │
│                                    [＋添加源]                    │
└─────────────────────────────────────────────────────────────────┘
```

### 11.2 SourceEditPage 编辑页面布局

```
┌─────────────────────────────────────────────────────────────────┐
│  AppBar                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  [←] 编辑源                                    [保存]    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  TabBar                                                      │  │
│  │  [基础] [网络] [登录] [搜索] [发现] [详情] [目录] [正文] [其他]│  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  TabBarView（内容区）                                      │  │
│  │                                                             │  │
│  │  // Tab 1: 基础信息                                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  源地址 *  [____________________________]           │  │  │
│  │  │  源名称 *  [____________________________]           │  │  │
│  │  │  源类型    [文本 ▼]                                 │  │  │
│  │  │  分组      [____________________________] (逗号分隔) │  │  │
│  │  │  权重      [0] (0-1000)                             │  │  │
│  │  │  启用      [✓]    启用发现    [✓]                  │  │  │
│  │  │  NSFW      [ ]    手动排序    [0]                   │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  │  // Tab 2: 网络配置                                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  请求头      [____________________________] [?]     │  │  │
│  │  │  并发率      [____________________________] [?]     │  │  │
│  │  │  启用Cookie  [✓]                                    │  │  │
│  │  │  高危API     [ ]                                    │  │  │
│  │  │  JS库        [                            ] [导入]  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  │  // Tab 3: 登录配置                                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  登录地址    [____________________________]         │  │  │
│  │  │  登录UI      [                            ] [?]    │  │  │
│  │  │  登录检测JS  [                            ] [?]    │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  │  // Tab 4: 搜索规则                                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  搜索URL      [____________________________] [?]   │  │  │
│  │  │  校验关键字    [____________________________]       │  │  │
│  │  │  ──────────── 列表规则 ────────────                │  │  │
│  │  │  列表规则      [____________________________]       │  │  │
│  │  │  书名规则      [____________________________]       │  │  │
│  │  │  作者规则      [____________________________]       │  │  │
│  │  │  封面规则      [____________________________]       │  │  │
│  │  │  链接规则      [____________________________]       │  │  │
│  │  │  简介规则      [____________________________]       │  │  │
│  │  │  分类规则      [____________________________]       │  │  │
│  │  │  最新章节      [____________________________]       │  │  │
│  │  │  更新时间      [____________________________]       │  │  │
│  │  │  字数规则      [____________________________]       │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  │  // Tab 5: 发现规则                                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  发现URL      [____________________________]       │  │  │
│  │  │  发现样式      [0 ▼] (0/1/2)                       │  │  │
│  │  │  发现筛选      [                            ] [?]  │  │  │
│  │  │  ──────────── 列表规则 ────────────                │  │  │
│  │  │  (同搜索规则字段)                                   │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  │  // Tab 6: 详情规则                                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  初始化JS     [                            ] [?]   │  │  │
│  │  │  书名规则      [____________________________]       │  │  │
│  │  │  作者规则      [____________________________]       │  │  │
│  │  │  封面规则      [____________________________]       │  │  │
│  │  │  简介规则      [____________________________]       │  │  │
│  │  │  分类规则      [____________________________]       │  │  │
│  │  │  最新章节      [____________________________]       │  │  │
│  │  │  更新时间      [____________________________]       │  │  │
│  │  │  目录URL规则   [____________________________]       │  │  │
│  │  │  字数规则      [____________________________]       │  │  │
│  │  │  允许重命名    [____________________________]       │  │  │
│  │  │  下载地址      [____________________________]       │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  │  // Tab 7: 目录规则                                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  预更新JS     [                            ] [?]   │  │  │
│  │  │  格式化JS     [                            ] [?]   │  │  │
│  │  │  ──────────── 章节规则 ────────────                │  │  │
│  │  │  章节列表      [____________________________]       │  │  │
│  │  │  章节名称      [____________________________]       │  │  │
│  │  │  章节URL       [____________________________]       │  │  │
│  │  │  是否为卷      [____________________________]       │  │  │
│  │  │  是否VIP       [____________________________]       │  │  │
│  │  │  是否付费      [____________________________]       │  │  │
│  │  │  更新时间      [____________________________]       │  │  │
│  │  │  下一页URL     [____________________________]       │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  │  // Tab 8: 正文规则                                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  正文内容      [____________________________]       │  │  │
│  │  │  标题规则      [____________________________]       │  │  │
│  │  │  下一页URL     [____________________________]       │  │  │
│  │  │  WebView JS   [                            ] [?]   │  │  │
│  │  │  源正则        [____________________________]       │  │  │
│  │  │  替换规则      [                            ] [?]   │  │  │
│  │  │  图片样式      [____________________________]       │  │  │
│  │  │  图片解密JS    [                            ] [?]   │  │  │
│  │  │  购买操作      [                            ] [?]   │  │  │
│  │  │  LRC歌词规则   [____________________________]       │  │  │
│  │  │  音乐封面      [____________________________]       │  │  │
│  │  │  拦截跳转      [____________________________]       │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  │  // Tab 9: 其他配置                                        │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  注释          [                            ]       │  │  │
│  │  │  变量说明      [                            ]       │  │  │
│  │  │  封面解密JS    [                            ] [?]   │  │  │
│  │  │  ──────────── IRIS 扩展 ────────────                │  │  │
│  │  │  解析地址      [____________________________]       │  │  │
│  │  │  ──────────── 只读信息 ────────────                │  │  │
│  │  │  最后更新      2026-06-16 12:00:00                  │  │  │
│  │  │  响应时间      125ms                                │  │  │
│  │  │  详情页正则    [____________________________]       │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 11.3 SourceCheckPage 源校验页面布局

```
┌─────────────────────────────────────────────────────────────────┐
│  AppBar                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  [←] 源校验                                    [开始]    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  校验配置                                                    │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  校验关键字    [我的________________]                │  │  │
│  │  │  超时时间      [180000] ms                          │  │  │
│  │  │  并发数        [5]                                  │  │  │
│  │  │  ──────────── 校验范围 ────────────                │  │  │
│  │  │  [✓] 校验搜索    [✓] 校验发现                      │  │  │
│  │  │  [✓] 校验详情    [✓] 校验目录                      │  │  │
│  │  │  [✓] 校验正文                                      │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  校验进度                                                    │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  ████████████░░░░░░░░░░  60%  30/50               │  │  │
│  │  │  当前: 示例源                                        │  │  │
│  │  │  已用时: 00:32                                       │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  校验结果                                                    │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  ✅ 示例源 (125ms)                                  │  │  │
│  │  │  ❌ 失效源 - 搜索失效                               │  │  │
│  │  │  ⏱️ 超时源 - 校验超时                               │  │  │
│  │  │  ❌ 错误源 - js失效                                 │  │  │
│  │  │  ...                                                │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  │  统计: 成功 30 | 失败 15 | 超时 5                          │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 11.4 组件设计规范

#### SourceTile 列表项组件

```dart
// lib/pages/sources/widgets/source_tile.dart
class SourceTile extends StatelessWidget {
  final BookSourcePart source;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool?> onSelectionChanged;
  final VoidCallback onEdit;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // 多选模式显示复选框
              if (isMultiSelectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: onSelectionChanged,
                ),

              // 源类型图标
              _buildTypeIcon(source.bookSourceType),

              SizedBox(width: 12),

              // 主要信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：名称 + 状态标签
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            source.bookSourceName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: source.enabled ? null : Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusChip(source),
                      ],
                    ),

                    SizedBox(height: 4),

                    // 第二行：URL
                    Text(
                      source.bookSourceUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 4),

                    // 第三行：分组 + 响应时间
                    Row(
                      children: [
                        // 分组标签
                        if (source.bookSourceGroup != null)
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              children: _buildGroupChips(source.bookSourceGroup),
                            ),
                          ),

                        // 响应时间
                        Text(
                          _formatRespondTime(source.respondTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 操作菜单
              if (!isMultiSelectMode)
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'test', child: Text('测试')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit': onEdit(); break;
                      case 'test': onTest(); break;
                      case 'delete': onDelete(); break;
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BookSourcePart source) {
    Color color;
    String text;

    if (!source.enabled) {
      color = Colors.grey;
      text = '禁用';
    } else if (source.respondTime >= 180000) {
      color = Colors.red;
      text = '超时';
    } else {
      color = Colors.green;
      text = '活跃';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  Widget _buildTypeIcon(int type) {
    IconData icon;
    Color color;

    switch (type) {
      case BookSourceType.video:
        icon = Icons.videocam;
        color = Colors.blue;
        break;
      case BookSourceType.audio:
        icon = Icons.music_note;
        color = Colors.purple;
        break;
      case BookSourceType.image:
        icon = Icons.image;
        color = Colors.orange;
        break;
      case BookSourceType.file:
        icon = Icons.file_download;
        color = Colors.brown;
        break;
      case BookSourceType.rss:
        icon = Icons.rss_feed;
        color = Colors.teal;
        break;
      default:
        icon = Icons.book;
        color = Colors.green;
    }

    return Icon(icon, color: color, size: 28);
  }
}
```

#### SourceFilterBar 筛选栏组件

```dart
// lib/pages/sources/widgets/source_filter_bar.dart
class SourceFilterBar extends StatelessWidget {
  final int currentFilter; // 0全部 1活跃 2禁用 3错误
  final String? currentGroup;
  final int? currentType;
  final List<String> groups;
  final ValueChanged<int> onFilterChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<int?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // 状态筛选
          _buildFilterChip('全部', currentFilter == 0, () => onFilterChanged(0)),
          _buildFilterChip('活跃', currentFilter == 1, () => onFilterChanged(1)),
          _buildFilterChip('禁用', currentFilter == 2, () => onFilterChanged(2)),
          _buildFilterChip('错误', currentFilter == 3, () => onFilterChanged(3)),

          VerticalDivider(width: 16),

          // 分组筛选
          _buildGroupDropdown(),

          SizedBox(width: 8),

          // 类型筛选
          _buildTypeDropdown(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      ),
    );
  }

  Widget _buildGroupDropdown() {
    return DropdownButton<String>(
      value: currentGroup,
      hint: Text('分组'),
      items: [
        DropdownMenuItem(value: null, child: Text('全部分组')),
        ...groups.map((g) => DropdownMenuItem(value: g, child: Text(g))),
      ],
      onChanged: onGroupChanged,
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButton<int>(
      value: currentType,
      hint: Text('类型'),
      items: [
        DropdownMenuItem(value: null, child: Text('全部类型')),
        DropdownMenuItem(value: 0, child: Text('文本')),
        DropdownMenuItem(value: 1, child: Text('音频')),
        DropdownMenuItem(value: 2, child: Text('图片')),
        DropdownMenuItem(value: 3, child: Text('文件')),
        DropdownMenuItem(value: 4, child: Text('视频')),
        DropdownMenuItem(value: 5, child: Text('RSS')),
      ],
      onChanged: onTypeChanged,
    );
  }
}
```

#### SourceBatchBar 批量操作栏组件

```dart
// lib/pages/sources/widgets/source_batch_bar.dart
class SourceBatchBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onRevertSelection;
  final VoidCallback onDelete;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onEnableExplore;
  final VoidCallback onDisableExplore;
  final VoidCallback onTop;
  final VoidCallback onBottom;
  final VoidCallback onExport;
  final VoidCallback onAddToGroup;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Container(
        height: 64,
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // 选中数量
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$selectedCount 已选',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '共 $totalCount 个源',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            VerticalDivider(width: 16),

            // 全选/反选
            IconButton(
              icon: Icon(Icons.select_all),
              tooltip: '全选',
              onPressed: onSelectAll,
            ),
            IconButton(
              icon: Icon(Icons.flip),
              tooltip: '反选',
              onPressed: onRevertSelection,
            ),

            VerticalDivider(width: 16),

            // 批量操作（可滚动）
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildActionButton(
                    icon: Icons.check_circle,
                    label: '启用',
                    color: Colors.green,
                    onPressed: onEnable,
                  ),
                  _buildActionButton(
                    icon: Icons.block,
                    label: '禁用',
                    color: Colors.orange,
                    onPressed: onDisable,
                  ),
                  _buildActionButton(
                    icon: Icons.explore,
                    label: '启用发现',
                    color: Colors.blue,
                    onPressed: onEnableExplore,
                  ),
                  _buildActionButton(
                    icon: Icons.explore_off,
                    label: '禁用发现',
                    color: Colors.grey,
                    onPressed: onDisableExplore,
                  ),
                  _buildActionButton(
                    icon: Icons.vertical_align_top,
                    label: '置顶',
                    onPressed: onTop,
                  ),
                  _buildActionButton(
                    icon: Icons.vertical_align_bottom,
                    label: '置底',
                    onPressed: onBottom,
                  ),
                  _buildActionButton(
                    icon: Icons.folder,
                    label: '分组',
                    onPressed: onAddToGroup,
                  ),
                  _buildActionButton(
                    icon: Icons.save,
                    label: '导出',
                    onPressed: onExport,
                  ),
                  _buildActionButton(
                    icon: Icons.delete,
                    label: '删除',
                    color: Colors.red,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(icon, color: color),
            iconSize: 20,
            onPressed: onPressed,
            constraints: BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
```

#### SourceSortMenu 排序菜单组件

```dart
// lib/pages/sources/widgets/source_sort_menu.dart
class SourceSortMenu extends StatelessWidget {
  final BookSourceSort currentSort;
  final bool sortAscending;
  final ValueChanged<BookSourceSort> onSortChanged;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BookSourceSort>(
      icon: Icon(Icons.sort),
      tooltip: '排序',
      itemBuilder: (context) => [
        PopupMenuItem(
          value: BookSourceSort.custom,
          child: _buildSortItem('手动排序', Icons.drag_handle, BookSourceSort.custom),
        ),
        PopupMenuItem(
          value: BookSourceSort.name,
          child: _buildSortItem('按名称', Icons.sort_by_alpha, BookSourceSort.name),
        ),
        PopupMenuItem(
          value: BookSourceSort.url,
          child: _buildSortItem('按URL', Icons.link, BookSourceSort.url),
        ),
        PopupMenuItem(
          value: BookSourceSort.weight,
          child: _buildSortItem('按权重', Icons.fitness_center, BookSourceSort.weight),
        ),
        PopupMenuItem(
          value: BookSourceSort.update,
          child: _buildSortItem('按更新时间', Icons.update, BookSourceSort.update),
        ),
        PopupMenuItem(
          value: BookSourceSort.enable,
          child: _buildSortItem('按启用状态', Icons.toggle_on, BookSourceSort.enable),
        ),
        PopupMenuItem(
          value: BookSourceSort.respond,
          child: _buildSortItem('按响应时间', Icons.speed, BookSourceSort.respond),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            title: Text(sortAscending ? '升序' : '降序'),
            onTap: () {
              Navigator.pop(context);
              onToggleDirection();
            },
          ),
        ),
      ],
      onSelected: onSortChanged,
    );
  }

  Widget _buildSortItem(String label, IconData icon, BookSourceSort sort) {
    return Row(
      children: [
        Icon(icon, size: 20),
        SizedBox(width: 12),
        Text(label),
        if (currentSort == sort) ...[
          Spacer(),
          Icon(Icons.check, size: 20, color: Colors.blue),
        ],
      ],
    );
  }
}
```

#### SubscriptionDialog 订阅管理对话框

```dart
// lib/pages/sources/widgets/subscription_dialog.dart
class SubscriptionDialog extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final store = useSourceStore();
    final subscriptions = store.state.subscriptions;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 标题栏
            Row(
              children: [
                Icon(Icons.subscriptions),
                SizedBox(width: 8),
                Text('订阅管理', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.add),
                  tooltip: '添加订阅',
                  onPressed: () => _showAddSubscriptionDialog(context),
                ),
                IconButton(
                  icon: Icon(Icons.sync),
                  tooltip: '同步全部',
                  onPressed: () => store.syncAllSubscriptions(),
                ),
              ],
            ),

            Divider(),

            // 订阅列表
            Expanded(
              child: subscriptions.isEmpty
                  ? Center(child: Text('暂无订阅'))
                  : ListView.builder(
                      itemCount: subscriptions.length,
                      itemBuilder: (context, index) {
                        final sub = subscriptions[index];
                        return _SubscriptionTile(
                          subscription: sub,
                          onSync: () => store.syncSubscription(sub.url),
                          onDelete: () => store.removeSubscription(index),
                          onToggleAutoSync: (value) {
                            store.updateSubscription(
                              index,
                              sub.copyWith(autoSync: value),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: '订阅名称',
                hintText: '例如：我的订阅',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: '订阅URL',
                hintText: 'https://example.com/sources.json',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && urlController.text.isNotEmpty) {
                final store = useSourceStore();
                store.addSubscription(SourceSubscription(
                  name: nameController.text,
                  url: urlController.text,
                ));
                Navigator.pop(context);
              }
            },
            child: Text('添加'),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final SourceSubscription subscription;
  final VoidCallback onSync;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleAutoSync;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          subscription.lastSyncSuccess == true
              ? Icons.check_circle
              : subscription.lastSyncSuccess == false
                  ? Icons.error
                  : Icons.sync_disabled,
          color: subscription.lastSyncSuccess == true
              ? Colors.green
              : subscription.lastSyncSuccess == false
                  ? Colors.red
                  : Colors.grey,
        ),
        title: Text(subscription.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subscription.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '源数量: ${subscription.sourceCount}',
                  style: TextStyle(fontSize: 11),
                ),
                SizedBox(width: 16),
                Text(
                  '同步时间: ${_formatTime(subscription.lastSyncTime)}',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 自动同步开关
            Switch(
              value: subscription.autoSync,
              onChanged: onToggleAutoSync,
            ),
            // 同步按钮
            IconButton(
              icon: Icon(Icons.sync),
              tooltip: '同步',
              onPressed: onSync,
            ),
            // 删除按钮
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              tooltip: '删除',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
```

### 11.5 交互设计规范

#### 多选模式交互流程

```
普通模式                          多选模式
    │                                 │
    ├─ 点击列表项 → 进入详情          ├─ 点击列表项 → 切换选中状态
    │                                 │
    ├─ 长按列表项 → 进入多选模式      ├─ 长按列表项 → 无响应
    │   └─ 自动选中该项               │
    │                                 ├─ 点击全选 → 选中所有
    ├─ 点击更多菜单 → 显示菜单        │
    │   ├─ 添加源                     ├─ 点击反选 → 反转选中状态
    │   ├─ 测试全部                   │
    │   ├─ 校验全部                   ├─ 点击返回 → 退出多选模式
    │   ├─ 导入                       │
    │   ├─ 导出                       ├─ 选中数量 = 0 → 自动退出多选模式
    │   └─ 订阅管理                   │
    │                                 ├─ 点击批量操作 → 执行操作
    └─ FAB点击 → 添加源对话框         │
                                        └─ FAB隐藏
```

#### 拖拽排序交互流程

```
手动排序模式下：
    │
    ├─ 长按列表项 → 开始拖拽
    │   └─ 列表项浮起，显示拖拽手柄
    │
    ├─ 拖拽移动 → 列表项跟随移动
    │   └─ 其他列表项自动让位
    │
    ├─ 释放 → 结束拖拽
    │   └─ 更新 customOrder
    │   └─ 保存到数据库
    │
    └─ 切换到其他排序模式 → 拖拽禁用
```

#### 源校验交互流程

```
    │
    ├─ 点击"校验全部" → 显示校验配置对话框
    │   └─ 用户配置关键字、超时、范围
    │   └─ 点击"开始"
    │
    ├─ 进入校验页面
    │   └─ 显示进度条
    │   └─ 实时显示当前校验源
    │   └─ 实时显示校验结果
    │
    ├─ 校验完成
    │   └─ 显示统计信息
    │   └─ 自动标记失效分组
    │
    └─ 点击"完成" → 返回源列表
        └─ 失效源显示错误标签
```

### 11.6 主题与样式规范

```dart
// lib/pages/sources/source_styles.dart
class SourceStyles {
  // 颜色
  static const Color activeColor = Colors.green;
  static const Color inactiveColor = Colors.grey;
  static const Color errorColor = Colors.red;
  static const Color timeoutColor = Colors.orange;

  // 间距
  static const double listItemPadding = 12.0;
  static const double cardMargin = 8.0;
  static const double chipSpacing = 4.0;

  // 文字样式
  static const TextStyle titleStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );

  static const TextStyle urlStyle = TextStyle(
    fontSize: 11,
    color: Colors.blue,
    decoration: TextDecoration.underline,
  );

  // 图标
  static const double typeIconSize = 28.0;
  static const double actionIconSize = 20.0;

  // 卡片
  static final cardDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
    ],
  );
}
```

---

## 十二、实施计划

### 阶段一：数据模型重构（1-2天）

- [ ] 创建 `BookSource` 主实体（完全兼容 Legado JSON）
- [ ] 创建所有规则数据结构（SearchRule, ExploreRule, BookInfoRule, TocRule, ContentRule, ReviewRule）
- [ ] 创建 `BookSourceType` 枚举
- [ ] 创建 `BookSourcePart` 轻量视图
- [ ] 创建 `BookSourceSort` 排序枚举
- [ ] 创建 `CheckSourceConfig` 校验配置
- [ ] 运行 `build_runner build` 生成代码

### 阶段二：状态管理重构（2-3天）

- [ ] 重构 `SourceState` 聚合状态
- [ ] 重构 `SourceStore`：
  - [ ] 源 CRUD（单个/批量）
  - [ ] 批量操作（启用/禁用/置顶/置底）
  - [ ] 分组管理（多分组支持）
  - [ ] 排序（7种方式 + 拖拽）
  - [ ] 导入导出（完全兼容 Legado JSON）
  - [ ] 源校验（完整校验流程）
  - [ ] 查询方法（搜索/筛选/分组）

### 阶段三：解析器重构（1-2天）

- [ ] 重构 `SourceParser`：
  - [ ] `parseSearchList()` 解析搜索结果
  - [ ] `parseExploreList()` 解析发现列表
  - [ ] `parseBookInfo()` 解析详情
  - [ ] `parseToc()` 解析目录
  - [ ] `parseContent()` 解析正文
  - [ ] `getSearchUrl()` 构建搜索URL
- [ ] 创建数据类（ParsedBookItem, ParsedBookInfo, ParsedChapter, ParsedContent）
- [ ] 新增 `SourceChecker` 源校验器

### 阶段四：UI 组件开发（2-3天）

- [ ] 创建 `SourceStyles` 样式规范
- [ ] 创建 `SourceTile` 列表项组件
  - [ ] 多选模式支持
  - [ ] 状态标签显示
  - [ ] 类型图标显示
  - [ ] 分组标签显示
  - [ ] 操作菜单
- [ ] 创建 `SourceFilterBar` 筛选栏组件
  - [ ] 状态筛选（全部/活跃/禁用/错误）
  - [ ] 分组下拉筛选
  - [ ] 类型下拉筛选
- [ ] 创建 `SourceBatchBar` 批量操作栏组件
  - [ ] 选中数量显示
  - [ ] 全选/反选按钮
  - [ ] 批量操作按钮组
- [ ] 创建 `SourceSortMenu` 排序菜单组件
  - [ ] 7种排序方式选项
  - [ ] 升降序切换
- [ ] 创建 `SubscriptionDialog` 订阅管理对话框
  - [ ] 订阅列表
  - [ ] 添加订阅
  - [ ] 同步操作
  - [ ] 自动同步开关

### 阶段五：页面重构（3-4天）

- [ ] 重构 `SourcesPage`：
  - [ ] 集成 `SourceFilterBar`
  - [ ] 集成 `SourceSortMenu`
  - [ ] 实现多选模式（长按进入）
  - [ ] 集成 `SourceBatchBar`
  - [ ] 实现拖拽排序（手动排序模式）
  - [ ] 实现域名分组排序
  - [ ] 集成 `SubscriptionDialog`
  - [ ] 添加源对话框（支持类型选择）
  - [ ] 导入对话框（支持URL/文件/合并/替换）
  - [ ] 导出功能
- [ ] 重构 `SourceEditPage`：
  - [ ] 实现 TabBar（9个Tab）
  - [ ] 基础信息Tab（URL/名称/类型/分组/权重/启用）
  - [ ] 网络配置Tab（请求头/并发率/Cookie/JS库）
  - [ ] 登录配置Tab（登录地址/登录UI/检测JS）
  - [ ] 搜索规则Tab（searchUrl/checkKeyWord/列表规则）
  - [ ] 发现规则Tab（exploreUrl/样式/筛选/列表规则）
  - [ ] 详情规则Tab（init/各字段规则/tocUrl）
  - [ ] 目录规则Tab（chapterList/chapterName/chapterUrl/分页）
  - [ ] 正文规则Tab（content/title/replaceRegex/图片样式）
  - [ ] 其他配置Tab（注释/变量/NSFW/解析地址/只读信息）
  - [ ] 分组自动完成
  - [ ] 规则帮助提示
- [ ] 新增 `SourceCheckPage`：
  - [ ] 校验配置区
  - [ ] 校验进度显示
  - [ ] 校验结果列表
  - [ ] 统计信息

### 阶段六：国际化（0.5天）

- [ ] 添加所有新增国际化键（约50个）
- [ ] 中文翻译
- [ ] 英文翻译

### 阶段七：测试与优化（1-2天）

- [ ] 导入 Legado 源 JSON 测试
  - [ ] 单个源导入
  - [ ] 批量源导入
  - [ ] URL导入
  - [ ] 合并/替换模式
- [ ] 导出测试
  - [ ] 导出全部
  - [ ] 导出选中
  - [ ] Legado 兼容性验证
- [ ] 源校验功能测试
  - [ ] 单个源校验
  - [ ] 批量校验
  - [ ] 超时处理
  - [ ] 失效标记
- [ ] 批量操作测试
  - [ ] 多选模式
  - [ ] 全选/反选
  - [ ] 批量删除/启用/禁用
  - [ ] 置顶/置底
- [ ] 拖拽排序测试
- [ ] 分组管理测试
- [ ] 订阅管理测试
- [ ] 性能优化
  - [ ] 1000+ 源列表流畅滚动
  - [ ] 批量操作响应时间 < 1秒
  - [ ] 源校验并发执行

---

## 十三、验收标准

### 13.1 兼容性验收

- [ ] 可直接导入 Legado 书源 JSON，无需转换
- [ ] 导出的 JSON 可被 Legado 直接导入
- [ ] 所有 Legado 规则字段完整支持
- [ ] 支持 Legado 所有源类型（文本/音频/图片/文件/视频/RSS）

### 13.2 功能验收

- [ ] **批量操作**：多选、全选/反选、批量删除/启用/禁用/置顶/置底/导出
- [ ] **拖拽排序**：手动排序模式下可拖拽调整顺序
- [ ] **源校验**：完整校验流程（搜索+发现+详情+目录+正文）
- [ ] **分组管理**：多分组支持（逗号/分号分隔）、添加/删除/重命名分组
- [ ] **排序**：7种排序方式，支持升降序
- [ ] **筛选**：按状态/分组/类型筛选
- [ ] **订阅管理**：添加/删除/同步订阅，自动同步开关
- [ ] **导入导出**：支持URL/文件导入，合并/替换模式

### 13.3 UI 验收

- [ ] **列表项**：显示名称、URL、状态、类型图标、分组标签、响应时间
- [ ] **多选模式**：长按进入，显示复选框，底部显示批量操作栏
- [ ] **筛选栏**：状态/分组/类型筛选，实时更新列表
- [ ] **排序菜单**：7种排序方式，升降序切换
- [ ] **编辑页面**：9个Tab，完整规则编辑
- [ ] **校验页面**：配置、进度、结果、统计
- [ ] **订阅对话框**：列表、添加、同步、自动同步

### 13.4 性能验收

- [ ] 1000+ 源列表流畅滚动（60fps）
- [ ] 批量操作响应时间 < 1秒
- [ ] 源校验并发执行，可配置并发数
- [ ] 内存占用合理（< 100MB for 1000源）

---

## 十四、风险评估

| 风险 | 影响 | 应对措施 |
|-----|------|---------|
| 数据迁移 | 现有源数据格式不兼容 | 提供迁移工具，自动转换旧格式 |
| FFI 兼容性 | 新规则结构可能与 FFI 不兼容 | 验证 FFI 调用，必要时调整封装层 |
| 性能问题 | 大量源的批量操作可能卡顿 | 分批处理，使用 Isolate |
| 学习成本 | 用户需要适应新的规则编辑方式 | 提供文档和示例 |
| UI 复杂度 | 9个Tab的编辑页面可能过于复杂 | 合理分组，提供帮助提示 |
| 拖拽冲突 | 拖拽可能与滚动/点击冲突 | 仅在手动排序模式启用，长按触发 |

---

## 十五、文件清单

### 新增文件

```
lib/models/
├── book_source.dart              # 主实体
├── book_source_part.dart         # 轻量视图
├── book_source_type.dart         # 类型枚举
├── book_source_sort.dart         # 排序枚举
├── check_source_config.dart      # 校验配置
├── check_result.dart             # 校验结果
├── import_result.dart            # 导入结果
└── rule/
    ├── search_rule.dart          # 搜索规则
    ├── explore_rule.dart         # 发现规则
    ├── book_info_rule.dart       # 详情规则
    ├── toc_rule.dart             # 目录规则
    ├── content_rule.dart         # 正文规则
    └── review_rule.dart          # 段评规则

lib/pages/sources/
├── source_check_page.dart        # 源校验页面
└── widgets/
    ├── source_tile.dart          # 列表项组件
    ├── source_filter_bar.dart    # 筛选栏组件
    ├── source_batch_bar.dart     # 批量操作栏组件
    ├── source_sort_menu.dart     # 排序菜单组件
    └── source_styles.dart        # 样式规范

lib/utils/
└── source_checker.dart           # 源校验器
```

### 修改文件

```
lib/pages/sources/
├── sources_page.dart             # 主页面重构
├── source_edit_page.dart         # 编辑页面重构
└── widgets/
    └── subscription_dialog.dart  # 订阅对话框重构

lib/store/
└── use_source_store.dart         # 状态管理重构

lib/utils/
└── source_parser.dart            # 解析器重构

lib/l10n/
├── app_zh.arb                    # 中文国际化
└── app_en.arb                    # 英文国际化
```

### 删除文件

```
lib/models/
├── video_source.dart             # 替换为 book_source.dart
└── source_rule.dart              # 替换为 rule/ 目录
```

---

*生成时间：2026-06-16*
*方案版本：v2.0*
