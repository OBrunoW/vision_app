/// Segmento final do path RTMP (nome MediaMTX ou chave YouTube, etc.).
String rtmpPathSegmentForConnect(String cameraName, String streamKey) {
  final k = streamKey.trim();
  if (k.isNotEmpty) return k;
  return cameraName.trim();
}

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
