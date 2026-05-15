import 'package:flutter_test/flutter_test.dart';
import 'package:vision_app/features/streaming/streaming_form_utils.dart';
import 'package:vision_app/services/rtmp_service.dart';

void main() {
  group('rtmpPathSegmentForConnect', () {
    test('prioriza a chave de stream quando não está vazia', () {
      expect(
        rtmpPathSegmentForConnect('cam1', '  yt-key-123  '),
        'yt-key-123',
      );
    });

    test('usa o nome da câmara quando a chave está vazia', () {
      expect(rtmpPathSegmentForConnect('  celular1  ', ''), 'celular1');
    });
  });

  group('buildRtmpStreamUrl', () {
    test('acrescenta o segmento ao path da URL base', () {
      expect(
        buildRtmpStreamUrl('rtmp://192.168.0.10/live', 'a1'),
        'rtmp://192.168.0.10/live/a1',
      );
    });

    test('remove segmentos vazios do path antes de acrescentar', () {
      expect(
        buildRtmpStreamUrl('rtmp://host/live/', 'key'),
        'rtmp://host/live/key',
      );
    });
  });

  group('formatStreamingElapsed', () {
    test('formata minutos e segundos', () {
      expect(
        formatStreamingElapsed(const Duration(minutes: 3, seconds: 7)),
        '03:07',
      );
    });

    test('inclui horas quando necessário', () {
      expect(
        formatStreamingElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
    });
  });
}
