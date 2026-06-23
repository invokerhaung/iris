import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../models/book_source.dart';
import '../../models/book_source_type.dart';
import '../../models/rule/search_rule.dart';
import '../../models/rule/explore_rule.dart';
import '../../models/rule/book_info_rule.dart';
import '../../models/rule/toc_rule.dart';
import '../../models/rule/content_rule.dart';
import '../../store/use_source_store.dart';

/// 源编辑页面
class SourceEditPage extends HookWidget {
  final String bookSourceUrl;

  const SourceEditPage({
    super.key,
    required this.bookSourceUrl,
  });

  @override
  Widget build(BuildContext context) {
    final store = useSourceStore();
    final source = store.getSource(bookSourceUrl);

    if (source == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑源')),
        body: const Center(child: Text('源不存在')),
      );
    }

    // 编辑状态
    final editedSource = useState(source);
    final isModified = useState(false);

    return DefaultTabController(
      length: 9,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('编辑源'),
          actions: [
            // 保存按钮
            TextButton(
              onPressed: isModified.value
                  ? () async {
                      await store.updateSource(editedSource.value);
                      isModified.value = false;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('保存成功')),
                        );
                        Navigator.pop(context);
                      }
                    }
                  : null,
              child: const Text('保存'),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '基础'),
              Tab(text: '网络'),
              Tab(text: '登录'),
              Tab(text: '搜索'),
              Tab(text: '发现'),
              Tab(text: '详情'),
              Tab(text: '目录'),
              Tab(text: '正文'),
              Tab(text: '其他'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: 基础信息
            _BasicInfoTab(
              source: editedSource.value,
              onChanged: (newSource) {
                editedSource.value = newSource;
                isModified.value = true;
              },
            ),

            // Tab 2: 网络配置
            _NetworkConfigTab(
              source: editedSource.value,
              onChanged: (newSource) {
                editedSource.value = newSource;
                isModified.value = true;
              },
            ),

            // Tab 3: 登录配置
            _LoginConfigTab(
              source: editedSource.value,
              onChanged: (newSource) {
                editedSource.value = newSource;
                isModified.value = true;
              },
            ),

            // Tab 4: 搜索规则
            _SearchRuleTab(
              source: editedSource.value,
              onChanged: (newSource) {
                editedSource.value = newSource;
                isModified.value = true;
              },
            ),

            // Tab 5: 发现规则
            _ExploreRuleTab(
              source: editedSource.value,
              onChanged: (newSource) {
                editedSource.value = newSource;
                isModified.value = true;
              },
            ),

            // Tab 6: 详情规则
            _BookInfoRuleTab(
              source: editedSource.value,
              onChanged: (newSource) {
                editedSource.value = newSource;
                isModified.value = true;
              },
            ),

            // Tab 7: 目录规则
            _TocRuleTab(
              source: editedSource.value,
              onChanged: (newSource) {
                editedSource.value = newSource;
                isModified.value = true;
              },
            ),

            // Tab 8: 正文规则
            _ContentRuleTab(
              source: editedSource.value,
              onChanged: (newSource) {
                editedSource.value = newSource;
                isModified.value = true;
              },
            ),

            // Tab 9: 其他配置
            _OtherConfigTab(
              source: editedSource.value,
              onChanged: (newSource) {
                editedSource.value = newSource;
                isModified.value = true;
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ========== Tab 组件 ==========

/// Tab 1: 基础信息
class _BasicInfoTab extends StatelessWidget {
  final BookSource source;
  final ValueChanged<BookSource> onChanged;

  const _BasicInfoTab({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 源地址
        TextFormField(
          initialValue: source.bookSourceUrl,
          decoration: const InputDecoration(
            labelText: '源地址 *',
            border: OutlineInputBorder(),
            helperText: '书源的唯一标识',
          ),
          onChanged: (value) => onChanged(source.copyWith(bookSourceUrl: value)),
        ),
        const SizedBox(height: 16),

        // 源名称
        TextFormField(
          initialValue: source.bookSourceName,
          decoration: const InputDecoration(
            labelText: '源名称 *',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => onChanged(source.copyWith(bookSourceName: value)),
        ),
        const SizedBox(height: 16),

        // 源类型
        DropdownButtonFormField<int>(
          value: source.bookSourceType,
          decoration: const InputDecoration(
            labelText: '源类型',
            border: OutlineInputBorder(),
          ),
          items: BookSourceType.allTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(BookSourceType.getName(type)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(source.copyWith(bookSourceType: value));
            }
          },
        ),
        const SizedBox(height: 16),

        // 分组
        TextFormField(
          initialValue: source.bookSourceGroup,
          decoration: const InputDecoration(
            labelText: '分组',
            border: OutlineInputBorder(),
            helperText: '多个分组用逗号分隔',
          ),
          onChanged: (value) => onChanged(source.copyWith(bookSourceGroup: value)),
        ),
        const SizedBox(height: 16),

        // 权重
        TextFormField(
          initialValue: source.weight.toString(),
          decoration: const InputDecoration(
            labelText: '权重',
            border: OutlineInputBorder(),
            helperText: '0-1000，用于智能排序',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final weight = int.tryParse(value) ?? 0;
            onChanged(source.copyWith(weight: weight));
          },
        ),
        const SizedBox(height: 16),

        // 开关选项
        SwitchListTile(
          title: const Text('启用'),
          subtitle: const Text('是否启用此源'),
          value: source.enabled,
          onChanged: (value) => onChanged(source.copyWith(enabled: value)),
        ),
        SwitchListTile(
          title: const Text('启用发现'),
          subtitle: const Text('是否在发现页显示'),
          value: source.enabledExplore,
          onChanged: (value) => onChanged(source.copyWith(enabledExplore: value)),
        ),
        SwitchListTile(
          title: const Text('NSFW'),
          subtitle: const Text('标记为成人内容'),
          value: source.isNsfw,
          onChanged: (value) => onChanged(source.copyWith(isNsfw: value)),
        ),
      ],
    );
  }
}

/// Tab 2: 网络配置
class _NetworkConfigTab extends StatelessWidget {
  final BookSource source;
  final ValueChanged<BookSource> onChanged;

  const _NetworkConfigTab({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 请求头
        TextFormField(
          initialValue: source.header,
          decoration: const InputDecoration(
            labelText: '请求头',
            border: OutlineInputBorder(),
            helperText: 'JSON格式，如 {"User-Agent": "..."}',
          ),
          maxLines: 3,
          onChanged: (value) => onChanged(source.copyWith(header: value)),
        ),
        const SizedBox(height: 16),

        // 并发率
        TextFormField(
          initialValue: source.concurrentRate,
          decoration: const InputDecoration(
            labelText: '并发率',
            border: OutlineInputBorder(),
            helperText: '如 10/1s 表示每秒10次请求',
          ),
          onChanged: (value) => onChanged(source.copyWith(concurrentRate: value)),
        ),
        const SizedBox(height: 16),

        // Cookie
        SwitchListTile(
          title: const Text('启用Cookie'),
          subtitle: const Text('自动保存Cookie'),
          value: source.enabledCookieJar,
          onChanged: (value) => onChanged(source.copyWith(enabledCookieJar: value)),
        ),

        // 高危API
        SwitchListTile(
          title: const Text('高危API'),
          subtitle: const Text('启用高危API调用'),
          value: source.enableDangerousApi,
          onChanged: (value) => onChanged(source.copyWith(enableDangerousApi: value)),
        ),
        const SizedBox(height: 16),

        // JS库
        TextFormField(
          initialValue: source.jsLib,
          decoration: const InputDecoration(
            labelText: 'JS库',
            border: OutlineInputBorder(),
            helperText: '自定义JavaScript库',
          ),
          maxLines: 5,
          onChanged: (value) => onChanged(source.copyWith(jsLib: value)),
        ),
      ],
    );
  }
}

/// Tab 3: 登录配置
class _LoginConfigTab extends StatelessWidget {
  final BookSource source;
  final ValueChanged<BookSource> onChanged;

  const _LoginConfigTab({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 登录地址
        TextFormField(
          initialValue: source.loginUrl,
          decoration: const InputDecoration(
            labelText: '登录地址',
            border: OutlineInputBorder(),
            helperText: '登录页面URL',
          ),
          onChanged: (value) => onChanged(source.copyWith(loginUrl: value)),
        ),
        const SizedBox(height: 16),

        // 登录UI
        TextFormField(
          initialValue: source.loginUi,
          decoration: const InputDecoration(
            labelText: '登录UI',
            border: OutlineInputBorder(),
            helperText: 'RowUi JSON数组或JS表达式',
          ),
          maxLines: 5,
          onChanged: (value) => onChanged(source.copyWith(loginUi: value)),
        ),
        const SizedBox(height: 16),

        // 登录检测JS
        TextFormField(
          initialValue: source.loginCheckJs,
          decoration: const InputDecoration(
            labelText: '登录检测JS',
            border: OutlineInputBorder(),
            helperText: '检测是否已登录的JS代码',
          ),
          maxLines: 3,
          onChanged: (value) => onChanged(source.copyWith(loginCheckJs: value)),
        ),
      ],
    );
  }
}

/// Tab 4: 搜索规则
class _SearchRuleTab extends StatelessWidget {
  final BookSource source;
  final ValueChanged<BookSource> onChanged;

  const _SearchRuleTab({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rule = source.ruleSearch ?? const SearchRule();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 搜索URL
        TextFormField(
          initialValue: source.searchUrl,
          decoration: const InputDecoration(
            labelText: '搜索URL',
            border: OutlineInputBorder(),
            helperText: '使用 {{key}} 作为搜索词占位符',
          ),
          onChanged: (value) => onChanged(source.copyWith(searchUrl: value)),
        ),
        const SizedBox(height: 16),

        // 校验关键字
        TextFormField(
          initialValue: rule.checkKeyWord,
          decoration: const InputDecoration(
            labelText: '校验关键字',
            border: OutlineInputBorder(),
            helperText: '用于源校验的搜索词',
          ),
          onChanged: (value) => onChanged(
            source.copyWith(ruleSearch: rule.copyWith(checkKeyWord: value)),
          ),
        ),
        const SizedBox(height: 24),

        // 列表规则
        const Text('列表规则', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildRuleField('列表规则', rule.bookList, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(bookList: value)));
        }),
        _buildRuleField('书名规则', rule.name, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(name: value)));
        }),
        _buildRuleField('作者规则', rule.author, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(author: value)));
        }),
        _buildRuleField('封面规则', rule.coverUrl, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(coverUrl: value)));
        }),
        _buildRuleField('链接规则', rule.bookUrl, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(bookUrl: value)));
        }),
        _buildRuleField('简介规则', rule.intro, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(intro: value)));
        }),
        _buildRuleField('分类规则', rule.kind, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(kind: value)));
        }),
        _buildRuleField('最新章节', rule.lastChapter, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(lastChapter: value)));
        }),
        _buildRuleField('更新时间', rule.updateTime, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(updateTime: value)));
        }),
        _buildRuleField('字数规则', rule.wordCount, (value) {
          onChanged(source.copyWith(ruleSearch: rule.copyWith(wordCount: value)));
        }),
      ],
    );
  }

  Widget _buildRuleField(
    String label,
    String? value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Tab 5: 发现规则
class _ExploreRuleTab extends StatelessWidget {
  final BookSource source;
  final ValueChanged<BookSource> onChanged;

  const _ExploreRuleTab({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rule = source.ruleExplore ?? const ExploreRule();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 发现URL
        TextFormField(
          initialValue: source.exploreUrl,
          decoration: const InputDecoration(
            labelText: '发现URL',
            border: OutlineInputBorder(),
            helperText: '使用 {{page}} 作为页码占位符',
          ),
          onChanged: (value) => onChanged(source.copyWith(exploreUrl: value)),
        ),
        const SizedBox(height: 24),

        // 列表规则
        const Text('列表规则', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildRuleField('列表规则', rule.bookList, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(bookList: value)));
        }),
        _buildRuleField('书名规则', rule.name, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(name: value)));
        }),
        _buildRuleField('作者规则', rule.author, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(author: value)));
        }),
        _buildRuleField('封面规则', rule.coverUrl, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(coverUrl: value)));
        }),
        _buildRuleField('链接规则', rule.bookUrl, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(bookUrl: value)));
        }),
        _buildRuleField('简介规则', rule.intro, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(intro: value)));
        }),
        _buildRuleField('分类规则', rule.kind, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(kind: value)));
        }),
        _buildRuleField('最新章节', rule.lastChapter, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(lastChapter: value)));
        }),
        _buildRuleField('更新时间', rule.updateTime, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(updateTime: value)));
        }),
        _buildRuleField('字数规则', rule.wordCount, (value) {
          onChanged(source.copyWith(ruleExplore: rule.copyWith(wordCount: value)));
        }),
      ],
    );
  }

  Widget _buildRuleField(
    String label,
    String? value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Tab 6: 详情规则
class _BookInfoRuleTab extends StatelessWidget {
  final BookSource source;
  final ValueChanged<BookSource> onChanged;

  const _BookInfoRuleTab({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rule = source.ruleBookInfo ?? const BookInfoRule();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('详情规则', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildRuleField('初始化规则', rule.init, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(init: value)));
        }),
        _buildRuleField('书名规则', rule.name, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(name: value)));
        }),
        _buildRuleField('作者规则', rule.author, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(author: value)));
        }),
        _buildRuleField('简介规则', rule.intro, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(intro: value)));
        }),
        _buildRuleField('分类规则', rule.kind, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(kind: value)));
        }),
        _buildRuleField('最新章节', rule.lastChapter, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(lastChapter: value)));
        }),
        _buildRuleField('更新时间', rule.updateTime, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(updateTime: value)));
        }),
        _buildRuleField('封面规则', rule.coverUrl, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(coverUrl: value)));
        }),
        _buildRuleField('目录URL', rule.tocUrl, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(tocUrl: value)));
        }),
        _buildRuleField('字数规则', rule.wordCount, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(wordCount: value)));
        }),
        _buildRuleField('允许重命名', rule.canReName, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(canReName: value)));
        }),
        _buildRuleField('下载地址', rule.downloadUrls, (value) {
          onChanged(source.copyWith(ruleBookInfo: rule.copyWith(downloadUrls: value)));
        }),
      ],
    );
  }

  Widget _buildRuleField(
    String label,
    String? value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Tab 7: 目录规则
class _TocRuleTab extends StatelessWidget {
  final BookSource source;
  final ValueChanged<BookSource> onChanged;

  const _TocRuleTab({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rule = source.ruleToc ?? const TocRule();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('目录规则', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildRuleField('预更新JS', rule.preUpdateJs, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(preUpdateJs: value)));
        }),
        _buildRuleField('章节列表', rule.chapterList, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(chapterList: value)));
        }),
        _buildRuleField('章节名称', rule.chapterName, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(chapterName: value)));
        }),
        _buildRuleField('章节URL', rule.chapterUrl, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(chapterUrl: value)));
        }),
        _buildRuleField('格式化JS', rule.formatJs, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(formatJs: value)));
        }),
        _buildRuleField('是否为卷', rule.isVolume, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(isVolume: value)));
        }),
        _buildRuleField('是否VIP', rule.isVip, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(isVip: value)));
        }),
        _buildRuleField('是否付费', rule.isPay, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(isPay: value)));
        }),
        _buildRuleField('更新时间', rule.updateTime, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(updateTime: value)));
        }),
        _buildRuleField('下一页URL', rule.nextTocUrl, (value) {
          onChanged(source.copyWith(ruleToc: rule.copyWith(nextTocUrl: value)));
        }),
      ],
    );
  }

  Widget _buildRuleField(
    String label,
    String? value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Tab 8: 正文规则
class _ContentRuleTab extends StatelessWidget {
  final BookSource source;
  final ValueChanged<BookSource> onChanged;

  const _ContentRuleTab({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rule = source.ruleContent ?? const ContentRule();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('正文规则', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildRuleField('正文内容', rule.content, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(content: value)));
        }),
        _buildRuleField('标题规则', rule.title, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(title: value)));
        }),
        _buildRuleField('下一页URL', rule.nextContentUrl, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(nextContentUrl: value)));
        }),
        _buildRuleField('WebView JS', rule.webJs, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(webJs: value)));
        }),
        _buildRuleField('源正则', rule.sourceRegex, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(sourceRegex: value)));
        }),
        _buildRuleField('替换规则', rule.replaceRegex, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(replaceRegex: value)));
        }),
        _buildRuleField('图片样式', rule.imageStyle, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(imageStyle: value)));
        }),
        _buildRuleField('图片解密', rule.imageDecode, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(imageDecode: value)));
        }),
        _buildRuleField('购买操作', rule.payAction, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(payAction: value)));
        }),
        _buildRuleField('LRC歌词', rule.lrcRule, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(lrcRule: value)));
        }),
        _buildRuleField('音乐封面', rule.musicCover, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(musicCover: value)));
        }),
        _buildRuleField('拦截跳转', rule.shouldOverrideUrlLoading, (value) {
          onChanged(source.copyWith(ruleContent: rule.copyWith(shouldOverrideUrlLoading: value)));
        }),
      ],
    );
  }

  Widget _buildRuleField(
    String label,
    String? value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// Tab 9: 其他配置
class _OtherConfigTab extends StatelessWidget {
  final BookSource source;
  final ValueChanged<BookSource> onChanged;

  const _OtherConfigTab({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 解析地址
        TextFormField(
          initialValue: source.jiexiUrl,
          decoration: const InputDecoration(
            labelText: '解析地址',
            border: OutlineInputBorder(),
            helperText: '视频源专用的解析地址',
          ),
          onChanged: (value) => onChanged(source.copyWith(jiexiUrl: value)),
        ),
        const SizedBox(height: 16),

        // 封面解密JS
        TextFormField(
          initialValue: source.coverDecodeJs,
          decoration: const InputDecoration(
            labelText: '封面解密JS',
            border: OutlineInputBorder(),
            helperText: '用于解密封面图片的JS代码',
          ),
          maxLines: 3,
          onChanged: (value) => onChanged(source.copyWith(coverDecodeJs: value)),
        ),
        const SizedBox(height: 16),

        // 注释
        TextFormField(
          initialValue: source.bookSourceComment,
          decoration: const InputDecoration(
            labelText: '注释',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          onChanged: (value) => onChanged(source.copyWith(bookSourceComment: value)),
        ),
        const SizedBox(height: 16),

        // 变量说明
        TextFormField(
          initialValue: source.variableComment,
          decoration: const InputDecoration(
            labelText: '变量说明',
            border: OutlineInputBorder(),
            helperText: '说明源中使用的变量',
          ),
          maxLines: 3,
          onChanged: (value) => onChanged(source.copyWith(variableComment: value)),
        ),
        const SizedBox(height: 16),

        // 详情页URL正则
        TextFormField(
          initialValue: source.bookUrlPattern,
          decoration: const InputDecoration(
            labelText: '详情页URL正则',
            border: OutlineInputBorder(),
            helperText: '用于匹配详情页URL的正则表达式',
          ),
          onChanged: (value) => onChanged(source.copyWith(bookUrlPattern: value)),
        ),
        const SizedBox(height: 16),

        // 发现样式
        DropdownButtonFormField<int>(
          value: source.exploreStyle,
          decoration: const InputDecoration(
            labelText: '发现样式',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 0, child: Text('列表')),
            DropdownMenuItem(value: 1, child: Text('网格')),
            DropdownMenuItem(value: 2, child: Text('瀑布流')),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(source.copyWith(exploreStyle: value));
            }
          },
        ),
        const SizedBox(height: 16),

        // 发现筛选规则
        TextFormField(
          initialValue: source.exploreScreen,
          decoration: const InputDecoration(
            labelText: '发现筛选规则',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) => onChanged(source.copyWith(exploreScreen: value)),
        ),
      ],
    );
  }
}
