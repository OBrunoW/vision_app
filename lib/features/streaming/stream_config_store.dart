import 'package:shared_preferences/shared_preferences.dart';

import 'stream_protocol.dart';

/// Valores do formulário de transmissão.
class StreamFormData {
  const StreamFormData({
    this.url = '',
    this.name = '',
    this.streamKey = '',
  });

  final String url;
  final String name;
  final String streamKey;
}

/// Persistência separada por protocolo (RTMP / RTSP).
class StreamConfigStore {
  StreamConfigStore._();

  static const lastProtocolKey = 'last_stream_protocol';

  // Chaves legadas (migração única para RTMP).
  static const _legacyUrl = 'last_rtmp_url';
  static const _legacyName = 'last_camera_name';
  static const _legacyKey = 'last_stream_key_optional';

  static String _urlKey(StreamProtocol p) => '${p.name}_stream_url';
  static String _nameKey(StreamProtocol p) => '${p.name}_stream_name';
  static String _streamKeyKey(StreamProtocol p) => '${p.name}_stream_key';

  static Future<void> migrateLegacy(SharedPreferences prefs) async {
    if (prefs.getString(_urlKey(StreamProtocol.rtmp)) != null) return;
    final legacyUrl = prefs.getString(_legacyUrl);
    if (legacyUrl == null) return;
    await prefs.setString(_urlKey(StreamProtocol.rtmp), legacyUrl);
    await prefs.setString(
      _nameKey(StreamProtocol.rtmp),
      prefs.getString(_legacyName) ?? '',
    );
    await prefs.setString(
      _streamKeyKey(StreamProtocol.rtmp),
      prefs.getString(_legacyKey) ?? '',
    );
  }

  static Future<StreamFormData> load(
    SharedPreferences prefs,
    StreamProtocol protocol,
  ) async {
    await migrateLegacy(prefs);
    return StreamFormData(
      url: prefs.getString(_urlKey(protocol)) ?? '',
      name: prefs.getString(_nameKey(protocol)) ?? '',
      streamKey: prefs.getString(_streamKeyKey(protocol)) ?? '',
    );
  }

  static Future<void> save(
    SharedPreferences prefs,
    StreamProtocol protocol,
    StreamFormData data,
  ) async {
    await prefs.setString(_urlKey(protocol), data.url.trim());
    await prefs.setString(_nameKey(protocol), data.name.trim());
    await prefs.setString(_streamKeyKey(protocol), data.streamKey.trim());
    await prefs.setString(lastProtocolKey, protocol.name);
  }
}
