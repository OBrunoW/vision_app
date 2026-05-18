import 'package:flutter_test/flutter_test.dart';
import 'package:vision_app/features/streaming/stream_protocol.dart';
import 'package:vision_app/features/streaming/streaming_form_utils.dart';
import 'package:vision_app/services/rtmp_service.dart';

void main() {
  group('validateStreamConfig', () {
    test('rejeita URL vazia', () {
      expect(
        validateStreamConfig(
          protocol: StreamProtocol.rtmp,
          baseUrl: '',
          cameraName: 'cam',
          streamKey: '',
        ),
        isNotNull,
      );
    });

    test('rejeita quando falta nome e chave', () {
      expect(
        validateStreamConfig(
          protocol: StreamProtocol.rtmp,
          baseUrl: 'rtmp://host/live',
          cameraName: '  ',
          streamKey: '',
        ),
        isNotNull,
      );
    });

    test('aceita configuração RTMP válida', () {
      expect(
        validateStreamConfig(
          protocol: StreamProtocol.rtmp,
          baseUrl: 'rtmp://host/live',
          cameraName: 'cam1',
          streamKey: '',
        ),
        isNull,
      );
    });

    test('aceita configuração RTSP válida', () {
      expect(
        validateStreamConfig(
          protocol: StreamProtocol.rtsp,
          baseUrl: 'rtsp://host:8554/cam',
          cameraName: 'celular1',
          streamKey: '',
        ),
        isNull,
      );
    });

    test('rejeita esquema diferente do protocolo', () {
      expect(
        validateStreamConfig(
          protocol: StreamProtocol.rtsp,
          baseUrl: 'rtmp://host/live',
          cameraName: 'cam1',
          streamKey: '',
        ),
        'A URL deve começar por rtsp://',
      );
    });
  });

  group('pathSegmentForConnect', () {
    test('prioriza a chave de stream quando não está vazia', () {
      expect(
        pathSegmentForConnect('cam1', '  yt-key-123  '),
        'yt-key-123',
      );
    });

    test('usa o nome da câmara quando a chave está vazia', () {
      expect(pathSegmentForConnect('  celular1  ', ''), 'celular1');
    });
  });

  group('buildStreamUrl', () {
    test('acrescenta o segmento ao path da URL base RTMP', () {
      expect(
        buildStreamUrl('rtmp://192.168.0.10/live', 'a1'),
        'rtmp://192.168.0.10/live/a1',
      );
    });

    test('acrescenta o segmento ao path da URL base RTSP', () {
      expect(
        buildStreamUrl('rtsp://192.168.0.10:8554/cam', 'a1'),
        'rtsp://192.168.0.10:8554/cam/a1',
      );
    });

    test('remove segmentos vazios do path antes de acrescentar', () {
      expect(
        buildStreamUrl('rtmp://host/live/', 'key'),
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
