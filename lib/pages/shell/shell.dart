import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_zustand/flutter_zustand.dart';
import 'package:iris/pages/home/home_page.dart';
import 'package:iris/pages/player/player_view.dart';
import 'package:iris/pages/settings/settings_page.dart';
import 'package:iris/pages/sources/sources_page.dart';
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
    final showPlayer =
        useAppStore().select(context, (state) => state.showPlayer);

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.folder_outlined),
        selectedIcon: const Icon(Icons.folder_rounded),
        label: t.files,
      ),
      NavigationDestination(
        icon: const Icon(Icons.cloud_outlined),
        selectedIcon: const Icon(Icons.cloud_rounded),
        label: t.sources,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings_rounded),
        label: t.settings,
      ),
    ];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          body: IndexedStack(
            index: currentTab,
            children: const [
              HomePage(),
              SourcesPage(),
              SettingsPage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentTab,
            onDestinationSelected: (index) =>
                useAppStore().updateCurrentTab(index),
            destinations: destinations,
          ),
        ),
        // Player overlay — only shown when user explicitly plays a file
        if (showPlayer)
          Positioned.fill(
            child: _PlayerOverlay(
              playerBackend: playerBackend,
              onClose: () => useAppStore().updateShowPlayer(false),
            ),
          ),
      ],
    );
  }
}

class _PlayerOverlay extends HookWidget {
  const _PlayerOverlay({
    required this.playerBackend,
    required this.onClose,
  });

  final dynamic playerBackend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PlayerView(playerBackend: playerBackend),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 28),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}
