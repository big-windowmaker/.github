# 03 — Empacotamento e configuração: `comm-wmaker`, `comm-wmaker-config`, `biglinux-skel-wmaker`, `biglinux-calamares-wmaker`

> Data da análise: 2026-10-25
> Host de referência: BigLinux (`ID=biglinux`, base Manjaro), Plasma 6.7.4 + SDDM, 64 pacotes `big*`/`biglinux*` instalados.
> Repositórios analisados (somente leitura; nada foi modificado nem enviado):
>
> | Repo | HEAD | Período | Commits | Origem do clone | Tamanho (sem `.git`) |
> |---|---|---|---|---|---|
> | `upstream/comm-wmaker` | `bf177b9` | 2025-02-23 → 2025-03-05 | 27 | `github.com/ruscher/comm-wmaker` | 68 MB / 1214 arquivos |
> | `upstream/comm-wmaker-config` | `c91e0b4` | 2024-08-21 → 2024-09-07 | 11 | `github.com/ruscher/comm-wmaker-config` | 3,3 MB / 48 arquivos |
> | `upstream/biglinux-skel-wmaker` | `0e2cdf1` | 2022-12-10 → 2024-12-24 | 59 | `github.com/ruscher/biglinux-skel-wmaker` | 15 MB / 521 arquivos |
> | `upstream/biglinux-calamares-wmaker` | `845af81` | 2022-12-10 → 2023-05-26 | 77 | `github.com/ruscher/biglinux-calamares-wmaker` | 288 KB / 65 arquivos |
>
> Ferramentas usadas: `md5sum` (comparação de todos os arquivos), `pacman -Qo` (1256 caminhos), `pacman -Si`/`-Sp`/`-F` (todas as dependências e comandos citados), `shellcheck`, `sqlite3`, `readelf`, e inspeção dos pacotes binários atuais `windowmaker`, `wmnd`, `wmautomenu-biglinux`, `lxdm-biglinux-theme`, `biglinux-livecd` e `comm-xfce-config` (baixados para o scratchpad, não instalados).

---

## 0. Resumo executivo

1. **Nenhum dos quatro pacotes está nos repositórios atuais** (BigLinux nem Community). Eles são protótipos de duas gerações diferentes: a geração “BigLinux 2022” (`biglinux-skel-wmaker` + `biglinux-calamares-wmaker`) e a geração “BigCommunity 2024/25” (`comm-wmaker-config` e depois `comm-wmaker`, que absorveu os outros).
2. **`comm-wmaker` não pode ser publicado do jeito que está.** O `pkgbuild.install` roda `pacman` de dentro do scriptlet depois de **apagar `db.lck`**, sobrescreve `GRUB_CMDLINE_LINUX_DEFAULT` com ~40 parâmetros, roda `mkinitcpio -P`, copia `/etc/skel` por cima do home do primeiro usuário com `chown -R` e **reinicia a máquina** em todo `post_install` **e todo `post_upgrade`**. O skel ainda traz 38 MB de cache, estado de uso real de navegador e cerca de 50 arquivos de configuração do Plasma/KDE.
3. **Os hooks de sessão quebram a integridade do pacote `windowmaker`.** Eles renomeiam `/usr/bin/wmaker` (o binário real) para `wmaker-session-big`/`-comm` e gravam um script no lugar. Depois do primeiro upgrade do `windowmaker`, o binário “real” continua sendo **o da versão antiga**, e a versão nova é sobrescrita pelo wrapper. O `sed` que deveria trocar o `Exec` da sessão **não faz nada**, porque o `wmaker.desktop` do Arch usa `Exec=wmaker` sem caminho.
4. **Instalação impossível sem `--overwrite`.** `comm-wmaker` e `biglinux-skel-wmaker` instalam `/etc/skel/.bashrc`, que pertence ao pacote **`bash`**. Além disso, 149 caminhos colidem com `big-skel` e cerca de 170 com `comm-skel`. `comm-wmaker` e `comm-wmaker-config` também colidem entre si em 39 caminhos (10 com conteúdo diferente).
5. **Dependências quebradas:** `windowmaker-extra`, `hardinfo-gtk3`, `chili-utils`, `wmsmpmon` (ainda chamado no `autostart`), `bashrc-manjaro` (em `conflicts`) e os comandos `change-keyboard-led` (hoje `big-keyboard-led`) e `startbiglive` (fluxo do live mudou). `wmnd` está ligado a `libsnmp.so.40`, mas o sistema traz a `.so.45`; o “conserto” é um symlink de ABI falso.
6. **O instalador mudou.** O mecanismo `bigbashview-calamares/desktops/<de>/pkginstall.txt` (do qual `biglinux-calamares-wmaker` depende) não existe mais: hoje `biglinux-livecd` traz perfis Calamares em `/usr/share/biglinux/calamares-profiles/<id>` e aceita perfis extras em `/etc/biglinux-livecd/calamares-profiles/<id>`. O `startbiglive` atual trata **`lxdm` como Plasma** (`exec startkde-biglinux`), e o perfil `bigcommunity` só configura `sddm | gdm | lightdm`.
7. **Recomendação:** abandonar os quatro repos como estão e criar **um único repo** (modelo `comm-xfce-config`) que gere um pacote de sessão/config e, se a infraestrutura permitir split packages, um metapacote. O que hoje é “skel” deve virar defaults em `/usr/share/…` aplicados no primeiro login pelo wrapper da sessão. A lista de pacotes deve ir para `iso-profiles/bigcommunity/wmaker/Packages-Desktop`. O suporte ao instalador deve sair do pacote e ir como PR para `biglinux-livecd` (detecção da sessão + perfil). Vale aproveitar: `WMRootMenu` (PT/EN), temas/estilos `BigLinux*.themed`, os 4 wallpapers, a ideia do wrapper de sessão e o layout do dock/clip.

---

## 1. Repositório por repositório

### 1.1 `comm-wmaker` (metapacote “WindowMaker retrô”, BigCommunity 2025)

**Propósito declarado (README, PT-BR):** metapacote que instala e configura o Window Maker com aparência retrô, menu de aplicativos gerado automaticamente e wallpapers gerados por IA, “compatível com as ISOs BigCommunity Base e Minimal”.

**Pacote gerado:** `comm-wmaker` (`arch=any`, `pkgver=$(date +%Y%m%d)`, `pkgrel=$(date +%H%M)`, `license=MIT`, `url=https://github.com/communitybig/comm-wmaker`, `source=git+url`, `md5sums=SKIP`, `install=pkgbuild.install`). O `package()` copia `usr/`, `etc/` e `opt/` com `cp -r` e instala LICENSE e README.

**Dependências (63):**
`windowmaker windowmaker-extra lxdm lxdm-biglinux-theme qt5ct tango-icon-theme numlockx onboard mousetweaks polkit polkit-kde-agent autoconf imake dolphin rootactions-servicemenu-biglinux libreoffice-fresh xterm konsole helvum kate kcalc xorg-fonts-cyrillic xorg-mkfontscale network-manager-applet wmclock wmsystemtray wmix wmmemload wmnd wmautomenu-biglinux lxrandr notification-daemon pamac-tray-icon-plasma ark xorg-xkill bluedevil manjaro-settings-manager gwenview spectacle clipit volumeicon hardinfo-gtk3 okular xfce4-settings xfce4-appfinder xfce4-notifyd xfce4-taskmanager chili-utils noto-fonts-emoji grub-btrfs grub-btrfs-timeshift timeshift bash-completion firefox xfce4-terminal base-devel libx11 libxext libxpm qt6-charts cbatticon`

Problemas na lista:
- `autoconf`, `imake`, `base-devel`, `libx11`, `libxext`, `libxpm` são dependências **de compilação** (sobras de quando se compilavam dockapps na máquina). Não pertencem a um metapacote de desktop.
- 9 pacotes KDE/Plasma (`dolphin konsole kate kcalc ark gwenview spectacle okular bluedevil` + `polkit-kde-agent`, `rootactions-servicemenu-biglinux`, `pamac-tray-icon-plasma`). Para um WM “leve” isso puxa boa parte do KF6.
- Dois servidores de notificação ao mesmo tempo (`notification-daemon` + `xfce4-notifyd`) e dois terminais além do xterm (`konsole` + `xfce4-terminal`).
- Itens de sistema que não cabem num pacote de desktop: `grub-btrfs`, `grub-btrfs-timeshift`, `timeshift`, `manjaro-settings-manager`, `firefox`, `libreoffice-fresh`.

**Arquivos instalados (1210 + LICENSE/README), por função:**

| Função | Qtde | Caminhos |
|---|---|---|
| Sessão / wrapper | 2 | `/usr/bin/bigwmaker` (exporta `QT_QPA_PLATFORMTHEME=qt5ct`, `SAL_USE_VCLPLUGIN=qt5` → `exec /usr/bin/wmaker`); `/usr/bin/startwmaker-biglinux` (wrapper copiado do DDE: “Run the original dde-session”) |
| Hooks ALPM | 3+3 | `wmaker-session.hook` → `wmaker-session-update-script` (troca o binário `/usr/bin/wmaker`); `big-prestart-windowmaker.hook` → `sed` em `/usr/share/xsessions/wmaker.desktop`; `fix-monitor-network.hook` → `ln -s libsnmp.so libsnmp.so.40` |
| D-Bus | 1 | `/usr/share/dbus-1/services/org.freedesktop.Notifications.service` → `notification-daemon` (modo 755) |
| Wallpapers | 4 | `/usr/share/wallpapers/{owl-ruscher,pinup-robot-ruscher,wmretro}.jpg` (4096×2160), `wallpaper-big-wm.jpg` (2560×1600) |
| GNUstep (defaults do WM) | 46 | `etc/skel/GNUstep/Defaults/{WindowMaker,WMGLOBAL,WMRootMenu,WMState,WMWindowAttributes,WPrefs,xdg_menu}` + **3 temporários `WMState.2LgdXm/.G90he6/.PMJuga`**; `Library/WindowMaker/{autostart,exitscript,README,README.themes}`; temas `BigLinux-Texture.themed`, `BigLinux-wmaker.themed`, `Ruscher.themed`; estilo `BigLinux.style`; 7 `Backgrounds/*.png`; 8 `CachedPixmaps/*.xpm`; ícones `biglinux*.png`, `clip.png`, `gaveta.png/.xcf`; cache `WPrefs/63950427.cache`; `.AppInfo/WindowMaker/History` |
| Autostart do menu | 1 | `etc/skel/.config/systemd/user/multi-user.target.wants/xdg_menu.path` (arquivo comum, não symlink; tem caracteres U+200B; `WantedBy=multi-user.target`, que não existe no manager de usuário) |
| Caches (`.cache`) | 454 (38 MB) | `mesa_shader_cache_db` (102), `mozilla` (289), `polkit-kde-authentication-agent-1` (30), `blesh` (15), `fontconfig` (10), `qtshadercache-x86_64-little_endian-lp64` (5), `ksycoca6_pt_*`, `event-sound-cache.tdb.<machine-id>.x86_64-pc-linux-gnu` |
| Estado de máquina | 88 (9 MB) | perfil de navegador e caches de um uso real, versionados por engano |
| Polybar | 385 (7,1 MB) | Coleção completa `adi1090x/polybar-themes` (blocks, colorblocks, cuts, docky, forest, grayblocks, hack, material, panels, pwidgets, shades, shapes). **Nada a inicia** e `polybar`/`rofi` não estão nas dependências |
| Fontes | 29 (3,7 MB) | `.local/share/fonts/` (Iosevka Nerd, Feather, Material Design Iconic, Fantasque, Terminus `.otb`, Droid/Noto Sans, waffle.bdf): fontes do polybar |
| Configs de apps KDE/Plasma | ~50 | `kdeglobals kwinrc plasmarc plasmashellrc ksmserverrc kscreenlockerrc ksplashrc krunnerrc kded5rc kactivitymanagerd* klassy* Kvantum/ breezerc lockplasma dolphinrc katerc konsolerc okular* gwenviewrc spectaclerc arkrc kxkbrc kcminputrc touchpadrc powerdevil.notifyrc powermanagementprofilesrc …`, `.local/share/{kxmlgui5,konsole,kate,dolphin,okular,kactivitymanagerd/resources/database*}`, `.local/state/*staterc` |
| Outros apps | ~30 | `lxqt/` (12, incluindo `debug.log`), `qBittorrent` (41, com plugins de busca `piratebay`, `rarbg` e `.pyc` cpython-37), `Clementine`, `strawberry`, `vlc`, `smplayer`, `mystiq`, `GIMP`, `gmic` (+`gmic_qt_log`), `GREYC`, `corectrl`, `htop`, `libreoffice`, `pulse/default.pa`, `xsettingsd`, `xfce4`, `clipit`, `volumeicon`, `dconf/user` (binário), `mimeapps.list` (Strawberry), `manjaro-settings-manager.conf`, `appimagelauncher.cfg`, `Trolltech.conf` |
| Dotfiles soltos | 4 | `.bashrc` (estilo Debian, com `/usr/games` e “bash-doc”), `.fonts.conf`, `.wmix.pid` (PID “1037”), `.wmndrc` |

**`pkgbuild.install` (post_install e post_upgrade):**
1. `rm -f /var/lib/pacman/db.lck` e, em seguida, `pacman -S --noconfirm --needed --overwrite '*'` **de dentro de uma transação do pacman**. Risco real de corromper o banco local; num chroot do Calamares os erros nem aparecem (`&>/dev/null`).
2. Instala drivers por `lspci` (`linux${KVER}-nvidia`, `lib32-*`, `mhwd-amdgpu`, `mhwd-ati`) e grava `blacklist nouveau` em **dois** arquivos. Isso duplica o trabalho do `mhwd`/`big-driver-manager`.
3. Cria o usuário `lxdm` com `useradd` e faz `mkdir`/`chown`, o que é redundante: o pacote `lxdm` já traz `sysusers.d/lxdm.conf` e `tmpfiles.d/lxdm.conf`. Depois roda `systemctl enable lxdm` sem desativar o DM atual (conflito com `sddm` no BigLinux).
4. Escolhe “o usuário” como o primeiro UID ≥ 1000 do `/etc/passwd`, faz `cp -Rfpa /etc/skel/.` **por cima do home dele** e `chown -R` no home inteiro. A condição `[[ -n $X || $X != 'root' ]]` sempre dá verdadeiro.
5. Fora do chroot: reescreve `GRUB_CMDLINE_LINUX_DEFAULT` inteiro (`acpi=force`, `libata.noacpi=1`, `intremap=off`, `nomce`, `audit=0`, `clearcpuid=514`, `tdx=on`, `radeon.si_support=0`… e um `DEEPIN_GFXMODE=` sem valor), roda `mkinitcpio -P` e `update-grub`.
6. **Contagem regressiva de 10 s e `reboot`**, também em todo upgrade.
7. Mensagem “Configuring Nautilus…” + `glib-compile-schemas` (resto de outro pacote).

**Histórico git:** 27 commits entre 23/02 e 05/03/2025 (Ruscher 22, vcatafesta 5 com “build-package new release”). Sequência: template `pkgbuild-template` → “New package WindowMaker” → “Enable lxdm” → “Add skel WMaker” (o skel do `biglinux-skel-wmaker` foi absorvido aqui) → wallpapers → “Fix cp -Rpa /etc/skel/.” → “Add Firefox and icon” (commit `c004505` “Fix skel” trouxe `.mozilla` e `.cache`) → “Remove Big-Skel” → “Add Apps Docks cbatticon” (+`wmsmpmon`, `base-devel`, `qt6-charts`) → “remove wmsmpmon” → README. Desenvolvimento rápido, com o perfil de usuário “fotografado” em vez de curado. O `.git` tem 39 MB, e o histórico vai carregar esses blobs para sempre.

---

### 1.2 `comm-wmaker-config` (config de desktop, BigCommunity 2024)

**Propósito:** pacote de configuração do Window Maker no padrão `comm-<de>-config` (como `comm-xfce-config`), dependente de `comm-skel`.

**Pacote gerado:** `comm-wmaker-config` (`arch=any`, `pkgver=$(date +%y.%m.%d)`, `license=MIT`, `url=…/communitybig/comm-wmaker-config`, `depends=('comm-skel')`, `conflicts=('bashrc-manjaro')`). O `package()` usa `cp -a` e o `pkgbuild.install` é só o template comentado.

**Arquivos (45 instalados):**

| Função | Caminhos |
|---|---|
| Sessão | `/usr/bin/startwmaker-community` (idêntico ao `startwmaker-biglinux`, mas com o bloco do LiveCD e a troca de shell comentados; executa `/usr/bin/wmaker-session-comm`); `/usr/bin/commwmaker` (cópia byte a byte de `bigwmaker`, **não referenciado por nada**) |
| Hooks | `wmaker-session.hook` + `wmaker-session-update-script` (versão “comm”); `fix-monitor-network.hook` + script |
| D-Bus | `org.freedesktop.Notifications.service` (mesmo conteúdo) |
| GNUstep | 37 arquivos: os mesmos defaults/temas em **inglês** (`WMRootMenu` traduzido, com erros como “Land” para “Lupa”, “To update” e “To execute…”), terminal `xfce4-terminal` no lugar de `xterm`, `CachedPixmaps/*.svg` (brave, calc, editor, firefox, office, thunar) |
| systemd user | `xdg_menu.path` (idêntico) |

**Erros de empacotamento:** no git, **todos os scripts têm modo 100644** (`usr/bin/*`, `usr/share/libalpm/scripts/*`). Com `cp -a`, os hooks falhariam com “Permission denied” e `startwmaker-community` não seria executável.

**Histórico:** 11 commits (Tales A. Mendonça, 21/08 → 07/09/2024) com mensagens “test”, “teste”, “fix 01”, “remove file log”, e dois merges de branches `testing-*`. Foi abandonado sem chegar ao repositório: `comm-wmaker` (2025) recomeçou do zero em vez de evoluir este.

---

### 1.3 `biglinux-skel-wmaker` (skel, BigLinux 2022)

**Propósito:** `/etc/skel` completo para a edição “BigLinux Community Window Maker” de dez/2022.

**Pacote gerado:** `biglinux-skel-wmaker` (`arch=any`, `license=GPL3` **sem arquivo LICENSE**, `url=github.com/ruscher/$pkgname`, `provides=($pkgname)` redundante, `conflicts=('big-skel')`). O `package()` faz `cp -r etc/ usr/`, sem `install`.

**Arquivos (519):**

| Função | Caminhos |
|---|---|
| Sessão | `/usr/bin/bigwmaker`: **as variáveis não são exportadas** (`QT_QPA_PLATFORMTHEME=qt5ct` sem `export`), portanto não tem efeito; `.xinitrc` com `DEFAULT_SESSION=startkde-biglinux` e **`/usr/lib/plasma-dbus-run-session-if-needed startkde-biglinux`**: um `startx` neste skel abre o **Plasma** |
| Hook | `big-prestart-windowmaker.hook` → `sed 's|/usr/bin/wmaker|/usr/bin/bigwmaker|g'` em `wmaker.desktop` (não casa com `Exec=wmaker`) |
| D-Bus | `org.freedesktop.Notifications.service` |
| GNUstep | 38 arquivos (mesmo conjunto de `comm-wmaker`, sem os `WMState.*` temporários; `BigLinux-wmaker.themed/wallpaper-big-wm.jpg`) |
| Polybar + fontes | 385 + 29 (idênticos aos de `comm-wmaker`) |
| Configs KDE/apps | `dolphinrc katerc kateschemarc konsolerc konsole.knsrc okular* gwenviewrc spectaclerc baloofile* powermanagementprofilesrc`, `Clementine`, `qBittorrent`, `smplayer`, `mystiq`, `GIMP`, `libreoffice`, `qt5ct`, `gtk-3.0`, `gtkrc*`, `fontconfig`, `xfce4/` (3) |
| Outros | `.Xdefaults` (tema do xterm), `.bashrc`, **`.pje/pkcs11.conf` e `.pki/nssdb/pkcs11.txt`** (módulos de token para o PJe/tribunais, copiados do `big-skel` da época) |

**Workflow:** `.github/workflows/translate-and-build-package.yml` com as etapas de tradução comentadas. Só dispara `repository_dispatch` para `BigLinux-Package-Build/build-package` (precisa do segredo `WEBHOOK_TOKEN`). Usa `actions/checkout@v3` e `ad-m/github-push-action@master` (sem versão fixa).

**Histórico:** 59 commits, quase todos entre 10 e 19/12/2022 (Ruscher via PRs #1–#23 e barnabedikartola com “first commit/rename/remove wmclock”). A sequência mostra a montagem da edição: polybar → docks wmmemload/wmnd → nm-applet no systray → xkill/atalhos → “remove hooks lightdm” → tema BigLinux wmaker. Houve um único commit em 2024 (“new”, só no PKGBUILD/workflow). Na prática, está **parado desde dez/2022**.

---

### 1.4 `biglinux-calamares-wmaker` (seleção de desktop no instalador, BigLinux 2022)

**Propósito:** registrar o “Window Maker” como desktop selecionável no antigo `bigbashview-calamares` (escolha de desktop antes do Calamares).

**Pacote gerado:** `biglinux-calamares-wmaker` (`arch=any`, `license=GPL3` sem LICENSE; o `desc.sh` diz “GPL V2 or greater”; `url=github.com/biglinux/$pkgname`).

**Arquivos:**
- `usr/share/bigbashview/bcc/apps/bigbashview-calamares/desktops/wmaker/`:
  - `desc.sh`: nome “Window Maker” + descrição gettext “Gerenciador de janela criado pelo brasileiro Alfredo Kojima em 1998.” (vale conferir o ano: as fontes históricas costumam citar 1997 para a primeira versão pública; o clone `upstream/wmaker` não tem datas no ChangeLog que confirmem).
  - `login.txt` = `lxdm`.
  - `pkginstall.txt` (50 pacotes: igual ao metapacote, mais `brave-browser`, `biglinux-skel-wmaker` e `biglinux-settings`).
  - `pkgremove.txt` (vazio).
  - `image.jpg` 600×338.
- `locale/*.po` (29 idiomas + `.pot`) e `usr/share/locale/*/LC_MESSAGES/biglinux-calamares-wmaker.mo` (28), gerados por tradução automática (Azure) no workflow.

**Workflow:** completo (apt `gettext`/`npm` → `attranslate` → clona `biglinux/big-auto-translator` → commit “new translate” → push → dispatch do build).

**Histórico:** 77 commits (10/12/2022 → 26/05/2023). Em dez/2022, Ruscher ajusta `pkginstall.txt` dezenas de vezes (lightdm → lxdm, conky → polybar, docks). Em 2023, barnabedikartola remove zsh e firefox, adiciona `biglinux-settings` e remove a tradução do nome. **Obsoleto:** o diretório `bigbashview-calamares/desktops/` não existe em nenhum pacote atual. O único resquício no repo é `biglinux-calamares-xivastudio` (build de 2023). O `calamares-biglinux` virou “Empty package” (2026-01) e o instalador foi para dentro do `biglinux-livecd` (seção 4.3).

---

## 2. Duplicação entre os 4 repositórios

Comparação por caminho e `md5sum` de todos os arquivos, excluindo `.git`:

| Par | Caminhos em comum | Idênticos | Diferentes |
|---|---|---|---|
| `comm-wmaker` × `biglinux-skel-wmaker` | **515** | **501** | 14 |
| `comm-wmaker` × `comm-wmaker-config` | 39 | 29 | 10 |
| `comm-wmaker-config` × `biglinux-skel-wmaker` | 34 | 29 | 5 |
| `biglinux-calamares-wmaker` × qualquer outro | 1–2 (`PKGBUILD`/workflow) | 0 | — |

### 2.1 Duplicatas exatas relevantes
- **Todo o polybar (385) + fontes (29)**: idênticos em `comm-wmaker` e `biglinux-skel-wmaker`.
- `xdg_menu.path`: idêntico nos três repos de config.
- `org.freedesktop.Notifications.service`: idêntico nos três (só muda o modo: 755 em dois e 644 no `config`).
- `fix-monitor-network{,.hook}`: idênticos em `comm-wmaker` e `comm-wmaker-config`.
- `big-prestart-windowmaker{,.hook}`: idênticos em `comm-wmaker` e `biglinux-skel-wmaker`.
- `usr/bin/bigwmaker` (`comm-wmaker`) ≡ `usr/bin/commwmaker` (`comm-wmaker-config`), com nomes diferentes.
- `.bashrc`, `WMGLOBAL`, `WPrefs`, `exitscript`, `README*`, temas `BigLinux-Texture.themed`, `Ruscher.themed`, `Styles/BigLinux.style`, `Backgrounds/*`, `Icons/*`: idênticos nos três.
- Mesmo conteúdo em caminhos diferentes:
  - `owl-ruscher.jpg`: em `/usr/share/wallpapers/` **e** em `Themes/Ruscher.themed/` (`comm-wmaker`).
  - `wallpaper-big-wm.jpg`: em `/usr/share/wallpapers/` (`comm-wmaker`) e em `Themes/BigLinux-wmaker.themed/` (`skel`).
  - `cutcube.png` e `random-grey-variations.png`: em `Backgrounds/` **e** em `Themes/BigLinux-Texture.themed/` (3 repos × 2 cópias).
  - `WMState` ≡ `WMState.PMJuga` em `comm-wmaker`.

### 2.2 Quase duplicatas (mesmo caminho, conteúdo divergente)
- `GNUstep/Defaults/{WindowMaker,WMState,WMWindowAttributes,WMRootMenu}`, `Library/WindowMaker/autostart`, `Themes/BigLinux-wmaker.themed/style`, `.AppInfo/WindowMaker/History`: três variantes do mesmo layout. As diferenças são idioma (PT x EN), wallpaper padrão, docks extras (`cbatticon`, `wmclock`, `wmsystemtray`, `wmsmpmon`), terminal (`xterm` x `xfce4-terminal`) e ícones de clip (Brave/Thunar x Firefox/Dolphin).
- `wmaker-session-update-script`: mesma lógica, sufixo `-big` x `-comm`.
- `startwmaker-biglinux` x `startwmaker-community`: mesmo arquivo com blocos comentados.
- `usr/bin/bigwmaker` (`skel`, sem `export`) x `usr/bin/bigwmaker` (`comm-wmaker`, com `export`).
- `dolphinrc`, `katerc`, `baloofileinformationrc`, `kxmlgui5/{dolphin,kate}`, `anonymous.katesession`: ajustes pequenos de estado de UI.

**Conclusão:** existe **um único conteúdo útil** (≈40 arquivos GNUstep + 4 wallpapers + um wrapper), espalhado em 3 cópias com divergências que ninguém reconciliou. Todo o resto é estado de máquina, que não deveria estar versionado.

---

## 3. Conflitos de arquivos e com o sistema atual

### 3.1 Colisões entre os próprios pacotes
- `comm-wmaker` ↔ `comm-wmaker-config`: 39 caminhos (`/usr/share/libalpm/hooks/wmaker-session.hook`, `…/fix-monitor-network*`, `/usr/share/dbus-1/services/org.freedesktop.Notifications.service`, todo o `GNUstep`). Não há `conflicts=` entre eles.
- `comm-wmaker` ↔ `biglinux-skel-wmaker`: 515 caminhos. O commit `ac81547` removeu a dependência `biglinux-skel-wmaker` e o conteúdo foi copiado, mas ninguém declarou `conflicts`/`replaces`.
- Os **dois hooks de sessão** (`-big` e `-comm`) disputam `/usr/bin/wmaker`. Se ambos estiverem instalados, o resultado depende da ordem alfabética dos hooks.

### 3.2 Colisões com pacotes do sistema (`pacman -Qo` neste host)
Dos 1256 caminhos que os quatro pacotes instalariam, 150 já pertencem a algum pacote:

| Dono atual | Caminhos | Observação |
|---|---|---|
| **`bash`** | `/etc/skel/.bashrc` | `comm-wmaker` e `biglinux-skel-wmaker` instalam esse arquivo. **A instalação falha com “conflicting files” sem `--overwrite`.** O `big-skel` e o `comm-skel` evitam esse caminho de propósito (usam `provides=bashrc`) |
| **`big-skel`** (instalado) | 149 | `.config/{kdeglobals,kwinrc,plasmarc,plasmashellrc,ksmserverrc,dolphinrc,konsolerc,…}`, `.local/share/{konsole,kxmlgui5,…}`, `.cache/blesh/…`, `.config/lxqt/*`, `.pje/pkcs11.conf`, `.pki/nssdb/pkcs11.txt`, `qBittorrent`, `vlc`, `gtk-3.0/*`, etc. Só `biglinux-skel-wmaker` declara `conflicts=big-skel`; `comm-wmaker` não declara (o commit “Remove Big-Skel” só tirou a dependência) |
| **`comm-skel`** (repo) | ~170 | Mesma família de arquivos. `comm-wmaker-config` **depende** de `comm-skel` e não colide com ele; `comm-wmaker` colidiria |

Outros pontos em que eles mexem no sistema por fora do pacman:
- `/usr/bin/wmaker` (dono: `windowmaker`): renomeado e sobrescrito pelo hook. `pacman -Qkk windowmaker` passa a acusar alteração. Pior: no **upgrade** do `windowmaker`, o pacman grava o binário novo em `/usr/bin/wmaker`, o hook vê que `wmaker-session-big` já existe, **não renomeia** e sobrescreve o binário novo com o wrapper. **O usuário fica preso para sempre no binário da primeira instalação**, e a remoção do pacote deixa `/usr/bin/wmaker-session-big` órfão.
- `/usr/share/xsessions/wmaker.desktop` (dono: `windowmaker`): alvo de `sed`, que hoje não casa (`Exec=wmaker`). O próprio BigLinux usa `sed` em `.desktop` de sessão (`biglinux-multi-kde`, `startxfce-community.hook`), mas só no `Exec=` do `.desktop` e nunca no binário.
- `/usr/lib/libsnmp.so.40`: symlink criado por hook para `libsnmp.so` (hoje → `.so.45`, de `net-snmp`). Fica sem dono, falha na segunda execução (`ln -s` sem `-f`) e mascara uma quebra de ABI: o `wmnd 0.4.18-1` do repo BigLinux tem `NEEDED libsnmp.so.40`. **A solução é recompilar o `wmnd`.** O script é 644 e o hook falha antes disso.
- `/usr/share/dbus-1/services/org.freedesktop.Notifications.service`: arquivo genérico sem dono no host, mas reivindica o **mesmo nome de barramento** que `plasma-workspace` (`org.kde.plasma.Notifications.service`) e `xfce4-notifyd` (`org.xfce.xfce4-notifyd.Notifications.service`, que também é dependência). Numa máquina com Plasma + Window Maker, quem atende as notificações do Plasma fica indefinido.
- `/etc/default/grub`, `/etc/modprobe.d/{nouveau,blacklist}.conf`, `/var/lib/pacman/db.lck`, homes de usuários: alterados pelo `pkgbuild.install` (seção 1.1).
- `/usr/share/wallpapers/`: diretório compartilhado (`breeze`, `biglinux-wallpapers-*`). Os nomes não colidem, mas `owl-ruscher.jpg` etc. aparecem misturados no seletor de wallpapers do Plasma. É melhor usar um subdiretório.

### 3.3 Dependências inexistentes, renomeadas ou abandonadas (`pacman -Si`)

| Item | Onde aparece | Situação em 2026-10 |
|---|---|---|
| `windowmaker-extra` | `comm-wmaker` depends | **Não existe** (era AUR). Torna o metapacote ininstalável |
| `hardinfo-gtk3` | `comm-wmaker`, `pkginstall.txt` | **Não existe**. Substituto: `hardinfo2` (extra) |
| `chili-utils` | `comm-wmaker` | **Não existe** (o `xdg_menu` estático ainda aponta para `chili-clonedisk`) |
| `wmsmpmon` | removido do PKGBUILD, mas **ainda chamado no `autostart`** | **Não existe** |
| `bashrc-manjaro` | `conflicts` de `comm-wmaker-config` | Não existe (inócuo; `big-skel`/`comm-skel` mantêm o mesmo `conflicts`) |
| `big-skel` | antiga dep (removida) | Existe (`biglinux-stable` 26.08.07), `provides=bashrc` |
| `comm-skel` | `comm-wmaker-config` depends | Existe (`community-stable` 1:26.09.08) |
| `windowmaker` | todas | **`extra` 0.96.0-5** (x86_64). Ótimo: não é mais AUR |
| `lxdm` | todas | `extra` 0.5.3-10 (GTK3, upstream parado desde 2016) |
| `lxdm-biglinux-theme`, `wmautomenu-biglinux` | todas | Existem, **build de dez/2022** |
| `wmclock wmsystemtray wmix wmmemload wmnd` | todas | `biglinux-stable`; `wmnd` com ABI `libsnmp.so.40` quebrada |
| `tango-icon-theme` | todas | `biglinux-stable` 0.8.90-14 |
| `pamac-tray-icon-plasma`, `manjaro-settings-manager`, `clipit`, `volumeicon`, `cbatticon`, `notification-daemon`, `polkit-kde-agent`, `qt5ct` | todas | Existem em `extra` |
| `brave-browser` | `pkginstall.txt` | Existe em `extra` |
| **Comando** `change-keyboard-led` | wrapper de sessão | **Renomeado para `big-keyboard-led`** (`biglinux-session-and-themes`) |
| **Comando** `biglinux-change-default-shell bash-power` | wrapper `-biglinux` | Existe (`biglinux-bash-config`, `/usr/sbin`), opção `bash-power` válida |
| **Comando** `startbiglive` + `calamares-biglinux.desktop` | wrapper `-biglinux` | `startbiglive` existe (`biglinux-livecd`), mas o atalho agora é `com.biglinux.calamares-config.desktop` e quem o cria é o próprio `startbiglive`. O bloco do wrapper é obsoleto e usa `/home/biglinux` fixo |
| `xdg_menu` | autostart, `.path` | `wmautomenu-biglinux` (2022): roda **`pkexec sed` em `/lib/systemd/user/xdg_menu.path`** a cada execução para incluir `~/.local/share/applications` |
| `kvantum` (via `QT_STYLE_OVERRIDE=kvantum`) | wrapper | Existe, mas **não é dependência** |
| `polybar`, `rofi` | skel | Existem, mas não são dependências e nada as inicia |
| `psmisc` (killall), `pciutils` (lspci), `spice-vdagent`, `virtualbox-guest-utils` | autostart | Não declarados |

---

## 4. Qualidade: caminhos fixos, KDE, ferramentas antigas, scripts

### 4.1 Caminhos e nomes fixos
- `/home/biglinux/Desktop` (wrapper), `/home/bruno` e `/home/big` (`Clementine.conf`, `strawberry.conf`, `gmic_qt.conf`, `user-places.xbel`), `/home/biglinux` (`Clementine.conf` do skel).
- `IconPath = ("/home/$USER/GNUstep/…")` em `WindowMaker` (deveria ser `~/GNUstep/…` ou `$HOME`).
- `"Configurar WindowMaker" → /usr/lib/GNUstep/Applications/WPrefs.app/WPrefs`: **não existe** no pacote do Arch (`/usr/bin/WPrefs`). A entrada do menu está quebrada.
- Fontes `Trebuchet MS`, `Verdana`, `Arial` (MS Core Fonts, não instaladas) em `WindowMaker`. `gtk-theme-name=Arc` e `cursor Breeze_Snow` sem dependência. `qt5ct` aponta para `airy.conf` e o estilo `Windows`.
- `WorkspaceBack = (spixmap, "/usr/share/wallpapers/owl-ruscher.jpg", …)`.
- O skel inteiro presume que o primeiro login cria o home, o que não vale para quem já tem conta e passa a usar a sessão Window Maker.

### 4.2 Referências a KDE/Plasma
Arquivos fora de cache, Firefox e polybar que citam plasma/kde/kwin/dolphin/konsole/kate: **39 em `comm-wmaker`**, 15 em `biglinux-skel-wmaker`, 3 em `comm-wmaker-config`, 1 em `calamares`. Destaques: `.xinitrc` → `startkde-biglinux`; `lockplasma`; `kwinrc`; `plasmashellrc`; `ksmserverrc`; `polkit-kde-authentication-agent-1` em `autostart`, `WMState` e `WMWindowAttributes`; cache `ksycoca6`; `kactivitymanagerd` (banco SQLite); o `startwmaker-*` é cópia do wrapper do DDE/KDE (`QT_QPA_PLATFORMTHEME=wmaker`, **um plugin de plataforma Qt que não existe**, que sobrescreve o `qt5ct` exportado pelo `bigwmaker` executado antes).

### 4.3 Compatibilidade com o live/instalador atual (`biglinux-livecd` 26.10)
- Perfis Calamares por edição em `/usr/share/biglinux/calamares-profiles/{biglinux,bigcommunity,xivastudio}`. `resolve-profile` lê `ID` de `/etc/os-release` ou do marcador `/etc/biglinux-livecd/profile` e **aceita perfis extras em `/etc/biglinux-livecd/calamares-profiles/<id>`** (exige `settings.conf`, `profile.json`, `modules/`, `branding/`). É esse o ponto de extensão correto para uma edição Window Maker, não o `bigbashview-calamares`.
- `bigcommunity/modules/displaymanager.conf` → `displaymanagers: [sddm, gdm, lightdm]`. **Com `lxdm` o Calamares não configura o DM** no sistema instalado.
- `startbiglive` (sessão live): `case $display_manager in sddm|gdm|lightdm|lxdm)` e, na hora de despachar a sessão, **`sddm`/`lxdm` → `exec startkde-biglinux`**. Uma ISO Window Maker com lxdm iniciaria o Plasma (ou falharia sem ele). Com lightdm, ele procura `xfce.desktop` ou `startcinnamon-community` e, sem nenhum dos dois, reinicia o DM em loop. **É necessário um PR no `biglinux-livecd`** adicionando, por exemplo, `elif [[ -x /usr/bin/startwmaker-community ]]; then exec startwmaker-community`.
- `iso-profiles` (HEAD 2026-10-21) tem só `bigcommunity/{cinnamon,gnome,kde,xfce}`, e nenhuma referência a wmaker. A lista de pacotes de uma edição vive em `Packages-Desktop`. O metapacote `comm-wmaker` duplica esse papel.

### 4.4 Scripts (`shellcheck`) e lógica
O `shellcheck` acusa pouco (`SC2034` no `bigwmaker` do skel por falta de `export`, `SC2086` no `autostart`, `SC1090/SC2034` no `.xinitrc`). Os problemas reais são de lógica, não de sintaxe:
- **`autostart` bloqueante:** o Window Maker executa o `autostart` com `system()` e espera terminar (`src/main.c: execInitScript`). A versão `comm-wmaker` tem `sleep 4` + `sleep 10`, o que dá **≥ 14 s de tela congelada em todo login**.
- `autostart` roda `sed -i` em `Preferences` do Chromium, Chrome e Brave em todo login (com erro se não existirem); `killall` de docks sem `psmisc`; `lspci` duas vezes para detectar VM (`systemd-detect-virt` é o correto); `VBoxClient-all` e `spice-vdagent` deveriam vir dos próprios `/etc/xdg/autostart`. **O Window Maker não processa XDG autostart** (`/etc/xdg/autostart` tem 23 entradas no host). Faltam, por exemplo, `dex -a` (pacote `dex` em `extra`) ou equivalente, que integraria polkit, nm-applet, pamac, ferramentas do BigLinux etc. sem lista fixa.
- `xdg_menu &` no `autostart` **e** `xdg_menu.path` no systemd. Esse `.path` está em `multi-user.target.wants` (target de sistema) e o `.service` correspondente já é entregue pelo `wmautomenu-biglinux`. A cópia no skel é morta. O Window Maker 0.96 tem `wmmenugen -parser:xdg` e `OPEN_PLMENU`, que geram o menu na hora, sem watcher nem `pkexec`.
- `wmaker-session-update-script`: veja 3.2 (binário congelado). Os hooks `-comm` não são executáveis.
- `pkgbuild.install`: veja 1.1. É o item mais perigoso dos quatro repos.
- O `xdg_menu` estático versionado em `GNUstep/Defaults/xdg_menu` cita `terminator`, `chili-clonedisk` e `/usr/bin/spectacle`. É gerado, não deveria ser versionado.
- PKGBUILDs: `pkgver=$(date …)` (não reprodutível e muda a cada `makepkg`), `source=git+…` sem commit fixo e `SKIP`, `url` apontando para a org antiga `communitybig` (a atual é `big-comm`) ou para o fork pessoal `ruscher`. A detecção dinâmica de `install=` no `package()` reatribui `srcdir`. `provides=($pkgname)` é inútil.

### 4.5 Suposições x86-only
- `arch=any`, mas o pacote entrega `libgmpopenh264.so` (ELF x86-64), `qtshadercache-x86_64-…`, `event-sound-cache…x86_64-pc-linux-gnu`, caches Mesa (específicos de GPU e driver) e `.pyc` cpython-37.
- `pkgbuild.install` instala `lib32-*` (exige multilib), `linux${KVER}-nvidia` (nomenclatura Manjaro) e `mhwd-*`.
- O wrapper exporta `VK_INSTANCE_LAYERS=VK_LAYER_OBS_vkcapture_64:VK_LAYER_VALVE_steam_overlay_64` e `RADV_PERFTEST`.
- O próprio `windowmaker` do repositório é x86_64. Não há hoje plano ARM, mas um `-config` deveria ser genuinamente `any`.

### 4.6 Privacidade, licenças e conteúdo sensível
- **Estado de máquina versionado e distribuído:** perfil de navegador e caches de uso real. Nunca devem ir para um pacote.
- `libgmpopenh264.so`: binário OpenH264 da Cisco. A licença de patente da Cisco só cobre o binário baixado diretamente da Cisco. Redistribuir dentro de um pacote anula essa cobertura.
- qBittorrent com plugins de busca `piratebay`/`rarbg`/`eztv` pré-instalados (risco jurídico/reputacional; o rarbg acabou em 2023).
- **Licenças misturadas:**
  - `comm-wmaker`: PKGBUILD e LICENSE dizem **MIT**, o README diz **GPL-3.0**.
  - `biglinux-skel-wmaker` e `biglinux-calamares-wmaker`: dizem GPL3 sem arquivo de licença; `desc.sh` diz GPL-2+.
  - Conteúdo de terceiros sem atribuição: `polybar-themes` de Aditya Shakya (GPL-3.0); fontes Iosevka/Fantasque/Terminus/Material/Noto (OFL), Feather (MIT) e Droid (Apache-2.0); `README`/`README.themes`/`Backgrounds` do Window Maker (GPL-2.0+); wallpapers `zorin.png` etc. do polybar (marcas de terceiros); wallpapers “gerados por IA” sem declaração de licença.
  - Um pacote `license=MIT` não pode simplesmente conter tudo isso.
- `.pje/pkcs11.conf` / `.pki/nssdb`: configuração de tokens do PJe. Isso é tarefa do `big-skel` e do `biglinux-config`, não de uma edição de WM.

---

## 5. O que manter, reescrever ou descartar

| Componente | Decisão | Motivo |
|---|---|---|
| `WMRootMenu` (PT e EN) | **Manter e reescrever** | Bom esqueleto. Corrigir o caminho do WPrefs, as traduções EN (“Land”, “To update”) e o duplicado “Turquesa = Anil (#243e6c)”; trocar o `xdg_menu` estático por `OPEN_PLMENU "\|\| wmmenugen -parser:xdg …"`; usar `systemctl poweroff/reboot` e logout via `EXIT` |
| `WindowMaker`, `WMGLOBAL`, `WMWindowAttributes`, `WMState` | **Manter, curar** | Uma única variante, sem `WMState.*` temporários; fontes livres (Noto/DejaVu); `IconPath` com `~`; wallpaper em `/usr/share/wallpapers/big-wmaker/` |
| Temas `BigLinux-Texture`, `BigLinux-wmaker`, `Ruscher.themed`, `BigLinux.style` | **Manter** | Instalar em `/usr/share/WindowMaker/Themes` e `Styles` (diretórios de sistema), não no skel, e deduplicar imagens |
| 4 wallpapers | **Manter** | Declarar autoria e licença (CC-BY-SA?) e mover para subdiretório |
| Ícones `biglinux*.png`, `clip.png`, `gaveta.png` | **Manter** | `/usr/share/WindowMaker/Icons` ou `/usr/share/icons/hicolor` |
| Wrapper de sessão (`startwmaker-*`) | **Reescrever** | Modelo `startxfce-community`/`startkde-biglinux`: `export XDG_CURRENT_DESKTOP=WindowMaker`, Qt via `qt6ct`/`xdg-desktop-portal` (com dependência), `big-keyboard-led`, `biglinux-change-default-shell`, bootstrap do primeiro login (copia defaults de `/usr/share/big-wmaker/GNUstep` se `~/GNUstep` não existir ou se a versão mudar), `dex -a` para XDG autostart e `systemctl --user import-environment` + target gráfico; no fim `exec wmaker` (o binário real, intocado) |
| Entrada de sessão | **Reescrever** | `.desktop` próprio (`/usr/share/xsessions/big-wmaker.desktop`, `Exec=/usr/bin/startwmaker-community`) **ou** hook só no `Exec=` do `wmaker.desktop`, como em `startxfce-community.hook`. **Nunca** mexer em `/usr/bin/wmaker` |
| `autostart` | **Reescrever** | Curto e não bloqueante (`&`, sem `sleep`), só docks; o resto via XDG autostart |
| Hook `fix-monitor-network` | **Descartar** | Recompilar o `wmnd` contra o `net-snmp` atual (ou trocá-lo por dockapp mantido; ver relatório 02) |
| Override de `org.freedesktop.Notifications.service` | **Descartar** | Escolher **um** daemon (`xfce4-notifyd` já traz seu `.service`) e iniciá-lo pela sessão |
| `xdg_menu.path` no skel / `wmautomenu-biglinux` | **Descartar / substituir** | `wmmenugen` nativo; se o watcher for mantido, reescrever o `wmautomenu` com `%h` no `.path`, `WantedBy=default.target` e sem `pkexec` |
| `pkgbuild.install` do `comm-wmaker` | **Descartar inteiro** | Drivers → mhwd/big-driver-manager; GRUB → `grub-theme`/`biglinux-config`; DM → Calamares/iso-profile; skel → wrapper de sessão |
| `.cache/`, `.mozilla/`, `.local/state`, `kactivitymanagerd`, `dconf/user`, `*.pid`, logs | **Descartar** | Estado de máquina |
| Configs KDE/Plasma (~50) e de apps (Clementine, qBittorrent, VLC…) | **Descartar** | Já vêm do `big-skel`/`comm-skel`, que são a fonte única de configs de apps |
| Polybar + fontes (414 arquivos) | **Descartar** (ou pacote opcional separado) | Não usado, GPL-3 de terceiro, 11 MB |
| `.xinitrc` (inicia Plasma), `.bashrc` (Debian) | **Descartar** | Se precisar, um `.xinitrc` com `exec startwmaker-community` |
| `bigbashview-calamares/desktops/wmaker` + 29 `.po` | **Descartar** | Mecanismo extinto. Reaproveitar só a frase de descrição e a imagem |
| Metapacote de 63 deps | **Mover** | Para `iso-profiles/bigcommunity/wmaker/Packages-Desktop`, enxuto e sem ferramentas de build. Se ainda quiser um metapacote “instalar Window Maker num BigLinux existente”, manter `depends` mínimo e `optdepends` para o resto |

---

## 6. Consolidação proposta

### 6.1 Separar em 4 repositórios se justifica?
**Não.**
- Três dos quatro repos contêm o **mesmo** conteúdo GNUstep (29 arquivos idênticos e 3 variantes divergentes). Cada correção precisaria ser feita três vezes, e o histórico mostra que nunca foi.
- O skel separado (`biglinux-skel-wmaker`) existia porque o modelo de 2022 era “um skel inteiro por edição” com `conflicts=big-skel`. O modelo atual da Community é `comm-skel` (base comum) + `comm-<de>-config` (só o específico do desktop), que é exatamente o que `comm-wmaker-config` tentou ser.
- O pacote Calamares separado não tem mais onde se encaixar: o instalador agora é do `biglinux-livecd` e as listas de pacotes são do `iso-profiles`.
- A divisão BigLinux x Community (`-big` x `-comm`, `bigwmaker` x `commwmaker`) é só de nome. O conteúdo é o mesmo.

### 6.2 Estrutura recomendada: **1 repo** (`big-comm/comm-wmaker-config`, ou `big-wmaker` se o projeto preferir marca própria)

```
comm-wmaker-config/            # ou big-wmaker/
├── pkgbuild/PKGBUILD          # pkgbase com split packages (se o build-package suportar)
├── usr/bin/startwmaker-community
├── usr/share/xsessions/big-wmaker.desktop        # ou hook só no Exec=
├── usr/share/big-wmaker/GNUstep/{Defaults,Library}/…   # defaults “de fábrica”
├── usr/share/WindowMaker/Themes/BigLinux-*.themed/
├── usr/share/WindowMaker/Styles/BigLinux.style
├── usr/share/WindowMaker/Icons/biglinux*.png
├── usr/share/wallpapers/big-wmaker/*.jpg
├── usr/lib/systemd/user/…                         # se houver serviço (menu, notifyd)
├── usr/share/licenses/…  (MIT p/ scripts; CC-BY-SA p/ arte; GPL-2+ p/ derivados do WM)
├── etc/biglinux-livecd/calamares-profiles/bigwmaker/   # opcional: perfil do instalador
└── .github/workflows/…                            # mesmo dispatch do build-package
```

Pacotes gerados (nomes no padrão Community; o equivalente `big-wmaker-*` serve se o projeto quiser marca própria):

| Pacote | Conteúdo | Depende de |
|---|---|---|
| `comm-wmaker-config` (≈ “big-wmaker-session” + “big-wmaker-config”) | wrapper, `.desktop` de sessão, defaults GNUstep em `/usr/share`, temas/estilos/ícones/wallpapers | `windowmaker`, `comm-skel` **ou** `big-skel` (via `provides=bashrc`, sem conflito), `xfce4-notifyd`, `dex`, `qt6ct`, polkit agent leve (`lxqt-policykit` ou `polkit-gnome`), `network-manager-applet` e os dockapps curados |
| `comm-wmaker` (metapacote, opcional) | nenhum arquivo | `comm-wmaker-config` + apps. Se o build-package não fizer split, deixar só a lista no `iso-profiles` |
| ~~`*-skel`~~ | — | Não criar: o bootstrap no primeiro login substitui o `/etc/skel` específico do WM, sem colidir com `big-skel`/`comm-skel` e funcionando também para usuários que já existem |
| ~~`*-calamares`~~ | — | Não criar. Em vez disso: (a) **PR no `biglinux-livecd`**: no `startbiglive`, um ramo para `startwmaker-community` e para `lightdm`/`lxdm` sem Plasma; (b) usar o perfil `bigcommunity` com `lightdm` (já suportado) **ou** entregar `/etc/biglinux-livecd/calamares-profiles/bigwmaker/` dentro de `comm-wmaker-config` (o `resolve-profile` já procura lá) |

E fora do repo:
- `iso-profiles/bigcommunity/wmaker/` (`Packages-Desktop`, `profile.conf` com `displaymanager="lightdm"`, `desktop-overlay`), seguindo o padrão do `xfce`.
- **Display manager:** trocar `lxdm` por **`lightdm` + `lightdm-slick-greeter`** (como `comm-xfce-config`; já suportado pelo Calamares e pelo `startbiglive`) ou por `sddm` (padrão BigLinux, tema `sddm-theme-biglinux` pronto). `lxdm` exigiria PRs em dois lugares (perfil Calamares e `startbiglive`) e é software parado.
- Recompilar `wmnd` (ou removê-lo), retirar `wmsmpmon` e `windowmaker-extra`, trocar `hardinfo-gtk3` por `hardinfo2` e `change-keyboard-led` por `big-keyboard-led`.

### 6.3 Ordem sugerida
1. Criar o repo novo do zero, **sem importar o histórico** do `comm-wmaker` (39 MB de `.git` com perfil Firefox e caches). Os outros três ficam arquivados como referência.
2. Importar só os ~40 arquivos GNUstep reconciliados, os temas e os wallpapers, com licenças declaradas.
3. Escrever o wrapper e o `.desktop` de sessão. Testar `pacman -Qkk windowmaker` limpo depois do install/upgrade.
4. Montar o `iso-profiles/bigcommunity/wmaker`.
5. Abrir PR no `biglinux-livecd` (sessão live + DM) antes de gerar a primeira ISO.
