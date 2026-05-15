import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_streaming/camera.dart' as streaming;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/rtmp_service.dart';
import '../widgets/live_indicator.dart';

class StreamingScreen extends StatefulWidget {
  const StreamingScreen({
    super.key,
    required this.rtmpBaseUrl,
    required this.cameraName,
  });

  final String rtmpBaseUrl;
  final String cameraName;

  @override
  State<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends State<StreamingScreen> {
  streaming.CameraController? _controller;
  List<streaming.CameraDescription>? _cameras;
  int _cameraIndex = 0;
  final RtmpService _rtmp = RtmpService();
  bool _initializing = true;
  String? _permissionIssue;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _rtmp.addListener(_onRtmpState);
    unawaited(WakelockPlus.enable());
    unawaited(_bootstrap());
  }

  void _onRtmpState() {
    if (!mounted) return;
    setState(() {});
    if (_rtmp.state == RtmpSessionState.live && _elapsedTimer == null) {
      _elapsed = Duration.zero;
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
      });
    }
    if (_rtmp.state == RtmpSessionState.error ||
        _rtmp.state == RtmpSessionState.idle) {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
  }

  Future<void> _bootstrap() async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      if (mounted) {
        setState(() {
          _permissionIssue = 'Permissões de câmera e microfone são obrigatórias.';
          _initializing = false;
        });
      }
      return;
    }
    streaming.CameraController? ctrl;
    try {
      final list = await streaming.availableCameras();
      if (list.isEmpty) {
        if (mounted) {
          setState(() {
            _permissionIssue = 'Nenhuma câmera disponível.';
            _initializing = false;
          });
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
      );
      await ctrl.initialize(list[_cameraIndex]);
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _initializing = false;
      });
      await _rtmp.start(
        ctrl,
        widget.rtmpBaseUrl,
        widget.cameraName,
      );
    } catch (e) {
      await ctrl?.dispose();
      _controller = null;
      if (mounted) {
        setState(() {
          _permissionIssue = e.toString();
          _initializing = false;
        });
      }
    }
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$m:$s';
    }
    return '$m:$s';
  }

  Future<void> _endAndLeave() async {
    _elapsedTimer?.cancel();
    await _rtmp.stop();
    await _controller?.dispose();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _flipCamera() async {
    final ctrl = _controller;
    final cams = _cameras;
    if (ctrl == null || cams == null || cams.length < 2) return;
    final wasLive = ctrl.value.isStreamingVideoRtmp == true;
    _rtmp.beginMaintenance();
    try {
      if (wasLive) {
        await ctrl.stopVideoStreaming();
      }
      _cameraIndex = (_cameraIndex + 1) % cams.length;
      final id = cams[_cameraIndex].name;
      if (id == null) return;
      await ctrl.switchCamera(id);
      if (wasLive && mounted) {
        await _rtmp.start(
          ctrl,
          widget.rtmpBaseUrl,
          widget.cameraName,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    } finally {
      _rtmp.endMaintenance();
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _rtmp.removeListener(_onRtmpState);
    final cam = _controller;
    _controller = null;
    unawaited(Future(() async {
      await _rtmp.stop();
      await cam?.dispose();
      await WakelockPlus.disable();
      _rtmp.dispose();
    }));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionIssue != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _permissionIssue!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_initializing || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ctrl = _controller!;
    final topMessage = _rtmp.state == RtmpSessionState.connecting
        ? 'Conectando…'
        : _rtmp.state == RtmpSessionState.error
            ? (_rtmp.errorMessage ?? 'Erro na transmissão')
            : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: ctrl.value.previewSize?.height ?? 1,
                height: ctrl.value.previewSize?.width ?? 1,
                child: streaming.CameraPreview(ctrl),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        LiveIndicator(
                          visible: _rtmp.state == RtmpSessionState.live,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatElapsed(_elapsed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (topMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        topMessage,
                        style: TextStyle(
                          color: _rtmp.state == RtmpSessionState.error
                              ? Colors.redAccent
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 24,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 28,
                color: Colors.white,
                onPressed: _endAndLeave,
                icon: const Icon(Icons.stop_circle_outlined),
              ),
            ),
          ),
          if ((_cameras?.length ?? 0) > 1)
            Positioned(
              right: 16,
              bottom: 24,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: IconButton(
                  iconSize: 28,
                  color: Colors.white,
                  onPressed: _flipCamera,
                  icon: const Icon(Icons.cameraswitch),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
