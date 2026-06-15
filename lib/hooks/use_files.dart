import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/models/file.dart';
import 'package:iris/models/storages/storage.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/utils/files_sort.dart';

({List<FileItem> files, bool isLoading, bool isError, VoidCallback refresh})
    useFiles(Storage storage, List<String> currentPath) {
  final refreshState = useState(false);
  void refresh() => refreshState.value = !refreshState.value;

  final sortBy = useAppStore().select(useContext(), (s) => s.sortBy);
  final sortOrder = useAppStore().select(useContext(), (s) => s.sortOrder);
  final folderFirst = useAppStore().select(useContext(), (s) => s.folderFirst);

  final getFiles = useMemoized(
    () async => await storage.getFiles(currentPath),
    [currentPath, refreshState.value],
  );

  final result = useFuture(getFiles);
  final isLoading =
      useMemoized(() => result.connectionState == ConnectionState.waiting,
          [result.connectionState]);
  final isError = result.error != null;

  final filteredFiles = useMemoized(
    () => (result.data ?? [])
        .where((file) =>
            [ContentType.video, ContentType.audio].contains(file.type) ||
            file.isDir)
        .toList(),
    [result.data],
  );

  final files = useMemoized(
    () => filesSort(
      files: filteredFiles,
      sortBy: sortBy,
      sortOrder: sortOrder,
      folderFirst: folderFirst,
    ),
    [filteredFiles, sortBy, sortOrder, folderFirst],
  );

  return (files: files, isLoading: isLoading, isError: isError, refresh: refresh);
}
