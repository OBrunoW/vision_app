import 'dart:io' show Platform;

import 'stream_protocol.dart';

/// Valida URL e segmento do fluxo sem depender de um [Form] na árvore de widgets.
String? validateStreamConfig({
  required StreamProtocol protocol,
  required String baseUrl,
  required String cameraName,
  required String streamKey,
}) {
  if (protocol == StreamProtocol.rtsp && Platform.isIOS) {
    return 'RTSP só está disponível no Android nesta versão.';
  }

  final url = baseUrl.trim();
  if (url.isEmpty) {
    return 'Preencha a URL ${protocol.label} (base).';
  }

  Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException {
    return 'URL ${protocol.label} inválida.';
  }

  if (uri.scheme.isNotEmpty && uri.scheme != protocol.scheme) {
    return 'A URL deve começar por ${protocol.scheme}://';
  }

  if (pathSegmentForConnect(cameraName, streamKey).isEmpty) {
    return 'Preencha o nome do fluxo ou a chave de transmissão.';
  }
  return null;
}

/// Segmento final do path (nome MediaMTX ou chave YouTube, etc.).
String pathSegmentForConnect(String cameraName, String streamKey) {
  final k = streamKey.trim();
  if (k.isNotEmpty) return k;
  return cameraName.trim();
}

@Deprecated('Use pathSegmentForConnect')
String rtmpPathSegmentForConnect(String cameraName, String streamKey) =>
    pathSegmentForConnect(cameraName, streamKey);

/// Formata duração do cronómetro em direto (mm:ss ou hh:mm:ss).
String formatStreamingElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:$m:$s';
  }
  return '$m:$s';
}
