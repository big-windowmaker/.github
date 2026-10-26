# Big WindowMaker — Decisão de Arquitetura (ADR-0001)

Data: 2026-10-25 · Status: **aprovada** (2026-10-25)

Fontes: [01-wayland-estrategia.md](../analise/01-wayland-estrategia.md) · [02-x11-wmaker-dockapps.md](../analise/02-x11-wmaker-dockapps.md) · [03-empacotamento-config.md](../analise/03-empacotamento-config.md) · [04-infra-iso-ci.md](../analise/04-infra-iso-ci.md)

## 1. Situação encontrada

| Repositório | Estado real |
|---|---|
| ruscher/wmaker | Espelho de upstream parado em 2021-03 (`82ab2d2`). Zero commits próprios. 324 commits atrás. |
| ruscher/wlmaker | Idêntico a phkaeser/wlmaker (`7481afe`). Zero commits próprios. |
| windowmaker-wl | Port GPL-2 ativo de mar–jun/2026, parado desde 29/06. Exige wlroots 0.19 (indisponível no Manjaro). |
| comm-wmaker | Não publicado. `.install` destrutivo (apaga `db.lck`, roda pacman na transação, reescreve GRUB, `reboot`). Skel de 66 MB com estado de máquina (caches, perfil de navegador). |
| comm-wmaker-config | Abandonado em "test". |
| biglinux-skel-wmaker / biglinux-calamares-wmaker | Geração 2022, mecanismo de instalador que não existe mais. |
| big-comm/build-iso | Arquivado; substituído por `build-iso/build-iso.sh` em biglinux/iso-profiles (manjaro-tools `buildiso` em Docker). |
| big-comm/iso-profiles | Sem edição wmaker. |

## 2. Decisões

### D1 — Sessão X11 (padrão, estável)
- Base: **window-maker/wmaker master** fixado por commit (pré-0.97.0), migrando para a tag 0.97.0 quando publicada.
- `big-windowmaker/wmaker`: fork com `master` espelho intocado; correções em branches → PR upstream. Distribuição via PKGBUILD com fila curta de patches.
- Configure: flags do Arch + `--enable-pango --enable-res`.
- Companheiros obrigatórios: `dex` (XDG autostart), `snixembed` (SNI→XEmbed), `picom`, `xss-lock` + locker, `autorandr`, `xsettingsd`, polkit agent, **um** daemon de notificação.

### D2 — Sessão Wayland (experimental)
- **Estratégia A: wlmaker** (Apache-2.0), tag `v0.8.1`/commit validado do main, contra `wlroots0.20`.
- Rótulo de login: **"Big WindowMaker — Wayland (experimental)"**.
- windowmaker-wl: apenas referência de comportamento. **Nenhuma cópia de código** (GPL-2 e arquivos sem cabeçalho).
- Lacunas a trabalhar upstream (phkaeser): DnD entre apps, xdg-activation, IME, temas compartilhados com X11.
- Reavaliar a Estratégia B em ~6 meses.

### D3 — Repositórios (consolidação)
A proposta de 11 repos é reduzida para **6**. Separações sem benefício (skel, themes, calamares, docs em repos próprios) foram eliminadas: mudam juntas, são versionadas juntas.

| Repo | Conteúdo | Justificativa |
|---|---|---|
| `.github` | perfil, templates de issue/PR, CODEOWNERS padrão, workflows reutilizáveis | padrão da org |
| `wmaker` | fork upstream (X11) | patches enviáveis upstream |
| `wlmaker` | fork upstream (Wayland) | patches enviáveis upstream |
| `big-wm` (existente) | **monorepo do desktop**: sessões, config padrão em `/usr/share`, temas, wallpapers, menus, calamares, traduções, docs — gera pacotes split | substitui os 4 repos antigos |
| `packages` | PKGBUILDs: wmaker, wlmaker, big-dockapps, dependências ausentes, keyring | ciclo de build próprio |
| `build-iso` | workflow da ISO + perfil `wmaker` (até ser aceito em big-comm/iso-profiles) | pipeline separado de pacotes |

Repo `keyring` só na Fase 2 (D5).

### D4 — Configuração do usuário
- **Sem pacote de skel.** Defaults em `/usr/share/big-wm/`; o wrapper de sessão aplica no primeiro login se `~/GNUstep` não existir; `exec wmaker` sem tocar no binário.
- Pacotes **nunca** escrevem em `/etc/skel`, `/home`, GRUB ou initramfs; sem `reboot`; sem pacman dentro de hooks.
- Coexistência com Plasma: nenhum arquivo em comum com pacotes KDE/BigLinux (verificado por `pacman -Qo` em CI).
- Display manager: **LightDM** (substitui LXDM; compatível com o perfil Calamares atual).

### D5 — Infraestrutura (duas fases)
- **Fase 1:** edição `bigcommunity/wmaker` via PR em big-comm/iso-profiles; pacotes genéricos no repo community assinados pela BigCommunity. Exige acordo com mantenedores.
- **Fase 2:** build sem segredos separado da publicação (modelo biglinux/build-package), actions fixadas por SHA, chave própria com subchave, `bigwm-keyring`, ISO com teste de boot QEMU, SHA256SUMS assinado e atestado de proveniência.

### D6 — Aproveitar dos repos antigos
Menu raiz (PT/EN), temas BigLinux, 4 wallpapers, layout do dock. Todo o resto é reescrito.

## 3. Pendências de coordenação externa
- BigCommunity: hospedagem de pacotes, dispatch em build-package, keyring, gitrepo.
- BigLinux: PR no motor build-iso.sh (produto/repo/keyring extras) e no biglinux-livecd (sessão live WM).
