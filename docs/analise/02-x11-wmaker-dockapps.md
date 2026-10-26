# 02 — Window Maker (X11) e dockapps: estado do upstream, base do fork e empacotamento

> Data da análise: 2026-10-25
> Repositórios analisados (somente leitura, nada foi modificado nem enviado):
> - `upstream/wmaker` → `github.com/ruscher/wmaker` (HEAD `82ab2d2`, 2021-03-18)
> - `upstream/window-maker-wmaker` → `github.com/window-maker/wmaker` (HEAD `558e67f`, 2026-10-10)
> - `upstream/dockapps` → `github.com/window-maker/dockapps` (HEAD `251e851`, 2026-04-10)
>
> Contexto local também consultado: `upstream/comm-wmaker` (metapacote atual + `autostart` do skel).

---

## 1. Relação entre `ruscher/wmaker` e o upstream

### 1.1 Método

Os dois clones são *partial clones* (`--filter=blob:none`), e o `git fetch` de um para o outro falhou
(“aborting due to possible repository corruption on the remote side”, efeito da falta de blobs).
Por isso a comparação foi feita pelos hashes: o commit do fork existe no upstream e é ancestral de `master`.
Nenhuma ref foi criada no fork (`for-each-ref | grep up/` = 0; working tree limpo).

### 1.2 Resultado

| Item | Valor |
|---|---|
| HEAD do fork | `82ab2d2` “Correct calculation of usable space for reserved area.” (Roman Dobosz, 2021-03-18) |
| `git describe` no upstream | `wmaker-0.95.9-25-g82ab2d2` → 0.95.9 + 25 commits |
| Merge-base | **o próprio `82ab2d2`**: o fork é ancestral direto de `upstream/master` |
| Commits exclusivos do fork | **0** (nenhum patch do ruscher; o único branch remoto é `master` = `82ab2d2`) |
| Commits do upstream que faltam no fork | **324** (`82ab2d2..master`) |
| Último release | **`wmaker-0.96.0`** (`d0aa2ce`, 2023-08-05) |
| Commits após 0.96.0 | **130** (`wmaker-0.96.0-130-g558e67f`) |
| Versão no `configure.ac` | ainda `0.96.0`, mas o `NEWS` já tem a seção **“-- 0.97.0”** (lançamento em preparação, sem tag) |
| Branches do upstream | `next` está **parado** (0 à frente, 231 atrás de master); `cairo` é de 2010. Só `master` importa. |
| `repo.or.cz/wmaker-crm.git` | espelho idêntico (`HEAD = 558e67f`), e é de onde o Arch compila |

**Conclusão:** `ruscher/wmaker` é um espelho desatualizado, sem customizações. Ele não guarda nenhum valor
próprio e pode ser descartado ou ressincronizado sem perda.

### 1.3 O que o upstream ganhou desde o fork (324 commits)

Autores principais: David Maciejak (186; mantenedor ativo em 2025–2026), Christophe Curis (48), Doug Torrance (31).
Por assunto (pelos títulos dos commits): cerca de 98 correções, 29 achados do Coverity, 18 vazamentos de memória,
14 casos de crash, NULL, overflow ou use-after-free, e 25 commits sobre RandR, Xinerama ou multi-head.

**Entre o fork (mar/2021) e o 0.96.0 (ago/2023):**
- XDG: histórico em `$XDG_STATE_HOME`; WPrefs no menu XDG; `wmaker.desktop` para os display managers; `wmaker.inst` não mexe mais em `~/.xinitrc`.
- **Hot corners** (comando por canto da tela), **captura de tela** nativa (região, janela ou tela inteira).
- `_NET_WM_FULLSCREEN_MONITORS`, **KeepDockOnPrimaryHead**, snapping desenhado direito em multi-head.
- Estado de maximização persistente, duplo clique na barra de título para desmaximizar, “centralizar janela ativa”.
- libXRes opcional: descobre o PID e o `WM_COMMAND` de apps que não o informam, o que permite fazer autostart delas.
- Ícones até 256 px e “dots” do dock escaláveis (ajuda em HiDPI).
- Rodada grande de correções do Coverity, correção da compilação com Pango, libtiff 4.3 e `mallinfo2`.

**Depois do 0.96.0 (130 commits, seção “0.97.0” do NEWS):**
- **RandR 1.3 reescrito** (`1f03c13`): ativado automaticamente; modo estático (padrão, layout feito com xrandr, arandr ou autorandr) ou **`HotplugMonitor = YES`** (detecta monitor conectado e o põe à direita). Opção também no WPrefs. `ScreenSwitchKey` passa a percorrer as saídas RandR (`78b58d4`).
- **`_NET_WM_MOVERESIZE`** (`6d0953b`): mover e redimensionar janelas com CSD (Chrome, VS Code, Steam, Discord). **Isso torna desnecessário o hack `sed custom_chrome_frame:false` do `autostart` atual do Big.**
- Foco direcional, marcação de janelas no estilo vim, atalhos multi-tecla (*key chains*), rótulos de modificadores em Unicode.
- Rolar a roda do mouse pode dar foco (opcional), ícones de apps na lista de janelas e no switch panel, Alt-Tab por todos os workspaces.
- Botão de idioma (layout XKB) na barra de título, que exige `libxkbfile`.
- **A tecla Print deixou de ser capturada por padrão** (`896bbce`), então ela fica livre para Spectacle e afins.
- WRaster: JPEG XL opcional, interpolação Catmull-Rom, alpha mais rápido. wmiv: abre arquivos compactados (libarchive).
- **Segurança e robustez:** overflow inteiro no parser de `_NET_WM_ICON` (`5eb3287`), checagens de `RCreateImage` (`aa7287e`, `0dd8b6a`), crash com janelas sem `WM_HINTS` (`ee9fd77`), NULL deref em atalho sem janela focada (`56ec561`), crash “X connection broken” e leak no `wmsetbg` (`6c107e0`, `7c80e91`), UTF-8 cortado em títulos (`7294226`, `fa49b7c`), janelas 1×1 não gerenciadas (`535288c`, que afetava qiv e outros), `_NET_WM_WINDOW_TYPE` tratado como lista (`0d74066`).
- `X-GDM-SessionRegisters` removido do `.desktop` (`ac19c4b`). O Arch aplicava isso via `sed`, e agora já vem do upstream.
- **Tradução:** o antigo `po/pt.po` era na verdade **pt_BR** e virou `po/pt_BR.po` (`b69c9db`, jun/2026). Ele é de **2000** (`PO-Revision-Date: 2000-06-06`). O WPrefs só tem `pt.po`, também de 2000 e brasileiro. **Aqui o projeto Big pode contribuir com o upstream.**

---

## 2. Recomendação: base e estratégia do fork

### 2.1 Base: **upstream `master` fixado em um commit**, migrando para a tag `wmaker-0.97.0` quando ela sair

| Opção | Prós | Contras | Veredito |
|---|---|---|---|
| `ruscher/wmaker` | nenhum | 0.95.9+25, de 2021, 324 commits atrás, sem patches próprios | **Descartar** |
| Tag `wmaker-0.96.0` (= Arch `extra`) | release “oficial”, mesmo binário do Arch | 3 anos de idade; sem `_NET_WM_MOVERESIZE`, sem RandR hotplug e sem as correções de crash e overflow | Só como fallback |
| **`master` fixado** (ex.: `558e67f`) | todas as correções de 2025–2026; o upstream está ativo e a 0.97.0 está em preparação | snapshot não lançado, então é preciso testar o ISO | **Recomendado** |

Na prática:
- `pkgver=0.96.0.r130.g558e67f` (no formato do `git describe`), com `source=("git+https://github.com/window-maker/wmaker.git#commit=558e67f…")`.
- Atualizar o commit fixado de forma deliberada (por exemplo, a cada mês ou a cada correção relevante), com um teste rápido em VM.
- Quando `wmaker-0.97.0` for publicada, mudar para `#tag=wmaker-0.97.0` e voltar a seguir só os releases e as correções escolhidas.

### 2.2 Estratégia do fork `big-windowmaker/wmaker`

**Recomendação: fila de patches no repositório do PKGBUILD. O fork no GitHub serve só para desenvolver e mandar contribuições ao upstream.**

1. **Fork no GitHub (`big-windowmaker/wmaker`):**
   - `master`: **espelho intocado** do `window-maker/wmaker` (sincronizado por GitHub Action ou “Sync fork”). O `ruscher/wmaker` pode ser ressincronizado ou arquivado.
   - Branches `feature/*` e `fix/*` para cada mudança, sempre a partir de `master`, abrindo **PR no upstream**. O upstream aceita PRs no GitHub (veja “Imported from window-maker/wmaker pull request 68”) e também pela lista `wmaker-dev@googlegroups.com`.
   - Não manter um branch “big” de longa duração com rebase eterno: com o upstream ativo, isso vira dívida rapidamente.
2. **PKGBUILD (`windowmaker-big` ou substituindo `windowmaker`):**
   - `provides=(windowmaker) conflicts=(windowmaker)`.
   - Diretório `patches/NNNN-*.patch` gerado com `git format-patch` a partir das branches acima, aplicado em `prepare()`. A fila deve ser **pequena**, com cada patch ligado a um PR do upstream e removido quando for aceito.
3. **Nada de tema ou configuração em patch.** Defaults, menu, temas, ícones e `autostart` ficam em `comm-wmaker-config` / `biglinux-skel-wmaker` (como hoje em `/etc/skel/GNUstep`) ou, melhor, em `/usr/share/WindowMaker` + `/etc/GNUstep/Defaults` como padrão do sistema, com o skel ficando mínimo.
4. **Primeiras contribuições candidatas ao upstream:** atualizar `po/pt_BR.po`, criar `WPrefs.app/po/pt_BR.po`, e futuramente suporte a XDG autostart e a `_NET_WM_STATE_DEMANDS_ATTENTION` (seção 5).

### 2.3 Flags de configure recomendadas

O Arch usa (`extra/windowmaker 0.96.0-5`, fonte `repo.or.cz/wmaker-crm.git#tag=wmaker-0.96.0`):
```
--prefix=/usr --sysconfdir=/etc --localstatedir=/var
--enable-modelock --enable-wmreplace --enable-xinerama --enable-randr --enable-usermenu
LINGUAS=<todas as .po>
```
Padrões do `configure.ac` atual: `pango`, `res`, `randr`, `xinerama`, `jxl`, `webp`, `magick`, `shape` e `shm` = *auto*; `modelock`, `usermenu` e `wmreplace` = *no*.

Para o Big, sobre o `master`:
```
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
  --enable-modelock --enable-wmreplace --enable-xinerama --enable-randr \
  --enable-usermenu --enable-pango --enable-res
```
- Acrescentar às `depends` **`libxres`** (o Arch não lista, então o recurso XRes acaba desligado num build em chroot limpo), **`libxkbfile`** (botão de layout da barra de título com modelock) e, opcionalmente, `libjxl` e `libarchive` (wmiv).
- Não usar `--enable-native` em pacote de distribuição.
- O `sed` de `X-GDM-SessionRegisters` que o Arch faz já não é necessário com `master`.

---

## 3. Empacotamento no Arch, AUR e no repositório BigLinux

### 3.1 Window Maker

| Pacote | Repo | Versão | Observação |
|---|---|---|---|
| `windowmaker` | extra | 0.96.0-5 (build de jul/2026) | Tag 0.96.0 com as flags acima. Deps: imagemagick, giflib, libexif, libwebp, libxft, libxinerama, libxmu, libxrandr, pango, perl, xorg-xset… (sem libxres) |
| `windowmaker-git` | AUR | 0.96.0.r14.gda676c9e-2 (mod. 2026-06) | Snapshot de **nov/2024**, ou seja, também antigo. Flags: `--enable-xinerama --enable-usermenu --enable-modelock --enable-randr --with-gnustepdir=/usr/lib/GNUstep`; inclui libxres e libbsd |
| `windowmaker-extra` | AUR | 0.1-6 (2018) | Ícones e temas extras (o `comm-wmaker` atual depende dele) |
| `menumaker` | extra | 0.99.14 | Gerador de menus |
| `wmautomenu-biglinux` | biglinux-stable | 22.12.14 | Gerador de menu XDG do Big (`xdg_menu`) |
| `wlmaker` | AUR | 0.8.1 | Compositor Wayland inspirado no WM (caminho de longo prazo, fora do escopo deste relatório) |

### 3.2 Dockapps já disponíveis

- **biglinux-stable:** `wmamixer`, `wmclock`, `wmix` (24.11.06, compilado do git dockapps), `wmmemload`, `wmnd`, `wmsystemtray`, `wmsystray`, `wmautomenu-biglinux`.
- **AUR (busca por nome e descrição), com os mais relevantes destacados:** `libdockapp` 0.7.3, `wmbattery` 2.56, `wmbatteries` 0.1.7, `wmcpuload` 1.1.1, `wmcore` 0.0.4, `wmtop` 0.85, `wmsysmon`, `wmsmpmon` 3.1, `wmnd` 0.4.18, `wmnet`, `wmifs` 1.9, `wmwifi`, `wmmixer` 1.9, `wmpulsemixer` 0.1.4 (2026), `volume.app`, `wmusic` 2.1.1 (MPRIS), `wmclock`, `wmtime` 1.4, `wmcalclock` 1.25, `wmclockmon` 0.8.1 (antigo; o upstream já está em 1.0.0), `wmweather` 2.4.8, `wmweather+`, `wmudmount` 3.0, `wmvolman` 2.0.1, `wmtrash`, `wmcliphist`, `wmshutdown`, `wmsystemtray` 1.4, `wmcube`, `wmbiff`, `wmgtemp`, `wmarchup-git` (marcado como desatualizado), `docker-tray`, `xdock` (emula o dock em outros WMs), `fsviewer` (2024, FileViewer estilo NeXT).
- **Não encontrados no AUR:** `wmacpi`, `wmmoonclock`, `wmmon`, `wmload`, `wmhdplop`, `wmsupermon`, `wmglobe`. O `wmmemload` só existe no biglinux-stable.

---

## 4. Dockapps (`window-maker/dockapps`)

O repositório tem 107 diretórios. Datas de 2023-10-10, 2024-05 e 2025-02-26 são, em boa parte, **commits em massa** (remoção de declarações pré-ANSI, correções para GCC 14, `AddMouseRegion` unsigned). Isso indica que o código compila, não que o dockapp tem manutenção real.

### 4.1 Com manutenção real (2024–2026)

| Dockapp | Última mudança | Observação |
|---|---|---|
| `wmusic` | 2026-04 | Controle remoto **MPRIS** via D-Bus (qualquer player moderno), capa do álbum |
| `wmacpi` | 2026-03 | Bateria ACPI. Lê `/sys/class/power_supply` com fallback para `/proc/acpi`; corrigido para musl |
| `wmbiff` | 2026-02 | Contador de e-mail IMAP/POP com TLS |
| `wmnet` | 2025-08 | Tráfego de rede (`/proc/net/dev`), migrado para autotools |
| `wmclockmon` | 2024-05 | 1.0.0, configurador em GTK3 (o AUR ainda está na 0.8.1) |
| `wmCalClock`, `wmtime`, `wmmoonclock`, `wmsun`, `wmcube`, `wmget`, `wmix` | 2024–2025 | Compilam com GCC atual |
| `libdockapp` | 2024-10 | Biblioteca de base para muitos dockapps |

### 4.2 Relevantes para uma distro moderna

| Função | Recomendado | Backend | Situação |
|---|---|---|---|
| Bateria | **`wmbattery`** (UPower; precisa de `upower-glib`) ou `wmacpi` (sysfs) | UPower / sysfs | OK. `cbatticon` (bandeja) continua como alternativa |
| Volume | **`wmix`** com o dispositivo ALSA `default` | ALSA → `pipewire-alsa` | Funciona sobre PipeWire pelo plugin ALSA. `wmpulsemixer` (AUR, 2026) usa a API Pulse e funciona com `pipewire-pulse` |
| Mídia | **`wmusic`** | MPRIS/D-Bus | Moderno |
| CPU | **`wmcpuload`** / `wmcore` (por núcleo) / `wmsmpmon` | `/proc/stat` | OK |
| Memória | **`wmmemload`** | `/proc/meminfo` | OK, já está no biglinux-stable |
| Rede | **`wmnd`** ou `wmnet` | `/proc/net/dev` | OK |
| Relógio e calendário | **`wmclock`** / `wmCalClock` / `wmclockmon` / `wmtime` | — | OK |
| Clima | **`wmweather`** (AUR 2.4.8; fora do repositório dockapps) | METAR (NOAA), código ICAO (SBGR, SBPA…) | Depende de serviço externo da NOAA; testar a disponibilidade antes de incluir |
| Bandeja | **`wmsystemtray`** | XEmbed | **Essencial**, mas só aceita XEmbed (ver 5.3) |
| Discos removíveis | `wmudmount` / `wmvolman` | UDisks2 | OK |
| Atualizações | `wmArchUp` | `checkupdates` | Específico do Arch. Seria preciso adaptar para pamac ou para o atualizador do Big |
| Lixeira | `wmtrash` | GTK2 | Toolkit antigo |
| Desligar | `wmshutdown` | logind (D-Bus), GTK3 | Moderno |

### 4.3 Dependem de APIs obsoletas (evitar no ISO)

- **APM:** `wmapm`, `wmpower` (APM com `/proc/acpi`), partes do `wmbattery` (que tem UPower e sysfs como alternativa).
- **`/proc/acpi` (removido do kernel há mais de 10 anos):** `wmbatteries` (cópia no repositório), `wmacpiload`, `wmpower`.
- **OSS (`/dev/mixer`):** `wmmixer`, `wmsmixer`, `ascd`. O `wmix` tem OSS como alternativa, mas usa ALSA por padrão.
- **ALSA puro (hardware, sem PipeWire):** `AlsaMixer.app`, `wmmixer-alsa`. Funcionam no máximo pelo plugin, sem controle por aplicativo.
- **`/proc/net/wireless` (wireless-extensions):** `wmwifi`, `wmfu`. Só funcionam com `CONFIG_CFG80211_WEXT` e devem ser substituídos por `nm-applet` na bandeja.
- **XMMS, CD-ROM, ISDN, PPP, TV, webcam V4L1:** `wmmp3`, `wmcdplay`, `wmisdn`, `wmppp.app`, `yawmppp`, `wmtv`, `wmwebcam`.
- **GTK2:** `wmtrash`, `wmcalendar` (provável), `washerdryer`, entre outros.
- **Serviços externos mortos ou instáveis:** `wmckgmail` (API do Gmail antiga), `Temperature.app` (o endpoint `weather.noaa.gov` mudou), `wmspaceweather`.

### 4.4 Conjunto curado proposto para o ISO (13 itens)

| # | Dockapp | Função | Fonte |
|---|---|---|---|
| 1 | `wmsystemtray` | Bandeja (nm-applet, pamac, bluetooth…) | biglinux-stable |
| 2 | `wmclock` (ou `wmCalClock`) | Relógio e data | biglinux-stable |
| 3 | `wmix` | Volume (ALSA `default` sobre PipeWire) | biglinux-stable |
| 4 | `wmusic` | Controle de mídia MPRIS | AUR → empacotar do git dockapps |
| 5 | `wmbattery` | Bateria via UPower (só aparece em notebooks) | AUR → biglinux |
| 6 | `wmcpuload` | CPU | AUR → biglinux |
| 7 | `wmmemload` | RAM e swap | biglinux-stable |
| 8 | `wmnd` | Tráfego de rede | biglinux-stable |
| 9 | `wmudmount` | Montar pendrives e discos (UDisks2) | AUR → biglinux |
| 10 | `wmweather` | Clima (METAR/ICAO) | AUR → biglinux (opcional, desligado por padrão) |
| 11 | `wmshutdown` | Desligar e reiniciar via logind | AUR → biglinux |
| 12 | `wmmoonclock` | Fase da lua (visual clássico) | git dockapps → biglinux |
| 13 | `wmcube` | Visual clássico (decorativo) | AUR / git dockapps |

Opcionais: `wmpulsemixer` (se o wmix der problema com PipeWire), `wmcore` (por núcleo), `wmbiff` (e-mail), uma versão adaptada do `wmArchUp` para pamac, e `wmgtemp`/`wmhdplop` (temperatura e disco).
Remover do metapacote atual: o `wmsmpmon` do autostart (aceitável, mas redundante com wmcpuload e wmmemload) e o `wmsystray` (duplicado do wmsystemtray).

Recomendação de empacotamento: **um PKGBUILD “split” (`big-dockapps`) que compila vários dockapps do git `window-maker/dockapps` fixado em um commit**, em vez de 13 pacotes AUR mantidos por pessoas diferentes (vários sem atualização desde 2015–2016).

---

## 5. Limitações do X11 e do Window Maker num desktop moderno, e ferramentas complementares

### 5.1 Cobertura EWMH (`src/wmspec.c` do `master`)

Suportado: `_NET_SUPPORTED`, `CLIENT_LIST(_STACKING)`, desktops, `ACTIVE_WINDOW`, `WORKAREA`, `SHOWING_DESKTOP`, `CLOSE_WINDOW`, `MOVERESIZE_WINDOW`, **`WM_MOVERESIZE`** (novo), `WM_NAME`/`VISIBLE_NAME`, `WM_DESKTOP`, **`WM_FULLSCREEN_MONITORS`**, todos os `WM_WINDOW_TYPE_*`, `WM_STATE_*` (sticky, maximized, shaded, skip_*, hidden, fullscreen, above, below, focused), `ALLOWED_ACTIONS`, `STRUT`/`STRUT_PARTIAL`, `WM_ICON`, `WM_PID`, `WM_WINDOW_OPACITY`, `FRAME_EXTENTS`.

**Lacunas confirmadas por grep (ausentes no código):**
- `_NET_WM_STATE_DEMANDS_ATTENTION`: o pedido de atenção EWMH não é tratado (só o `XUrgencyHint` do ICCCM, com o “bounce” do appicon).
- `_NET_WM_USER_TIME`: não há prevenção de roubo de foco.
- `_NET_WM_SYNC_REQUEST`: redimensionamento sem sincronia, com *tearing* ao redimensionar apps GTK, Qt e Electron.
- `_NET_WM_PING`: declarado, mas marcado `/* TODO */`. Não detecta janela travada.
- `_NET_REQUEST_FRAME_EXTENTS`, `_NET_RESTACK_WINDOW`, `_NET_WM_BYPASS_COMPOSITOR`, `_GTK_FRAME_EXTENTS` (sombras CSD do GTK).
- `_NET_WM_STRUT_PARTIAL` tem o comentário “doesn't really fit into the current strut scheme”, o que afeta painéis parciais em multi-monitor.

### 5.2 Tabela de limitações e ferramentas

| Área | Limitação no Window Maker | Ferramenta sugerida (repo) | Situação atual no `comm-wmaker` |
|---|---|---|---|
| **Notificações** | O WM não implementa `org.freedesktop.Notifications` | `xfce4-notifyd` (extra) **ou** `dunst` (extra) | **Conflito:** o metapacote puxa `notification-daemon` **e** `xfce4-notifyd`, e só um pode ter o nome D-Bus. Manter só um |
| **XDG autostart** | O WM só executa `~/GNUstep/Library/WindowMaker/autostart` e não lê `/etc/xdg/autostart` nem `~/.config/autostart` | `dex -a` (extra) chamado no autostart | O `autostart` atual inicia tudo à mão (polkit, nm-applet, pamac…), com `sleep 4` + `sleep 10` e `killall`, o que é frágil |
| **Polkit** | Sem agente | `polkit-kde-agent` (atual), `lxqt-policykit`, `mate-polkit` ou `polkit-gnome` | Funciona, mas o `.desktop` do agente em `/etc/xdg/autostart` é ignorado sem `dex` |
| **Bloqueio de tela** | O WM não tem locker nem integra com `loginctl lock-session`; o menu gerado usa `xlock` | `xss-lock` + `i3lock` / `xsecurelock`, ou `xscreensaver` 6.x | `light-locker` exige LightDM e **não funciona com LXDM** |
| **Compositor** | O WM não compõe: sem sombras, transparência real ou vsync | `picom` 13 (extra), modo `glx` | Não está no metapacote. O WM exporta `_NET_WM_WINDOW_OPACITY`. Excluir dockapps e ícones do WM das sombras (`shadow-exclude` por `class_g`) |
| **HiDPI** | Fontes definidas em `pixelsize` (`Sans:pixelsize=12`), que ignoram `Xft.dpi`; botões e temas em XPM fixos; dockapps são bitmaps 64×64 | Ajustar `*Font` nos Defaults, `IconSize` 96/128 (até 256 px no upstream), `Xft.dpi` via `xrdb` ou `xsettingsd`, `GDK_SCALE`, `QT_SCREEN_SCALE_FACTORS` | Sem escala fracionária. Para HiDPI, oferecer um “perfil 2×” no `comm-wmaker-config` |
| **Multi-monitor** | O fork 0.95.9 tem só Xinerama e reinício em RandR. O `master` tem RandR 1.3 estático ou hotplug | `autorandr` (perfis automáticos), `arandr` ou `lxrandr`; `HotplugMonitor=YES` | Usa `lxrandr`, lido no autostart por um *parsing* frágil. Trocar por `autorandr` |
| **Bandeja do sistema** | `wmsystemtray` só aceita **XEmbed**; apps Qt6, KDE, Electron e Flatpak usam **StatusNotifierItem** (D-Bus) | `snixembed` (extra), ponte SNI → XEmbed | Faltando. Sem ele, ícones como Discord, Telegram e KDE Connect podem não aparecer |
| **Janelas CSD** | Antes do 0.97 não havia `_NET_WM_MOVERESIZE` | Usar `master` | O autostart força `custom_chrome_frame:false` no Chrome e no Brave; esse hack sai com o novo base |
| **Teclas multimídia, brilho, OSD** | O WM permite ligar teclas a comandos, mas não tem OSD | `wpctl`/`pactl`, `brightnessctl`, `playerctl`, notificação como OSD (dunst ou xfce4-notifyd) | `volumeicon` está duplicado com o `wmix` (escolher um) |
| **Configurações GTK e Qt, tema e escuro** | Sem daemon XSETTINGS | `xsettingsd` ou `xfsettingsd` (do `xfce4-settings`, já instalado), `qt5ct`/`qt6ct`, `nwg-look`/`lxappearance` | `xfce4-settings` já está no metapacote: iniciar o `xfsettingsd` no autostart |
| **Portais (Flatpak, seletor de arquivos)** | Sem portal | `xdg-desktop-portal-gtk` (ou `-kde`) | Verificar |
| **Chaveiro e senhas** | O WM não inicia o keyring | `gnome-keyring` (PAM + `--start`) ou `kwallet` + `kwallet-pam` | Verificar a integração com o PAM do LXDM |
| **Gerenciamento de energia e inatividade** | Só o `xset` (DPMS) | `xset s`/`dpms` + `xss-lock`; logind para suspender ao fechar a tampa | O logind já cuida da tampa |
| **Gestos do touchpad** | Nenhum | `touchegg` (extra) | Opcional |
| **Área de transferência** | Nenhuma | `clipit` (GTK2, sem manutenção) → considerar `copyq` ou `xfce4-clipman` | Usa `clipit` |
| **Montagem automática** | Nenhuma | `udiskie` (extra) ou o dockapp `wmudmount` | — |
| **Sessão e logout** | `Exit` do WM; sem integração com logind além do sinal de saída | Entradas de menu com `systemctl poweroff/reboot/suspend` e `loginctl lock-session` | — |
| **Wayland** | O Window Maker é só X11. Xwayland não se aplica | Longo prazo: `wlmaker` (AUR 0.8.1) | Fora do escopo |

### 5.3 Ajustes recomendados no `autostart` e no metapacote (resumo)

1. Trocar a lista manual por `dex -a -e WindowMaker &`. Assim, polkit, nm-applet, pamac-tray, xfsettingsd e spice-vdagent vêm de `/etc/xdg/autostart`, e o `VBoxClient-all`/`spice-vdagent` já trazem `.desktop` com condição.
2. Iniciar os dockapps **pelo próprio dock** (atributo *AutoLaunch* no `WMState`) em vez de `sleep 14` + `killall`. O WM espera o dock estar pronto.
3. Acrescentar `snixembed`, `picom`, `xss-lock` + `i3lock`/`xsecurelock`, `autorandr`, `dex`, `xdg-desktop-portal-gtk`; remover `notification-daemon` (manter `xfce4-notifyd`) e o `volumeicon` **ou** o `wmix`.
4. Retirar o hack `custom_chrome_frame` depois de migrar para o `master` do upstream.

---

## 6. Resumo executivo

- `ruscher/wmaker` = upstream `82ab2d2` (0.95.9+25, mar/2021), **sem nenhum patch próprio**, **324 commits atrás**.
- Upstream muito ativo em 2025–2026, com a **0.97.0 em preparação**: RandR com hotplug, `_NET_WM_MOVERESIZE` (Chrome, VS Code, Steam), correções de overflow e crash, Print livre, pt_BR separado.
- **Base recomendada:** `window-maker/wmaker` `master` fixado (`558e67f`), migrando para a tag `wmaker-0.97.0`. **Estratégia:** fork no GitHub como espelho + branches para PRs ao upstream; PKGBUILD com fila curta de patches; tema e configuração fora dos patches.
- **Arch:** `extra/windowmaker 0.96.0-5` (`--enable-modelock --enable-wmreplace --enable-xinerama --enable-randr --enable-usermenu`). O `windowmaker-git` do AUR está em nov/2024. Acrescentar `libxres`, `libxkbfile` e `--enable-pango --enable-res`.
- **Dockapps:** 13 escolhidos (wmsystemtray, wmclock, wmix, wmusic, wmbattery, wmcpuload, wmmemload, wmnd, wmudmount, wmweather, wmshutdown, wmmoonclock, wmcube). Evitar os que usam APM, `/proc/acpi`, OSS, wireless-extensions ou GTK2. Empacotar como um split `big-dockapps` a partir do git fixado.
- **Ferramentas complementares indispensáveis:** `dex` (XDG autostart), `snixembed` (SNI→XEmbed), um único daemon de notificações, `picom`, `xss-lock` + locker, `autorandr`, agente polkit, `xsettingsd`/`xfsettingsd`, portal GTK.
