import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Entrada do serviço em primeiro plano (Android). Tem de ser função de topo.
@pragma('vm:entry-point')
void startStreamForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(RtmpForegroundStreamHandler());
}

class RtmpForegroundStreamHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationButtonPressed(String id) {
    switch (id) {
      case 'start_stream':
        FlutterForegroundTask.sendDataToMain(<String, String>{
          'action': 'start_from_notification',
        });
      case 'stop_stream':
        FlutterForegroundTask.sendDataToMain(<String, String>{
          'action': 'stop_from_notification',
        });
    }
  }
}
