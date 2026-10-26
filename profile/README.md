<p align="center">
  <img src="https://raw.githubusercontent.com/big-windowmaker/big-wm/main/themes/logo/big-wm.svg" width="140" alt="Logo do Big WindowMaker">
</p>

<h1 align="center">Big WindowMaker</h1>

<p align="center">
  Uma edição do <a href="https://www.biglinux.com.br">BigLinux</a> / <a href="https://communitybig.org">BigCommunity</a>
  com o <b>Window Maker</b>: a experiência clássica do NeXTSTEP,<br>
  sessões X11 e Wayland e integração completa com o sistema.
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/big-windowmaker/big-wm/main/docs/screenshots/x11-desktop.png" width="90%" alt="Sessão X11 do Big WindowMaker">
</p>

## Sessões

- **Big WindowMaker — X11** · padrão e estável: Window Maker com Dock, Clip,
  dockapps, menus em português e inglês, notificações, polkit, bandeja e bloqueio de tela.
- **Big WindowMaker — Wayland (experimental)** · compositor Wayland nativo
  [wlmaker](https://github.com/phkaeser/wlmaker), com o mesmo visual e XWayland.

## Repositórios

| Repositório | Função | Estado |
|---|---|---|
| [big-wm](https://github.com/big-windowmaker/big-wm) | Sessões, configuração padrão, temas e integração do desktop | [![CI](https://github.com/big-windowmaker/big-wm/actions/workflows/ci.yml/badge.svg)](https://github.com/big-windowmaker/big-wm/actions/workflows/ci.yml) |
| [packages](https://github.com/big-windowmaker/packages) | PKGBUILDs: Window Maker, wlmaker, dockapps | [![build](https://github.com/big-windowmaker/packages/actions/workflows/build.yml/badge.svg)](https://github.com/big-windowmaker/packages/actions/workflows/build.yml) |
| [build-iso](https://github.com/big-windowmaker/build-iso) | Geração da ISO, boot em VMs e testes de instalação | [![Build ISO](https://github.com/big-windowmaker/build-iso/actions/workflows/build-iso.yml/badge.svg)](https://github.com/big-windowmaker/build-iso/actions/workflows/build-iso.yml) |
| [iso-profiles](https://github.com/big-windowmaker/iso-profiles) | Perfil da edição `bigcommunity/wmaker` (branch `wmaker-edition`) | |
| [biglinux-livecd](https://github.com/big-windowmaker/biglinux-livecd) | Sessão live com suporte ao Window Maker (branch `window-maker`) | |
| [wmaker](https://github.com/big-windowmaker/wmaker) | Fork do [Window Maker](https://www.windowmaker.org/) para correções enviadas ao upstream | |
| [wlmaker](https://github.com/big-windowmaker/wlmaker) | Fork do [wlmaker](https://github.com/phkaeser/wlmaker) para correções enviadas ao upstream | |
| [.github](https://github.com/big-windowmaker/.github) | Documentação, decisões de arquitetura e padrões | |

Decisões de arquitetura: [ADR-0001](https://github.com/big-windowmaker/.github/blob/main/docs/adr/0001-arquitetura.md).
