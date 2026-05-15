import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_streaming/camera.dart' as streaming;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/rtmp_service.dart';
import '../widgets/live_indicator.dart';

class StreamingScreen extends StatefulWidget {
  const StreamingScreen({super.key});

  @override
  State<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends State<StreamingScreen> {
  static const _keyName = 'last_camera_name';
  static const _keyUrl = 'last_rtmp_url';

  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final RtmpService _rtmp = RtmpService();

  streaming.CameraController? _controller;
  List<streaming.CameraDescription>? _cameras;
  int _cameraIndex = 0;
  bool _initializing = true;
  String? _permissionIssue;
  bool _configOpen = false;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _rtmp.addListener(_onRtmpState);
    unawaited(WakelockPlus.enable());
    unawaited(_loadPrefs());
    unawaited(_bootstrap());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString(_keyName) ?? '';
      _urlController.text = prefs.getString(_keyUrl) ?? '';
    });
  }

  void _onRtmpState() {
    if (!mounted) return;
    if (_rtmp.state == RtmpSessionState.live) {
      if (_elapsedTimer == null) {
        _elapsed = Duration.zero;
        _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() {
            _elapsed += const Duration(seconds: 1);
          });
        });
      }
    }
    if (_rtmp.state == RtmpSessionState.error ||
        _rtmp.state == RtmpSessionState.idle) {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
    setState(() {
      if (_rtmp.state == RtmpSessionState.live) {
        _configOpen = false;
      } else if (_rtmp.state == RtmpSessionState.error) {
        _configOpen = true;
      }
    });
  }

  Future<void> _bootstrap() async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      if (mounted) {
        setState(() {
          _permissionIssue =
              'Ative câmera e microfone para continuar.';
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

  Future<void> _persistAndStart() async {
    if (_nameController.text.trim().isEmpty || _urlController.text.trim().isEmpty) {
      if (mounted) {
        setState(() => _configOpen = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha nome e URL RTMP.')),
        );
      }
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ctrl = _controller;
    if (ctrl == null) return;
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyUrl, url);
    if (!mounted) return;
    await _rtmp.start(ctrl, url, name);
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

  Future<void> _stopBroadcast() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _rtmp.stop();
    if (mounted) {
      setState(() {
        _configOpen = true;
      });
    }
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
          _urlController.text.trim(),
          _nameController.text.trim(),
        );
      }
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      _rtmp.endMaintenance();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
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

  static const _glassBorder = Color(0x66FFFFFF);
  static const _hintOnGlass = Color(0xB3FFFFFF);

  Widget _glassPill({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _glassBorder),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: child,
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _hintOnGlass, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: Colors.white),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildBottomGlass(BuildContext context, streaming.CameraController ctrl) {
    final live = _rtmp.state == RtmpSessionState.live;
    final connecting = _rtmp.state == RtmpSessionState.connecting;
    final err = _rtmp.state == RtmpSessionState.error;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.45),
              ],
            ),
            border: const Border(
              top: BorderSide(color: _glassBorder),
            ),
          ),
          child: SafeArea(
            top: false,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_configOpen && !live && !connecting && !err)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () => setState(() => _configOpen = true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Configurar e iniciar',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              if ((_cameras?.length ?? 0) > 1) ...[
                                const SizedBox(width: 10),
                                _glassPill(
                                  padding: EdgeInsets.zero,
                                  child: IconButton(
                                    onPressed: _flipCamera,
                                    color: Colors.white,
                                    icon: const Icon(Icons.cameraswitch_rounded, size: 26),
                                    tooltip: 'Trocar câmera',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (live || connecting || err)
                        _glassPill(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              LiveIndicator(visible: live),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  live
                                      ? _formatElapsed(_elapsed)
                                      : connecting
                                          ? 'A ligar ao servidor…'
                                          : (_rtmp.errorMessage ?? 'Erro na transmissão'),
                                  style: TextStyle(
                                    color: err ? scheme.error : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (live || connecting || err) const SizedBox(height: 12),
                      if (_configOpen && !live) ...[
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _fieldDecoration('Nome da câmera'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _urlController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _fieldDecoration('URL RTMP'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: (connecting ||
                                        ctrl.value.isStreamingVideoRtmp == true)
                                    ? null
                                    : _persistAndStart,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Iniciar transmissão',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                              ),
                            ),
                            if ((_cameras?.length ?? 0) > 1) ...[
                              const SizedBox(width: 10),
                              _glassPill(
                                padding: EdgeInsets.zero,
                                child: IconButton(
                                  onPressed: connecting ? null : _flipCamera,
                                  color: Colors.white,
                                  icon: const Icon(Icons.cameraswitch_rounded, size: 26),
                                  tooltip: 'Trocar câmera',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (live || connecting) const SizedBox(height: 12),
                      if (live || connecting)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: connecting ? null : _stopBroadcast,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: _glassBorder),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.stop_circle_outlined, size: 22),
                                label: const Text('Parar'),
                              ),
                            ),
                            if ((_cameras?.length ?? 0) > 1) ...[
                              const SizedBox(width: 10),
                              _glassPill(
                                padding: EdgeInsets.zero,
                                child: IconButton(
                                  onPressed: connecting ? null : _flipCamera,
                                  color: Colors.white,
                                  icon: const Icon(Icons.cameraswitch_rounded, size: 26),
                                  tooltip: 'Trocar câmera',
                                ),
                              ),
                            ],
                          ],
                        ),
                      if (err && !connecting) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _persistAndStart,
                          child: const Text(
                            'Tentar novamente',
                            style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionIssue != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _glassBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _permissionIssue!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () async {
                                await openAppSettings();
                              },
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Abrir definições'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.9),
                                foregroundColor: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_initializing || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF020617)],
                ),
              ),
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _glassBorder),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: Color(0xFF93C5FD),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'A preparar a câmera…',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final ctrl = _controller!;

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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _configOpen = !_configOpen;
                        });
                      },
                      icon: Icon(
                        _configOpen ? Icons.visibility_off_outlined : Icons.tune_rounded,
                      ),
                      tooltip: _configOpen ? 'Ocultar configuração' : 'Configurar',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomGlass(context, ctrl),
          ),
        ],
      ),
    );
  }
}
