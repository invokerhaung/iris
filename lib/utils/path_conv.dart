import 'package:path/path.dart' as p;

List<String> pathConv(String path) {
  try {
    String normalizedPath = p.normalize(path.trim());

    if (normalizedPath.isEmpty || normalizedPath == '.') {
      return [];
    }

    if (normalizedPath == '/' || normalizedPath == '\\') {
      return ['/'];
    }

    final List<String> result = normalizedPath
        .replaceAll('\\', '/')
        .split('/')
        .where((element) => element.isNotEmpty)
        .toList();

    if (path.startsWith('\\\\')) {
      return ['\\\\${result[0]}', ...result.sublist(1)];
    }

    if (path.startsWith('/')) {
      return ['/', ...result];
    }

    return result;
  } on FormatException {
    return [];
  }
}
