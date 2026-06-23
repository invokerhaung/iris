# HTTP 改造计划 — 实施方案

## 一、改造目标

将项目中排除 WebDAV 以外的所有 HTTP 请求统一到 `NetworkService` 抽象层，所有平台统一使用 Dio 作为 HTTP 基础框架：
- Windows 端：Dio + 自定义 `HttpClientAdapter`（底层通过 FFI 调用 `libcurl-impersonate` + Isolate），实现 TLS 指纹伪装
- Android 端：Dio + `cronet_http`（Cronet adapter），借用系统 Chrome 内核
- 其他平台（Linux/macOS/iOS）：Dio 默认 adapter，无特殊处理
- 业务层统一调用 `NetworkService.get()` / `NetworkService.post()`

## 二、现状分析

### 当前 HTTP 使用点（共 3 个文件）

| 文件 | 用途 | 当前方式 | 代理支持 |
|---|---|---|---|
| `lib/utils/source_fetcher.dart` | 书源抓取（搜索、发现、详情、正文） | `http.Client` / `IOClient` | ✅ |
| `lib/store/use_source_store.dart` | 源导入（URL 下载）、源可用性测试 | `http.get` 直接调用 | ❌ |
| `lib/utils/get_latest_release.dart` | GitHub 更新检查 | `http.get` 直接调用 | ❌ |

### 已有资源

- `windows/runner/lib/` 下已有 11 个 libcurl-impersonate DLL
- CMakeLists.txt 中**缺少** DLL 复制命令（需补充）

## 三、目标架构

```
业务层 (SourceFetcher / SourceStore / getLatestRelease)
    │
    ▼
NetworkService (抽象接口，基于 Dio)
    │
    ├── NetworkFactory.instance  (平台分发单例)
    │       │
    │       ├── Windows   → DioNetworkService (Dio + WinCurlAdapter FFI + Isolate)
    │       ├── Android   → DioNetworkService (Dio + CronetAdapter)
    │       └── 其他平台  → DioNetworkService (Dio 默认 adapter)
    │
    └── NetworkResult (统一响应模型)
```

所有平台共享 `DioNetworkService` 实现，差异仅在 `HttpClientAdapter` 层：
- Windows：自定义 adapter，FFI 调用 curl-impersonate（Isolate 内执行）
- Android：`CronetHttpClient` adapter
- 其他：Dio 默认 `IOHttpClientAdapter`

## 四、实施步骤

### 步骤 1：添加依赖

**文件：`pubspec.yaml`**

```yaml
dependencies:
  dio: ^5.4.0
  cronet_http: ^1.2.0
```

### 步骤 2：CMake 配置 — DLL 自动复制

**文件：`windows/runner/CMakeLists.txt`**

在文件末尾追加 DLL 复制命令，确保构建时 DLL 被复制到 .exe 同级目录：

```cmake
# 拷贝 curl-impersonate 依赖 DLL
set(IMPERSONATE_DLLS
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libcurl-11bfc6a4136d7ce248863d4c5ef4c6be.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libnghttp2-14-a5a14079d5e6f7e02bdea4c68e15625e.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbrotlidec-252c2f843d5224cc9b1ee9be5b889404.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbrotlicommon-9015c7e64e1216016fe7f8f27253ab5a.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libzstd-4a24f8e0e538f6782383866e3242d5c7.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/zlib1-14685ce489c41d0eb9cd110148c86d46.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libpsl-5-8e6d3ac480752bbffa34ca209d96a185.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libidn2-0-8086a128bb32ed858feb3e2a888df65b.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libunistring-5-bade1bc819b29d8ddf30ff7be6a66e53.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libiconv-2-657ca3a64139260fa69df2a4af38e3d9.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/lib/libintl-8-bc88842044f5ddc85d72473aa45dc56a.dll"
)
foreach(dll ${IMPERSONATE_DLLS})
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${dll}" "$<TARGET_FILE_DIR:${BINARY_NAME}>")
endforeach()
```

### 步骤 3：创建 NetworkService 抽象接口

**新建文件：`lib/utils/network/network_service.dart`**

定义统一的网络请求接口，扩展原方案以支持当前业务需求：

```dart
/// 统一网络请求接口
abstract class NetworkService {
  /// GET 请求
  Future<NetworkResult> get(String url, {Map<String, String>? headers, Duration? timeout});

  /// POST 请求
  Future<NetworkResult> post(String url, {Map<String, String>? headers, Object? body, Duration? timeout});
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

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  String? get contentType => headers['content-type'];
  bool get isHtml => contentType?.contains('text/html') ?? false;
  bool get isJson => contentType?.contains('application/json') ?? false;
}

/// 网络请求异常
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
```

### 步骤 4：Windows DioAdapter — WinCurlAdapter

**新建文件：`lib/utils/network/win_curl_adapter.dart`**

自定义 `HttpClientAdapter`，底层 FFI 封装 libcurl-impersonate，通过 `Isolate.run` 避免阻塞 UI：

- 实现 `HttpClientAdapter` 接口（`fetch` 方法）
- 内部 FFI 加载 `libcurl-11bfc6a4136d7ce248863d4c5ef4c6be.dll`
- FFI 绑定：`curl_easy_init`、`curl_easy_setopt`、`curl_easy_impersonate`、`curl_easy_perform`、`curl_easy_cleanup`
- 核心伪装：`curl_easy_impersonate(handle, "chrome120", 1)` 伪装 Chrome 120 TLS 指纹
- 将 Dio 的 `RequestOptions` 转换为 curl 参数（URL、headers、method、timeout、proxy）
- 通过 `Isolate.run` 执行同步 FFI 调用，返回 Dio 的 `ResponseBody`
- 支持自定义 headers、timeout（`CURLOPT_TIMEOUT` 宏值 13）
- 支持代理（复用 AppStore 的 proxy 配置，通过 `CURLOPT_PROXY` 设置）

### 步骤 5：DioNetworkService 统一实现

**新建文件：`lib/utils/network/dio_network_service.dart`**

所有平台共享的 `NetworkService` 实现，差异仅在构造时注入的 adapter：

```dart
class DioNetworkService implements NetworkService {
  late final Dio _dio;

  DioNetworkService({HttpClientAdapter? adapter}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
    }
  }

  @override
  Future<NetworkResult> get(String url, {Map<String, String>? headers, Duration? timeout}) async {
    final response = await _dio.get<String>(url,
      options: Options(headers: headers, receiveTimeout: timeout),
    );
    return NetworkResult(
      statusCode: response.statusCode ?? 0,
      body: response.data ?? '',
      headers: response.headers.map.map((k, v) => MapEntry(k, v.join(', '))),
      url: url,
    );
  }

  @override
  Future<NetworkResult> post(String url, {Map<String, String>? headers, Object? body, Duration? timeout}) async {
    final response = await _dio.post<String>(url,
      data: body,
      options: Options(headers: headers, receiveTimeout: timeout),
    );
    return NetworkResult(
      statusCode: response.statusCode ?? 0,
      body: response.data ?? '',
      headers: response.headers.map.map((k, v) => MapEntry(k, v.join(', '))),
      url: url,
    );
  }
}
```

### 步骤 6：平台分发工厂

**新建文件：`lib/utils/network/network_factory.dart`**

```dart
class NetworkFactory {
  static NetworkService? _instance;

  static NetworkService get instance {
    if (_instance != null) return _instance!;
    if (Platform.isWindows) {
      _instance = DioNetworkService(adapter: WinCurlAdapter());
    } else if (Platform.isAndroid) {
      final cronetEngine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 10 * 1024 * 1024,
      );
      _instance = DioNetworkService(adapter: CronetHttpClient.fromCronetEngine(cronetEngine));
    } else {
      _instance = DioNetworkService(); // Dio 默认 adapter
    }
    return _instance!;
  }
}
```

所有平台统一使用 `DioNetworkService`，差异仅在 adapter 注入。

### 步骤 7：重构 SourceFetcher

**修改文件：`lib/utils/source_fetcher.dart`**

改造点：
- 移除 `http.Client` / `IOClient` 依赖
- `_createClient()` → 改为通过 `NetworkFactory.instance` 发起请求
- `get()` / `post()` 内部调用 `NetworkService.get()` / `NetworkService.post()`
- `FetchResult` 保留但内部改为包装 `NetworkResult`（或直接复用 `NetworkResult`）
- `_buildHeaders()` 逻辑不变（源配置的自定义 header 仍需解析）
- 代理配置统一由底层 `NetworkService` 实现处理，`SourceFetcher` 不再感知

### 步骤 8：重构 use_source_store.dart

**修改文件：`lib/store/use_source_store.dart`**

改造点：
- `importSources()` 第 486 行：`http.get` → `NetworkFactory.instance.get()`
- `testSource()` 第 681 行：`http.get` → `NetworkFactory.instance.get()`
- 移除 `import 'package:http/http.dart' as http;`
- 这两处现在自动获得代理和 TLS 指纹伪装支持

### 步骤 9：重构 get_latest_release.dart

**修改文件：`lib/utils/get_latest_release.dart`**

改造点：
- 第 41 行：`http.get` → `NetworkFactory.instance.get()`
- 移除 `import 'package:http/http.dart' as http;`
- 更新检查现在自动获得代理和 TLS 指纹伪装支持

### 步骤 10：清理依赖

**文件：`pubspec.yaml`**

- 添加 `dio`、`cronet_http`
- `http` 包可移除 — 改造后项目代码不再直接使用 `package:http`，`webdav_client` 会自行依赖它

## 五、新增文件清单

| 文件路径 | 说明 |
|---|---|
| `lib/utils/network/network_service.dart` | 抽象接口 + NetworkResult + NetworkException |
| `lib/utils/network/win_curl_adapter.dart` | Windows Dio HttpClientAdapter（FFI + Isolate） |
| `lib/utils/network/dio_network_service.dart` | Dio 统一实现（所有平台共享） |
| `lib/utils/network/network_factory.dart` | 平台分发工厂 |

## 六、修改文件清单

| 文件路径 | 改动说明 |
|---|---|
| `pubspec.yaml` | 添加 `dio`、`cronet_http` |
| `windows/runner/CMakeLists.txt` | 追加 DLL 复制命令 |
| `lib/utils/source_fetcher.dart` | 移除 http.Client，改用 NetworkService |
| `lib/store/use_source_store.dart` | `http.get` → NetworkService |
| `lib/utils/get_latest_release.dart` | `http.get` → NetworkService |

## 七、验收标准

1. **Windows 构建通过**：`flutter build windows` 成功，DLL 被正确复制到输出目录
2. **Android 构建通过**：`flutter build apk --split-per-abi` 成功
3. **TLS 指纹验证**：请求 `https://tls.peet.ws/api/clean`，返回的 `ja3`/`ja4` 为标准 Chrome 特征
4. **代理验证**：开启代理后，源导入、源测试、更新检查均走代理
5. **功能验证**：
   - 源导入（URL）正常工作
   - 源可用性测试正常工作
   - 源校验（搜索/发现/详情/目录/正文）正常工作
   - 更新检查正常工作
6. **静态分析通过**：`flutter analyze` 无新增 warning/error
