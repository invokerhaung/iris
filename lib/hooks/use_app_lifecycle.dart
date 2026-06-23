import 'dart:ui';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:iris/models/player.dart';
import 'package:provider/provider.dart';

void useAppLifecycle() {
  final context = useContext();

  AppLifecycleState? appLifecycleState = useAppLifecycleState();

  useEffect(() {
    try {
      if (appLifecycleState == AppLifecycleState.paused) {
        context.read<MediaPlayer>().saveProgress();
      }
    } catch (e) {
      // ignore
    }
    return;
  }, [appLifecycleState]);
}
