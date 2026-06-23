import 'dart:io';

import 'dio_network_service.dart';
import 'network_service.dart';
import 'win_curl_adapter.dart';

/// 网络服务工厂
///
/// 根据平台分发不同的 NetworkService 实现：
/// - Windows: Dio + WinCurlAdapter (FFI libcurl-impersonate, TLS 指纹伪装)
/// - Android: Dio 默认 adapter（后续可替换为 Cronet）
/// - 其他平台: Dio 默认 adapter
class NetworkFactory {
  static NetworkService? _instance;

  static NetworkService get instance {
    if (_instance != null) return _instance!;

    if (Platform.isWindows) {
      _instance = DioNetworkService(adapter: WinCurlAdapter());
    } else {
      // Android / Linux / macOS / iOS 统一使用 Dio 默认 adapter
      // Android 后续可通过注入 Cronet adapter 获得 Chrome 内核网络栈
      _instance = DioNetworkService();
    }

    return _instance!;
  }

  /// 重置实例（用于测试）
  static void reset() {
    _instance = null;
  }
}
