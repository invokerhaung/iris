/// Legado Go Analyzer FFI 绑定层
///
/// 统一导出入口。使用时只需：
/// ```dart
/// import 'package:iris/ffi/ffi.dart';
/// ```
///
/// 提供以下高层 API：
/// - [LegadoLog] — 日志管理
/// - [LegadoAnalyzer] — HTML/内容解析
/// - [LegadoRuleData] — 键值对变量存储
/// - [LegadoJS] — JavaScript 引擎
/// - [LegadoURL] — URL 解析
///
/// 如需访问底层绑定，可使用 [LegadoFFIBindings.instance]。

library;

export 'legado_ffi_bindings.dart';
export 'legado_ffi.dart';
