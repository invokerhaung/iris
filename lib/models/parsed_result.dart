/// 解析后的书籍项（搜索/发现列表）
class ParsedBookItem {
  final String? name;           // 书名
  final String? author;         // 作者
  final String? intro;          // 简介
  final String? kind;           // 分类/标签
  final String? lastChapter;    // 最新章节
  final String? updateTime;     // 更新时间
  final String? bookUrl;        // 详情页URL
  final String? coverUrl;       // 封面URL
  final String? wordCount;      // 字数

  const ParsedBookItem({
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.bookUrl,
    this.coverUrl,
    this.wordCount,
  });

  @override
  String toString() {
    return 'ParsedBookItem(name: $name, author: $author, bookUrl: $bookUrl)';
  }

  /// 是否有效（必须有名称和URL）
  bool get isValid => name != null && name!.isNotEmpty && bookUrl != null && bookUrl!.isNotEmpty;
}

/// 解析后的书籍详情
class ParsedBookInfo {
  final String? name;           // 书名
  final String? author;         // 作者
  final String? intro;          // 简介
  final String? kind;           // 分类
  final String? lastChapter;    // 最新章节
  final String? updateTime;     // 更新时间
  final String? coverUrl;       // 封面URL
  final String? tocUrl;         // 目录页URL
  final String? wordCount;      // 字数

  const ParsedBookInfo({
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.coverUrl,
    this.tocUrl,
    this.wordCount,
  });

  @override
  String toString() {
    return 'ParsedBookInfo(name: $name, author: $author)';
  }
}

/// 解析后的章节
class ParsedChapter {
  final String? name;           // 章节名称
  final String? url;            // 章节URL
  final bool isVolume;          // 是否为卷（分组）
  final bool isVip;             // 是否VIP章节
  final bool isPay;             // 是否付费章节
  final String? updateTime;     // 更新时间

  const ParsedChapter({
    this.name,
    this.url,
    this.isVolume = false,
    this.isVip = false,
    this.isPay = false,
    this.updateTime,
  });

  @override
  String toString() {
    return 'ParsedChapter(name: $name, url: $url)';
  }

  /// 是否有效
  bool get isValid => name != null && name!.isNotEmpty;
}

/// 解析后的正文内容
class ParsedContent {
  final String? title;          // 标题
  final String? content;        // 正文内容
  final String? nextContentUrl; // 下一页URL

  const ParsedContent({
    this.title,
    this.content,
    this.nextContentUrl,
  });

  @override
  String toString() {
    return 'ParsedContent(title: $title, contentLength: ${content?.length ?? 0})';
  }

  /// 是否有下一页
  bool get hasNextPage => nextContentUrl != null && nextContentUrl!.isNotEmpty;
}

/// 解析后的段评
class ParsedReview {
  final String? avatar;         // 头像
  final String? content;        // 内容
  final String? postTime;       // 发布时间
  final String? reviewUrl;      // 段评URL

  const ParsedReview({
    this.avatar,
    this.content,
    this.postTime,
    this.reviewUrl,
  });

  @override
  String toString() {
    return 'ParsedReview(content: ${content?.substring(0, content!.length > 20 ? 20 : content!.length)}...)';
  }
}
