import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:screen_brightness/screen_brightness.dart';

ValueNotifier<double?> useBrightness(bool isGesture) {
  final brightness = useState<double?>(null);

  useEffect(() {
    try {
      () async {
        if (!isGesture) return;
        brightness.value = await ScreenBrightness.instance.application;
      }();
    } catch (e) {
      // ignore
    }
    return () => brightness.value = null;
  }, [isGesture]);

  useEffect(() {
    try {
      if (brightness.value != null && isGesture) {
        ScreenBrightness.instance
            .setApplicationScreenBrightness(brightness.value!);
      }
    } catch (e) {
      // ignore
    }
    return;
  }, [brightness.value]);

  // 退出时重置亮度
  useEffect(
    () => () {
      try {
        ScreenBrightness.instance.resetApplicationScreenBrightness();
      } catch (e) {
        // ignore
      }
    },
    [],
  );

  return brightness;
}
