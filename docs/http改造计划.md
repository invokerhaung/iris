# Flutter 跨平台 TLS 指纹伪装网络请求方案

## 一、 架构总览

采用**接口抽象 + 工厂分发**模式，业务层完全不感知底层差异。

- **统一入口**：业务层调用 `NetworkService.get(url)`
- **Windows 端**：Dart FFI 调用 `libcurl-impersonate`，通过子 Isolate 执行避免 UI 卡顿。
- **Android 端**：`Dio` + `cronet_http`，原生异步，借用系统 Chrome 内核。

## 二、 第一步：项目准备与依赖

### 1. 添加依赖 (`pubspec.yaml`)

```
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  cronet_http: ^1.2.0
  ffi: ^2.1.0
```

### 2. 放置 Windows DLL

将之前提取的 11 个 DLL 文件（以 `libcurl-11bfc...dll` 为主库）全部放入：
`你的项目/windows/runner/lib` 目录下。

### 3. 修改 CMake 配置 (`windows/runner/CMakeLists.txt`)

在文件末尾追加以下代码，确保打包时 DLL 被复制到运行目录：

```
# 拷贝 curl-impersonate 依赖 DLL
set(IMPERSONATE_DLLS
  "${CMAKE_CURRENT_SOURCE_DIR}/libcurl-11bfc6a4136d7ce248863d4c5ef4c6be.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/libnghttp2-14-a5a14079d5e6f7e02bdea4c68e15625e.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/libbrotlidec-252c2f843d5224cc9b1ee9be5b889404.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/libbrotlicommon-9015c7e64e1216016fe7f8f27253ab5a.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/libzstd-4a24f8e0e538f6782383866e3242d5c7.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/zlib1-14685ce489c41d0eb9cd110148c86d46.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/libpsl-5-8e6d3ac480752bbffa34ca209d96a185.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/libidn2-0-8086a128bb32ed858feb3e2a888df65b.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/libunistring-5-bade1bc819b29d8ddf30ff7be6a66e53.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/libiconv-2-657ca3a64139260fa69df2a4af38e3d9.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/libintl-8-bc88842044f5ddc85d72473aa45dc56a.dll"
)
foreach(dll ${IMPERSONATE_DLLS})
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${dll}" "$<TARGET_FILE_DIR:${BINARY_NAME}>")
endforeach()
```

## 三、 核心代码实现

### 1. 统一接口定义 (`network_service.dart`)

```
abstract class NetworkService {
  Future<String> get(String url, {Map<String, String>? headers});
}
```

### 2. Windows 实现：FFI + Isolate (`win_curl_service.dart`)

**核心逻辑**：FFI 封装为**同步方法**，然后通过 `Isolate.run` 将其丢入子线程执行，防止阻塞 UI。

```
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'network_service.dart';

// --- FFI 签名定义 ---
typedef _CurlInitC = Pointer<Void> Function();
typedef _CurlInitDart = Pointer<Void> Function();

typedef _CurlSetoptC = Int32 Function(Pointer<Void>, Int32, Pointer<Void>);
typedef _CurlSetoptDart = int Function(Pointer<Void>, int, Pointer<Void>);

typedef _CurlImpersonateC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32);
typedef _CurlImpersonateDart = int Function(Pointer<Void>, Pointer<Utf8>, int);

typedef _CurlPerformC = Int32 Function(Pointer<Void>);
typedef _CurlPerformDart = int Function(Pointer<Void>);

typedef _CurlCleanupC = Void Function(Pointer<Void>);
typedef _CurlCleanupDart = void Function(Pointer<Void>);

typedef _WriteCallbackC = Size Function(Pointer<Uint8>, Size, Size, Pointer<Void>);
typedef _WriteCallbackDart = int Function(Pointer<Uint8>, int, int, Pointer<Void>);

class WinCurlService implements NetworkService {
  // 顶层静态函数，供 Isolate 执行（必须接收/返回基本类型）
  static String _syncGetInIsolate(String url) {
    final lib = DynamicLibrary.open('libcurl-11bfc6a4136d7ce248863d4c5ef4c6be.dll');
    
    final curlInit = lib.lookupFunction<_CurlInitC, _CurlInitDart>('curl_easy_init');
    final curlSetopt = lib.lookupFunction<_CurlSetoptC, _CurlSetoptDart>('curl_easy_setopt');
    final curlImpersonate = lib.lookupFunction<_CurlImpersonateC, _CurlImpersonateDart>('curl_easy_impersonate');
    final curlPerform = lib.lookupFunction<_CurlPerformC, _CurlPerformDart>('curl_easy_perform');
    final curlCleanup = lib.lookupFunction<_CurlCleanupC, _CurlCleanupDart>('curl_easy_cleanup');

    final handle = curlInit();
    if (handle == nullptr) throw Exception('curl init failed');

    final bytesBuilder = BytesBuilder();

    // 写回调：将 C 内存拷贝到 Dart
    int writeCallback(Pointer<Uint8> ptr, int size, int nmemb, Pointer<Void> userdata) {
      bytesBuilder.add(ptr.asTypedList(size * nmemb));
      return size * nmemb;
    }
    final nativeCb = Pointer.fromFunction<_WriteCallbackC>(writeCallback, 0);

    // 设置参数
    const CURLOPT_URL = 10002;
    const CURLOPT_WRITEFUNCTION = 20011;
    
    final urlPtr = url.toNativeUtf8();
    curlSetopt(handle, CURLOPT_URL, urlPtr.cast());
    curlSetopt(handle, CURLOPT_WRITEFUNCTION, nativeCb.cast());

    // ⭐ 核心伪装：伪装成 Chrome 120
    final targetPtr = 'chrome120'.toNativeUtf8();
    curlImpersonate(handle, targetPtr, 1);

    // 执行请求 (阻塞点)
    int result = curlPerform(handle);

    // 清理内存
    curlCleanup(handle);
    calloc.free(urlPtr);
    calloc.free(targetPtr);

    if (result != 0) throw Exception('Request failed: $result');
    return String.fromCharCodes(bytesBuilder.takeBytes());
  }

  @override
  Future<String> get(String url, {Map<String, String>? headers}) async {
    // 将同步阻塞请求扔进 Isolate 执行，UI 不卡顿
    return await Isolate.run(() => _syncGetInIsolate(url));
  }
}
```

### 3. Android 实现：Dio + Cronet (`android_dio_service.dart`)

**核心逻辑**：用 Cronet 替换 Dio 底层，原生异步。

```
import 'package:dio/dio.dart';
import 'package:cronet_http/cronet_http.dart';
import 'network_service.dart';

class AndroidDioService implements NetworkService {
  late final Dio _dio;

  AndroidDioService() {
    final cronetEngine = CronetEngine.build(
      cacheMode: CacheMode.memory,
      cacheMaxSize: 10 * 1024 * 1024,
      userAgent: 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    );

    final httpClient = CronetHttpClient.fromCronetEngine(cronetEngine);
    
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _dio.httpClientAdapter = HttpClientAdapterImpl(httpClient);
  }

  @override
  Future<String> get(String url, {Map<String, String>? headers}) async {
    final response = await _dio.get<String>(url, options: Options(headers: headers));
    return response.data ?? '';
  }
}
```

### 4. 工厂分发注入 (`network_factory.dart`)

在入口处根据平台初始化对应的实现类。

```
import 'dart:io';
import 'network_service.dart';
// import 'win_curl_service.dart';
// import 'android_dio_service.dart';

class NetworkFactory {
  static NetworkService? _instance;

  static NetworkService get instance {
    if (_instance != null) return _instance!;
    
    if (Platform.isWindows) {
      _instance = WinCurlService();
    } else if (Platform.isAndroid) {
      _instance = AndroidDioService();
    } else {
      throw UnsupportedError('当前平台不支持');
    }
    return _instance!;
  }
}
```

## 四、 业务层调用方式

在你的页面或 ViewModel 中，完全不需要写任何 `if/else` 判断平台：

```
void fetchWebsiteData() async {
  try {
    String html = await NetworkFactory.instance.get('https://tls.peet.ws/api/clean') ;
    print('获取成功: $html');
  } catch (e) {
    print('获取失败: $e');
  }
}
```

## 五、 开发与排查指南

1. **验证指纹是否生效**：运行后请求 `https://tls.peet.ws/api/clean`，如果返回的 JSON 里 `ja3` 和 `ja4` 变成了标准 Chrome 的特征，说明 Windows 和 Android 双端指纹伪装均成功。
2. **WinError 126 报错**：如果 Windows 端启动即崩溃报找不到模块，说明 DLL 没拷全，或者没有放在 `.exe` 同级目录下。检查 `CMakeLists.txt` 是否配置正确。
3. **内存泄漏排查**：Windows 端开发时，在循环调用 `get` 的情况下打开 Windows 任务管理器，如果内存不断上涨，检查 `curl_easy_cleanup` 和 `calloc.free` 是否漏写。
4. **超时控制**：当前 FFI 代码未体现超时控制。可以在 FFI 中增加 `CURLOPT_TIMEOUT` (宏值 13) 来设置 C 层的硬超时，防止网络挂死导致 Isolate 无法退出。