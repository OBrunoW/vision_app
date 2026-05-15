import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_streaming/camera.dart' as streaming;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/app_branding.dart';
import '../../services/rtmp_service.dart';
import '../../services/stream_foreground_task.dart';
import 'streaming_form_utils.dart';

typedef StreamSnack = void Function(String message);

class StreamingViewModel {
  StreamingViewModel(this._rtmp);

  final RtmpService _rtmp;
  StreamSnack? _onSnack;

  RtmpService get rtmp => _rtmp;

  void attachSnack(StreamSnack snack) => _onSnack = snack;

  void _snack(String message) => _onSnack?.call(message);

  static const _keyName = 'last_camera_name';
  static const _keyUrl = 'last_rtmp_url';
  static const _keyStreamKey = 'last_stream_key_optional';

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final urlController = TextEditingController();
  final streamKeyController = TextEditingController();

  final initializing = signal<bool>(true);
  final permissionIssue = signal<String?>(null);
  final configOpen = signal<bool>(false);
  final elapsed = signal<Duration>(Duration.zero);
  final lastKnownPosition = signal<Position?>(null);
  final sessionState = signal<RtmpSessionState>(RtmpSessionState.idle);
  /// Serviço em primeiro plano ativo após "Minimizar" (mantém-se mesmo sem stream).
  final backgroundMode = signal<bool>(false);

  streaming.CameraController? _controller;
  List<streaming.CameraDescription>? _cameras;
  int _cameraIndex = 0;
  Timer? _elapsedTimer;
  bool _disposed = false;

  streaming.CameraController? get cameraController => _controller;
  List<streaming.CameraDescription>? get cameras => _cameras;

  String get rtmpPathSegment =>
      rtmpPathSegmentForConnect(nameController.text, streamKeyController.text);

  void _touchForm() {
    if (_disposed) return;
    // Força reconstrução quando o texto dos campos altera validação cruzada.
    configOpen.set(configOpen.peek(), force: true);
  }

  void init() {
    _rtmp.addListener(_onRtmpState);
    sessionState.value = _rtmp.state;
    FlutterForegroundTask.addTaskDataCallback(_onForegroundTaskData);
    nameController.addListener(_touchForm);
    streamKeyController.addListener(_touchForm);
    unawaited(WakelockPlus.enable());
    unawaited(_loadPrefs());
    unawaited(_bootstrap());
  }

  void _onForegroundTaskData(Object data) {
    if (data is! Map || _disposed) return;
    switch (data['action']) {
      case 'start_from_notification':
        unawaited(persistAndStart());
      case 'stop_from_notification':
        unawaited(stopBroadcast());
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    nameController.text = prefs.getString(_keyName) ?? '';
    urlController.text = prefs.getString(_keyUrl) ?? '';
    streamKeyController.text = prefs.getString(_keyStreamKey) ?? '';
  }

  void _onRtmpState() {
    if (_disposed) return;
    sessionState.value = _rtmp.state;
    if (_rtmp.state == RtmpSessionState.live) {
      if (_elapsedTimer == null) {
        elapsed.value = Duration.zero;
        _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_disposed) return;
          elapsed.value = elapsed.peek() + const Duration(seconds: 1);
          if (Platform.isAndroid && backgroundMode.peek()) {
            unawaited(_updateForegroundNotification());
          }
        });
      }
    }
    if (_rtmp.state == RtmpSessionState.error ||
        _rtmp.state == RtmpSessionState.idle) {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
    if (_rtmp.state == RtmpSessionState.live) {
      configOpen.value = false;
    } else if (_rtmp.state == RtmpSessionState.error) {
      configOpen.value = true;
    }
    unawaited(_syncBroadcastForeground());
  }

  Future<void> _syncBroadcastForeground() async {
    if (!Platform.isAndroid) return;
    final keepService = backgroundMode.peek() ||
        _rtmp.state == RtmpSessionState.live ||
        _rtmp.state == RtmpSessionState.connecting;
    if (!keepService) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      return;
    }
    if (!await FlutterForegroundTask.isRunningService) {
      await _startForegroundService();
      return;
    }
    await _updateForegroundNotification();
  }

  List<NotificationButton> _notificationButtons() {
    final live = _rtmp.state == RtmpSessionState.live;
    final connecting = _rtmp.state == RtmpSessionState.connecting;
    if (live || connecting) {
      return const [NotificationButton(id: 'stop_stream', text: 'Parar')];
    }
    return const [NotificationButton(id: 'start_stream', text: 'Iniciar')];
  }

  String _notificationText() {
    switch (_rtmp.state) {
      case RtmpSessionState.live:
        return formatStreamingElapsed(elapsed.peek());
      case RtmpSessionState.connecting:
        return 'A ligar…';
      case RtmpSessionState.error:
        final msg = _rtmp.errorMessage?.trim();
        if (msg == null || msg.isEmpty) return 'Erro';
        return msg.length > 48 ? '${msg.substring(0, 48)}…' : msg;
      case RtmpSessionState.idle:
        return '';
    }
  }

  Future<void> _startForegroundService() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await _updateForegroundNotification();
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: kAppDisplayName,
      notificationText: _notificationText(),
      notificationIcon: kForegroundNotificationIcon,
      serviceTypes: const [
        ForegroundServiceTypes.camera,
        ForegroundServiceTypes.microphone,
      ],
      notificationButtons: _notificationButtons(),
      callback: startStreamForegroundCallback,
    );
  }

  Future<void> _updateForegroundNotification() async {
    if (!Platform.isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: kAppDisplayName,
      notificationText: _notificationText(),
      notificationIcon: kForegroundNotificationIcon,
      notificationButtons: _notificationButtons(),
    );
  }

  /// Minimiza a app e ativa o serviço em primeiro plano (com ou sem stream).
  Future<void> minimizeToBackground() async {
    if (Platform.isAndroid) {
      backgroundMode.value = true;
      await _startForegroundService();
    }
    FlutterForegroundTask.minimizeApp();
  }

  String? _configValidationError() => validateStreamConfig(
        baseUrl: urlController.text,
        cameraName: nameController.text,
        streamKey: streamKeyController.text,
      );

  Future<void> saveConfig() async {
    final err = _configValidationError();
    if (err != null) {
      _snack(err);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, nameController.text.trim());
    await prefs.setString(_keyUrl, urlController.text.trim());
    await prefs.setString(_keyStreamKey, streamKeyController.text.trim());
    if (!_disposed) configOpen.value = false;
  }

  Future<void> _bootstrap() async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      if (!_disposed) {
        permissionIssue.value = 'Ative câmera e microfone para continuar.';
        initializing.value = false;
      }
      return;
    }
    streaming.CameraController? ctrl;
    try {
      final list = await streaming.availableCameras();
      if (list.isEmpty) {
        if (!_disposed) {
          permissionIssue.value = 'Nenhuma câmera disponível.';
          initializing.value = false;
        }
        return;
      }
      var idx = list.indexWhere(
        (e) => e.lensDirection == streaming.CameraLensDirection.back,
      );
      if (idx < 0) idx = 0;
      _cameras = list;
      _cameraIndex = idx;
      ctrl = streaming.CameraController(
        streaming.ResolutionPreset.high,
        enableAudio: true,
        // OpenGL pode deixar o preview preto em alguns Xiaomi/MediaTek.
        androidUseOpenGL: false,
      );
      await ctrl.initialize(list[_cameraIndex]);
      if (Platform.isIOS) {
        try {
          await ctrl.setMultitaskingCameraAccessEnabled(true);
        } catch (_) {}
      }
      if (_disposed) {
        await ctrl.dispose();
        return;
      }
      _controller = ctrl;
      initializing.value = false;
      if (Platform.isAndroid) {
        await _ensureNotificationPermission();
      }
      unawaited(_requestLocationPermission());
    } catch (e) {
      await ctrl?.dispose();
      _controller = null;
      if (!_disposed) {
        permissionIssue.value = e.toString();
        initializing.value = false;
      }
    }
  }

  Future<void> _ensureNotificationPermission() async {
    try {
      final notif = await FlutterForegroundTask.checkNotificationPermission();
      if (notif == NotificationPermission.granted) return;
      await FlutterForegroundTask.requestNotificationPermission();
    } on PlatformException catch (_) {
      // Cancelado ou outro pedido de permissão em curso.
    } catch (_) {}
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (_disposed) return;
    if (!status.isGranted) {
      _snack(
        'Sem localização o servidor não saberá onde está esta câmara. '
        'Podes ativar nas definições do sistema.',
      );
    }
  }

  Future<void> _refreshPositionForStream() async {
    if (!await Permission.locationWhenInUse.isGranted) return;
    final servicesOn = await Geolocator.isLocationServiceEnabled();
    if (!servicesOn) {
      if (!_disposed) {
        _snack('Ativa o serviço de localização (GPS) para obter coordenadas.');
      }
      return;
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!_disposed) lastKnownPosition.value = p;
    } catch (_) {
      if (!_disposed) {
        _snack('Não foi possível ler a localização neste momento.');
      }
    }
  }

  Future<void> persistAndStart() async {
    final err = _configValidationError();
    if (err != null) {
      configOpen.value = true;
      _snack(err);
      return;
    }
    final url = urlController.text.trim();
    final pathSeg = rtmpPathSegment;
    final ctrl = _controller;
    if (ctrl == null) return;
    final name = nameController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyUrl, url);
    await prefs.setString(_keyStreamKey, streamKeyController.text.trim());
    if (_disposed) return;
    await _refreshPositionForStream();
    if (_disposed) return;
    await _rtmp.start(ctrl, url, pathSeg);
  }

  Future<void> stopBroadcast() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _rtmp.stop();
    if (!_disposed) {
      configOpen.value = false;
      lastKnownPosition.value = null;
    }
  }

  Future<void> flipCamera() async {
    final ctrl = _controller;
    final cams = _cameras;
    if (ctrl == null || cams == null || cams.length < 2) return;

    // O plugin troca a lente nativamente sem fechar o RTMP (ver exemplo do rtmp_streaming).
    _rtmp.beginMaintenance();
    try {
      _cameraIndex = (_cameraIndex + 1) % cams.length;
      final id = cams[_cameraIndex].name;
      if (id == null) return;
      await ctrl.switchCamera(id);
    } catch (_) {
      if (!_disposed) {
        _snack('Não foi possível trocar a câmera.');
      }
    } finally {
      _rtmp.endMaintenance();
    }
  }

  void toggleConfig() {
    if (_disposed) return;
    configOpen.value = !configOpen.peek();
  }

  void dispose() {
    _disposed = true;
    nameController.removeListener(_touchForm);
    streamKeyController.removeListener(_touchForm);
    nameController.dispose();
    urlController.dispose();
    streamKeyController.dispose();
    _elapsedTimer?.cancel();
    _rtmp.removeListener(_onRtmpState);
    FlutterForegroundTask.removeTaskDataCallback(_onForegroundTaskData);
    final cam = _controller;
    _controller = null;
    unawaited(Future(() async {
      if (Platform.isAndroid && await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      await _rtmp.stop();
      await cam?.dispose();
      await WakelockPlus.disable();
      _rtmp.dispose();
    }));
    initializing.dispose();
    permissionIssue.dispose();
    configOpen.dispose();
    elapsed.dispose();
    lastKnownPosition.dispose();
    sessionState.dispose();
    backgroundMode.dispose();
  }
}
