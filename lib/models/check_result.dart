import 'book_source.dart';

/// 校验结果类型
enum CheckResultType {
  success,  // 成功
  timeout,  // 超时
  error,    // 错误
}

/// 校验结果
class CheckResult {
  final CheckResultType type;
  final BookSource source;
  final String? errorMessage;
  final Duration? duration;

  const CheckResult._({
    required this.type,
    required this.source,
    this.errorMessage,
    this.duration,
  });

  /// 成功
  factory CheckResult.success(BookSource source, Duration duration) {
    return CheckResult._(
      type: CheckResultType.success,
      source: source,
      duration: duration,
    );
  }

  /// 超时
  factory CheckResult.timeout(BookSource source) {
    return CheckResult._(
      type: CheckResultType.timeout,
      source: source,
    );
  }

  /// 错误
  factory CheckResult.error(BookSource source, String message) {
    return CheckResult._(
      type: CheckResultType.error,
      source: source,
      errorMessage: message,
    );
  }

  bool get isSuccess => type == CheckResultType.success;
  bool get isTimeout => type == CheckResultType.timeout;
  bool get isError => type == CheckResultType.error;
}
