# Registo de alterações

Todos os itens notáveis deste projeto serão documentados neste ficheiro.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-PT/1.0.0/),
e o projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [1.0.0] — 2026-05-15

### Adicionado
- Aplicação **rtmp_camera**: configuração (nome + URL RTMP), streaming em ecrã inteiro, troca de câmera, indicador ao vivo, cronómetro e reconexão RTMP.
- **Identidade visual**: logo SVG (`assets/svg/logo-visor.svg`), tema claro/escuro alinhado ao sistema Android, paleta neutra tipo ChatGPT e cores da marca (azul e verde do logo).
- **Splash**: ecrã inicial Flutter (`SplashScreen`) e splash nativa (Android/iOS) com modo claro e escuro.
- **Ícone da aplicação**: Android (incl. ícone adaptativo) e iOS gerados a partir do logo.
- Teste `test/export_branding_pngs_test.dart` para regenerar PNGs (`assets/png/`) a partir do SVG, usados pelos geradores de ícone e splash.

### Corrigido
- Chamada a `prepareForVideoStreaming` apenas no iOS (no Android o plugin não implementa o método, evitando `MissingPluginException`).
- Evitar reconexão RTMP espúria ao trocar de câmera durante a transmissão.

### Documentação
- `README.md` com stack, estrutura, execução, MediaMTX e permissões.
