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

  /// Botão circular de vidro (câmera, minimizar, definições).
  Widget _glassCircleControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: enabled ? 0.4 : 0.24),
              border: Border.all(color: _glassBorder),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    icon,
                    size: 26,
                    color: Colors.white.withValues(alpha: enabled ? 0.95 : 0.38),
                  ),
                ),
              ),
            ),
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

  Widget _buildTopStatusPill(
    BuildContext context,
    StreamingViewModel vm,
    ColorScheme scheme,
  ) {
    final live = vm.sessionState.value == RtmpSessionState.live;
    final connecting = vm.sessionState.value == RtmpSessionState.connecting;
    final err = vm.sessionState.value == RtmpSessionState.error;
    if (!live && !connecting && !err) return const SizedBox.shrink();

    if (live) {
      return _glassPill(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const LiveIndicator(visible: true),
            const SizedBox(height: 6),
            Text(
              formatStreamingElapsed(vm.elapsed.value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
                letterSpacing: 0.2,
              ),
            ),
            if (vm.lastKnownPosition.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${vm.lastKnownPosition.value!.latitude.toStringAsFixed(5)}, '
                  '${vm.lastKnownPosition.value!.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return _glassPill(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        connecting
            ? 'A ligar ao servidor…'
            : (vm.rtmp.errorMessage ?? 'Erro na transmissão'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: err ? scheme.error : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildConfigOverlay(
    BuildContext context,
    StreamingViewModel vm,
  ) {
    final live = vm.sessionState.value == RtmpSessionState.live;
    if (!vm.configOpen.value || live) return const SizedBox.shrink();

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: vm.toggleConfig,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _glassPill(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      child: Form(
                        key: vm.formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Definições RTMP',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
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
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: vm.toggleConfig,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: _glassBorder),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('Cancelar'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: vm.saveConfig,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('Guardar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// REC / stop centralizado na base; troca de câmera à esquerda, sem gaveta em largura total.
  Widget _buildBottomCenterControls(
    StreamingViewModel vm,
    streaming.CameraController ctrl,
  ) {
    final live = vm.sessionState.value == RtmpSessionState.live;
    final connecting = vm.sessionState.value == RtmpSessionState.connecting;
    final multiCam = (vm.cameras?.length ?? 0) > 1;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            if (!live && !connecting)
              Align(
                alignment: Alignment.bottomCenter,
                child: _RecButton(
                  mode: _RecButtonMode.start,
                  onPressed: vm.persistAndStart,
                ),
              ),
            if (multiCam && !live && !connecting)
              Positioned(
                left: 0,
                bottom: 0,
                child: _glassCircleControl(
                  icon: Icons.cameraswitch_rounded,
                  tooltip: 'Trocar câmera',
                  onPressed: vm.flipCamera,
                ),
              ),
            if (live || connecting)
              Align(
                alignment: Alignment.bottomCenter,
                child: _RecButton(
                  mode: connecting ? _RecButtonMode.connecting : _RecButtonMode.stop,
                  onPressed: connecting ? null : vm.stopBroadcast,
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _glassCircleControl(
                icon: Icons.arrow_circle_down_outlined,
                tooltip: 'Minimizar',
                onPressed: vm.minimizeToBackground,
              ),
            ),
          ],
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
                child: _CameraPreviewFill(controller: ctrl),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Center(
                      child: _buildTopStatusPill(
                        context,
                        _vm,
                        Theme.of(context).colorScheme,
                      ),
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
                      padding: const EdgeInsets.only(top: 6, right: 10),
                      child: _glassCircleControl(
                        icon: _vm.configOpen.value
                            ? Icons.close_rounded
                            : Icons.settings_outlined,
                        tooltip: _vm.configOpen.value
                            ? 'Fechar'
                            : 'Definições RTMP',
                        onPressed: _vm.toggleConfig,
                      ),
                    ),
                  ),
                ),
              _buildConfigOverlay(context, _vm),
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildBottomCenterControls(_vm, ctrl),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Pré-visualização em ecrã inteiro (cover) sem distorcer.
///
/// O [streaming.CameraPreview] no Android usa [AndroidView] e deve ficar dentro
/// de [AspectRatio] com o valor do plugin (`altura / largura` do buffer).
/// Um [SizedBox] exterior com outra proporção esticava a imagem.
class _CameraPreviewFill extends StatelessWidget {
  const _CameraPreviewFill({required this.controller});

  final streaming.CameraController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.value.isInitialized != true) {
          return const ColoredBox(color: Colors.black);
        }

        // Mesmo valor que o exemplo do rtmp_streaming: previewSize.height / width.
        final aspect = controller.value.aspectRatio;
        if (aspect <= 0 || !aspect.isFinite) {
          return const ColoredBox(color: Colors.black);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final boxW = constraints.maxWidth;
            final boxH = constraints.maxHeight;
            if (!boxW.isFinite ||
                !boxH.isFinite ||
                boxW <= 0 ||
                boxH <= 0) {
              return const ColoredBox(color: Colors.black);
            }

            // Tamanho “fit” com proporção correta (sem esticar).
            final double fitW;
            final double fitH;
            if (boxW / boxH > aspect) {
              fitH = boxH;
              fitW = boxH * aspect;
            } else {
              fitW = boxW;
              fitH = boxW / aspect;
            }

            // Escala uniforme para cover (mantém proporção).
            final scale = (boxW / fitW) > (boxH / fitH)
                ? boxW / fitW
                : boxH / fitH;

            return ClipRect(
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: fitW,
                    height: fitH,
                    child: AspectRatio(
                      aspectRatio: aspect,
                      child: streaming.CameraPreview(controller),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
