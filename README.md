# rtmp_camera

Aplicação Flutter que transforma o telemóvel numa câmera de streaming **RTMP**. O *preview* ocupa o ecrã inteiro: configuras nome e URL num painel de vidro na parte inferior, inicias a transmissão no mesmo ecrã, podes alternar câmera e seguir o tempo no ar.

## Lançamento v1.1.0

Versão atual: **ecrã único** (câmera + configuração em painel de vidro) e **splash** mais rápida.

**Tag Git:** `v1.1.0`  
**Versão no `pubspec.yaml`:** `1.1.0+2` (nome do pacote: `vision_app`)

A tag `v1.0.0` mantém-se no histórico para a primeira versão estável anterior.

### Publicar no GitHub (sem GitHub CLI)

1. Na raiz do projeto (com `origin` já configurado):

```bash
git push -u origin main
git push origin v1.1.0
```

2. No GitHub: **Releases → Create a new release**, escolhe a tag `v1.1.0` e escreve a descrição da release no editor (resumo das alterações).

### Publicar com GitHub CLI (`gh`)

```bash
git push origin main
git push origin v1.1.0
gh release create v1.1.0 --title "rtmp_camera v1.1.0" --notes "Ecrã único de câmera, painel de vidro e splash rápida."
```

*(Para a primeira publicação do repositório, vê os passos da versão 1.0.0 no histórico do Git ou documentação antiga.)*

---

## Stack

- Flutter (Material 3)
- [rtmp_streaming](https://pub.dev/packages/rtmp_streaming) — *preview*, captura e publicação RTMP (Android com RootEncoder, iOS com HaishinKit)
- [permission_handler](https://pub.dev/packages/permission_handler) — câmera e microfone
- [shared_preferences](https://pub.dev/packages/shared_preferences) — última URL e nome guardados
- [wakelock_plus](https://pub.dev/packages/wakelock_plus) — ecrã ligado durante a transmissão
- [flutter_svg](https://pub.dev/packages/flutter_svg) — logo vectorial na UI

O pacote oficial `camera` não é usado no código: o `rtmp_streaming` expõe `CameraController` e `CameraPreview` próprios.

## Estrutura

```
lib/
├── main.dart
├── theme/
│   └── app_theme.dart
├── screens/
│   ├── splash_screen.dart
│   └── streaming_screen.dart
├── services/
│   └── rtmp_service.dart
└── widgets/
    └── live_indicator.dart
assets/
├── svg/logo-visor.svg
└── png/
```

## Identidade e tema

- Tema **claro/escuro** segue o sistema (`ThemeMode.system`).
- Cores de marca extraídas do logo (azuis e verde); restantes neutras estilo ChatGPT.
- O vetor do logo está em `assets/svg/`; os *bitmaps* e recursos nativos de ícone e splash correspondentes estão em `assets/png/`, `android/` e `ios/` (já versionados no repositório).

## Configuração e execução

1. Instala o [Flutter](https://docs.flutter.dev/get-started/install) e verifica com `flutter doctor`.
2. Na raiz: `flutter pub get`
3. Android: dispositivo ou emulador com API ≥ 21 — `flutter run`.
4. iOS (opcional): `cd ios && pod install`, depois `flutter run` num Mac com certificado de desenvolvimento.

## MediaMTX

1. Sobe o [MediaMTX](https://github.com/bluenviron/mediamtx) na máquina ou servidor acessível na rede.
2. Em **URL RTMP**, usa o endpoint sem o nome do fluxo no fim, por exemplo: `rtmp://IP:1935/live`
3. Em **Nome da câmera**, usa o *stream key*, por exemplo: `celular1` → URL final `rtmp://IP:1935/live/celular1`.
4. Lê o fluxo no MediaMTX ou ativa HLS conforme o teu `mediamtx.yml`.

## Permissões

| Plataforma | Permissões |
|------------|------------|
| Android    | `INTERNET`, `CAMERA`, `RECORD_AUDIO`, `WAKE_LOCK` (`AndroidManifest.xml`) |
| iOS        | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` (`Info.plist`) |

## Requisitos Android

- `minSdkVersion` 21  
- `targetSdkVersion` 34  

Definidos em `android/app/build.gradle.kts`.
