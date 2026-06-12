import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/pages/files/files_page.dart';
import 'package:iris/pages/player/player_view.dart';
import 'package:iris/pages/settings/settings_page.dart';
import 'package:iris/store/use_app_store.dart';
import 'package:iris/utils/get_localizations.dart';

class Shell extends HookWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final currentTab =
        useAppStore().select(context, (state) => state.currentTab);
    final playerBackend =
        useAppStore().select(context, (state) => state.playerBackend);

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.folder_outlined),
        selectedIcon: const Icon(Icons.folder_rounded),
        label: t.files,
      ),
      NavigationDestination(
        icon: const Icon(Icons.play_circle_outline_rounded),
        selectedIcon: const Icon(Icons.play_circle_filled_rounded),
        label: t.play,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings_rounded),
        label: t.settings,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: currentTab,
        children: [
          const FilesPage(),
          PlayerView(playerBackend: playerBackend),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (index) =>
            useAppStore().updateCurrentTab(index),
        destinations: destinations,
      ),
    );
  }
}
