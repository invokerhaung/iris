import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../models/check_source_config.dart';
import '../../models/check_result.dart';
import '../../store/use_source_store.dart';
import '../../utils/source_checker.dart';

/// 源校验页面
class SourceCheckPage extends HookWidget {
  final List<String>? bookSourceUrls;

  const SourceCheckPage({super.key, this.bookSourceUrls});

  @override
  Widget build(BuildContext context) {
    final store = useSourceStore();

    // 校验配置
    final config = useState(const CheckSourceConfig());

    // 校验状态
    final isChecking = useState(false);
    final currentIndex = useState(0);
    final totalCount = useState(0);
    final results = useState<List<CheckResult>>([]);
    final startTime = useState<DateTime?>(null);

    // 统计
    final successCount = useMemoized(() {
      return results.value.where((r) => r.isSuccess).length;
    }, [results.value]);
    final failCount = useMemoized(() {
      return results.value.where((r) => r.isError || r.isTimeout).length;
    }, [results.value]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('源校验'),
        actions: [
          if (!isChecking.value)
            TextButton(
              onPressed: () => _startCheck(
                store,
                config.value,
                isChecking,
                currentIndex,
                totalCount,
                results,
                startTime,
              ),
              child: const Text('开始'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 校验配置
          _buildConfigSection(config),

          const SizedBox(height: 24),

          // 校验进度
          if (isChecking.value || results.value.isNotEmpty)
            _buildProgressSection(
              isChecking.value,
              currentIndex.value,
              totalCount.value,
              startTime.value,
              successCount,
              failCount,
            ),

          const SizedBox(height: 24),

          // 校验结果
          if (results.value.isNotEmpty)
            _buildResultsSection(results.value),
        ],
      ),
    );
  }

  /// 构建配置区域
  Widget _buildConfigSection(ValueNotifier<CheckSourceConfig> config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '校验配置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 校验关键字
            TextFormField(
              initialValue: config.value.keyword,
              decoration: const InputDecoration(
                labelText: '校验关键字',
                border: OutlineInputBorder(),
                helperText: '用于搜索校验的关键词',
              ),
              onChanged: (value) {
                config.value = config.value.copyWith(keyword: value);
              },
            ),
            const SizedBox(height: 16),

            // 超时时间
            TextFormField(
              initialValue: config.value.timeout.toString(),
              decoration: const InputDecoration(
                labelText: '超时时间 (ms)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final timeout = int.tryParse(value) ?? 180000;
                config.value = config.value.copyWith(timeout: timeout);
              },
            ),
            const SizedBox(height: 16),

            // 并发数
            TextFormField(
              initialValue: config.value.threadCount.toString(),
              decoration: const InputDecoration(
                labelText: '并发数',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final count = int.tryParse(value) ?? 5;
                config.value = config.value.copyWith(threadCount: count);
              },
            ),
            const SizedBox(height: 16),

            // 校验范围
            const Text('校验范围', style: TextStyle(fontWeight: FontWeight.w500)),
            CheckboxListTile(
              title: const Text('校验搜索'),
              value: config.value.checkSearch,
              onChanged: (value) {
                config.value = config.value.copyWith(checkSearch: value ?? true);
              },
            ),
            CheckboxListTile(
              title: const Text('校验发现'),
              value: config.value.checkDiscovery,
              onChanged: (value) {
                config.value = config.value.copyWith(checkDiscovery: value ?? true);
              },
            ),
            CheckboxListTile(
              title: const Text('校验详情'),
              value: config.value.checkInfo,
              onChanged: (value) {
                config.value = config.value.copyWith(checkInfo: value ?? true);
              },
            ),
            CheckboxListTile(
              title: const Text('校验目录'),
              value: config.value.checkCategory,
              onChanged: (value) {
                config.value = config.value.copyWith(checkCategory: value ?? true);
              },
            ),
            CheckboxListTile(
              title: const Text('校验正文'),
              value: config.value.checkContent,
              onChanged: (value) {
                config.value = config.value.copyWith(checkContent: value ?? true);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建进度区域
  Widget _buildProgressSection(
    bool isChecking,
    int currentIndex,
    int totalCount,
    DateTime? startTime,
    int successCount,
    int failCount,
  ) {
    final progress = totalCount > 0 ? currentIndex / totalCount : 0.0;
    final elapsed = startTime != null
        ? DateTime.now().difference(startTime)
        : Duration.zero;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '校验进度',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 进度条
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),

            // 进度信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$currentIndex / $totalCount'),
                Text('${(progress * 100).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),

            // 统计信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('成功', successCount, Colors.green),
                _buildStatItem('失败', failCount, Colors.red),
                _buildStatItem('用时', elapsed.inSeconds, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  /// 构建结果区域
  Widget _buildResultsSection(List<CheckResult> results) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '校验结果',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ...results.map((result) => _buildResultItem(result)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(CheckResult result) {
    IconData icon;
    Color color;
    String status;

    if (result.isSuccess) {
      icon = Icons.check_circle;
      color = Colors.green;
      status = '成功 (${result.duration?.inMilliseconds ?? 0}ms)';
    } else if (result.isTimeout) {
      icon = Icons.access_time;
      color = Colors.orange;
      status = '超时';
    } else {
      icon = Icons.error;
      color = Colors.red;
      status = '失败';
    }

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(result.source.bookSourceName),
      subtitle: Text(status),
      dense: true,
    );
  }

  /// 开始校验
  Future<void> _startCheck(
    SourceStore store,
    CheckSourceConfig config,
    ValueNotifier<bool> isChecking,
    ValueNotifier<int> currentIndex,
    ValueNotifier<int> totalCount,
    ValueNotifier<List<CheckResult>> results,
    ValueNotifier<DateTime?> startTime,
  ) async {
    isChecking.value = true;
    results.value = [];
    startTime.value = DateTime.now();

    final sources = bookSourceUrls != null
        ? store.state.sources
            .where((s) => bookSourceUrls!.contains(s.bookSourceUrl))
            .toList()
        : store.state.sources;

    totalCount.value = sources.length;

    final checker = SourceChecker(store, config: config);

    for (var i = 0; i < sources.length; i++) {
      currentIndex.value = i + 1;

      final result = await checker.checkSource(sources[i]);
      results.value = [...results.value, result];

      // 更新源状态
      await store.updateSource(result.source);
    }

    isChecking.value = false;
  }
}
