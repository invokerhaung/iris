import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';

import '../../store/use_app_store.dart';

// ========== curl FFI 类型定义 ==========

typedef _CurlInitNative = Pointer<Void> Function();
typedef _CurlInitDart = Pointer<Void> Function();

typedef _CurlSetoptNative = Int32 Function(Pointer<Void>, Int32, Pointer<Void>);
typedef _CurlSetoptDart = int Function(Pointer<Void>, int, Pointer<Void>);

typedef _CurlImpersonateNative = Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32);
typedef _CurlImpersonateDart = int Function(Pointer<Void>, Pointer<Utf8>, int);

typedef _CurlPerformNative = Int32 Function(Pointer<Void>);
typedef _CurlPerformDart = int Function(Pointer<Void>);

typedef _CurlCleanupNative = Void Function(Pointer<Void>);
typedef _CurlCleanupDart = void Function(Pointer<Void>);

typedef _CurlGetinfoNative = Int32 Function(Pointer<Void>, Int32, Pointer<Void>);
typedef _CurlGetinfoDart = int Function(Pointer<Void>, int, Pointer<Void>);

typedef _SlistAppendNative = Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>);
typedef _SlistAppendDart = Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>);
typedef _SlistFreeAllNative = Void Function(Pointer<Void>);
typedef _SlistFreeAllDart = void Function(Pointer<Void>);

// write_callback: size_t callback(char *ptr, size_t size, size_t nmemb, void *userdata)
// 用 Uint64 代替 Size 以兼容 Pointer.fromFunction 的类型检查
typedef _WriteCallbackNative = Uint64 Function(Pointer<Uint8>, Uint64, Uint64, Pointer<Void>);

// ========== curl 常量 ==========

const _curloptUrl = 10002;
const _curloptWritefunction = 20011;
const _curloptHeader = 42; // CURLOPT_HEADER: 将响应头包含在 body 中
const _curloptHttpheader = 10023;
const _curloptPost = 47;
const _curloptPostfields = 10015;
const _curloptPostfieldsize = 60;
const _curloptTimeout = 13;
const _curloptProxy = 10004;
const _curloptSslVerifypeer = 64;
const _curloptSslVerifyhost = 81;
const _curloptAcceptEncoding = 10102; // CURLOPT_ACCEPT_ENCODING: 空字符串启用自动解压
const _curloptFollowlocation = 52; // CURLOPT_FOLLOWLOCATION: 自动跟随重定向
const _curloptVerbose = 41; // CURLOPT_VERBOSE: 启用详细日志
const _curlinfoResponsecode = 2097154;

/// 请求参数（可跨 Isolate 传递）
class _CurlRequestParams {
  final String url;
  final String method;
  final Map<String, String> headers;
  final String? body;
  final int timeoutSeconds;
  final String? proxy;
  const _CurlRequestParams({
    required this.url,
    required this.method,
    required this.headers,
    this.body,
    required this.timeoutSeconds,
    this.proxy,
  });
}

/// 响应结果（可跨 Isolate 传递）
class _CurlResponseData {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final int rawLength; // 原始响应长度（含 HTTP 头）
  const _CurlResponseData({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.rawLength,
  });
}

/// 全局写缓冲区（每个 Isolate 独立，不通过 userdata 传递）
BytesBuilder? _globalWriteBuffer;

/// 写回调（顶层函数，Pointer.fromFunction 要求）
/// 不依赖 userdata，直接访问全局缓冲区（每个 Isolate 有独立副本）
int _writeCallback(Pointer<Uint8> ptr, int size, int nmemb, Pointer<Void> userdata) {
  final totalSize = size * nmemb;
  final buffer = _globalWriteBuffer;
  if (buffer != null) {
    buffer.add(ptr.asTypedList(totalSize));
  }
  return totalSize;
}

/// 从响应中分离 HTTP 头和 body
///
/// curl 返回格式: "HTTP/1.1 200 OK\r\nHeader: Value\r\n\r\nBodyContent"
(String body, Map<String, String> headers) _splitHeadersAndBody(String raw) {
  final headers = <String, String>{};

  // 找到 HTTP 头和 body 的分隔符 \r\n\r\n
  final headerEnd = raw.indexOf('\r\n\r\n');
  if (headerEnd == -1) {
    return (raw, headers);
  }

  final headerSection = raw.substring(0, headerEnd);
  final body = raw.substring(headerSection.length + 4);

  // 解析 HTTP 头
  final lines = headerSection.split('\r\n');
  for (var i = 1; i < lines.length; i++) {
    // 跳过第一行 (HTTP/1.1 200 OK)
    final line = lines[i];
    final colonIndex = line.indexOf(':');
    if (colonIndex > 0) {
      final key = line.substring(0, colonIndex).trim().toLowerCase();
      final value = line.substring(colonIndex + 1).trim();
      headers[key] = value;
    }
  }

  return (body, headers);
}

/// 在 Isolate 中执行的 curl 请求（同步阻塞）
_CurlResponseData _curlRequestInIsolate(_CurlRequestParams params) {
  final DynamicLibrary lib;
  try {
    lib = DynamicLibrary.open(
      'libcurl-11bfc6a4136d7ce248863d4c5ef4c6be.dll',
    );
  } catch (e) {
    throw Exception('加载 libcurl DLL 失败: $e');
  }

  final curlInit = lib.lookupFunction<_CurlInitNative, _CurlInitDart>('curl_easy_init');
  final curlSetopt = lib.lookupFunction<_CurlSetoptNative, _CurlSetoptDart>('curl_easy_setopt');
  final curlImpersonate = lib.lookupFunction<_CurlImpersonateNative, _CurlImpersonateDart>('curl_easy_impersonate');
  final curlPerform = lib.lookupFunction<_CurlPerformNative, _CurlPerformDart>('curl_easy_perform');
  final curlCleanup = lib.lookupFunction<_CurlCleanupNative, _CurlCleanupDart>('curl_easy_cleanup');
  final curlGetinfo = lib.lookupFunction<_CurlGetinfoNative, _CurlGetinfoDart>('curl_easy_getinfo');
  final slistAppend = lib.lookupFunction<_SlistAppendNative, _SlistAppendDart>('curl_slist_append');
  final slistFreeAll = lib.lookupFunction<_SlistFreeAllNative, _SlistFreeAllDart>('curl_slist_free_all');

  final handle = curlInit();
  if (handle == nullptr) {
    throw Exception('curl_easy_init failed');
  }

  // 注册全局写缓冲区
  _globalWriteBuffer = BytesBuilder();

  final writeCbPointer = Pointer.fromFunction<_WriteCallbackNative>(_writeCallback, 0);

  Pointer<Void> slist = nullptr;
  Pointer<Utf8>? urlPtr;
  Pointer<Utf8>? bodyPtr;
  Pointer<Utf8>? proxyPtr;
  Pointer<Utf8>? impersonateTarget;

  try {
    // 基本设置
    urlPtr = params.url.toNativeUtf8();
    curlSetopt(handle, _curloptUrl, urlPtr.cast());
    curlSetopt(handle, _curloptWritefunction, writeCbPointer.cast());

    // 启用 verbose 日志（输出到 stderr）
    curlSetopt(handle, _curloptVerbose, Pointer<Void>.fromAddress(1));

    // 将响应头包含在 body 中，后续解析分离
    curlSetopt(handle, _curloptHeader, Pointer<Void>.fromAddress(1));

    // TLS 指纹伪装
    impersonateTarget = 'chrome120'.toNativeUtf8();
    curlImpersonate(handle, impersonateTarget, 1);

    // 禁用 SSL 证书验证（与原 SourceFetcher 的 badCertificateCallback 一致）
    curlSetopt(handle, _curloptSslVerifypeer, Pointer<Void>.fromAddress(0));
    curlSetopt(handle, _curloptSslVerifyhost, Pointer<Void>.fromAddress(0));

    // 启用自动解压（空字符串 = curl 自动选择支持的编码）
    final emptyStr = ''.toNativeUtf8();
    curlSetopt(handle, _curloptAcceptEncoding, emptyStr.cast());
    calloc.free(emptyStr);

    // 自动跟随重定向
    curlSetopt(handle, _curloptFollowlocation, Pointer<Void>.fromAddress(1));

    // 超时
    curlSetopt(handle, _curloptTimeout, Pointer<Void>.fromAddress(params.timeoutSeconds));

    // 自定义请求头
    if (params.headers.isNotEmpty) {
      for (final entry in params.headers.entries) {
        final headerStr = '${entry.key}: ${entry.value}';
        final headerPtr = headerStr.toNativeUtf8();
        slist = slistAppend(slist, headerPtr);
        calloc.free(headerPtr);
      }
      curlSetopt(handle, _curloptHttpheader, slist);
    }

    // 代理
    if (params.proxy != null && params.proxy!.isNotEmpty) {
      proxyPtr = params.proxy!.toNativeUtf8();
      curlSetopt(handle, _curloptProxy, proxyPtr.cast());
    }

    // POST 请求
    if (params.method == 'POST' && params.body != null) {
      curlSetopt(handle, _curloptPost, Pointer<Void>.fromAddress(1));
      bodyPtr = params.body!.toNativeUtf8();
      curlSetopt(handle, _curloptPostfields, bodyPtr.cast());
      curlSetopt(handle, _curloptPostfieldsize,
          Pointer<Void>.fromAddress(params.body!.length));
    }

    // 执行请求
    final result = curlPerform(handle);
    if (result != 0) {
      throw Exception('curl_easy_perform failed: $result');
    }

    // 获取状态码
    final codePtr = calloc<Int32>();
    curlGetinfo(handle, _curlinfoResponsecode, codePtr.cast());
    final statusCode = codePtr.value;
    calloc.free(codePtr);

    // 获取原始响应（包含 HTTP 头 + body），用 UTF-8 解码
    final rawBytes = _globalWriteBuffer!.takeBytes();
    final rawResponse = utf8.decode(rawBytes, allowMalformed: true);

    // 分离 HTTP 头和 body
    final (body, responseHeaders) = _splitHeadersAndBody(rawResponse);

    return _CurlResponseData(
      statusCode: statusCode,
      body: body,
      headers: responseHeaders,
      rawLength: rawBytes.length,
    );
  } finally {
    if (slist != nullptr) slistFreeAll(slist);
    if (urlPtr != null) calloc.free(urlPtr);
    if (bodyPtr != null) calloc.free(bodyPtr);
    if (proxyPtr != null) calloc.free(proxyPtr);
    if (impersonateTarget != null) calloc.free(impersonateTarget);
    _globalWriteBuffer = null;
    curlCleanup(handle);
  }
}

/// Windows 平台 Dio HttpClientAdapter
///
/// 底层通过 FFI 调用 libcurl-impersonate，实现 TLS 指纹伪装（Chrome 120）
/// 通过 Isolate.run 执行同步 FFI 调用，避免阻塞 UI
class WinCurlAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 读取请求体
    String? body;
    if (requestStream != null) {
      final chunks = <List<int>>[];
      await for (final chunk in requestStream) {
        chunks.add(chunk);
      }
      final bytes = chunks.expand((c) => c).toList();
      body = String.fromCharCodes(bytes);
    } else if (options.data is String) {
      body = options.data as String;
    } else if (options.data is Map) {
      body = Uri(queryParameters: Map<String, dynamic>.from(options.data as Map)).query;
    }

    // 代理配置
    final appStore = useAppStore();
    String? proxy;
    if (appStore.state.enableProxy && appStore.state.proxyHost.isNotEmpty) {
      proxy = '${appStore.state.proxyHost}:${appStore.state.proxyPort}';
    }

    // 构建请求参数
    final params = _CurlRequestParams(
      url: options.uri.toString(),
      method: options.method,
      headers: options.headers.map((k, v) => MapEntry(k, v.toString())),
      body: body,
      timeoutSeconds: (options.receiveTimeout?.inSeconds ?? 15).clamp(1, 300),
      proxy: proxy,
    );

    // 在 Isolate 中执行
    final _CurlResponseData data;
    try {
      data = await Isolate.run(() => _curlRequestInIsolate(params));
    } catch (e) {
      rethrow;
    }

    // 转换 headers 为 Dio 期望的格式 Map<String, List<String>>
    final headersMap = <String, List<String>>{};
    for (final entry in data.headers.entries) {
      headersMap[entry.key] = [entry.value];
    }

    return ResponseBody.fromString(
      data.body,
      data.statusCode,
      headers: headersMap,
    );
  }

  @override
  void close({bool force = false}) {}
}
