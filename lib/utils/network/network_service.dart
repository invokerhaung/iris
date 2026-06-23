/// 统一网络请求接口
abstract class NetworkService {
  /// GET 请求
  Future<NetworkResult> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  });

  /// POST 请求
  Future<NetworkResult> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  });
}

/// 统一响应模型
class NetworkResult {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final String url;

  const NetworkResult({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.url,
  });

  /// 是否成功（2xx）
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// 内容类型
  String? get contentType => headers['content-type'];

  /// 是否为 HTML
  bool get isHtml => contentType?.contains('text/html') ?? false;

  /// 是否为 JSON
  bool get isJson => contentType?.contains('application/json') ?? false;
}

/// 网络请求异常
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
