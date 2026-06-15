import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/hooks/use_files.dart';
import 'package:iris/models/file.dart';
import 'package:iris/models/storages/local.dart';
import 'package:iris/models/storages/storage.dart';
import 'package:iris/models/store/storage_state.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/store/use_history_store.dart';
import 'package:iris/store/use_play_queue_store.dart';
import 'package:iris/store/use_storage_store.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/widgets/media_card.dart';
import 'package:iris/widgets/popup.dart';
import 'package:iris/widgets/popups/history.dart';
import 'package:iris/widgets/storage_card.dart';

const double kCardSpacing = 9.0;
const double kMinCardWidth = 160.0;

class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final currentStorage =
        useStorageStore().select(context, (state) => state.currentStorage);
    final currentPath =
        useStorageStore().select(context, (state) => state.currentPath);
    final favorites =
        useStorageStore().select(context, (state) => state.favorites);

    final localStoragesFuture =
        useMemoized(() async => await getLocalStorages(context), []);
    final localStorages = useFuture(localStoragesFuture).data ?? [];

    final storages =
        useStorageStore().select(context, (state) => state.storages);

    final allStorages = useMemoized(
        () => [...localStorages, ...storages], [localStorages, storages]);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardCount = useMemoized(() {
      int count =
          ((screenWidth + kCardSpacing) / (kMinCardWidth + kCardSpacing))
              .floor();
      return count.clamp(2, 6);
    }, [screenWidth]);

    void playFile(List<FileItem> files, int index) async {
      final clickedFile = files[index];
      final filteredFiles = files
          .where((f) =>
              [ContentType.video, ContentType.audio].contains(f.type))
          .toList();
      final playQueue = filteredFiles
          .asMap()
          .entries
          .map((e) => PlayQueueItem(file: e.value, index: e.key))
          .toList();
      final newIndex = filteredFiles.indexOf(clickedFile);
      await useAppStore().updateAutoPlay(true);
      await useAppStore().updateShuffle(false);
      await usePlayQueueStore().update(playQueue: playQueue, index: newIndex);
      useAppStore().updateShowPlayer(true);
    }

    void openStorage(Storage storage) {
      useStorageStore().updateCurrentPath(storage.basePath);
      useStorageStore().updateCurrentStorage(storage);
    }

    void backToStorageList() {
      if (currentPath.length > (currentStorage?.basePath.length ?? 0)) {
        useStorageStore().updateCurrentPath(
            currentPath.sublist(0, currentPath.length - 1));
      } else {
        useStorageStore().updateCurrentStorage(null);
        useStorageStore().updateCurrentPath([]);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: currentStorage != null
            ? Text(currentStorage.name)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.png', width: 24, height: 24),
                  const SizedBox(width: 8),
                  const Text('IRIS'),
                ],
              ),
        leading: currentStorage != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: backToStorageList,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: t.history,
            onPressed: () => showPopup(
              context: context,
              child: const History(),
              direction: PopupDirection.right,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: t.settings,
            onPressed: () => useAppStore().updateCurrentTab(2),
          ),
        ],
      ),
      body: currentStorage != null
          ? _FilesGrid(
              storage: currentStorage,
              currentPath: currentPath,
              cardCount: cardCount,
              onPlay: playFile,
              onNavigate: (file) =>
                  useStorageStore().updateCurrentPath([...currentPath, file.name]),
              onBack: backToStorageList,
            )
          : _StoragesGrid(
              allStorages: allStorages,
              favorites: favorites,
              localStorages: localStorages,
              cardCount: cardCount,
              onOpenStorage: openStorage,
            ),
    );
  }
}

class _StoragesGrid extends HookWidget {
  const _StoragesGrid({
    required this.allStorages,
    required this.favorites,
    required this.localStorages,
    required this.cardCount,
    required this.onOpenStorage,
  });

  final List<Storage> allStorages;
  final List<Favorite> favorites;
  final List<Storage> localStorages;
  final int cardCount;
  final void Function(Storage) onOpenStorage;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    if (allStorages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_rounded,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withAlpha(128)),
            const SizedBox(height: 16),
            Text(
              t.noStorages,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withAlpha(180),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(kCardSpacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cardCount,
        crossAxisSpacing: kCardSpacing,
        mainAxisSpacing: kCardSpacing,
        childAspectRatio: 3 / 4,
      ),
      itemCount: allStorages.length,
      itemBuilder: (context, index) {
        return StorageCard(
          storage: allStorages[index],
          onTap: () => onOpenStorage(allStorages[index]),
        );
      },
    );
  }
}

class _FilesGrid extends HookWidget {
  const _FilesGrid({
    required this.storage,
    required this.currentPath,
    required this.cardCount,
    required this.onPlay,
    required this.onNavigate,
    required this.onBack,
  });

  final Storage storage;
  final List<String> currentPath;
  final int cardCount;
  final void Function(List<FileItem>, int) onPlay;
  final void Function(FileItem) onNavigate;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final colorScheme = Theme.of(context).colorScheme;
    final result = useFiles(storage, currentPath);

    if (result.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (result.isError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: colorScheme.error.withAlpha(180)),
            const SizedBox(height: 16),
            Text(t.unable_to_fetch_files),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: result.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t.retry),
            ),
          ],
        ),
      );
    }

    if (result.files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded,
                size: 64,
                color: colorScheme.onSurfaceVariant.withAlpha(128)),
            const SizedBox(height: 16),
            Text(
              t.unable_to_fetch_files,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withAlpha(180),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(kCardSpacing),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cardCount,
              crossAxisSpacing: kCardSpacing,
              mainAxisSpacing: kCardSpacing,
              childAspectRatio: 3 / 4,
            ),
            itemCount: result.files.length,
            itemBuilder: (context, index) {
              final file = result.files[index];

              if (file.isDir) {
                return MediaCard(
                  icon: Icons.folder_rounded,
                  title: file.name,
                  onTap: () => onNavigate(file),
                );
              }

              final progress = useHistoryStore().findById(file.getID());
              String? badge;
              if (progress != null && progress.file.type == ContentType.video) {
                if ((progress.duration.inMilliseconds -
                        progress.position.inMilliseconds) <=
                    5000) {
                  badge = '100%';
                } else {
                  badge =
                      '${(progress.position.inMilliseconds / progress.duration.inMilliseconds * 100).toStringAsFixed(0)}%';
                }
              }

              return MediaCard(
                icon: file.type == ContentType.video
                    ? Icons.movie_rounded
                    : Icons.audiotrack_rounded,
                title: file.name,
                badge: badge,
                onTap: () => onPlay(result.files, index),
              );
            },
          ),
        ),
        _Breadcrumb(
          storage: storage,
          currentPath: currentPath,
          onBack: onBack,
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.storage,
    required this.currentPath,
    required this.onBack,
  });

  final Storage storage;
  final List<String> currentPath;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withAlpha(64),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: t.back,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: onBack,
          ),
          IconButton(
            tooltip: t.home,
            icon: const Icon(Icons.home_rounded, size: 20),
            onPressed: () {
              useStorageStore().updateCurrentStorage(null);
              useStorageStore().updateCurrentPath([]);
            },
          ),
          Expanded(
            child: BreadCrumb.builder(
              itemCount: currentPath.length,
              overflow: const WrapOverflow(),
              builder: (index) {
                return BreadCrumbItem(
                  content: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      [
                        storage.basePath.length > 1
                            ? currentPath.first
                            : storage.name,
                        ...currentPath.sublist(1),
                      ][index],
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () {
                      useStorageStore()
                          .updateCurrentPath(currentPath.sublist(0, index + 1));
                    },
                  ),
                );
              },
              divider: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant.withAlpha(180),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
