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

| 函数 | 说明 |
|------|------|
| `LogInit(path)` | 初始化日志文件 |
| `LogSetEnabled(enabled)` | 启用/禁用日志 |
| `LogClose()` | 关闭日志文件 |

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

// 定义函数类型
typedef LogInitNative = Void Function(Pointer<Utf8>);
typedef LogInitDart = void Function(Pointer<Utf8>);

// 获取函数
final logInit = dylib.lookupFunction<LogInitNative, LogInitDart>('LogInit');

// 调用
final path = 'legado_ffi.log'.toNativeUtf8();
logInit(path);
malloc.free(path);
```

## 日志调试

1. 初始化日志：
   ```dart
   logInit('legado_ffi.log'.toNativeUtf8());
   ```

2. 运行 Flutter 应用

3. 查看日志文件 `legado_ffi.log`，格式：
   ```
   [LEGADO] 2024/01/01 12:00:00 [INFO] AnalyzerNew: 创建成功, id=1
   [LEGADO] 2024/01/01 12:00:00 [DEBUG] AnalyzerGetString(id=1, rule=h1@text)
   [LEGADO] 2024/01/01 12:00:00 [DEBUG] AnalyzerGetString: result="Hello" (耗时 1.234ms)
   ```

## 注意事项

1. **内存管理**：使用完毕后必须调用 `Free` 函数释放资源
2. **字符串编码**：所有字符串使用 UTF-8 编码
3. **线程安全**：所有函数都是线程安全的
4. **错误处理**：出错时返回空字符串，详细错误信息写入日志
