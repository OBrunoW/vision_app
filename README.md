# rtmp_camera

Aplicativo Flutter que transforma o celular em uma câmera de streaming RTMP. Informe um nome para o fluxo e a URL base do servidor, visualize o preview em tela cheia, alterne entre câmera frontal e traseira e acompanhe o tempo no ar.

## Stack

- Flutter (Material 3)
- [rtmp_streaming](https://pub.dev/packages/rtmp_streaming) — preview, captura e publicação RTMP (Android com RootEncoder, iOS com HaishinKit), mantido de forma mais recente que alternativas como `rtmp_broadcaster` apenas com dependências antigas
- [permission_handler](https://pub.dev/packages/permission_handler) — solicitação de câmera e microfone
- [shared_preferences](https://pub.dev/packages/shared_preferences) — última URL e nome salvos
- [wakelock_plus](https://pub.dev/packages/wakelock_plus) — tela ligada durante a transmissão

O pacote oficial `camera` não é usado no código: o `rtmp_streaming` expõe `CameraController` e `CameraPreview` próprios, evitando conflito de tipos com o plugin `camera`.

## Estrutura

```
lib/
├── main.dart
├── screens/
│   ├── config_screen.dart
│   └── streaming_screen.dart
├── services/
│   └── rtmp_service.dart
└── widgets/
    └── live_indicator.dart
```

## Configuração e execução

1. Instale o [Flutter](https://docs.flutter.dev/get-started/install) e confira o ambiente com `flutter doctor`.
2. Na raiz do projeto: `flutter pub get`
3. Android: conecte um dispositivo ou emulador com API ≥ 21 e execute `flutter run`.
4. iOS (opcional): `cd ios && pod install`, depois `flutter run` com um Mac e certificado de desenvolvimento.

## MediaMTX

1. Suba o [MediaMTX](https://github.com/bluenviron/mediamtx) (binário ou Docker) na máquina ou servidor acessível pela rede local.
2. No app, em **URL RTMP**, use o endpoint de publicação sem o nome do fluxo no final, por exemplo: `rtmp://IP_DO_SERVIDOR:1935/live`
3. Em **Nome da câmera**, use o identificador do path (stream key), por exemplo: `celular1`. O app monta `rtmp://IP:1935/live/celular1`.
4. No MediaMTX, leia o stream em `rtmp://IP:1935/live/celular1` ou habilite HLS conforme a configuração padrão do `mediamtx.yml`.

Ajuste host, porta e path (`live`, `mystream`, etc.) conforme o seu `mediamtx.yml`.

## Permissões

| Plataforma | Permissões |
|------------|------------|
| Android    | `INTERNET`, `CAMERA`, `RECORD_AUDIO`, `WAKE_LOCK` (declaradas no `AndroidManifest.xml`) |
| iOS        | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` no `Info.plist` |

O app solicita câmera e microfone ao abrir a tela de transmissão.

## Requisitos Android

- `minSdkVersion` 21  
- `targetSdkVersion` 34  

Definidos em `android/app/build.gradle.kts`.
