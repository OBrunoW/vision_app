/// Protocolo de publicação em direto.
enum StreamProtocol {
  rtmp,
  rtsp;

  String get label => switch (this) {
        StreamProtocol.rtmp => 'RTMP',
        StreamProtocol.rtsp => 'RTSP',
      };

  String get scheme => name;

  static StreamProtocol fromPrefs(String? value) =>
      value == 'rtsp' ? StreamProtocol.rtsp : StreamProtocol.rtmp;
}
