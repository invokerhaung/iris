import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/book_source.dart';
import 'network/network_factory.dart';
import 'network/network_service.dart';

/// 源网络请求封装
///
/// 封装 HTTP 请求，支持自定义请求头、Cookie、超时、代理等
/// 底层统一使用 NetworkService（Windows: curl-impersonate, 其他: Dio）
class SourceFetcher {
  final BookSource source;
  final Duration timeout;

  /// debug 模式下本地 HTML 文件目录
  static const String _debugHtmlDir = 'debug_html';

  SourceFetcher(
    this.source, {
    this.timeout = const Duration(seconds: 10),
  });

  /// 发起 GET 请求
  Future<NetworkResult> get(String url, {Map<String, String>? extraHeaders}) async {
    // debug 模式下尝试加载本地文件
    if (kDebugMode) {
      final localResult = _tryLoadLocalHtml(url);
      if (localResult != null) {
        return localResult;
      }
    }

    final headers = _buildHeaders(extraHeaders);

    try {
      final result = await NetworkFactory.instance.get(
        url,
        headers: headers,
        timeout: timeout,
      );
      return result;
    } on NetworkException {
      rethrow;
    }
  }

  /// 发起 POST 请求
  Future<NetworkResult> post(
    String url, {
    Map<String, String>? extraHeaders,
    Object? body,
    Encoding? encoding,
  }) async {
    // debug 模式下尝试加载本地文件
    if (kDebugMode) {
      final localResult = _tryLoadLocalHtml(url);
      if (localResult != null) {
        return localResult;
      }
    }

    final headers = _buildHeaders(extraHeaders);

    try {
      final result = await NetworkFactory.instance.post(
        url,
        headers: headers,
        body: body,
        timeout: timeout,
      );
      return result;
    } on NetworkException {
      rethrow;
    }
  }

  /// 尝试从本地加载 HTML（debug 模式）
  ///
  /// 直接读取 debug_html/debug.html 文件
  NetworkResult? _tryLoadLocalHtml(String url) {
    try {
      final file = File('$_debugHtmlDir/debug.html');
      if (!file.existsSync()) return null;

      final content = file.readAsStringSync();
      return NetworkResult(
        statusCode: 200,
        body: content,
        headers: {},
        url: url,
      );
    } catch (e) {
      return null;
    }
  }

  /// 构建请求头
  ///
  /// Windows 端使用 curl-impersonate 的 TLS 指纹伪装，不使用源配置的请求头
  /// 以避免自定义 User-Agent 与 Chrome 120 指纹冲突
  Map<String, String> _buildHeaders(Map<String, String>? extraHeaders) {
    final headers = <String, String>{};

    // Windows 端不使用源配置的请求头（curl-impersonate 自带 Chrome 120 指纹）
    if (!Platform.isWindows) {
      headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

      if (source.header != null && source.header!.isNotEmpty) {
        try {
          final Map<String, dynamic> sourceHeaders = jsonDecode(source.header!);
          for (final entry in sourceHeaders.entries) {
            headers[entry.key] = entry.value.toString();
          }
        } catch (e) {
          // header 解析失败，忽略
        }
      }
    }

    // 添加额外请求头
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }
}
