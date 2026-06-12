import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:iris/utils/get_localizations.dart';
import 'package:iris/widgets/popups/settings/settings.dart';

class SettingsPage extends HookWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings),
      ),
      body: Settings(
        onClose: () {},
      ),
    );
  }
}
