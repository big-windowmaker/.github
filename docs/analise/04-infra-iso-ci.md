# 04 — Infraestrutura de ISO, pacotes e CI/CD (BigCommunity → Big WindowMaker)

> Análise feita em 2026-10-25 sobre clones somente leitura em
> `/home/ruscher/Documentos/Git/git-big-windowmaker/upstream/`. Nenhum repositório
> foi modificado nem recebeu push.
>
> Repositórios pedidos: `iso-profiles`, `gitrepo`, `build-iso` (arquivado), `community-keyring`.
> Clonados a mais para esta análise (`git clone --filter=blob:none`), por serem as
> peças **ativas** que substituíram o `build-iso`:
>
> | Diretório local | Origem | Último commit | Papel |
> |---|---|---|---|
> | `biglinux-iso-profiles/` | biglinux/iso-profiles | 2026-10-22 | **motor de ISO ativo** (`build-iso/build-iso.sh`) + workflows GitHub + openQA |
> | `build-package/` | big-comm/build-package | 2026-10-23 | CI de pacotes da BigCommunity (build → assina → publica) |
> | `biglinux-build-package/` | biglinux/build-package | 2026-10-25 | versão "segura" do mesmo CI (jobs separados, SHAs fixados) |
> | `talesam-build-iso/` | talesam/build-iso | 2026-03-29 | destino remoto do `biso` (gitrepo) — motor antigo |
> | `bigbruno-build-iso/` | bigbruno/build-iso | 2026-02-03 | fork do anterior (diferença de 14 linhas) |
> | `community-livecd-key/` | big-comm/community-livecd-key | 2026-10-22 | keyring pré-montado da sessão live |
> | `community-release/` | big-comm/community-release | 2026-09-08 | `/etc/lsb-release` da BigCommunity |
> | `isovault/` | big-comm/isovault | 2026-10-10 | app GTK que publica ISOs em S3/CDN77 (iso.communitybig.org) |
> | `comm-docker-config/` | big-comm/comm-docker-config | 2025-04-15 | irrelevante para ISO (config de docker do usuário) |

---

## Sumário executivo

1. **Não existe edição wmaker** em `big-comm/iso-profiles` (`grep -ri wmaker` → zero
   ocorrências). Hoje há só 4 edições: `kde`, `gnome`, `xfce`, `cinnamon`. O README ainda
   lista 8 (cosmic, deepin, hyprland e core foram removidas em 2026-09-03) e fala em "140
   symlinks" (são 64).
2. **`big-comm/build-iso` foi substituído pelo motor que vive dentro de
   `biglinux/iso-profiles`** (`build-iso/build-iso.sh`, 946 linhas). Esse único script é
   executado (a) pelo app `gitrepo`/Build ISO em contêiner local, (b) pelo workflow
   `Build ISO` do GitHub em `biglinux/iso-profiles` e (c) por um pipeline GitLab oficial
   (privado). Para BigCommunity, o motor recebe os perfis de outro checkout via
   `PROFILES_ROOT`. O caminho remoto do `gitrepo` (`biso`) ainda dispara
   `repository_dispatch` para `talesam/build-iso` / `bigbruno/build-iso`, que usam um
   motor antigo.
3. **Ferramenta de build**: `manjaro-tools` (`buildiso`), não `mkarchiso` (o pacote
   `archiso` é instalado só como dependência). Roda dentro de contêiner Docker privilegiado:
   `talesam/community-build` (BigCommunity) ou `xivastudio/biglinux_build_package`
   (BigLinux, fixado por digest no workflow do GitHub). Runners: **somente GitHub-hosted**
   (`ubuntu-latest` / `ubuntu-24.04`); nenhum self-hosted encontrado.
4. **`gitrepo` não é um CI**: é um app desktop (GTK4 + CLI `bpkg`/`biso`) que faz commit,
   sincroniza branches e **dispara** workflows via `repository_dispatch` em
   `<org>/build-package` e `<org>/build-iso`. Organizações estão fixas no código
   (`big-comm`, `biglinux`; `talesam`, `bigbruno` para ISO).
5. **Pacotes**: `big-comm/build-package` compila com `makepkg` no contêiner, assina com
   **uma única chave GPG** (`AECEEE84E52BBFAA9F1C9DF01EA0CEEEB09B44A3`, RSA-4096, sem
   expiração), envia por `rsync`/SSH para o servidor e roda `repo-add` remoto. Repositórios
   servidos em `https://repo.communitybig.org/$repo/$arch` (`community-testing|stable|extra`).
   Banco de dados **não é assinado** (`.db.sig` → 404; `SigLevel = PackageRequired`).
6. **Riscos de supply chain relevantes** no CI da BigCommunity: chave GPG e chave SSH
   presentes no mesmo job que executa PKGBUILDs arbitrários (inclusive do AUR), imagens
   `:latest`, actions por tag, `ssh-keyscan` sem pin de host, interpolação de
   `client_payload` em shell, `tmate` no mesmo job dos segredos. O
   `biglinux/build-package` já corrige quase tudo isso e é o melhor modelo para copiar.
7. **Recomendação**: começar com a edição `wmaker` **como PR em `big-comm/iso-profiles`** e
   com os pacotes genéricos (dockapps etc.) em `community-extra`, mas preparar desde já a
   org `big-windowmaker` com: fork do `biglinux/build-package` (pipeline seguro), repositório
   próprio `bigwm-*` + `bigwm-keyring` para o que for identidade da distro, e um
   `build-iso` próprio que roda o motor da BigLinux fixado por SHA. Detalhes na seção 7.

---

## 1. `big-comm/iso-profiles`

### 1.1 Estrutura

```
iso-profiles/
├── repo_info                  "0.15.0" — o manjaro-tools localiza o repositório de perfis por este arquivo
├── shared/                    tudo que é comum às edições
│   ├── Packages-Root          sistema instalado (base, kernel KERNEL, biglinux-*, community-*, áudio, GPU…)
│   ├── Packages-Live          só sessão live (calamares, biglinux-livecd>=26.10.19, community-livecd-key, memtest…)
│   ├── Packages-Mhwd          repositório offline de drivers (/opt/mhwd) lido pelo big-driver-manager-cli
│   ├── profile.conf           MODELO (não é lido por nenhuma ISO)
│   ├── pacman.conf            vira /etc/pacman.conf (via symlinks nos overlays)
│   ├── user-repos.conf        vazio (e o motor o apaga de qualquer forma)
│   ├── root-overlay/          → sistema instalado
│   ├── desktop-overlay/       → imagem desktop
│   ├── live-overlay/          → só sessão live (GRUB live, branding do Calamares, units systemd, memtest)
│   ├── grub-assets/, grub-i18n/  ícones e traduções (28 idiomas) do menu GRUB live
└── bigcommunity/<edição>/     uma pasta por edição
└── tests/test_grub_contracts.py   22 testes pytest do menu GRUB live (contratos de boot)
└── docs/images/header.webp    (docs/ só tem a imagem do README)
```

Não há `.github/workflows` neste repositório: **nenhum CI** (nem para rodar os testes).

### 1.2 Como uma edição é definida

Camadas do `buildiso` (manjaro-tools):

| Camada | Lista de pacotes | Overlay | Destino |
|---|---|---|---|
| rootfs | `Packages-Root` | `root-overlay/` | sistema instalado |
| desktopfs | `Packages-Desktop` | `desktop-overlay/` | sistema instalado |
| livefs | `Packages-Live` | `live-overlay/` | **apenas** a sessão live |
| (mhwd) | `Packages-Mhwd` | — | repositório offline `/opt/mhwd` |

Arquivos de uma edição (exemplo `bigcommunity/xfce/`):

| Arquivo | Tipo | Observação |
|---|---|---|
| `Packages-Desktop` | arquivo próprio | **único** arquivo de pacotes que a edição possui (xfce: 267 linhas) |
| `profile.conf` | arquivo próprio | `displaymanager`, `hostname`, `username`, `password`, `addgroups`, `enable_systemd`, `disable_systemd_live`, `custom_boot_args`, `default_desktop_file` (gnome). O `label=` é reescrito pelo motor |
| `Desktop-remove`, `Root-remove` (opcionais) | arquivo próprio | removidos da lista **e** desinstalados com `pacman -Rdd` após a instalação (motor) |
| `Packages-Root`, `Packages-Live`, `Packages-Mhwd`, `user-repos.conf` | symlink → `../../shared/` | o motor copia o arquivo antes de editar, para não afetar outras edições |
| `desktop-overlay/{etc,usr}` | symlinks → `shared/desktop-overlay/` | |
| `live-overlay/usr` | symlink **do diretório inteiro** → `shared/live-overlay/usr` | inclui GRUB live e branding do Calamares |
| `live-overlay/etc/{fstab,issue,localtime,pacman.conf,systemd}` | symlinks | `pacman.conf` → `shared/pacman.conf` |
| `live-overlay/etc/lightdm/lightdm.conf` | próprio | autologin `community`, sessão `livecd` |
| `root-overlay/etc/{pacman.conf,default/grub,pacman.d/mirrorcdn}` | symlinks | |
| `root-overlay/etc/{environment,makepkg.conf,mkinitcpio.conf,pamac.conf,lightdm/*,systemd/*,X11/xorg.conf.d/30-touchpad.conf}`, `usr/share/icons/default/index.theme` | próprios (cópias quase idênticas entre edições) | |

Marcadores nas listas: `KERNEL` é placeholder (`KERNEL-headers` → `linux612-headers`);
`>extra`, `>multilib`, `>i686`, `>nonfree_x86_64` são marcadores do manjaro-tools. O motor
roda `buildiso` **sem `-f`**, então linhas `>extra` não são instaladas.

Repositórios: `shared/pacman.conf` só traz `[biglinux-priority]` (acima de `[core]`), `core`,
`extra`, `multilib`. As seções `community-*` e `biglinux-*` são **anexadas pelo motor**
(`append_installed_repos`) durante o build.

Calamares: o branding fica em `shared/live-overlay/usr/share/calamares/branding/biglinux/`
(`branding.desc` com `productName: BigCommunity`, slideshow `BigBlocks.qml`). A
configuração dos módulos e o assistente vêm do pacote `biglinux-livecd` (repo
`biglinux/biglinux-livecd`), que traz `startbiglive`, sessões `livecd.desktop` /
`livecdWayland.desktop` e um assistente Python com tratamento específico para KDE, GNOME,
XFCE e Cinnamon.

Testes: `tests/test_grub_contracts.py` (22 testes) valida só o GRUB live compartilhado
(sintaxe com `grub-script-check`, argumentos de boot, blacklist NVIDIA, catálogos i18n,
temas). Não há validação de listas de pacotes nem de integridade de symlinks.

### 1.3 Edições existentes e wmaker

- Edições atuais: **kde** (sddm, `custom_boot_args=('wayland')`), **gnome** (gdm,
  `livecdWayland`), **xfce** (lightdm), **cinnamon** (lightdm).
- Removidas: `minimal` (2026-08-30); `core`, `cosmic`, `deepin`, `hyprland` (2026-09-03).
- `grep -ri 'wmaker\|windowmaker'` em iso-profiles, gitrepo, build-iso e community-keyring:
  **nenhuma ocorrência**.
- Fora destes repositórios existem peças wmaker antigas (clonadas em `upstream/`, todas sob
  `github.com/ruscher`): `comm-wmaker` (metapacote, deps: windowmaker, lxdm, dockapps,
  dolphin, konsole, firefox…), `comm-wmaker-config`, `biglinux-skel-wmaker`,
  `biglinux-calamares-wmaker` (plugin do antigo `bigbashview-calamares`, de 2023). O workflow
  delas ainda dispara para `BigLinux-Package-Build/build-package` (org antiga) com
  `secrets.WEBHOOK_TOKEN`.
- Disponibilidade das dependências do `comm-wmaker` (consulta aos `.db` em 2026-10-25):
  `windowmaker`, `lxdm`, `volumeicon`, `cbatticon` estão no Arch `extra`; `wmix`,
  `wmautomenu-biglinux`, `rootactions-servicemenu-biglinux` em `biglinux-stable`;
  `comm-skel` em `community-stable`; **`windowmaker-extra`, `wmclock`, `wmsystemtray`,
  `wmmemload`, `wmnd`, `clipit`, `chili-utils`, `hardinfo-gtk3`, `lxdm-biglinux-theme`
  não estão em nenhum repositório configurado** (vários só no AUR). Ou seja: a edição wmaker
  **exige publicar pacotes novos** em algum repositório antes de a ISO ser possível.

### 1.4 O que uma edição `bigcommunity/wmaker/` precisa (checklist exato)

1. `Packages-Desktop` (arquivo real): sessão Window Maker + dockapps + metapacote
   (`comm-wmaker` ou lista explícita), display manager, apps, fontes, drivers de entrada,
   `>multilib` etc. — partir de `xfce/Packages-Desktop` e trocar o bloco XFCE.
2. `profile.conf` (arquivo real, copiar de `xfce/`): `displaymanager="lightdm"`
   (recomendado, reaproveita o autologin live existente; `comm-wmaker` hoje puxa `lxdm`, e o
   `shared/live-overlay/etc/lxdm/lxdm.conf` está desatualizado: `autologin=biglinux`),
   `hostname`, `username`, `password`, `enable_systemd`, `disable_systemd_live`; **sem**
   `custom_boot_args=('wayland')` (Window Maker é X11).
3. Symlinks iguais aos do xfce: `Packages-Root`, `Packages-Live`, `Packages-Mhwd`,
   `user-repos.conf`, `desktop-overlay/{etc,usr}`, `live-overlay/usr`,
   `live-overlay/etc/{fstab,issue,localtime,pacman.conf,systemd}`,
   `live-overlay/boot/memtest86+/memtest.bin`, `root-overlay/etc/{pacman.conf,default/grub,pacman.d/mirrorcdn}`.
4. `live-overlay/etc/lightdm/lightdm.conf` com `autologin-session` adequado (ver item 9).
5. `root-overlay/etc/…` (lightdm, environment, makepkg.conf, mkinitcpio.conf, pamac.conf,
   systemd, X11 touchpad) + `usr/share/icons/default/index.theme`.
6. `Desktop-remove` / `Root-remove` opcionais (copiar o do xfce: vim, mesa-demos…).
7. Pacotes novos publicados (seção 1.3) **antes** do build.
8. Branding: se a ISO wmaker precisar de Calamares/GRUB live com identidade própria, o
   symlink de diretório `live-overlay/usr → shared/live-overlay/usr` precisa ser quebrado em
   links mais finos (senão não dá para sobrescrever só `calamares/branding/` na edição). O
   tema GRUB live é forçado pelo motor para `${DISTRONAME}-live` (ou seja,
   `bigcommunity-live`).
9. Sessão live: o `livecd.desktop` de `biglinux-livecd` usa `TryExec=/usr/bin/startplasma-x11`
   e o assistente conhece só KDE/GNOME/XFCE/Cinnamon → **validar** (ou contribuir) suporte a
   Window Maker no `biglinux-livecd`; alternativa é autologin direto numa sessão `wmaker` e
   abrir o assistente via `~/GNUstep/Library/WindowMaker/autostart`.
10. Instalador: confirmar se o Calamares atual (app GTK em `biglinux-livecd`) ainda usa
    `desktops/<de>` do `bigbashview-calamares`; se não, `biglinux-calamares-wmaker` está
    obsoleto.
11. Opcional/cosmético: adicionar `"wmaker": "Window Maker"` em `EDITION_DISPLAY_NAMES` do
    gitrepo e a pasta "Window Maker" no perfil do isovault.
12. Rodar `pytest tests/` (só cobre o GRUB compartilhado; a edição herda).

Nome resultante pelo motor: `bigcommunity_wmaker_<data>_k612.iso` (stable),
`bigcommunity_TESTING_wmaker_…` (testing); volume `BIGCOMMUNITY_LIVE_WMAKER`.

---

## 2. Build de ISO: `build-iso` (arquivado) e o que o substituiu

### 2.1 Como funcionava `big-comm/build-iso` (arquivado, último commit 2025-06-25)

- `.github/workflows/edition.yml`: gatilho `repository_dispatch` com tipos `ISO-*`
  (payload: `distroname`, `iso_profiles_repo`, `edition`, branches manjaro/biglinux/community,
  `kernel`, `tmate`). Job `setup` (Telegram) + job `build` em `ubuntu-latest` com contêiner
  `talesam/community-build:1.7.1 --privileged`, volumes em `/mnt` para
  `/var/lib/manjaro-tools/buildiso` e `/var/cache/manjaro-tools/iso`.
- `action.yml` (composite): adiciona `[community-extra]` ao contêiner, clona
  `biglinux/biglinux-key` e `big-comm/community-keyring`, `pacman-key --populate`, cria
  `/dev/sr0`, exporta variáveis e chama `build-iso.sh`; `tmate` opcional.
- `build-iso.sh` (786 linhas): instala `manjaro-tools-*-git`, `archiso`, `calamares`…;
  clona o perfil; anexa repositórios (`repo.biglinux.com.br/<branch>/$arch`,
  `repo.communitybig.org/<branch>/$arch`); **edita com `sed` os scripts de
  `/usr/lib/manjaro-tools/`** (nome da distro, label, compressão zstd 22/7, root-overlay,
  cleanups, plymouth); resolve kernel (`lts/oldlts` via kernel.org, `latest` via
  `biglinux/linux-latest`, `xanmod`); aplica `*-remove`; roda
  `buildiso -d zstd -f -p <edição> -b <branch> -k linuxXXX`.
- Saída: ISO + `.md5` + `.pkgs`, compactado em `7z -v2000m` (limite de 2 GiB por asset),
  publicado com `softprops/action-gh-release@v1` com tag `AAAA-MM-DD_HH-MM`.
- Segredos: `TOKEN_BOT`, `CHAT_ID` (Telegram), `TOKEN_RELEASE`, `GITHUB_TOKEN`.

### 2.2 O substituto ativo: motor em `biglinux/iso-profiles`

`biglinux/iso-profiles` juntou **descrição e motor** num só repositório:

```
sources/  (diffs editados à mão: common/{Root,Live,Mhwd}-{add,remove}, editions/<ed>/Desktop-add, special-commands.sh)
   │  make-profiles.yml — a cada push e semanal: rebaseia nas listas do Manjaro
   ▼
biglinux/<edição>/  (gerado e commitado por bot)
   │  build-iso/build-iso.sh — sob demanda, ~4 h
   ▼
.iso + .iso.pkgs
```

Etapas do motor (`main()`): `read_inputs` → `validate_inputs` → `resolve_kernel` →
`prepare_host` (instala manjaro-tools, keyrings BigLinux + community, cria
`/dev/loop*`, escreve `manjaro-tools.conf` com `dist_name=$DISTRONAME`) →
`configure_build_repos` (`[biglinux-priority]` acima de `[core]`, `community-*`,
`biglinux-*`; apaga `user-repos.conf`) → `patch_manjaro_tools` (com `assert_present` após
cada `sed`) → `configure_profile` (repos no `shared/pacman.conf`, `*-remove`, ids de mídia,
`KERNEL`, `/etc/big-release`) → `run_build` (`buildiso -p ED -b BRANCH -k linuxXXX`) →
`collect_output` (único lugar que decide o nome publicado).

Contrato de ambiente (principais): `EDITION`, `KERNEL` (`oldlts|lts|latest|xanmod|xanmod-lts|big`),
`MANJARO_BRANCH`, `BIGLINUX_BRANCH`, `BIGCOMMUNITY_BRANCH`, `COMMUNITY_TESTING`,
`RELEASE_TAG`, `WORK_PATH`, `DISTRONAME`, **`PROFILES_ROOT`** (perfis de outro checkout),
`BUILD_MIRROR`, **`BIGLINUX_REPO_HOST`**, **`COMMUNITY_REPO_HOST`**, `MESA_TKG`.

Limitações importantes para uma distro derivada:
- `DISTRONAME` só aceita `biglinux` ou `bigcommunity` (`die "unknown DISTRONAME"`), e é
  detectado pela pasta `bigcommunity/` ou `biglinux/` em `PROFILES_ROOT`.
- O nome do produto na ISO, `dist_name`, `iso_name`, tema GRUB e `misobasedir` derivam de
  `DISTRONAME`; só `xivastudio` tem nome de produto próprio (hard-coded em `collect_output`).
- Os únicos repositórios extras que o motor sabe injetar são `biglinux-*` e `community-*`;
  hosts podem ser trocados, mas **não há variável para um terceiro repositório** (o
  `user-repos.conf` do perfil é apagado de propósito).
- Os keyrings instalados no contêiner são só `biglinux/biglinux-key` e
  `big-comm/community-keyring` (clonados por HTTPS, `--depth 1`, sem pin de commit).
- O cabeçalho diz que o suporte a bigcommunity "ainda precisa de um build real da
  comunidade para ser validado".

Workflows do `biglinux/iso-profiles`:

| Workflow | Gatilho | Observações |
|---|---|---|
| `build-iso.yml` | `workflow_dispatch` (edition `kde|xivastudio`, kernel, branches, `community_testing`, `publish_release`) | contêiner `xivastudio/biglinux_build_package@sha256:317d…` `--privileged`; `timeout-minutes: 240`; gera `.md5` + `.sha256`; artefato candidato → **gate openQA** (BIOS+UEFI, instala, abre apps via árvore de acessibilidade) → job `publish` com `contents: write`, divide em 7z se > 2 GiB, `softprops/action-gh-release@3d0d…`. **Só usa `GITHUB_TOKEN`** |
| `make-profiles.yml` | push em qualquer branch, cron semanal, manual | clona Manjaro iso-profiles, gera `biglinux/`, commita com bot (`ad-m/github-push-action@v1`) |
| `test.yml` | push/PR | `bash -n` + `pytest build-iso/tests/` |
| `openqa*.yml`, `mirror-openqa-image.yml` | reutilizáveis / manual | imagem openQA espelhada em GHCR **por digest** |

Também há `build-iso/build-local.sh` (podman/docker local; imagem padrão
`docker.io/talesam/community-build:latest` para bigcommunity) e `gitlab-ci.example.yml`
(runner GitLab com contêiner privilegiado). O pipeline GitLab oficial (SSH, torrent,
notificações) fica num repositório `build-iso` que não está no GitHub.

### 2.3 Quem dispara ISOs da BigCommunity hoje

- **Local** (`gitrepo` → Build ISO / `biso --local`): roda `talesam/community-build:latest`
  com `--cap-add SYS_ADMIN`, `apparmor=unconfined`, regras de device cgroup para loop/sr;
  dentro do contêiner clona `biglinux/iso-profiles` (motor), clona `big-comm/iso-profiles`
  (perfis) e chama o motor com `PROFILES_ROOT`. Registra o digest da imagem e os commits
  clonados num manifesto (bom para reprodutibilidade).
- **Remoto** (`biso --auto`): `POST /repos/<org>/build-iso/dispatches` com
  `event_type = ISO-<distro>_<STABLE|BETA|DEVELOPMENT>_<edição>_<tag>`. Organizações
  válidas no código: `talesam` (padrão) e `bigbruno` — ou seja, `talesam/build-iso`
  (motor antigo, 942 linhas, `talesam/community-build:latest`, segredos `TOKEN_BOT`,
  `CHAT_ID`, `TOKEN_RELEASE`).
- **Publicação no espelho**: manual, com o app `isovault` (S3 CDN77 →
  `iso.communitybig.org`), pastas por DE (GNOME, Cinnamon, XFCE, KDE).

### 2.4 Toolchain, runners e segredos (resumo)

| Item | Valor |
|---|---|
| Ferramenta | `manjaro-tools` (`buildiso`, `mkchroot`, mksquashfs/xorriso), pacotes `manjaro-tools-*-git` |
| Contêiner | `talesam/community-build` (tags 1.8.x, `latest` atualizado em 2026-10-22; Dockerfile não publicado) / `xivastudio/biglinux_build_package` |
| Privilégios | `--privileged` (GitHub) ou `SYS_ADMIN` + loop devices (local) |
| Runner | GitHub-hosted `ubuntu-latest`; disco grande em `/mnt` (~15 GB de chroots) |
| Tempo | 1–4 h por ISO (`timeout-minutes: 240`) |
| Segredos | motor: nenhum; `biglinux` build-iso.yml: só `GITHUB_TOKEN`; legados: `TOKEN_BOT`, `CHAT_ID`, `TOKEN_RELEASE` |

---

## 3. `big-comm/gitrepo`

**O que é**: pacote Arch (`gitrepo`, MIT, Python 3 + GTK4/libadwaita) com quatro launchers:
`gitrepo` (GUI Build Package), `bpkg` (CLI), `build-iso` (GUI Build ISO), `biso` (CLI). Não
contém workflows. Tokens GitHub ficam no libsecret, por organização.

**Fluxo de pacote** (Build Package): o mantenedor commita num branch `dev-*`, escolhe
testing/stable/extra ou AUR; o app faz push (stable/extra sempre a partir de `main`) e
dispara `POST /repos/<org>/build-package/dispatches`:

```json
{"event_type": "<nome-do-pacote>",
 "client_payload": {"branch": "...", "branch_type": "testing|stable|extra",
                    "build_env": "normal", "url": "https://github.com/<owner>/<repo>",
                    "new_branch": "...", "pkgbuild_dir": "...", "tmate": false}}
```
AUR: `event_type = aur-<nome>`. Depois verifica se o dispatch gerou um run.
`build_package/core/config.py`: `VALID_ORGANIZATIONS = ["big-comm", "biglinux"]` (é um
`choices=` do argparse).

**Como o pacote é construído/publicado** (`big-comm/build-package`):

1. `build-package.yml`: `repository_dispatch` (todos os tipos exceto `aur-*`) ou manual;
   `aur-package-build.yml` para `aur-*`. Contêiner `talesam/community-build:latest
   --privileged`, permissões `contents/packages/actions/deployments/issues/pull-requests:
   write`.
2. `action.yml` (composite, ~1500 linhas): importa a chave GPG; configura repos
   (`community-*`, `biglinux-*` em `$repo/$arch`); `PACKAGER` e
   `GPGKEY=AECEEE84…` no `makepkg.conf`; clona a URL do payload; `makepkg -s`; assina cada
   pacote (`gpg --detach-sign`); `ssh-keyscan` + `rsync` para
   `<PKGBUILD_DIR>/community-<branch>/x86_64/`; executa `scripts/update-repository.sh` no
   servidor (mantém a versão mais nova via `vercmp`, `repo-add --prevent-downgrade` num
   diretório temporário e move atomicamente, `flock`, falha se o pacote enviado não entrou
   no banco); cria GitHub Release (exceto testing/AUR) no repositório de origem se o dono
   for `big-comm|talesam`, **senão no próprio `build-package`**; dispara
   `windows-msi-build`; notifica Telegram.
3. Segredos: `PKGBUILD_KEY`, `PKGBUILD_HOST/USER/PORT/DIR`, `GPG_PRIVATE_KEY`, `PASSPHRASE`,
   `TOKEN_BOT`, `CHAT_ID`, `REPOSITORY_TOKEN`, `ORGANIZATION_TOKEN`, `OPENAI_KEY`
   (tradução, desativada).

Exemplo do padrão "repo de pacote → build-package": `community-livecd-key` regenera o
keyring semanalmente e chama `big-comm/build-package/dispatches` com `REPOSITORY_TOKEN`.

**`biglinux/build-package`** (mesma origem, evoluído): workflow reutilizável
`_secure-package-pipeline.yml` com **job de build sem segredos** (artefato não assinado) e
**job de publicação num runner novo**, em `environment: package-production` (assinatura,
SSH com `StrictHostKeyChecking=yes` e `PKGBUILD_KNOWN_HOSTS`), notificações em
`environment: package-notifications`, actions fixadas por SHA, `namcap`, `aur_commit` para
fixar o commit do AUR revisado e variáveis de repositório (`REPO_DB_PREFIX`,
`REPO_AUR_BRANCH`, `REPO_INCLUDE_SIGS`, `REPO_POST_PUBLISH`, `BIGLINUX_BUILDER_IMAGE`).
**É reaproveitável por outra organização só mudando variáveis e segredos.**

**O que uma nova org precisa para reaproveitar o gitrepo**:
- Ter `big-windowmaker/build-package` (para `bpkg`) e `big-windowmaker/build-iso` (para
  `biso --auto`) aceitando o mesmo payload.
- PR no gitrepo: incluir `big-windowmaker` em `VALID_ORGANIZATIONS` (build_package e
  build_iso), um bloco em `ORG_DEFAULT_CONFIGS` (`distroname`, `iso_profiles_repo`,
  `build_dir`, `edition: "wmaker"`), `ISO_PROFILES_REPOS`/`API_PROFILES` e o nome de exibição
  da edição. Hoje `DISTRO_DISPLAY_NAMES`/`VALID_DISTROS` só conhecem bigcommunity e biglinux.
- Enquanto o PR não sair: usar `workflow_dispatch` direto ou `gh workflow run`, ou
  `curl … /dispatches` com o mesmo payload.

---

## 4. `big-comm/community-keyring` e assinatura

**Conteúdo**: `community.gpg` (export armored), `community-trusted`
(`AECEEE84E52BBFAA9F1C9DF01EA0CEEEB09B44A3:4:`), `community-revoked` (vazio), `Makefile`
(`update` = `gpg --recv-keys` + export; `install` em `/usr/share/pacman/keyrings/`),
`PKGBUILD` (versão por data, `epoch=1`, confere sha256 fixos dos quatro arquivos no
`prepare()`), `community-keyring.install` (`pacman-key --init` + `--populate community`).

Chave: **RSA-4096 criada em 2024-08-19, sem data de expiração, uma única chave primária
[SC]** + subchave [E], UID pessoal (`talesam@gmail.com`). A mesma chave é a `GPGKEY` do
CI e o secret `GPG_PRIVATE_KEY` do `big-comm/build-package` (inclui a primária, já que não
há subchave de assinatura).

Onde a confiança é distribuída:
- Sistema instalado: `community-keyring` em `shared/Packages-Root`.
- Sessão live: `community-livecd-key` (keyring pré-montado `pubring.gpg`/`trustdb.gpg`
  regenerado semanalmente por workflow; verifica que as chaves BigLinux `F7EB9C28…` e
  community `AECEEE84…` estão presentes).
- Contêiner de build: o motor clona `big-comm/community-keyring` por HTTPS sem pin.
- Repositório: `SigLevel = PackageRequired` (pacotes assinados, **banco não assinado**).

### Proposta para big-windowmaker

| | A) Reusar o repositório/chave community | B) Chave + keyring próprios (`bigwm-keyring`) |
|---|---|---|
| Confiança do usuário | nenhuma âncora nova; já vem na ISO | nova âncora: pacote `bigwm-keyring` em `Packages-Root` |
| Quem assina | só o CI do big-comm (a chave nunca deve sair de lá) | CI da big-windowmaker |
| Autonomia/cadência | depende de revisão e do token dos mantenedores | total |
| Infra | nenhuma | servidor/bucket de repositório, chave, keyring live, ajustes no motor |
| Raio de dano | comprometimento de qualquer lado afeta ambos | isolado |
| Live ISO | já funciona (`community-livecd-key`) | precisa de `bigwm-livecd-key` ou PR incluindo a chave no `community-livecd-key` |
| Build da ISO | motor já instala o keyring community | motor não conhece a chave → pré-passo no workflow ou PR (`EXTRA_KEYRINGS`) |

**Recomendação (híbrida, em duas fases)**:
1. **Fase 1**: pacotes genéricos e úteis a toda a comunidade (Window Maker extras, dockapps,
   temas, `comm-wmaker*`) vão para **`community-extra`/`community-stable`** via
   `big-comm/build-package`, assinados pela chave community. A edição entra em
   `big-comm/iso-profiles`. Zero chave nova.
2. **Fase 2** (quando houver identidade própria — `bigwm-release`, branding, skel, configs
   opinativos — ou cadência própria): criar a chave e o repositório `bigwm-*`:
   - chave primária **offline** (ed25519 ou RSA-4096), **subchave só de assinatura** com
     expiração de 1–2 anos no secret do CI, certificado de revogação guardado offline por 2
     mantenedores, UID institucional (ex.: `Big WindowMaker Package Signing
     <packages@…>`), fingerprint publicado no README e no site;
   - `big-windowmaker/bigwm-keyring` copiando o layout do `community-keyring`
     (`bigwm.gpg`, `bigwm-trusted`, `bigwm-revoked`, Makefile, `.install` com
     `pacman-key --populate bigwm`), mas **sem** `pkgver=$(date)` + `source=git+…`
     sem pin: usar tag/commit fixo e sha256 dos arquivos;
   - assinar também o banco (`repo-add --sign`) e usar `SigLevel = Required` só nas seções
     `bigwm-*`.

**Exige coordenação com BigCommunity/BigLinux**:
- Aceitar a edição `wmaker` e os pacotes nos repositórios community (revisão, quem mantém).
- Conceder (ou não) a uma pessoa/time big-windowmaker o poder de disparar
  `big-comm/build-package` (é preciso token com escrita no repo; hoje qualquer dispatch com
  token builda **qualquer URL**, inclusive de outra org, e assina com a chave community).
- Incluir a chave bigwm no `community-livecd-key` (ou aceitar um `bigwm-livecd-key`
  paralelo, que instala os mesmos arquivos e portanto **conflita**).
- PR no motor (`biglinux/iso-profiles`): terceiro produto/repositório/keyring (seção 7.3).
- Sugestão de melhoria para eles: subchave de assinatura com expiração e primária offline;
  hoje a chave community não expira e a primária está no CI.

---

## 5. Auditoria dos workflows (segredos, runners, pinning, supply chain)

Runners: 35 jobs `ubuntu-latest`, 12 `ubuntu-24.04`, **nenhum self-hosted**.

| Repositório | Pinning de actions | Imagem | Segredos | Problemas |
|---|---|---|---|---|
| big-comm/build-iso (arquivado) | tags (`@v4`, `softprops@v1`, `action-tmate@v3`) | `talesam/community-build:1.7.1` (tag) `--privileged` | TOKEN_BOT, CHAT_ID, TOKEN_RELEASE | `iso_profiles_repo` do payload clonado sem validação; tmate no job do build; md5 apenas |
| talesam/build-iso | tags | `talesam/community-build:latest` | idem | motor antigo divergente; `:latest` |
| big-comm/build-package | tags (`checkout@v4`, `softprops@v1`, `action-tmate@v3`) | `talesam/community-build:latest` `--privileged` | GPG_PRIVATE_KEY, PASSPHRASE, PKGBUILD_KEY/HOST/USER/PORT/DIR, REPOSITORY_TOKEN, ORGANIZATION_TOKEN, TOKEN_BOT, CHAT_ID, OPENAI_KEY | **chave GPG importada e chave SSH no agente no mesmo job que roda `makepkg` de PKGBUILD arbitrário/AUR** (exfiltração trivial); `${{ client_payload.url }}`/`inputs.*` interpolados em `run:` (injeção de shell); `--passphrase` na linha de comando; `ssh-keyscan` TOFU; permissões amplas; URL de origem sem allowlist; pacotes `git+…` sem pin e `SKIP` |
| biglinux/build-package | **SHA** | variável `BIGLINUX_BUILDER_IMAGE` (padrão `:latest`) | separados em environments | modelo bom; só a imagem padrão ainda é `:latest` |
| biglinux/iso-profiles `build-iso.yml`/openQA | **SHA** | **digest** | só `GITHUB_TOKEN` | modelo bom (gate openQA antes de publicar, sha256) |
| biglinux/iso-profiles `make-profiles.yml` | tags + `ad-m/github-push-action@v1` | — | GITHUB_TOKEN | clona Manjaro profiles sem pin; tmate |
| community-livecd-key | `checkout@v5` | `manjarolinux/base:latest` | REPOSITORY_TOKEN (PAT) | keyrings clonados sem pin viram âncora de confiança da live ISO |
| repos wmaker antigos (ruscher) | `checkout@v3` | — | WEBHOOK_TOKEN | apontam para org antiga `BigLinux-Package-Build` |

Outros pontos de supply chain:
- Imagens `talesam/community-build` e `xivastudio/biglinux_build_package` sem Dockerfile
  público vinculado: conteúdo não auditável; contas pessoais no Docker Hub.
- O motor faz `curl` em kernel.org e `raw.githubusercontent.com/biglinux/linux-latest` para
  decidir o kernel (entrada externa não fixada, mas validada por regex).
- PKGBUILDs da família (ex.: `comm-wmaker`, `community-keyring`, `gitrepo`) usam
  `source=git+URL` sem tag/commit, `pkgver=$(date)` e `sha*sums=SKIP`: o pacote é o HEAD do
  momento do build — não reproduzível e sem verificação.
- Banco de repositório não assinado → sem proteção contra *freeze/rollback* de metadados.
- ISOs publicadas com md5 (legado) e sha256 (biglinux), mas **sem assinatura** nem
  proveniência.

---

## 6. Repositórios e servidores envolvidos (mapa)

```
Pacotes:  repo do pacote (PKGBUILD) ──dispatch──▶ <org>/build-package ──rsync/SSH──▶ servidor ──▶ https://repo.communitybig.org/community-{testing,stable,extra}/x86_64
                                                     │  assina com AECEEE84…                 (BigLinux: https://packages.biglinux.com.br/biglinux-{priority,testing,stable,extra}/x86_64)
                                                     └─ GitHub Release (.pkg + .sig + .md5)
ISO:      big-comm/iso-profiles (perfis) + biglinux/iso-profiles (motor) ──▶ contêiner manjaro-tools ──▶ .iso/.pkgs
                 └─ gitrepo local | talesam/build-iso (remoto) ──▶ GitHub Release / isovault → S3 CDN77 → iso.communitybig.org
Chaves:   big-comm/community-keyring ─▶ community-keyring (instalado) ; community-livecd-key (live) ; clonado pelo motor (build)
```

---

## 7. Pipeline proposto para big-windowmaker

### 7.1 Repositórios na org `big-windowmaker`

| Repositório | Conteúdo | Origem / reuso |
|---|---|---|
| `build-package` | pipeline de pacotes | **fork de `biglinux/build-package`** (pipeline seguro); configurar `vars` |
| `wmaker-*`, `comm-wmaker`, `comm-wmaker-config`, `bigwm-skel`, `bigwm-release`, `bigwm-calamares` … | um PKGBUILD por repo (ou monorepo `packages/` com `pkgbuild_dir`) | migrar de `ruscher/*`; workflow mínimo que só despacha |
| `aur-imports` (opcional) | lista de pacotes AUR + commit revisado | usa `aur-<nome>` + `aur_commit` |
| `bigwm-keyring`, `bigwm-livecd-key` (fase 2) | chaves | layout de `community-keyring` / `community-livecd-key` |
| `iso-profiles` (fase 2, ou PR upstream na fase 1) | `bigcommunity/wmaker/` + `shared/` | fork de `big-comm/iso-profiles` (manter a pasta `bigcommunity/` enquanto o motor exigir) |
| `build-iso` | workflows de ISO | novo, baseado em `biglinux/iso-profiles/.github/workflows/build-iso.yml` (+ openQA opcional) |
| `.github` | `CODEOWNERS`, `dependabot.yml` (github-actions), políticas | novo |

### 7.2 Fluxo ponta a ponta

```
[push em dev-* de um repo de pacote]  ─▶ dispatch {branch_type: testing}
[merge em main / tag vX]               ─▶ dispatch {branch_type: stable}
                │
                ▼
big-windowmaker/build-package
  job build      (ubuntu-24.04, contêiner fixado por DIGEST, SEM segredos, permissions: contents: read)
                 pacman -Syu, clona URL (allowlist: github.com/big-windowmaker/*), makepkg como builduser, namcap
                 └─ upload-artifact (pacotes não assinados + sha256)
  job publish    (runner novo, environment: package-production — só branch main, revisor obrigatório p/ stable)
                 baixa artefato (digest-mismatch: error), assina com SUBCHAVE, verifica .sig,
                 rsync com StrictHostKeyChecking=yes, repo-add [--sign] atômico (update-repository.sh),
                 GitHub Release no repo de origem, attest-build-provenance
  job notify     (environment: package-notifications) Telegram opcional
                │
                ▼
  repositório:  fase 1 → community-{testing,stable,extra} (via big-comm)  |  fase 2 → bigwm-{testing,stable,extra}
                │
                ▼ (opcional: repository_dispatch "packages-updated" ou cron)
big-windowmaker/build-iso
  gatilhos: workflow_dispatch (edition=wmaker, kernel, branches)
            repository_dispatch types: ["ISO-*"]  (compatível com `biso` do gitrepo)
            schedule: semanal → ISO TESTING
            push em iso-profiles → só o job de lint
  job lint       (sem privilégio) pytest tests/, integridade de symlinks, `bash -n`,
                 resolução das listas: `pacman -Sp --print` das Packages-* contra os repos (falha cedo, em minutos)
  job build      contêiner fixado por digest `--privileged`, volumes em /mnt, timeout 240 min
                 checkout do motor biglinux/iso-profiles @ SHA fixado + checkout dos perfis @ SHA
                 [pré-passo fase 2: instala bigwm.gpg/bigwm-trusted em /usr/share/pacman/keyrings e
                  anexa [bigwm-*] em /usr/share/manjaro-tools/pacman-{default,multilib}.conf]
                 PROFILES_ROOT=…  EDITION=wmaker  bash build-iso/build-iso.sh
                 sha256sum + md5sum, upload-artifact (candidato, retenção 2 dias)
  job test       boot em QEMU (BIOS+UEFI) — reaproveitar openqa.yml da BigLinux ou um smoke test
                 (chega ao lightdm/wmaker? calamares abre?)
  job publish    environment: iso-release (revisor obrigatório para STABLE), permissions: contents: write
                 verifica checksums, SHA256SUMS + SHA256SUMS.sig (subchave de release),
                 actions/attest-build-provenance da ISO, 7z -v2000m se > 2 GiB,
                 GitHub Release com .iso|.7z.*, .sha256, .md5, .pkgs, SHA256SUMS(.sig)
                 [opcional] upload S3/CDN em environment separado (iso-mirror) — ou combinado com o isovault
```

### 7.3 O que reaproveitar sem negociar

- O **motor** `biglinux/iso-profiles/build-iso/build-iso.sh` (GPL-3.0), chamado com
  `PROFILES_ROOT`, fixado por SHA — exatamente o que o gitrepo já faz para a BigCommunity.
- `biglinux/build-package` (pipeline seguro) e `scripts/update-repository.sh` /
  `publish-package.sh` (prefixo do banco via `REPO_DB_PREFIX`).
- Estrutura de `iso-profiles` (symlinks para `shared/`), testes do GRUB, workflows
  `build-iso.yml` + openQA da BigLinux (já com SHAs e digest).
- Layout do `community-keyring` e o workflow do `community-livecd-key`.
- `gitrepo` como cliente (com PR para a nova org, ou dispatch manual até lá).

### 7.4 O que precisa ser negociado

| Assunto | Com quem | Opções |
|---|---|---|
| Edição `wmaker` em `big-comm/iso-profiles` vs fork próprio | BigCommunity | PR upstream (fase 1) → fork só se precisar de identidade/ritmo próprios |
| Hospedar pacotes em `community-*` | BigCommunity | dockapps/WM genéricos em `community-extra`; identidade da distro em `bigwm-*` |
| Acesso ao `big-comm/build-package` (token de dispatch) ou revisão por eles | BigCommunity | eles disparam; ou token restrito; nunca copiar a chave community |
| Suporte a 3º produto no motor: `PRODUCT`/`ISO_PRODUCT` (nome da ISO, `dist_name`, tema GRUB), `EXTRA_REPOS` e `EXTRA_KEYRINGS` | **BigLinux** (dono do motor) | PR em `biglinux/iso-profiles`; até lá, pré-passo no workflow + nome `bigcommunity_wmaker_*` |
| Chave bigwm no `community-livecd-key` | BigCommunity | ou pacote `bigwm-livecd-key` com `conflicts/provides` |
| Sessão live/assistente para Window Maker em `biglinux-livecd`; Calamares (`desktops/wmaker`) | BigLinux | PR no `biglinux-livecd` ou sessão live própria |
| Organizações e edição no `gitrepo` | BigCommunity | PR em `config.py` (build_package e build_iso) |
| Espelho de ISOs (`iso.communitybig.org`, pasta "Window Maker" no isovault) | BigCommunity | ou GitHub Releases + SourceForge/espelho próprio |
| Identidade (`community-release` vs `bigwm-release`, branding Calamares/GRUB) | BigCommunity | `keep_release_identity` do motor já preserva o `lsb-release` de um pacote próprio |

### 7.5 Segredos/variáveis da org big-windowmaker

| Onde | Nome | Observação |
|---|---|---|
| `build-package` → env `package-production` | `GPG_PRIVATE_KEY` (só subchave de assinatura), `PASSPHRASE`, `PKGBUILD_KEY` (chave SSH com `command=`/rrsync restrito no servidor), `PKGBUILD_KNOWN_HOSTS`, `PKGBUILD_HOST/USER/PORT/DIR` | proteger com regra "apenas branch `main`" + revisor para stable |
| `build-package` → env `package-notifications` | `TOKEN_BOT`, `CHAT_ID` | opcional |
| `build-package` → `vars` | `REPO_DB_PREFIX=bigwm`, `REPO_AUR_BRANCH=extra`, `BIGLINUX_BUILDER_IMAGE=<imagem>@sha256:…` | |
| repos de pacote | token para `dispatches` | preferir **GitHub App** (`actions/create-github-app-token` por SHA) a PAT; PAT fino só com `contents:write` em `build-package` |
| `build-iso` | nenhum para build (só `GITHUB_TOKEN`); `ISO_SIGNING_KEY` no env `iso-release`; credenciais S3 no env `iso-mirror` | |

### 7.6 Regras de endurecimento (aplicar desde o primeiro commit)

1. Toda `uses:` fixada por SHA completo (com comentário da versão) + Dependabot para
   `github-actions`; imagens por **digest**; idealmente imagem de build própria em
   `ghcr.io/big-windowmaker/builder` gerada a partir de Dockerfile versionado.
2. `permissions:` mínimas por job (`contents: read` por padrão).
3. Nunca interpolar `${{ github.event.* }}`/`inputs.*` em `run:` — passar por `env:` e
   validar (regex/allowlist de URL e nomes de pacote).
4. Segredos apenas no job de publicação, em runner novo, com environment protegido;
   `tmate` só em `workflow_dispatch` e **nunca** em job com segredos.
5. `StrictHostKeyChecking=yes` com `known_hosts` em secret; chave SSH restrita no servidor.
6. PKGBUILDs com `source` fixado em tag/commit e checksums reais; AUR só por `aur_commit`
   revisado.
7. Banco assinado (`repo-add --sign`) para `bigwm-*`; ISO com `SHA256SUMS.sig` e
   atestado de proveniência.
8. `CODEOWNERS` e branch protection em `iso-profiles`, `build-package`, `build-iso` e nos
   repos de keyring.

### 7.7 Ordem sugerida de implementação

1. Abrir conversa com BigCommunity/BigLinux sobre a tabela 7.4 (principalmente hospedagem
   e motor).
2. Migrar e corrigir PKGBUILDs (`comm-wmaker` sem `lxdm` se for usar lightdm; dockapps
   faltantes) e publicá-los em `community-testing` (fase 1).
3. PR da edição `bigcommunity/wmaker` em `big-comm/iso-profiles` (checklist 1.4) + testar
   com `gitrepo` local (`biso --local --distro bigcommunity --edition wmaker`).
4. Criar `big-windowmaker/build-iso` rodando o motor fixado por SHA, com gate de boot e
   release assinada.
5. Fase 2 (se necessário): chave + `bigwm-keyring` + repositório `bigwm-*` + fork de
   `iso-profiles` + PR no motor para produto/repos/keyrings extras.

---

## 8. Divergências e pontos a validar

- README do `big-comm/iso-profiles` desatualizado (8 edições / 140 symlinks vs 4 / 64).
- `gitrepo` mantém `DEFAULT_EDITIONS` com cosmic/deepin (fallback offline) e o caminho
  remoto de ISO aponta para `talesam/build-iso`, cujo motor diverge do motor oficial.
- `shared/live-overlay/etc/lxdm/lxdm.conf` usa `autologin=biglinux` (usuário live da
  BigCommunity é `community`).
- `livecd.desktop` (`biglinux-livecd`) tem `TryExec=/usr/bin/startplasma-x11`; confirmar
  como as edições XFCE/Cinnamon contornam isso antes de copiar o esquema para wmaker.
- Repositórios community respondem nos dois layouts (`/stable/x86_64` legado e
  `/community-stable/x86_64` atual); usar o atual (`$repo/$arch`).
- O repositório community é pequeno (58 pacotes em stable, 51 em extra): adicionar ~10
  pacotes wmaker é proporcionalmente relevante — mais um motivo para combinar com os
  mantenedores.
