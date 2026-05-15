# rtmp_camera

Aplicação Flutter que transforma o telemóvel numa câmera de streaming **RTMP**. Indica um nome para o fluxo e a URL base do servidor, vê o *preview* em ecrã inteiro, alterna entre câmera frontal e traseira e segue o tempo no ar.

## Lançamento v1.0.0

Primeira versão estável. Consulta o ficheiro [`CHANGELOG.md`](CHANGELOG.md) para o detalhe das funcionalidades e correções.

**Tag Git:** `v1.0.0`  
**Versão no `pubspec.yaml`:** `1.0.0+1` (nome do pacote: `vision_app`)

### Publicar no GitHub (sem GitHub CLI)

1. Cria um repositório vazio no GitHub (ex.: `vision_app`).
2. Na raiz do projeto:

```bash
git remote add origin https://github.com/TEU_UTILIZADOR/vision_app.git
git branch -M main
git push -u origin main
git push origin v1.0.0
```

3. No GitHub: **Releases → Create a new release**, escolhe a tag `v1.0.0` e cola o resumo do `CHANGELOG.md` na descrição.

### Publicar com GitHub CLI (`gh`)

```bash
winget install GitHub.cli
gh auth login
gh repo create vision_app --private --source=. --push
git tag -a v1.0.0 -m "Lançamento v1.0.0"   # se ainda não existir
git push origin v1.0.0
gh release create v1.0.0 --title "rtmp_camera v1.0.0" --notes-file CHANGELOG.md
```

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
│   ├── config_screen.dart
│   └── streaming_screen.dart
├── services/
│   └── rtmp_service.dart
└── widgets/
    └── live_indicator.dart
assets/
├── svg/logo-visor.svg
└── png/                    # gerado pelo teste (ver abaixo)
```

## Identidade e tema

- Tema **claro/escuro** segue o sistema (`ThemeMode.system`).
- Cores de marca extraídas do logo (azuis e verde); restantes neutras estilo ChatGPT.
- **Regenerar ícones e splash nativos** após alterar o SVG:

```bash
flutter test test/export_branding_pngs_test.dart
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

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
