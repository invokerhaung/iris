import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_storage_store.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/widgets/popups/storages/storages.dart';

class FilesPage extends HookWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final currentStorage =
        useStorageStore().select(context, (state) => state.currentStorage);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentStorage != null ? currentStorage.name : t.files),
        leading: currentStorage != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  useStorageStore().updateCurrentStorage(null);
                  useStorageStore().updateCurrentPath([]);
                },
              )
            : null,
      ),
      body: Storages(
        onPlay: () => useAppStore().updateCurrentTab(1),
        onClose: () {
          useStorageStore().updateCurrentStorage(null);
          useStorageStore().updateCurrentPath([]);
        },
      ),
    );
  }
}
