# Legado Go Analyzer FFI

Flutter FFI 桥接层，将 Go 解析引擎导出为 C 共享库。

## 编译要求

### Windows
```bash
# Ubuntu/Debian
sudo apt install gcc-mingw-w64-x86-64

# macOS
brew install mingw-w64
```

### Android
需要安装 Android NDK，并设置环境变量：
```bash
export ANDROID_NDK_HOME=/path/to/android-ndk
```

### Linux (本地测试)
```bash
sudo apt install gcc
```

## 编译命令

### 使用编译脚本
```bash
# 编译 Windows x64 DLL
./build_ffi.sh windows64

# 编译 Android ARM64 SO
./build_ffi.sh android64

# 编译所有平台
./build_ffi.sh all
```

### 手动编译

#### Windows x64
```bash
CGO_ENABLED=1 \
GOOS=windows \
GOARCH=amd64 \
CC=x86_64-w64-mingw32-gcc \
go build -buildmode=c-shared \
    -o build/legado_ffi.dll \
    ./ffi/
```

#### Windows x86
```bash
CGO_ENABLED=1 \
GOOS=windows \
GOARCH=386 \
CC=i686-w64-mingw32-gcc \
go build -buildmode=c-shared \
    -o build/legado_ffi.dll \
    ./ffi/
```

#### Android ARM64
```bash
CGO_ENABLED=1 \
GOOS=android \
GOARCH=arm64 \
CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang \
go build -buildmode=c-shared \
    -o build/liblegado_ffi.so \
    ./ffi/
```

#### Android ARMv7
```bash
CGO_ENABLED=1 \
GOOS=android \
GOARCH=arm \
GOARM=7 \
CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang \
go build -buildmode=c-shared \
    -o build/liblegado_ffi.so \
    ./ffi/
```

#### Linux (本地测试)
```bash
CGO_ENABLED=1 \
GOOS=linux \
GOARCH=amd64 \
go build -buildmode=c-shared \
    -o build/liblegado_ffi.so \
    ./ffi/
```

## 输出文件

编译后会生成两个文件：
- `legado_ffi.dll` / `liblegado_ffi.so` - 共享库文件
- `legado_ffi.h` / `liblegado_ffi.h` - C 头文件

## 导出函数

### 日志系统

日志系统在库加载时自动初始化，无需手动调用。日志文件输出到调用程序同目录，文件名为 `<程序名>.log`。进程退出时自动关闭日志文件。

### Analyzer (解析引擎)

| 函数 | 说明 |
|------|------|
| `AnalyzerNew(ruleDataID, sourceID)` | 创建解析器实例 |
| `AnalyzerSetContent(id, content, baseUrl)` | 设置解析内容 |
| `AnalyzerSetRedirectUrl(id, url)` | 设置重定向 URL |
| `AnalyzerGetString(id, rule)` | 获取单个文本 |
| `AnalyzerGetStringList(id, rule)` | 获取文本列表 (JSON) |
| `AnalyzerGetElement(id, rule)` | 获取单个元素 |
| `AnalyzerGetElements(id, rule)` | 获取元素列表 |
| `AnalyzerFree(id)` | 释放实例 |

### RuleData (变量存储)

| 函数 | 说明 |
|------|------|
| `RuleDataNew()` | 创建变量存储 |
| `RuleDataPut(id, key, value)` | 保存变量 |
| `RuleDataGet(id, key)` | 获取变量 |
| `RuleDataFree(id)` | 释放实例 |

### JS Engine (JavaScript)

| 函数 | 说明 |
|------|------|
| `JSNew()` | 创建 JS 引擎 |
| `JSExec(id, code, varsJSON)` | 执行 JS 代码 |
| `JSExecWithResult(id, code, result)` | 带 result 执行 |
| `JSFree(id)` | 释放实例 |

### URL Analyzer (URL 解析)

| 函数 | 说明 |
|------|------|
| `URLNew(url, optionsJSON)` | 创建 URL 解析器 |
| `URLGetURL(id)` | 获取完整 URL |
| `URLGetURLNoQuery(id)` | 获取无查询参数 URL |
| `URLGetMethod(id)` | 获取请求方法 |
| `URLGetBody(id)` | 获取请求体 |
| `URLGetEncodedQuery(id)` | 获取编码后的查询参数 |
| `URLFree(id)` | 释放实例 |

## Dart 调用示例

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// 加载动态库
final dylib = DynamicLibrary.open('legado_ffi.dll');

// 日志系统在库加载时自动初始化，无需手动调用
// 日志文件：与调用程序同目录，文件名为 <程序名>.log

// 使用示例：创建解析器并获取元素
typedef AnalyzerNewNative = Int64 Function(Int64, Int64);
typedef AnalyzerNewDart = int Function(int, int);
final analyzerNew = dylib.lookupFunction<AnalyzerNewNative, AnalyzerNewDart>('AnalyzerNew');

typedef SetContentNative = Pointer<Utf8> Function(Int64, Pointer<Utf8>, Pointer<Utf8>);
typedef SetContentDart = Pointer<Utf8> Function(int, Pointer<Utf8>, Pointer<Utf8>);
final setContent = dylib.lookupFunction<SetContentNative, SetContentDart>('AnalyzerSetContent');

typedef GetElementsNative = Pointer<Utf8> Function(Int64, Pointer<Utf8>);
typedef GetElementsDart = Pointer<Utf8> Function(int, Pointer<Utf8>);
final getElements = dylib.lookupFunction<GetElementsNative, GetElementsDart>('AnalyzerGetElements');

typedef FreeStringNative = Void Function(Pointer<Utf8>);
typedef FreeStringDart = void Function(Pointer<Utf8>);
final freeString = dylib.lookupFunction<FreeStringNative, FreeStringDart>('FreeString');

// 调用示例
final analyzerId = analyzerNew(0, 0);
final content = '<html><body><ul><li>item1</li><li>item2</li></ul></body></html>'.toNativeUtf8();
final baseUrl = 'https://example.com'.toNativeUtf8();
setContent(analyzerId, content, baseUrl);

final rule = '@css:li'.toNativeUtf8();
final resultPtr = getElements(analyzerId, rule);
final result = resultPtr.toDartString(); // JSON 数组: ["<li>item1</li>","<li>item2</li>"]

// 释放内存
malloc.free(content);
malloc.free(baseUrl);
malloc.free(rule);
freeString(resultPtr);
```

## 日志调试

日志系统自动初始化，无需手动调用任何函数。

1. 运行 Flutter 应用

2. 查看日志文件 `<程序名>.log`（与可执行文件同目录），格式：
   ```
   [LEGADO] 2024/01/01 12:00:00 [INFO] 日志初始化完成，文件: /path/to/app.log
   [LEGADO] 2024/01/01 12:00:00 [INFO] AnalyzerNew: 创建成功, id=1
   [LEGADO] 2024/01/01 12:00:00 [DEBUG] AnalyzerGetElements(id=1, rule=@css:li)
   [LEGADO] 2024/01/01 12:00:00 [DEBUG] AnalyzerGetElements: 输入 rule=@css:li, 输出 ["<li>item1</li>","<li>item2</li>"] (耗时 1.234ms)
   ```

## 注意事项

1. **内存管理**：使用完毕后必须调用 `Free` 函数释放资源
2. **字符串编码**：所有字符串使用 UTF-8 编码
3. **线程安全**：所有函数都是线程安全的
4. **错误处理**：出错时返回空字符串，详细错误信息写入日志
5. **日志系统**：库加载时自动初始化，无需手动调用；进程退出时自动关闭日志文件
