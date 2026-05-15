import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:rtmp_streaming/camera.dart' as streaming;

enum RtmpSessionState {
  idle,
  connecting,
  live,
  error,
}

String buildRtmpStreamUrl(String baseUrl, String streamName) {
  final uri = Uri.parse(baseUrl.trim());
  final segments = List<String>.from(uri.pathSegments)
    ..removeWhere((e) => e.isEmpty);
  segments.add(streamName.trim());
  return uri.replace(pathSegments: segments).toString();
}

class RtmpService extends ChangeNotifier {
  RtmpSessionState _state = RtmpSessionState.idle;
  String? _errorMessage;
  streaming.CameraController? _controller;
  String? _streamUrl;
  bool _wantsStream = false;
  int _attemptsLeft = 3;
  bool _reconnectBusy = false;
  bool _maintenance = false;
  VoidCallback? _boundListener;

  RtmpSessionState get state => _state;
  String? get errorMessage => _errorMessage;

  Future<void> start(
    streaming.CameraController controller,
    String rtmpBaseUrl,
    String cameraName,
  ) async {
    await stop();
    _controller = controller;
    _streamUrl = buildRtmpStreamUrl(rtmpBaseUrl, cameraName);
    _wantsStream = true;
    _attemptsLeft = 3;
    _errorMessage = null;
    _state = RtmpSessionState.connecting;
    notifyListeners();
    _boundListener = _onControllerUpdated;
    _controller!.addListener(_boundListener!);
    await _tryConnect();
  }

  void beginMaintenance() {
    _maintenance = true;
  }

  void endMaintenance() {
    _maintenance = false;
  }

  void _onControllerUpdated() {
    if (_maintenance) return;
    final c = _controller;
    if (c == null || !_wantsStream) return;
    final v = c.value;
    if (_state == RtmpSessionState.live &&
        v.isStreamingVideoRtmp == false) {
      unawaited(_handleUnexpectedStop());
      return;
    }
    final raw = v.event;
    if (raw is Map) {
      final type = raw['eventType'] as String? ?? raw['event'] as String?;
      if (type == 'rtmp_stopped' &&
          _state == RtmpSessionState.live &&
          _wantsStream) {
        unawaited(_handleUnexpectedStop());
      }
    }
  }

  Future<void> _handleUnexpectedStop() async {
    if (_maintenance || _reconnectBusy || !_wantsStream) return;
    _reconnectBusy = true;
    try {
      _attemptsLeft--;
      if (_attemptsLeft <= 0) {
        _state = RtmpSessionState.error;
        _errorMessage =
            'Falha na transmissão após várias tentativas. Verifique a URL e a rede.';
        _wantsStream = false;
        notifyListeners();
        return;
      }
      _state = RtmpSessionState.connecting;
      notifyListeners();
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!_wantsStream) return;
      await _tryConnect();
    } finally {
      _reconnectBusy = false;
    }
  }

  Future<void> _tryConnect() async {
    final c = _controller;
    final url = _streamUrl;
    if (c == null || url == null || !_wantsStream) return;
    try {
      if (c.value.isStreamingVideoRtmp == true) {
        await c.stopVideoStreaming();
      }
      if (Platform.isIOS) {
        await c.prepareForVideoStreaming();
      }
      await c.startVideoStreaming(url);
      if (!_wantsStream) return;
      _state = RtmpSessionState.live;
      _attemptsLeft = 3;
      _errorMessage = null;
      notifyListeners();
    } on streaming.CameraException catch (e) {
      _attemptsLeft--;
      if (_attemptsLeft > 0 && _wantsStream) {
        _state = RtmpSessionState.connecting;
        notifyListeners();
        await Future<void>.delayed(const Duration(seconds: 1));
        if (_wantsStream) {
          await _tryConnect();
        }
      } else {
        _state = RtmpSessionState.error;
        _errorMessage = e.description ?? e.toString();
        _wantsStream = false;
        notifyListeners();
      }
    } catch (e) {
      _attemptsLeft--;
      if (_attemptsLeft > 0 && _wantsStream) {
        _state = RtmpSessionState.connecting;
        notifyListeners();
        await Future<void>.delayed(const Duration(seconds: 1));
        if (_wantsStream) {
          await _tryConnect();
        }
      } else {
        _state = RtmpSessionState.error;
        _errorMessage = e.toString();
        _wantsStream = false;
        notifyListeners();
      }
    }
  }

  Future<void> stop() async {
    _wantsStream = false;
    final c = _controller;
    if (c != null && _boundListener != null) {
      c.removeListener(_boundListener!);
      _boundListener = null;
    }
    _streamUrl = null;
    if (c != null && c.value.isStreamingVideoRtmp == true) {
      try {
        await c.stopVideoStreaming();
      } catch (_) {}
    }
    _controller = null;
    _state = RtmpSessionState.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
