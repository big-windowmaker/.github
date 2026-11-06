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

## Baixar

**Big WindowMaker Alpha** (ISO de teste, x86_64, BIOS e UEFI):
https://github.com/big-windowmaker/build-iso/releases

A ISO vem em partes `.7z` (limite de 2 GB por arquivo do GitHub). Para juntar
e conferir: `7z x bigcommunity_wmaker_*.iso.7z.001` e
`sha256sum -c SHA256SUMS --ignore-missing`. Modo live: usuário `community`,
senha `big`. É uma versão Alpha: teste primeiro numa máquina virtual.

## Novidades da Alpha (novembro de 2026)

<table>
<tr>
<td width="50%"><img src="https://raw.githubusercontent.com/big-windowmaker/big-wm/main/docs/screenshots/area-de-transferencia.png" alt="Janela Área de transferência com busca, Histórico e Favoritos"><br><b>Super+V</b>: histórico da área de transferência que sobrevive ao reinício, com busca, favoritos e privacidade, nas duas sessões</td>
<td width="50%"><img src="https://raw.githubusercontent.com/big-windowmaker/big-wm/main/docs/screenshots/bloqueio-teclado-wayland.png" alt="Tela de bloqueio com teclado na tela"><br><b>Tela de bloqueio OPENSTEP</b> com teclado na tela no Wayland (ABNT2 ou US), PAM do sistema</td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/big-windowmaker/big-wm/main/docs/screenshots/wmake-zones-dockapp.png" width="288" alt="Ladrilho do wmake-zones em Zonas, Mosaico e desligado"><br><b>wmake-zones 0.3.1</b>: zonas de encaixe e mosaico confiável em vários monitores; o ladrilho mostra o modo</td>
<td><img src="https://raw.githubusercontent.com/big-windowmaker/big-wm/main/docs/screenshots/vscodium-barra-de-titulo.png" alt="VSCodium com a barra do Electron e com a barra do Window Maker"><br><b>Barras de título do Window Maker</b> no GTK, Qt, Firefox e VSCodium</td>
</tr>
</table>

- Dockapps acoplados no Dock ou no Clip iniciam com a sessão (inclusive os adicionados pelo usuário).
- Nome e logo do Big WindowMaker para programas de fora (Big Screen Monitor Display, fastfetch).
- Versões: big-wm 26.11.06 · Window Maker 0.96.0.r130 (17 patches) · wlmaker 0.8.r80 (120 patches) · wmake-zones 0.3.1 · dockapps 20260412-9.

## Sessões

- **Big WindowMaker — X11** · padrão e estável: Window Maker com Dock, Clip,
  dockapps, menus em português e inglês, notificações, polkit, bandeja e bloqueio de tela.
- **Big WindowMaker — Wayland (experimental)** · compositor Wayland nativo
  [wlmaker](https://github.com/phkaeser/wlmaker), com o mesmo visual e XWayland.

## Instalar num BigLinux/BigCommunity

Os pacotes saem dos artefatos de CI de
[packages](https://github.com/big-windowmaker/packages) e
[big-wm](https://github.com/big-windowmaker/big-wm) (instruções em
[big-wm](https://github.com/big-windowmaker/big-wm#pacotes-num-sistema-biglinuxbigcommunity)).
Depois de instalar, escolha **Big WindowMaker** (X11) ou **Big WindowMaker —
Wayland** na tela de login.

Requisitos: x86_64, 2 GiB de RAM (a sessão X11 de referência usa cerca de
250 MiB de PSS), BIOS ou UEFI.

## Repositórios

| Repositório | Função | Estado |
|---|---|---|
| [big-wm](https://github.com/big-windowmaker/big-wm) | Sessões, configuração padrão, temas e integração do desktop | [![CI](https://github.com/big-windowmaker/big-wm/actions/workflows/ci.yml/badge.svg)](https://github.com/big-windowmaker/big-wm/actions/workflows/ci.yml) |
| [packages](https://github.com/big-windowmaker/packages) | PKGBUILDs: Window Maker, wlmaker, wmake-zones, dockapps | [![build](https://github.com/big-windowmaker/packages/actions/workflows/build.yml/badge.svg)](https://github.com/big-windowmaker/packages/actions/workflows/build.yml) |
| [wmake-zones](https://github.com/big-windowmaker/wmake-zones) | Zonas de encaixe e mosaico de janelas (X11 e Wayland) | [![CI](https://github.com/big-windowmaker/wmake-zones/actions/workflows/ci.yml/badge.svg)](https://github.com/big-windowmaker/wmake-zones/actions/workflows/ci.yml) |
| [build-iso](https://github.com/big-windowmaker/build-iso) | Geração da ISO, boot em VMs e testes de instalação | [![Build ISO](https://github.com/big-windowmaker/build-iso/actions/workflows/build-iso.yml/badge.svg)](https://github.com/big-windowmaker/build-iso/actions/workflows/build-iso.yml) |
| [iso-profiles](https://github.com/big-windowmaker/iso-profiles) | Perfil da edição `bigcommunity/wmaker` (branch `wmaker-edition`) | |
| [biglinux-livecd](https://github.com/big-windowmaker/biglinux-livecd) | Sessão live com suporte ao Window Maker (`main`) | |
| [wmaker](https://github.com/big-windowmaker/wmaker) | Fork do [Window Maker](https://www.windowmaker.org/) para correções enviadas ao upstream | |
| [wlmaker](https://github.com/big-windowmaker/wlmaker) | Fork do [wlmaker](https://github.com/phkaeser/wlmaker) para correções enviadas ao upstream | |
| [.github](https://github.com/big-windowmaker/.github) | Documentação, decisões de arquitetura e padrões | |

Decisões de arquitetura: [ADR-0001](https://github.com/big-windowmaker/.github/blob/main/docs/adr/0001-arquitetura.md).

## Créditos

Desenvolvimento do Big WindowMaker:

- **Rafael Ruscher** — <rruscher@gmail.com.br>
- **Barnabé Di Kartola** — <barnabedikartola@gmail.com>

Sobre os ombros do [Window Maker](https://www.windowmaker.org/), do
[wlmaker](https://github.com/phkaeser/wlmaker) (Philipp Kaeser), do
[BigLinux](https://www.biglinux.com.br) e da [BigCommunity](https://communitybig.org).
