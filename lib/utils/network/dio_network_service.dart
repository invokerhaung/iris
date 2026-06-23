import 'package:dio/dio.dart';

import 'network_service.dart';

/// 基于 Dio 的统一网络请求实现
///
/// 所有平台共享，差异仅在构造时注入的 HttpClientAdapter
class DioNetworkService implements NetworkService {
  late final Dio _dio;

  DioNetworkService({HttpClientAdapter? adapter}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      // 接受所有状态码，不抛异常（与原 http.Client 行为一致）
      validateStatus: (_) => true,
    ));
    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
    }
  }

  @override
  Future<NetworkResult> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          headers: headers,
          receiveTimeout: timeout,
        ),
      );
      return _toResult(response, url);
    } on DioException catch (e) {
      throw NetworkException(_dioErrorMessage(e));
    } catch (e) {
      throw NetworkException('请求异常: $e');
    }
  }

  @override
  Future<NetworkResult> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.post<String>(
        url,
        data: body,
        options: Options(
          headers: headers,
          receiveTimeout: timeout,
        ),
      );
      return _toResult(response, url);
    } on DioException catch (e) {
      throw NetworkException(_dioErrorMessage(e));
    } catch (e) {
      throw NetworkException('请求异常: $e');
    }
  }

  NetworkResult _toResult(Response<String> response, String url) {
    return NetworkResult(
      statusCode: response.statusCode ?? 0,
      body: response.data ?? '',
      headers: response.headers.map.map(
        (k, v) => MapEntry(k.toLowerCase(), v.join(', ')),
      ),
      url: url,
    );
  }

  String _dioErrorMessage(DioException e) {
    final detail = e.message ?? e.error?.toString() ?? '未知错误';
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时: ${e.requestOptions.uri}';
      case DioExceptionType.connectionError:
        return '网络连接错误: $detail';
      case DioExceptionType.badResponse:
        return 'HTTP ${e.response?.statusCode}: $detail';
      default:
        return '请求失败: $detail';
    }
  }
}
