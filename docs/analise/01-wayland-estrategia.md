# 01 — Estratégia Wayland para o Big WindowMaker

> Análise feita em 2026-10-25 sobre os clones locais, sem modificar os repositórios.
> Host: BigLinux baseado em Manjaro (kernel 7.2.12-1-big).
> Builds feitos fora da árvore, em `/tmp/claude-1000/-home-ruscher-Documentos-Git-git-big-windowmaker/c6299683-f610-46e1-bcda-d5878327d148/scratchpad/`.

| Estratégia | Repositório | HEAD analisado |
|---|---|---|
| **A — wlmaker** (compositor novo, inspirado no Window Maker) | `upstream/phkaeser-wlmaker` (github.com/phkaeser/wlmaker) | `7481afe` (2026-10-18), versão 0.8.1+80 commits |
| A (fork) | `upstream/wlmaker` (github.com/ruscher/wlmaker) | **idêntico**: mesmo `7481afe`, sem branches nem commits próprios (`git ls-remote` do fork também aponta `7481afe`) |
| **B — windowmaker-wl** (port do próprio Window Maker 0.96 para um backend wlroots) | `upstream/windowmaker-wl` (git.lneely.de/lkn/windowmaker-wl) | `15f19af` (2026-06-29). O remoto confirma que este é o HEAD atual. |

---

## 1. Resumo executivo

**Recomendação:** adotar a **Estratégia A (wlmaker)** como base da sessão Wayland e entregá-la marcada como **"experimental"**. A **Estratégia B** fica como **referência de design**, não como fonte direta de código, e entra em observação: se o autor voltar a mantê-la, vale reavaliar. A sessão X11 clássica continua com o **wmaker upstream (0.96)**, e não com o binário X11 do windowmaker-wl.

Motivos principais:

1. **A compila e roda neste host.** Bastam os pacotes oficiais do Manjaro (`wlroots0.20` está disponível). O build termina com zero warnings, as suítes de teste passam, e o compositor subiu em modo headless anunciando 24 globals Wayland, conferidos com `wayland-info`.
2. **B não configura neste host sem patches.** O `configure.ac` só aceita `wlroots-0.19` (ou o antigo `wlroots` sem sufixo), e o Manjaro só oferece `wlroots0.20`. Forçando o 0.20, dois arquivos falham por mudanças de API. Também há caminhos fixos da máquina do autor (`/home/lkn/src/wlroots/protocol`). Com 3 linhas corrigidas numa cópia de rascunho, o binário compilou e subiu em headless (35 globals).
3. **Manutenção.** A tem um mantenedor ativo, com 302 commits nos últimos 12 meses, releases a cada 2 a 4 meses, CI em 5 distros e pacote no AUR. B teve uma única rajada de 761 commits entre março e junho de 2026, em boa parte gerada por agentes de IA (`tools/wm-port/`, autor "Ollie <ollie@agent>"), e está **parado há 4 meses**.
4. **Segurança.** O `ext-session-lock-v1` de B **não bloqueia entrada nem oculta o desktop** quando a tela está travada. O flag `session_locked` é gravado e nunca lido. Em A o lock é um subsistema testado, com 1151 linhas e injeção de dependência para testes.
5. **Licença.** A é Apache-2.0 e B é GPL-2.0-or-later, e os 50 arquivos do backend Wayland de B não têm cabeçalho de licença. Código de B **não pode ser copiado** para o wlmaker upstream. Serve como referência de ideias.

O preço de A: não reaproveita WINGs nem WPrefs, não lê os temas `.style`/`.themed` do Window Maker e não roda dockapps X11 (wmclock e similares). O desktop "parece" Window Maker, mas é outro programa com outra configuração. Por isso a sessão deve sair como experimental.

---

## 2. Tabela comparativa

| Critério | A — wlmaker | B — windowmaker-wl |
|---|---|---|
| Natureza | Compositor novo em C11 com toolkit próprio (`wlmtk`) | Window Maker 0.96 com vtable `WMBackend` (≈250 slots) e backend wlroots |
| Maturidade declarada | "Early access" (README), v0.8.1 | ROADMAP diz que "smoke test passa", com HiDPI, iconify animation e DRM ainda pendentes |
| wlroots exigido | **main: `wlroots-0.20` apenas** (`src/CMakeLists.txt:19`). v0.8.1: 0.18, 0.19 ou 0.20 | **`wlroots-0.19`** ou `wlroots >= 0.15` (`configure.ac:661-667`). **Não aceita 0.20** |
| wayland-protocols | ≥ 1.32 (`protocols/CMakeLists.txt:18`) | ≥ 1.20 (client), mais o pacote `wlr-protocols` ou o caminho fixo `/home/lkn/...` (`src/Makefile.am:6`) |
| Disponível no Manjaro | `wlroots0.20 0.20.2-1` (extra). **Não existem** `wlroots0.18`, `wlroots0.19` nem `wlroots` | idem, então B não encontra wlroots |
| Build neste host | **OK** (com sysroot local dos pacotes oficiais, ver §6). 0 warnings | **Falha no configure**. Com alias 0.19→0.20 falha em 2 arquivos (3 erros de API). Com patch de 3 linhas compila e linka (1337 warnings) |
| Testes automatizados | 26 testes CTest e ≈157 casos unitários em 52 arquivos, todos executados no CI. Aqui passaram tudo, exceto 1 por ambiente | 2 testes unitários (`tests/test_geom.c`, `test_x11_event.c`) **fora do build** (`tests/Makefile.am:2-3`), mais um smoke test em shell baseado em grep de log |
| CI | GitHub Actions: Debian Forky e Trixie, Fedora 44, FreeBSD 15.1, openSUSE TW | Nenhum |
| Commits nos últimos 12 meses | 302 (294 do autor, 5 da Campbell Barton, 3 de outros) | 761, todos entre 2026-03-26 e 2026-06-29. Último em 2026-06-29 |
| Mantenedores | 1 principal (Philipp Kaeser; parte do código tem copyright Google LLC), comunidade pequena | aparentemente 1 humano (Levi Neely, como `lkn`, `Levi Neely` e possivelmente `Window Maker <wmaker@localhost>`) mais agentes de IA (`Ollie`) |
| Releases | v0.6 a v0.8.1 entre ago/2025 e jul/2026 | Nenhuma tag |
| Empacotamento | AUR `wlmaker 0.8.1-1` (mantido por aperez), Debian, Fedora, FreeBSD | Nenhum |
| Licença | Apache-2.0 | GPL-2.0-or-later. Arquivos novos sem cabeçalho |
| xdg-shell, toplevel e popups | Sim (`src/xdg_shell.c`, `xdg_popup.c`) | Sim. `xdg_popup` só entrou em 2026-06-28 |
| xdg-decoration (SSD) | Sim | Sim |
| layer-shell | Sim, v5 (sem popups de layer) | Sim (`wl_layer_shell.c`, 216 linhas) |
| xdg-activation | **Não** (`doc/FEATURES.md:260`) | Sim, mas sem validação de seat ou serial |
| XWayland | Sim, desligado por padrão (`--start_xwayland`) | Sim, ligado (eager) |
| Output management e multi-monitor | Sim (`wlr-output-management`, persistência em State.plist, hotplug) | Sim desde jun/2026 ("phase 3", `wl_output.c`, `wl_output_mgmt.c`). Pouco testado |
| HiDPI e escala fracionária | `wp_fractional_scale_v1`, escala por saída. Decorações não escalam com fração | **Não** (ROADMAP "Priority 4" todo aberto) |
| Session lock | Sim e robusto (`src/lock_mgr.c`) | Registrado, mas **inseguro** (ver §5) |
| Idle inhibit | Sim | Sim (só registra o global) |
| ext-idle-notify (swayidle) | Não (idle é interno, `src/idle.c`) | Não |
| Layouts de teclado | `Config.plist`: `XkbConfigurationFile=/etc/default/keyboard` ou RMLVO | Só variáveis `XKB_DEFAULT_*` (`wl_backend.c:565-569`) |
| Clipboard e primary selection | Sim, mais data-control | Sim, mais data-control, com ponte para XWayland |
| DnD entre clientes | **Não** (não trata `request_start_drag`) | Sim (`wl_dnd.c`, `wl_dragicon.c`) |
| Dock e Clip | Dock em processo separado (`wlmdock`) no main e Clip interno. Sem drawers, sem autosave do dock | **Dock e Clip originais do WM** (`src/dock.c`, 4884 linhas), com drawers e estado em `~/GNUstep` |
| Dockapps | Só os nativos do protocolo `zwlmaker_icon_manager_v1` (wlmclock, wlmbattery, wlmcpugraph...). **Dockapps X11 não docam** | Dockapps X11 via XWayland (`icon_window`), funcionalidade marcada como "WIP" nos commits. Protocolo nativo `wmaker_dockapp_manager_v1` sem clientes |
| WINGs e WPrefs | Não. Configuração por plist editado à mão | Sim. WINGs com backend Wayland e WPrefs (compilou aqui) |
| Temas do WM (`.style`, `.themed`, `~/GNUstep/Defaults`) | **Não compatível**: formato próprio (`share/Themes/*.plist`) | **Compatível** (mesmo `defaults.c`, `texture.c` e wrlib) |
| Sanitizers e memória | `valgrind.md`, arquivos `.supp`, commits de "valgrind cleanup" | `asan.sh` e `asan.log` (vazio), 50 commits de crash/UAF/heap/overflow, "canary-based heap overflow detection" |
| Higiene do repositório | Limpa (STYLE.md, iwyu, doxygen) | Arquivos de rascunho versionados (`[2=1]`, `+cmd~`, `stIncmtw`, `wm.log`, PNGs de screenshot na raiz) |
| Esforço até qualidade de produção (estimativa) | Média: integração e empacotamento em 2 a 4 semanas. Lacunas funcionais de semanas a meses, dependendo do upstream | Alta: 6 a 12+ pessoa-mês (auditoria de memória, testes, segurança, HiDPI), sem upstream ativo |

---

## 3. Evidências por critério

### 3.1 Fork do ruscher × upstream phkaeser

```
phkaeser-wlmaker  HEAD 7481afe  (origin = github.com/phkaeser/wlmaker)
wlmaker           HEAD 7481afe  (origin = github.com/ruscher/wlmaker)
git ls-remote https://github.com/ruscher/wlmaker HEAD -> 7481afe...
```

O fork é um espelho exato. Hoje não existe nenhum trabalho próprio nele. Ele serve como lugar para branches de integração do Big WindowMaker, com PRs para o upstream.

### 3.2 Compatibilidade com wlroots e wayland-protocols

`pacman -Si` neste host:

- `wlroots0.18`, `wlroots0.19` e `wlroots`: **não encontrados**.
- `wlroots0.20 0.20.2-1` (extra) existe, mas **não está instalado**.
- `wayland-protocols 1.49-1` (extra), **não instalado**.
- `wlr-protocols r112.a741f0a-1` (extra), não instalado.
- `libxdg-basedir 1.2.3-3` (extra), não instalado. A precisa dele.
- Já instalados: wayland 1.26, xkbcommon 1.13.2, cairo 1.18.4, librsvg 2.62.3, pixman 0.46.4, xorg-xwayland 24.1.13, libinput 1.31.3, seatd 0.9.3.

**A:**
- `phkaeser-wlmaker/src/CMakeLists.txt:18-19`: `# We build for wlroots 0.20.` e `pkg_check_modules(WLROOTS REQUIRED IMPORTED_TARGET wlroots-0.20>=0.20)`.
- O commit `9b0bd8b build: Updates code and dependencies to require wlroots 0.20.` veio depois da v0.8.1. A tag `v0.8.1` aceita 0.20, 0.19 ou 0.18 (fallback em `git show v0.8.1:src/CMakeLists.txt`, linhas 23-30).
- Com o Manjaro só tendo 0.20, **as duas versões servem**.

**B:**
- `windowmaker-wl/configure.ac:661-667` aceita `wlroots-0.19` ou `wlroots >= 0.15`. Desde a 0.18 o wlroots usa o nome versionado `wlroots-0.NN`, então a segunda alternativa nunca casa com versões novas.
- Commit `2026-05-10 wayland: migrate wlroots 0.16 API to 0.19`. Não há nenhum `#if WLR_VERSION`.
- Contra 0.20 há 3 quebras reais de API:
  - `wl_xwayland.c:352`: `wlr_xwayland_set_cursor()` passou a receber `struct wlr_buffer*` (4 argumentos, não 7).
  - `wl_extensions.c:390` e `:398`: os sinais `events.text_input` e `events.input_method` foram renomeados para `new_text_input` e `new_input_method`.
- `windowmaker-wl/src/Makefile.am:6`: `WLR_PROTO_DIR = $(shell pkg-config --variable=pkgdatadir wlr-protocols ... || echo "/home/lkn/src/wlroots/protocol")`. Mesmo com o pacote `wlr-protocols` instalado, o Makefile procura `$(WLR_PROTO_DIR)/wlr-layer-shell-unstable-v1.xml`, mas o pacote instala os XML em `.../wlr-protocols/unstable/`. **Só funciona com a árvore de fontes do wlroots do autor.**
- O build fora da árvore também quebra: os headers gerados em `src/protocols/` e `WINGs/WINGsP.h` não estão no include path.

### 3.3 Protocolos realmente registrados

**A**, chamadas `*_create` e `wl_global_create` em código de produção:

- `src/backend/backend.c`: `wlr_compositor_create`, `wlr_subcompositor_create`, `wlr_screencopy_manager_v1_create`, `wlr_ext_output_image_capture_source_manager_v1_create`, `wlr_ext_image_copy_capture_manager_v1_create`, e `wlr_renderer_init_wl_display` (wl_shm e linux-dmabuf).
- `src/backend/output_manager.c`: `wlr_output_manager_v1_create`, `wlr_xdg_output_manager_v1_create`.
- `src/server.c`: `wlr_viewporter_create`, `wlr_fractional_scale_manager_v1_create`, `wlr_data_device_manager_create`, `wlr_primary_selection_v1_device_manager_create`, `wlr_data_control_manager_v1_create`.
- `src/xdg_shell.c`, `src/xdg_decoration.c`, `src/layer_shell.c`, `src/lock_mgr.c`, `src/idle.c`, `src/input/cursor.c` (cursor-shape), `src/toplevel_tracker.c` (ext-foreign-toplevel-list), `src/xwl.c` (XWayland).
- `wl_global_create` próprios: `src/icon_manager.c` (`protocols/wlmaker-icon-unstable-v1.xml`) e `src/input_observation.c` (`protocols/ext-input-observation-v1.xml`).
- XML versionados: `protocols/ext-input-observation-v1.xml`, `protocols/wlmaker-icon-unstable-v1.xml`, `third_party/protocols/wlr-layer-shell-unstable-v1.xml`.

**Verificado em execução** (wlmaker headless e `wayland-info`), 24 interfaces:
`ext_foreign_toplevel_list_v1, ext_image_copy_capture_manager_v1, ext_input_observation_manager_v1, ext_output_image_capture_source_manager_v1, ext_session_lock_manager_v1, wl_compositor, wl_data_device_manager, wl_output, wl_seat, wl_shm, wl_subcompositor, wp_cursor_shape_manager_v1, wp_fractional_scale_manager_v1, wp_viewporter, xdg_wm_base, zwlmaker_icon_manager_v1, zwlr_data_control_manager_v1, zwlr_layer_shell_v1, zwlr_output_manager_v1, zwlr_screencopy_manager_v1, zwp_idle_inhibit_manager_v1, zwp_primary_selection_device_manager_v1, zxdg_decoration_manager_v1, zxdg_output_manager_v1`.
O linux-dmabuf não aparece porque o teste usou o renderer pixman.

Faltam em A: `xdg_activation_v1`, `wp_presentation`, `zwp_pointer_constraints_v1` e `zwp_relative_pointer_manager_v1` (jogos), `text_input_v3` e `input_method_v2` (IME, importante para CJK), `gamma_control` (luz noturna), `xdg_foreign`, `keyboard_shortcuts_inhibit`, `virtual_keyboard`, `ext_idle_notify_v1`.

**B**, todos concentrados em `src/backend/wayland/wl_extensions.c`:
compositor, subcompositor, data_device, primary_selection, data_control, xdg_output, idle_inhibit, viewporter, relative_pointer, pointer_constraints, keyboard_shortcuts_inhibit, screencopy, export_dmabuf, output_manager, output_power, gamma_control, presentation, text_input_v3, input_method_v2, session_lock, layer_shell, xdg_decoration, xdg_activation, xdg_foreign (v2), foreign_toplevel_manager (wlr), virtual_keyboard, virtual_pointer, xdg_shell.
Mais `wl_global_create` próprios em `wl_dockapp_proto.c` (`protocols/wmaker-dockapp-v1.xml`) e `wl_extensions.c` (`protocols/wmaker-popup-v1.xml`).

**Verificado em execução** (binário com o patch 0.20 de rascunho, headless), 35 interfaces, entre elas `xdg_activation_v1`, `wp_presentation`, `zwp_text_input_manager_v3`, `zwp_input_method_manager_v2`, `zwlr_gamma_control_manager_v1`, `zwlr_virtual_pointer_manager_v1`, `zwp_virtual_keyboard_manager_v1`, `xwayland_shell_v1`, `wmaker_dockapp_manager_v1` e `wmaker_popup_manager_v1`.

Ressalva: em B muitos desses protocolos estão **só registrados**, sem política ligada a eles. O próprio `ROADMAP.md` ("Priority 5: Protocol Wiring") diz que "wlroots already advertises these protocols. Wire them to policy". Ter mais globals não significa mais funcionalidade.

### 3.4 Funcionalidades além dos protocolos

- **Multi-monitor e hotplug.**
  - A: `doc/ROADMAP.md:174-195` (0.6, "Multiple outputs", escala fracionária por monitor, layout persistido) e `doc/FEATURES.md:341-345`. O README ainda diz "single-monitor output" como ressalva.
  - B: commits `c5ba4ba` e `b33774d` ("phase 3: multi-output support ... refresh heads on hotplug") de jun/2026. O plano (`MULTI_MONITOR_IMPLEMENTATION_PLAN.md`) deixa de fora dock e clip por monitor e "mixed-DPI".
- **HiDPI.**
  - A: `wp_fractional_scale_v1`, escala e transformação por saída (`FEATURES.md:249`). Itens ainda abertos: "Support configurable fractional scale for all decoration elements" e "Use pango proper".
  - B: nada implementado além do cursor (`wl_output.c:133`, xcursor por escala). `ROADMAP.md` "Priority 4" está todo desmarcado.
- **Teclado.** A lê `/etc/default/keyboard` (`etc/Config.plist:6-18`), o que se integra bem ao BigLinux. B depende de `XKB_DEFAULT_*` no ambiente.
- **DnD.** A não tem handler de `request_start_drag`: `grep` não acha "start_drag" em `src/`, e `server.c` só trata `request_set_selection` e `request_set_primary_selection`. **Arrastar entre aplicativos Wayland não funciona** (por exemplo, do arquivo no gerenciador de arquivos para o navegador). B tem `wl_dnd.c` e `wl_dragicon.c`.
- **Dock e Clip.**
  - A: o main atual removeu o dock embutido e só usa o binário `wlmdock` (commit `5651614`). O Clip continua no compositor. Persistência, drawers e autostart do dock seguem abertos (`FEATURES.md:287-310`).
  - B: reaproveita `src/dock.c` do WM com o comportamento completo.
- **Dockapps.**
  - A tem dockapps nativos em `apps/` (wlmclock, wlmbattery, wlmcpugraph, wlmmemgraph, wlmnetgraph, wlmeyes) usando `zwlmaker_icon_manager_v1`. Não há suporte a `icon_window` X11. A coleção `upstream/dockapps` do projeto **não docará** em A.
  - B tenta docar dockapps X11 via XWayland (`wl_client.c:103-120`, `wl_props.c:93`). A sequência de commits de 2026-06-28 ("WIP", "Revert ... WIP") mostra que isso estava instável quando o desenvolvimento parou. A screenshot do autor `20260627_19h59m14s_grim.png` mostra o wmclock docado. Não reproduzi.
- **WINGs e WPrefs.** Só B. WINGs ganhou arquivos `*_wl.c` e `wstubs_no_x11.c` (193 linhas de stubs). O WPrefs compilou neste teste. O `ROADMAP.md` declara que os painéis funcionam, mas não testei isso interativamente.
- **Temas.** B usa o mesmo `defaults.c`, `texture.c` e wrlib, então é compatível com `~/GNUstep/Defaults/WindowMaker` e com os temas do X11. A usa um esquema próprio (`share/Themes/Default.plist`: `Tile`, `Dock`, `Window.TitleBar`...), com cores `argb32:` e gradientes `DGRADIENT`. A sintaxe plist é parecida, mas as chaves não. Para ter um visual coerente entre as duas sessões, seria preciso um **conversor** de `.style`/`.themed` para o plist do wlmaker (texturas de pixmap como `tpixmap` não têm equivalente).

### 3.5 Qualidade de código

- **A**
  - Toolkit próprio orientado a objetos em C (`src/toolkit/`), com testes embutidos em cada módulo (`bs_test_case_t`), `STYLE.md`, `iwyu-mappings.imp` e doxygen.
  - Compilação com `-Wall -Wextra`: **0 warnings**. São 70 TODO/FIXME em `src/`.
  - O maior arquivo tem 2334 linhas (`toolkit/window.c`). A dívida técnica está documentada (`doc/BACKLOG.md`).
- **B**
  - Reaproveita cerca de 26 mil linhas de política do WM, que é código maduro. O backend Wayland tem 13.055 linhas em 50 arquivos, depende de um singleton global `wl_state` (1.079 referências) e tem 76 slots da vtable ligados a funções `wl_noop_*` (`wl_stubs.c`).
  - 1337 warnings no build (`-Wunused-variable` domina).
  - Há 50 commits do tipo "fix crash/UAF/heap corruption/overflow", e um workaround de "canary-based heap overflow detection to frame_bufs" (2026-06-25). Isso mostra que a gestão de memória do backend ainda não está estável.
  - O desenvolvimento foi conduzido por agentes: `tools/wm-port/README.md` despacha tarefas para `qwen/qwen3-coder` e `anthropic/claude-sonnet-4`, com o autor "Ollie <ollie@agent>". Houve 103 commits só em 2026-05-24 e cerca de 592 mil linhas inseridas no total.
  - Isso não desqualifica o código, mas aumenta muito o custo de revisão.

### 3.6 Manutenção

| | A | B |
|---|---|---|
| Commits (2025-10-25 → 2026-10-25) | 302, em 99 dias distintos | 761, em 36 dias distintos, todos entre mar e jun de 2026 |
| Distribuição mensal | 14 a 64 por mês, sem meses vazios desde ago/2025 (mar/2026: 2) | mar 85, mai 393, jun 283. **Jul a out: 0** |
| Último commit | 2026-10-18 | 2026-06-29 |
| Contribuidores externos | Campbell Barton (dockapps de gráficos, clipboard), Alex Myczko (Debian), Dirk Müller, Jan Beich (FreeBSD) | nenhum |

### 3.7 Segurança, sanitizers e testes

- **A**
  - `valgrind.md` e as supressões `libdrm.supp`, `libgallium.supp`, `libcairo-fontconfig.supp`. Há 8 commits de leak/crash/valgrind no último ano, todos de correção pontual.
  - Não há ASan no CMake.
  - `lock_mgr.c` trava o desktop via `wlmtk_desktop_lock()` **antes** de `send_locked` (`lock_mgr.c:384-409`).
- **B**
  - `asan.sh` só roda `ASAN_OPTIONS=detect_leaks=0 ./src/.libs/wmaker > asan.log`, e o `asan.log` versionado está **vazio**, então não serve de evidência.
  - O arquivo `+cmd~` mostra o fluxo de trabalho do autor (valgrind, ASan, `-fsanitize=leak`), mas não há resultado registrado.
  - Os testes não estão no `SUBDIRS` (`Makefile.am:42`, onde só `DIST_SUBDIRS` inclui `test`).
- **Falha crítica de B (session lock).** `src/backend/wayland/wl_session_lock.c`:
  - Envia `wlr_session_lock_v1_send_locked()` assim que recebe o lock (linha 86), antes de existir qualquer superfície de bloqueio.
  - Define `wl_state.session_locked = true`, mas **nenhum outro arquivo lê esse campo** (`grep` só encontra a declaração em `wl_types.h:328`). Atalhos do compositor, foco por clique e janelas continuam recebendo entrada.
  - Quando o cliente de lock morre, só comenta "keep locked state", sem cobrir a tela.
  - Todas as superfícies de lock são criadas em (0,0) da árvore, então em multi-monitor os outros monitores ficam expostos.
- **B (outros pontos).** Expõe sem filtro `virtual_keyboard`, `virtual_pointer`, `input_method`, `export_dmabuf` e `gamma_control`. É comum em compositores wlroots, mas aumenta a superfície de ataque. O `xdg_activation` aceita qualquer token e foca a janela (`wl_xdg_activation.c`), sem prevenção de roubo de foco.

### 3.8 Licença

- A: Apache-2.0 (`LICENSE`, cabeçalhos por arquivo). Também inclui `inih` (BSD) e `libbase` (Apache) como submódulos.
- B: GPL-2.0-or-later (`COPYING`, cabeçalhos herdados). **Os 50 arquivos `src/backend/wayland/*.c` não têm cabeçalho de licença.** Distribuir sob GPL é possível, mas a proveniência é imprecisa: commits gerados por agentes, sob identidades `@localhost`.
- Consequência: **não dá para copiar código de B para A.** O código Apache pode ir para um projeto GPLv3, mas o upstream do wlmaker é Apache e não aceitaria GPL. B serve como referência de comportamento.

### 3.9 Dependências de runtime

- A: wlroots-0.20, wayland-server, xkbcommon, cairo, librsvg, libxdg-basedir, libinput, xcb e (opcionalmente) xwayland. Submódulos libbase e inih vêm compilados estaticamente. Pacote leve.
- B: tudo do Window Maker (libX11, Xft, Xinerama, Xpm, libpng/jpeg/gif/tiff/webp, ImageMagick, pango) mais wlroots-0.19, pixman e wayland-client. O build padrão é **híbrido**: o mesmo `wmaker` traz backend X11 e Wayland, escolhido por `WMAKER_USE_WAYLAND` (`src/main.c:607-614`). Existe `--disable-x11-backend`, mas o autor descreve esse modo como cheio de crashes (commits de 2026-06-06).

---

## 4. Builds executados (o que aconteceu de fato)

Restrições do ambiente:

- `/tmp` está montado `noexec`, então binários não podem ser executados no scratchpad.
- Não instalei pacotes nem usei sudo. As dependências que faltavam (`wlroots0.20`, `wayland-protocols`, `libxdg-basedir`, `libliftoff`, `wlr-protocols`) foram **baixadas dos mirrors oficiais do Manjaro** (`pacman -Sp` + `curl`) e extraídas num sysroot local (`.../scratchpad/sysroot`), com os `.pc` ajustados.
- Para executar, copiei temporariamente os binários e as `.so` para `~/.cache/claude-wlmaker-testrun`. **Essa pasta já foi apagada.**
- O `HOME` de teste do wmaker foi `.../scratchpad/home-wmwl`, para não tocar em `~/GNUstep`.

### A — wlmaker (`build-wlmaker`)

1. `cmake` direto contra o sistema falha com `Package 'libxdg-basedir' not found`. Com ele resolvido, faltariam ainda `wlroots-0.20` e `wayland-protocols`.
2. Submódulos `libbase` (`1a58652`) e `inih` (`26254ee`) clonados na cópia de rascunho, já que o clone de `upstream/` não os inicializou.
3. Com o sysroot: `cmake` OK e `make -j` OK em cerca de 3 s. **0 warnings, 0 erros.** Gerou `wlmaker`, `wlmdock`, `wlmtool` e os dockapps.
4. Testes: 18 dos 26 itens do CTest passaram direto (validação de plists e `.desktop`). Os 8 binários de teste rodados fora do `noexec`:
   - `toolkit_test` 30/30, `input_test` 4/4, `backend_test` 2/2, `dock_test` 2/2, `util_test` 1/1, `wlmclient_test` 1/1, `segment_display_test` 1/1.
   - `wlmaker_test` 11/12. A única falha, `root_menu.generated_menu`, aconteceu porque ele chama `tool/wlmtool` dentro de `/tmp` (Permission denied). É uma falha **do ambiente**.
5. `wlmaker --version` retorna `0.8.1`. Execução headless (`WLR_BACKENDS=headless WLR_RENDERER=pixman`): iniciou em `wayland-1`, criou a saída `HEADLESS-1 1280x720` e o Clip, e `wayland-info` listou os 24 globals da §3.3. **Não testei clientes reais, DRM/KMS nem XWayland.**

### B — windowmaker-wl (`build-windowmaker-wl`)

1. `autogen.sh` OK (rodado com `sh`, numa cópia via `git archive`).
2. `configure --enable-wayland-backend` falha: **`configure: error: wlroots >= 0.15, wayland-server, or xkbcommon not found`**, porque só existe `wlroots-0.20`.
3. Com um alias `wlroots-0.19.pc` apontando para 0.20 (só no rascunho), o configure passou: `WaylandBackend WaylandClient X11Backend XWayland`.
4. `make` falhou primeiro por `noexec` (scripts `script/*.sh` executados diretamente; contornado com `$(SHELL)` nos Makefiles gerados), depois pelo `WLR_PROTO_DIR` e pelo include path fora da árvore (contornados por variáveis no `make`).
5. Sobraram **erros reais de API do wlroots 0.20**, só em `wl_xwayland.c` e `wl_extensions.c`. 48 dos 50 arquivos do backend compilaram. WINGs, wrlib, WPrefs e util compilaram.
6. Com patch de 3 linhas no rascunho (`wlr_xcursor_image_get_buffer()` e `new_text_input`/`new_input_method`): **build completo e `make install` OK**, com 1337 warnings.
7. Execução headless (`WMAKER_USE_WAYLAND=1 WMAKER_WAYLAND_NESTED=0 WLR_BACKENDS=headless`): chegou ao loop de eventos, iniciou o Xwayland em `:1` e anunciou 35 globals. Encerrado pelo `timeout` após 8 s, sem crash nesse intervalo e **sem nenhum cliente conectado**. Avisou que não conseguiu criar `~/GNUstep` de teste (falta `wmaker.inst`), mas seguiu com os padrões.

---

## 5. Riscos

### Estratégia A (adotada)

| Risco | Impacto | Mitigação |
|---|---|---|
| Upstream de mantenedor único | Alto se ele parar | O fork `ruscher/wlmaker` já existe. Mandar PRs ao upstream em vez de manter patches. Código Apache e limpo, fácil de assumir |
| O main está numa refatoração (dock em processo separado, `wlmtk_desktop_t`) | Regressões | Empacotar a tag **v0.8.1** (o AUR já tem PKGBUILD) ou um snapshot do main validado. Avaliar o main antes de trocar |
| Visual e configuração diferentes do WM X11 (temas, menus, WPrefs) | Expectativa do usuário | Rotular a sessão como "Window Maker (Wayland, experimental)". Fazer um conversor de tema `.style` → plist e um gerador de `RootMenu.plist` a partir do menu do Big (o `wlmtool` já gera a partir de XDG) |
| Dockapps X11 da coleção `upstream/dockapps` não docam | Funcionalidade emblemática ausente | Na Wayland, oferecer os wlm* nativos. Portar os dockapps mais usados para o protocolo `zwlmaker_icon_manager_v1` |
| Sem DnD entre clientes, sem xdg-activation, sem IME | Uso diário prejudicado | Contribuir upstream. São adições bem conhecidas no wlroots (dias cada) |
| XWayland desligado por padrão | Apps X11 não abrem | Passar `--start_xwayland` no `.desktop` da sessão |

### Estratégia B (referência)

- Não compila com o wlroots disponível no Manjaro sem patch. Build dependente da máquina do autor.
- Parado desde 2026-06-29. Sem releases, sem CI, sem testes no build.
- Session lock inseguro, que é um bloqueador para entrega a usuários finais.
- Grande volume de código gerado por agentes, com histórico de UAF e heap corruption, e sem auditoria.
- Fork pesado do Window Maker 0.96 (≈592 mil linhas inseridas, vtable em todo o core). Fazer rebase sobre o wmaker upstream futuro seria caro, e o upstream do WM não demonstrou intenção de absorver isso.
- Usar o binário de B também na sessão X11 colocaria em risco a sessão clássica, que hoje é estável.

---

## 6. Esforço estimado até qualidade de produção

**A (sessão experimental em 2 a 4 semanas; "estável" depende do upstream):**

1. Empacotamento (`wlroots0.20`, `libxdg-basedir`, PKGBUILD do AUR como base), `.desktop` de sessão para o display manager e integração com `xdg-desktop-portal-wlr`. **2 a 4 dias.**
2. Configuração Big: `Config.plist` com teclado do sistema, autostart (polkit agent, nm-applet via layer-shell/waybar opcional, swaylock, swaybg) e menu raiz. **3 a 5 dias.**
3. Conversor de temas WM → wlmaker para os temas default do Big. **3 a 5 dias.**
4. PRs upstream: `xdg-activation-v1`, DnD (`request_start_drag`), `ext-idle-notify` e `pointer-constraints`/`relative-pointer`. **1 a 3 semanas no total**, sujeito a revisão do upstream.
5. Dockapps: portar 2 ou 3 dockapps populares para o protocolo de ícone. **Semanas**, opcional.

**B (de 6 a 12+ pessoa-mês para chegar a produção):**

1. Port para wlroots 0.20 e correção do build system. Dias.
2. Session lock correto, auditoria das entradas privilegiadas e xdg-activation. 1 a 2 semanas.
3. HiDPI, multi-monitor robusto e dockapps X11. Meses.
4. Auditoria de memória de cerca de 13 mil linhas, testes no CI e ASan/UBSan contínuo. Meses.
5. Assumir a manutenção de um fork do WM inteiro sem upstream ativo. Contínuo.

---

## 7. Recomendação

1. **Primária: Estratégia A (wlmaker)**, empacotada a partir da tag `v0.8.1`, ou de um commit do main validado no próprio fork `ruscher/wlmaker`. Fazer o trabalho em branches do fork e enviar como PR ao `phkaeser/wlmaker`.
2. **Sessão Wayland entregue como "experimental".** O próprio upstream se declara "Early access". Faltam DnD entre apps, xdg-activation, IME, dockapps X11, WPrefs e compatibilidade de temas. A sessão padrão do Big WindowMaker continua sendo a **X11 com wmaker 0.96 upstream**.
3. **B como referência, sem copiar código** (licença GPL × Apache, proveniência imprecisa). Ideias úteis:
   - como docar `icon_window` X11 via XWayland (`wl_client.c`, `wl_props.c`);
   - o desenho de um protocolo de dockapp nativo (`protocols/wmaker-dockapp-v1.xml`);
   - o caminho de WINGs como cliente Wayland (`WINGs/*_wl.c`), útil se um dia se quiser um "WPrefs-like" para o wlmaker;
   - a lista de protocolos registrados em `wl_extensions.c`.
4. **Reavaliar B em 6 meses.** Se o autor retomar com wlroots 0.20, CI e a correção do lock, B pode virar uma sessão "Window Maker clássico sobre Wayland" com 100% de compatibilidade de temas e WPrefs. Esse é o grande atrativo dele e o único ponto em que supera A.
