/// Legado Go Analyzer FFI 高层封装
///
/// 提供 Dart 友好的 API，自动处理：
/// - String 与 Pointer 编码转换
/// - Go 分配的 C 字符串自动释放
/// - 实例生命周期管理（Finalizer 自动释放 + 手动 dispose）
///
/// 使用示例：
/// ```dart
/// final analyzer = LegadoAnalyzer(ruleDataId: 0, sourceId: 0);
/// analyzer.setContent('<h1>Hello</h1>', 'https://example.com');
/// final text = analyzer.getString('h1@text'); // "Hello"
/// analyzer.dispose();
/// ```

library;

import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'legado_ffi_bindings.dart';

/// 底层绑定实例，全局唯一
final _bindings = LegadoFFIBindings.instance;

// ============================================================
// LegadoAnalyzer — 内容解析引擎
// ============================================================

/// 内容解析器
///
/// 用于从 HTML 文本中按规则提取数据。
/// 支持 CSS 选择器和 Legado 自定义规则语法。
///
/// 实现了 [Finalizer]，在对象被 GC 回收时自动释放底层资源，
/// 但建议在确定不再使用时主动调用 [dispose] 以及时释放内存。
class LegadoAnalyzer {
  /// 解析器实例 ID（由 Go 分配）
  final int _id;

  /// Finalizer，确保 GC 时释放 Go 侧资源
  static final _finalizer = Finalizer<int>((id) => _bindings.analyzerFree(id));

  /// 创建解析器实例
  ///
  /// [ruleDataId] 关联的变量存储 ID，不需要时传 0。
  /// [sourceId] 数据源 ID，不需要时传 0。
  ///
  /// 抛出 [StateError] 如果底层创建失败（返回负数 ID）。
  LegadoAnalyzer({int ruleDataId = 0, int sourceId = 0})
      : _id = _bindings.analyzerNew(ruleDataId, sourceId) {
    if (_id < 0) {
      throw StateError('LegadoAnalyzer 创建失败，返回 ID: $_id');
    }
    _finalizer.attach(this, _id, detach: this);
  }

  /// 设置待解析的 HTML 内容
  ///
  /// [content] HTML 文本。
  /// [baseUrl] 基础 URL，用于将相对链接解析为绝对链接。
  void setContent(String content, String baseUrl) {
    final contentPtr = content.toNativeUtf8();
    final basePtr = baseUrl.toNativeUtf8();
    _bindings.analyzerSetContent(_id, contentPtr, basePtr);
    malloc.free(contentPtr);
    malloc.free(basePtr);
  }

  /// 设置重定向 URL
  void setRedirectUrl(String url) {
    final ptr = url.toNativeUtf8();
    _bindings.analyzerSetRedirectUrl(_id, ptr);
    malloc.free(ptr);
  }

  /// 根据规则提取单个文本值
  ///
  /// [rule] Legado 解析规则，如 `'h1@text'`、`'.title@text'`。
  /// 返回提取的文本，失败时返回空字符串。
  String getString(String rule) {
    return _callWithRule(rule, _bindings.analyzerGetString);
  }

  /// 根据规则提取文本列表（返回 JSON 数组字符串）
  ///
  /// [rule] Legado 解析规则。
  /// 返回 JSON 数组字符串，如 `'["a", "b"]'`，失败时返回 `'[]'`。
  String getStringList(String rule) {
    return _callWithRule(rule, _bindings.analyzerGetStringList);
  }

  /// 根据规则提取单个 DOM 元素
  ///
  /// [rule] Legado 解析规则。
  /// 返回 HTML 字符串，失败时返回空字符串。
  String getElement(String rule) {
    return _callWithRule(rule, _bindings.analyzerGetElement);
  }

  /// 根据规则提取 DOM 元素列表
  ///
  /// [rule] Legado 解析规则。
  /// 返回 JSON 数组字符串，失败时返回 `'[]'`。
  String getElements(String rule) {
    return _callWithRule(rule, _bindings.analyzerGetElements);
  }

  /// 通用的规则调用封装：传入规则字符串，调用 FFI 函数，自动释放内存
  String _callWithRule(
    String rule,
    Pointer<Utf8> Function(int id, Pointer<Utf8> rulePtr) fn,
  ) {
    final rulePtr = rule.toNativeUtf8();
    final resultPtr = fn(_id, rulePtr);
    malloc.free(rulePtr);
    return _readAndFree(resultPtr);
  }

  /// 读取 Go 返回的 C 字符串并释放内存
  ///
  /// Go 返回的 `char*` 通过 [FreeString] 释放（不是 malloc.free）。
  static String _readAndFree(Pointer<Utf8> ptr) {
    if (ptr == nullptr) return '';
    final result = ptr.toDartString();
    _bindings.freeString(ptr);
    return result;
  }

  /// 手动释放解析器资源
  ///
  /// 调用后不可再使用此实例。重复调用是安全的（忽略）。
  void dispose() {
    _finalizer.detach(this);
    _bindings.analyzerFree(_id);
  }
}

// ============================================================
// LegadoRuleData — 键值对变量存储
// ============================================================

/// 变量存储
///
/// 在解析过程中持久化键值对数据。
/// 支持 [Finalizer] 自动释放，建议主动调用 [dispose]。
class LegadoRuleData {
  /// 实例 ID
  final int _id;

  static final _finalizer =
      Finalizer<int>((id) => _bindings.ruleDataFree(id));

  /// 创建变量存储实例
  LegadoRuleData() : _id = _bindings.ruleDataNew() {
    _finalizer.attach(this, _id, detach: this);
  }

  /// 存储变量
  void put(String key, String value) {
    final keyPtr = key.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    _bindings.ruleDataPut(_id, keyPtr, valuePtr);
    malloc.free(keyPtr);
    malloc.free(valuePtr);
  }

  /// 获取变量
  ///
  /// 返回值，不存在时返回空字符串。
  String get(String key) {
    final keyPtr = key.toNativeUtf8();
    final resultPtr = _bindings.ruleDataGet(_id, keyPtr);
    malloc.free(keyPtr);
    return LegadoAnalyzer._readAndFree(resultPtr);
  }

  /// 手动释放资源
  void dispose() {
    _finalizer.detach(this);
    _bindings.ruleDataFree(_id);
  }
}

// ============================================================
// LegadoJS — 嵌入式 JavaScript 引擎
// ============================================================

/// JavaScript 引擎
///
/// 在 Go 侧执行 JavaScript 代码，支持传入变量。
/// 支持 [Finalizer] 自动释放，建议主动调用 [dispose]。
class LegadoJS {
  /// 实例 ID
  final int _id;

  static final _finalizer = Finalizer<int>((id) => _bindings.jsFree(id));

  /// 创建 JS 引擎实例
  LegadoJS() : _id = _bindings.jsNew() {
    _finalizer.attach(this, _id, detach: this);
  }

  /// 执行 JS 代码
  ///
  /// [code] JavaScript 代码字符串。
  /// [vars] 变量映射，会序列化为 JSON 传入 JS 环境。
  /// 返回执行结果字符串，失败时返回空字符串。
  String exec(String code, [Map<String, String>? vars]) {
    final codePtr = code.toNativeUtf8();
    final varsJson = vars != null
        ? _mapToJson(vars).toNativeUtf8()
        : '{}'.toNativeUtf8();
    final resultPtr = _bindings.jsExec(_id, codePtr, varsJson);
    malloc.free(codePtr);
    malloc.free(varsJson);
    return LegadoAnalyzer._readAndFree(resultPtr);
  }

  /// 执行 JS 代码，预设 result 变量
  ///
  /// [code] JavaScript 代码字符串。
  /// [result] 预设的 `result` 变量值。
  /// 返回执行结果字符串。
  String execWithResult(String code, String result) {
    final codePtr = code.toNativeUtf8();
    final resultPtr = result.toNativeUtf8();
    final retPtr = _bindings.jsExecWithResult(_id, codePtr, resultPtr);
    malloc.free(codePtr);
    malloc.free(resultPtr);
    return LegadoAnalyzer._readAndFree(retPtr);
  }

  /// 将 Map 序列化为简单的 JSON 字符串
  ///
  /// 仅支持 String 值，不处理嵌套对象。
  static String _mapToJson(Map<String, String> map) {
    final entries = map.entries.map((e) {
      final escapedValue = e.value
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n');
      return '"${e.key}":"$escapedValue"';
    }).join(',');
    return '{$entries}';
  }

  /// 手动释放资源
  void dispose() {
    _finalizer.detach(this);
    _bindings.jsFree(_id);
  }
}

// ============================================================
// LegadoURL — URL 解析器
// ============================================================

/// URL 解析器
///
/// 解析和拆解 URL，提取各组成部分。
/// 支持 [Finalizer] 自动释放，建议主动调用 [dispose]。
class LegadoURL {
  /// 实例 ID
  final int _id;

  static final _finalizer = Finalizer<int>((id) => _bindings.urlFree(id));

  /// 内部构造函数，直接接收已创建的 ID
  LegadoURL._(this._id) {
    _finalizer.attach(this, _id, detach: this);
  }

  /// 创建 URL 解析器
  ///
  /// [url] 待解析的 URL 字符串。
  /// [options] 可选配置（JSON 字符串），不需要时传空字符串。
  factory LegadoURL(String url, [String options = '']) {
    final urlPtr = url.toNativeUtf8();
    final optionsPtr = options.toNativeUtf8();
    final id = _bindings.urlNew(urlPtr, optionsPtr);
    malloc.free(urlPtr);
    malloc.free(optionsPtr);
    return LegadoURL._(id);
  }

  /// 获取完整 URL
  String getURL() => LegadoAnalyzer._readAndFree(_bindings.urlGetURL(_id));

  /// 获取不含查询参数的 URL
  String getURLNoQuery() =>
      LegadoAnalyzer._readAndFree(_bindings.urlGetURLNoQuery(_id));

  /// 获取 HTTP 请求方法（GET、POST 等）
  String getMethod() =>
      LegadoAnalyzer._readAndFree(_bindings.urlGetMethod(_id));

  /// 获取请求体
  String getBody() => LegadoAnalyzer._readAndFree(_bindings.urlGetBody(_id));

  /// 获取 URL 编码后的查询参数
  String getEncodedQuery() =>
      LegadoAnalyzer._readAndFree(_bindings.urlGetEncodedQuery(_id));

  /// 手动释放资源
  void dispose() {
    _finalizer.detach(this);
    _bindings.urlFree(_id);
  }
}

// ============================================================
// LegadoAnalyzer 扩展方法
// ============================================================

/// LegadoAnalyzer 扩展方法
extension LegadoAnalyzerExtension on LegadoAnalyzer {
  /// 提取文本（支持 @ 语法）
  String? extractText(String rule) {
    if (rule.isEmpty) return null;

    try {
      // 处理 @ 语法
      if (rule.contains('@')) {
        final parts = rule.split('@');
        final selector = parts[0];
        final attr = parts.length > 1 ? parts[1] : 'text';

        if (attr == 'text') {
          return getString(selector);
        } else {
          final element = getElement(selector);
          if (element.isEmpty) return null;
          // 从元素中提取属性
          final regex = RegExp('$attr=["\']([^"\']*)["\']');
          final match = regex.firstMatch(element);
          return match?.group(1);
        }
      }

      return getString(rule);
    } catch (e) {
      return null;
    }
  }

  /// 提取布尔值
  bool extractBool(String rule) {
    final text = extractText(rule);
    if (text == null) return false;
    return text.toLowerCase() == 'true' || text == '1';
  }

  /// 提取列表文本
  List<String> extractStringList(String rule) {
    try {
      final jsonStr = getStringList(rule);
      return (jsonDecode(jsonStr) as List).cast<String>();
    } catch (e) {
      return [];
    }
  }
}
