import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_streaming/camera.dart' as streaming;
import 'package:signals/signals_flutter.dart';

import '../core/di/injection.dart';
import '../features/streaming/streaming_form_utils.dart';
import '../features/streaming/streaming_view_model.dart';
import '../services/rtmp_service.dart';
import '../widgets/live_indicator.dart';

class StreamingScreen extends StatefulWidget {
  const StreamingScreen({super.key});

  @override
  State<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends State<StreamingScreen> {
  late final StreamingViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = getIt<StreamingViewModel>();
    _vm.attachSnack((message) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
    _vm.init();
  }

  @override
  void dispose() {
    _vm.dispose();
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

  Widget _buildBottomGlass(
    BuildContext context,
    StreamingViewModel vm,
    streaming.CameraController ctrl,
  ) {
    final live = vm.sessionState.value == RtmpSessionState.live;
    final connecting = vm.sessionState.value == RtmpSessionState.connecting;
    final err = vm.sessionState.value == RtmpSessionState.error;
    final scheme = Theme.of(context).colorScheme;
    final multiCam = (vm.cameras?.length ?? 0) > 1;

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
                  key: vm.formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!vm.configOpen.value && !live && !connecting && !err)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 48,
                                child: multiCam
                                    ? Align(
                                        alignment: Alignment.centerLeft,
                                        child: _glassPill(
                                          padding: EdgeInsets.zero,
                                          child: IconButton(
                                            onPressed: vm.flipCamera,
                                            color: Colors.white,
                                            icon: const Icon(Icons.cameraswitch_rounded, size: 24),
                                            tooltip: 'Trocar câmera',
                                            visualDensity: VisualDensity.compact,
                                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              Expanded(
                                child: Center(
                                  child: _RecButton(
                                    mode: _RecButtonMode.start,
                                    onPressed: vm.persistAndStart,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                      if (live || connecting || err)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _glassPill(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    LiveIndicator(visible: live),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            live
                                                ? formatStreamingElapsed(vm.elapsed.value)
                                                : connecting
                                                    ? 'A ligar ao servidor…'
                                                    : (vm.rtmp.errorMessage ?? 'Erro na transmissão'),
                                            style: TextStyle(
                                              color: err ? scheme.error : Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          if (live && vm.lastKnownPosition.value != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                '${vm.lastKnownPosition.value!.latitude.toStringAsFixed(5)}, '
                                                '${vm.lastKnownPosition.value!.longitude.toStringAsFixed(5)}',
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.65),
                                                  fontSize: 11,
                                                  fontFeatures: const [FontFeature.tabularFigures()],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (live || connecting)
                              _RecButton(
                                mode: connecting ? _RecButtonMode.connecting : _RecButtonMode.stop,
                                onPressed: connecting ? null : vm.stopBroadcast,
                              ),
                          ],
                        ),
                      if (live || connecting || err) const SizedBox(height: 10),
                      if (vm.configOpen.value && !live) ...[
                        TextFormField(
                          controller: vm.urlController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _fieldDecoration('URL RTMP (base)').copyWith(
                            helperText: 'Sem o último segmento (ex.: …/live ou …/live2)',
                            helperStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: vm.nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _fieldDecoration('Nome do fluxo').copyWith(
                            helperText: 'MediaMTX: nome da câmera no caminho',
                            helperStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                          validator: (v) {
                            final hasName = (v ?? '').trim().isNotEmpty;
                            final hasKey = vm.streamKeyController.text.trim().isNotEmpty;
                            if (!hasName && !hasKey) {
                              return 'Preencha o nome ou a chave abaixo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: vm.streamKeyController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _fieldDecoration('Chave de transmissão (opcional)').copyWith(
                            helperText: 'YouTube: cola a chave; tem prioridade sobre o nome.',
                            helperStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Só uma câmera é enviada por fluxo RTMP. Duas lentes em simultâneo não é suportado por este codificador.\n'
                          'A localização (em uso) é pedida ao preparar a câmara e lida de novo ao iniciar o stream, para poderes enviar ao servidor.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: _RecButton(
                                  mode: connecting ? _RecButtonMode.connecting : _RecButtonMode.start,
                                  onPressed: (connecting || ctrl.value.isStreamingVideoRtmp == true)
                                      ? null
                                      : vm.persistAndStart,
                                  diameter: 64,
                                ),
                              ),
                            ),
                            if (multiCam) ...[
                              const SizedBox(width: 8),
                              _glassPill(
                                padding: EdgeInsets.zero,
                                child: IconButton(
                                  onPressed: connecting ? null : vm.flipCamera,
                                  color: Colors.white,
                                  icon: const Icon(Icons.cameraswitch_rounded, size: 24),
                                  tooltip: 'Trocar câmera',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (err && !connecting) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: vm.persistAndStart,
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
    return Watch((context) {
      final issue = _vm.permissionIssue.value;
      if (issue != null) {
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
                                issue,
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

      if (_vm.initializing.value || _vm.cameraController == null) {
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

      final ctrl = _vm.cameraController!;
      final live = _vm.sessionState.value == RtmpSessionState.live;
      final connecting = _vm.sessionState.value == RtmpSessionState.connecting;

      return WithForegroundTask(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: ctrl.value.previewSize == null ||
                          ctrl.value.isInitialized != true
                      ? const ColoredBox(color: Colors.black)
                      : FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: AspectRatio(
                            aspectRatio: ctrl.value.aspectRatio,
                            child: streaming.CameraPreview(ctrl),
                          ),
                        ),
                ),
              ),
              if (!live && !connecting)
                Positioned(
                  top: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.88),
                            backgroundColor: Colors.black.withValues(alpha: 0.22),
                            shape: const CircleBorder(),
                          ),
                          onPressed: _vm.toggleConfig,
                          icon: Icon(
                            _vm.configOpen.value ? Icons.close_rounded : Icons.settings_outlined,
                            size: 20,
                          ),
                          tooltip: _vm.configOpen.value ? 'Fechar' : 'Definições RTMP',
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomGlass(context, _vm, ctrl),
              ),
            ],
          ),
        ),
      );
    });
  }
}

enum _RecButtonMode { start, stop, connecting }

class _RecButton extends StatelessWidget {
  const _RecButton({
    required this.mode,
    required this.onPressed,
    this.diameter = 72,
  });

  final _RecButtonMode mode;
  final VoidCallback? onPressed;
  final double diameter;

  static const Color _red = Color(0xFFE11D48);

  @override
  Widget build(BuildContext context) {
    final dimmed = onPressed == null && mode != _RecButtonMode.connecting;
    final outer = diameter;

    return Opacity(
      opacity: dimmed ? 0.42 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: outer + 16,
            height: outer + 16,
            child: Center(
              child: switch (mode) {
                _RecButtonMode.stop => Container(
                    width: outer,
                    height: outer,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _red,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _red.withValues(alpha: 0.42),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: outer * 0.32,
                        height: outer * 0.32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                _RecButtonMode.start => Container(
                    width: outer,
                    height: outer,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.88),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: outer * 0.58,
                        height: outer * 0.58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: onPressed != null ? _red : _red.withValues(alpha: 0.45),
                          boxShadow: onPressed != null
                              ? [
                                  BoxShadow(
                                    color: _red.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                _RecButtonMode.connecting => Container(
                    width: outer,
                    height: outer,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: outer * 0.52,
                        height: outer * 0.52,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
