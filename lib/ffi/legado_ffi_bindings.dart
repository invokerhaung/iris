/// Legado Go Analyzer FFI 底层绑定
///
/// 本文件通过 [DynamicLibrary.open] 加载 legado_ffi.dll，
/// 并使用 [lookupFunction] 将 C 导出函数映射为 Dart 可调用函数。
///
/// 所有字符串参数和返回值均使用 UTF-8 编码（[Pointer]）。
/// 返回的 [Pointer] 由 Go 分配内存，必须调用 [freeString] 释放。

library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';

// ============================================================
// C 类型定义
//
// 对应 legado_ffi.h 中 cgo 生成的类型映射：
//   GoInt64  → Int64   (long long)
//   char*    → Pointer<Utf8>
//   void     → Void
//   int      → Int32
// ============================================================

/// FFI 绑定单例
///
/// 通过 [instance] 获取，内部懒加载 [DynamicLibrary]。
class LegadoFFIBindings {
  LegadoFFIBindings._();

  /// 单例实例
  static final LegadoFFIBindings instance = LegadoFFIBindings._();

  /// 加载动态库
  ///
  /// Windows 下加载 legado_ffi.dll，需确保 DLL 位于可执行文件同目录。
  /// Android/Linux 下需加载对应的 .so 文件（当前仅支持 Windows）。
  late final DynamicLibrary _dylib = DynamicLibrary.open('legado_ffi.dll');

  // ============================================================
  // Log — 日志子系统（3 个函数）
  // ============================================================

  /// 初始化日志文件
  ///
  /// C 签名: `void LogInit(char* path)`
  late final void Function(Pointer<Utf8> path) logInit =
      _dylib.lookupFunction<Void Function(Pointer<Utf8>),
          void Function(Pointer<Utf8>)>('LogInit');

  /// 启用或禁用日志
  ///
  /// C 签名: `void LogSetEnabled(int enabled)`
  /// [enabled] 非 0 为启用，0 为禁用。
  late final void Function(int enabled) logSetEnabled =
      _dylib.lookupFunction<Void Function(Int32), void Function(int)>(
          'LogSetEnabled');

  /// 关闭日志文件
  ///
  /// C 签名: `void LogClose(void)`
  late final void Function() logClose =
      _dylib.lookupFunction<Void Function(), void Function()>('LogClose');

  // ============================================================
  // Analyzer — 内容解析引擎（8 个函数）
  //
  // 实例通过 [analyzerNew] 创建，返回一个 int64 ID。
  // 后续所有操作通过该 ID 引用，使用完毕必须调用 [analyzerFree] 释放。
  // ============================================================

  /// 创建解析器实例
  ///
  /// C 签名: `GoInt64 AnalyzerNew(GoInt64 ruleDataID, GoInt64 sourceID)`
  /// 返回解析器 ID，失败时返回负数。
  late final int Function(int ruleDataID, int sourceID) analyzerNew =
      _dylib.lookupFunction<Int64 Function(Int64, Int64),
          int Function(int, int)>('AnalyzerNew');

  /// 设置待解析的 HTML 内容
  ///
  /// C 签名: `void AnalyzerSetContent(GoInt64 analyzerID, char* content, char* baseUrl)`
  /// [content] 为 HTML 文本，[baseUrl] 用于解析相对链接。
  late final void Function(int analyzerID, Pointer<Utf8> content,
      Pointer<Utf8> baseUrl) analyzerSetContent = _dylib.lookupFunction<
          Void Function(Int64, Pointer<Utf8>, Pointer<Utf8>),
          void Function(int, Pointer<Utf8>, Pointer<Utf8>)>(
      'AnalyzerSetContent');

  /// 设置重定向 URL
  ///
  /// C 签名: `void AnalyzerSetRedirectUrl(GoInt64 analyzerID, char* url)`
  late final void Function(int analyzerID, Pointer<Utf8> url)
      analyzerSetRedirectUrl = _dylib.lookupFunction<
          Void Function(Int64, Pointer<Utf8>),
          void Function(int, Pointer<Utf8>)>('AnalyzerSetRedirectUrl');

  /// 根据规则提取单个文本值
  ///
  /// C 签名: `char* AnalyzerGetString(GoInt64 analyzerID, char* rule)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int analyzerID, Pointer<Utf8> rule)
      analyzerGetString = _dylib.lookupFunction<
          Pointer<Utf8> Function(Int64, Pointer<Utf8>),
          Pointer<Utf8> Function(int, Pointer<Utf8>)>('AnalyzerGetString');

  /// 根据规则提取文本列表（返回 JSON 数组字符串）
  ///
  /// C 签名: `char* AnalyzerGetStringList(GoInt64 analyzerID, char* rule)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int analyzerID, Pointer<Utf8> rule)
      analyzerGetStringList = _dylib.lookupFunction<
          Pointer<Utf8> Function(Int64, Pointer<Utf8>),
          Pointer<Utf8> Function(int, Pointer<Utf8>)>('AnalyzerGetStringList');

  /// 根据规则提取单个 DOM 元素
  ///
  /// C 签名: `char* AnalyzerGetElement(GoInt64 analyzerID, char* rule)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int analyzerID, Pointer<Utf8> rule)
      analyzerGetElement = _dylib.lookupFunction<
          Pointer<Utf8> Function(Int64, Pointer<Utf8>),
          Pointer<Utf8> Function(int, Pointer<Utf8>)>('AnalyzerGetElement');

  /// 根据规则提取 DOM 元素列表
  ///
  /// C 签名: `char* AnalyzerGetElements(GoInt64 analyzerID, char* rule)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int analyzerID, Pointer<Utf8> rule)
      analyzerGetElements = _dylib.lookupFunction<
          Pointer<Utf8> Function(Int64, Pointer<Utf8>),
          Pointer<Utf8> Function(int, Pointer<Utf8>)>('AnalyzerGetElements');

  /// 释放解析器实例
  ///
  /// C 签名: `void AnalyzerFree(GoInt64 analyzerID)`
  late final void Function(int analyzerID) analyzerFree =
      _dylib.lookupFunction<Void Function(Int64), void Function(int)>(
          'AnalyzerFree');

  // ============================================================
  // RuleData — 键值对变量存储（4 个函数）
  //
  // 用于在解析过程中持久化变量。
  // 实例通过 [ruleDataNew] 创建，使用完毕必须调用 [ruleDataFree] 释放。
  // ============================================================

  /// 创建变量存储实例
  ///
  /// C 签名: `GoInt64 RuleDataNew(void)`
  /// 返回实例 ID。
  late final int Function() ruleDataNew =
      _dylib.lookupFunction<Int64 Function(), int Function()>('RuleDataNew');

  /// 存储变量
  ///
  /// C 签名: `void RuleDataPut(GoInt64 ruleDataID, char* key, char* value)`
  late final void Function(
      int ruleDataID,
      Pointer<Utf8> key,
      Pointer<Utf8> value) ruleDataPut = _dylib.lookupFunction<
          Void Function(Int64, Pointer<Utf8>, Pointer<Utf8>),
          void Function(int, Pointer<Utf8>, Pointer<Utf8>)>('RuleDataPut');

  /// 获取变量
  ///
  /// C 签名: `char* RuleDataGet(GoInt64 ruleDataID, char* key)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int ruleDataID, Pointer<Utf8> key)
      ruleDataGet = _dylib.lookupFunction<
          Pointer<Utf8> Function(Int64, Pointer<Utf8>),
          Pointer<Utf8> Function(int, Pointer<Utf8>)>('RuleDataGet');

  /// 释放变量存储实例
  ///
  /// C 签名: `void RuleDataFree(GoInt64 ruleDataID)`
  late final void Function(int ruleDataID) ruleDataFree =
      _dylib.lookupFunction<Void Function(Int64), void Function(int)>(
          'RuleDataFree');

  // ============================================================
  // JS Engine — 嵌入式 JavaScript 引擎（4 个函数）
  //
  // 实例通过 [jsNew] 创建，使用完毕必须调用 [jsFree] 释放。
  // ============================================================

  /// 创建 JS 引擎实例
  ///
  /// C 签名: `GoInt64 JSNew(void)`
  /// 返回实例 ID。
  late final int Function() jsNew =
      _dylib.lookupFunction<Int64 Function(), int Function()>('JSNew');

  /// 执行 JS 代码，变量以 JSON 字符串传入
  ///
  /// C 签名: `char* JSExec(GoInt64 engineID, char* code, char* varsJSON)`
  /// [varsJSON] 为 JSON 对象字符串，如 `{"key": "value"}`。
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(
      int engineID,
      Pointer<Utf8> code,
      Pointer<Utf8> varsJSON) jsExec = _dylib.lookupFunction<
          Pointer<Utf8> Function(Int64, Pointer<Utf8>, Pointer<Utf8>),
          Pointer<Utf8> Function(
              int, Pointer<Utf8>, Pointer<Utf8>)>('JSExec');

  /// 执行 JS 代码，预设 result 变量
  ///
  /// C 签名: `char* JSExecWithResult(GoInt64 engineID, char* code, char* result)`
  /// [result] 会作为 JS 中的 `result` 变量供脚本使用。
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(
      int engineID,
      Pointer<Utf8> code,
      Pointer<Utf8> result) jsExecWithResult = _dylib.lookupFunction<
          Pointer<Utf8> Function(Int64, Pointer<Utf8>, Pointer<Utf8>),
          Pointer<Utf8> Function(
              int, Pointer<Utf8>, Pointer<Utf8>)>('JSExecWithResult');

  /// 释放 JS 引擎实例
  ///
  /// C 签名: `void JSFree(GoInt64 engineID)`
  late final void Function(int engineID) jsFree =
      _dylib.lookupFunction<Void Function(Int64), void Function(int)>(
          'JSFree');

  // ============================================================
  // URL — URL 解析器（7 个函数）
  //
  // 实例通过 [urlNew] 创建，使用完毕必须调用 [urlFree] 释放。
  // ============================================================

  /// 创建 URL 解析器
  ///
  /// C 签名: `GoInt64 URLNew(char* url, char* optionsJSON)`
  /// [optionsJSON] 为可选配置（JSON 字符串），可传空字符串。
  /// 返回实例 ID。
  late final int Function(Pointer<Utf8> url, Pointer<Utf8> optionsJSON)
      urlNew = _dylib.lookupFunction<
          Int64 Function(Pointer<Utf8>, Pointer<Utf8>),
          int Function(Pointer<Utf8>, Pointer<Utf8>)>('URLNew');

  /// 获取完整 URL
  ///
  /// C 签名: `char* URLGetURL(GoInt64 urlID)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int urlID) urlGetURL =
      _dylib.lookupFunction<Pointer<Utf8> Function(Int64),
          Pointer<Utf8> Function(int)>('URLGetURL');

  /// 获取不含查询参数的 URL
  ///
  /// C 签名: `char* URLGetURLNoQuery(GoInt64 urlID)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int urlID) urlGetURLNoQuery =
      _dylib.lookupFunction<Pointer<Utf8> Function(Int64),
          Pointer<Utf8> Function(int)>('URLGetURLNoQuery');

  /// 获取 HTTP 请求方法（GET、POST 等）
  ///
  /// C 签名: `char* URLGetMethod(GoInt64 urlID)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int urlID) urlGetMethod =
      _dylib.lookupFunction<Pointer<Utf8> Function(Int64),
          Pointer<Utf8> Function(int)>('URLGetMethod');

  /// 获取请求体
  ///
  /// C 签名: `char* URLGetBody(GoInt64 urlID)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int urlID) urlGetBody =
      _dylib.lookupFunction<Pointer<Utf8> Function(Int64),
          Pointer<Utf8> Function(int)>('URLGetBody');

  /// 获取 URL 编码后的查询参数
  ///
  /// C 签名: `char* URLGetEncodedQuery(GoInt64 urlID)`
  /// 返回的字符串由 Go 分配，必须调用 [freeString] 释放。
  late final Pointer<Utf8> Function(int urlID) urlGetEncodedQuery =
      _dylib.lookupFunction<Pointer<Utf8> Function(Int64),
          Pointer<Utf8> Function(int)>('URLGetEncodedQuery');

  /// 释放 URL 解析器实例
  ///
  /// C 签名: `void URLFree(GoInt64 urlID)`
  late final void Function(int urlID) urlFree =
      _dylib.lookupFunction<Void Function(Int64), void Function(int)>(
          'URLFree');

  // ============================================================
  // Utility — 内存管理（1 个函数）
  // ============================================================

  /// 释放由 Go 分配的 C 字符串
  ///
  /// C 签名: `void FreeString(char* str)`
  ///
  /// **重要**：所有返回 `Pointer<Utf8>` 的函数（AnalyzerGet*、RuleDataGet、
  /// JSExec*、URLGet* 系列）所返回的字符串都必须通过此函数释放，
  /// 否则会造成内存泄漏。
  late final void Function(Pointer<Utf8> str) freeString =
      _dylib.lookupFunction<Void Function(Pointer<Utf8>),
          void Function(Pointer<Utf8>)>('FreeString');
}
