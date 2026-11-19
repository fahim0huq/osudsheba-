import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time, updated at the start of every minute.
///
/// Screens that show "what is due now" watch this so they recompute as time passes:
/// without it the Home screen kept showing a dose as "next" long after its time.
final minuteClockProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;
  void scheduleNext() {
    final now = DateTime.now();
    final untilNextMinute = Duration(seconds: 60 - now.second, milliseconds: -now.millisecond);
    timer = Timer(untilNextMinute, () {
      controller.add(DateTime.now());
      scheduleNext();
    });
  }

  controller.add(DateTime.now());
  scheduleNext();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});
