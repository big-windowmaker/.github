# Auditoria e correções — outubro de 2026

Problemas encontrados ao construir, inicializar, instalar e testar o Big
WindowMaker, com a causa raiz e a correção. Cada item foi achado por um teste
(CI, contêiner de integração, smoke test em VM ou instalação openQA em VM) e
verificado depois da correção pelo mesmo teste.

Gravidade: **P0** impede gerar, iniciar ou instalar · **P1** função essencial,
segurança ou integridade · **P2** regressão ou instabilidade relevante ·
**P3** integração ou experiência · **P4** acabamento.

## Matriz de validação

Run [40302996482](https://github.com/big-windowmaker/build-iso/actions/runs/40302996482)
do `build-iso` (branch stable, kernel 6.18 LTS), ISO
`bigcommunity_wmaker_2026-10-26_k618.iso`, VMs QEMU/KVM no GitHub Actions
(2 vCPU, 4 GB, disco virtio de 30 GB, vídeo sem aceleração):

| Etapa | BIOS | UEFI |
|---|---|---|
| Lint do perfil, simulação da instalação dos 425 pacotes | ✅ | ✅ |
| Build da ISO e conferência dos pacotes (incluindo a camada live) | ✅ | ✅ |
| GRUB → kernel → systemd, sem unidades com falha | ✅ | ✅ |
| LightDM, autologin e assistente live | ✅ | ✅ |
| Sessão Window Maker live: Dock com os 6 dockapps, menu raiz (F12), EWMH | ✅ | ✅ |
| Terminal e instalador abrem e aparecem na tela | ✅ | ✅ |
| Calamares: particionamento automático, usuário, instalação | ✅ | ✅ |
| Boot pelo disco instalado, login no LightDM, sessão `big-wm` | ✅ | ✅ |
| Sessão Wayland (`big-wm-wayland`) no sistema instalado: wlmaker no DRM, XWayland, papel de parede | ✅ | ✅ |
| Saúde do sistema instalado (0 unidades com falha) | ✅ | ✅ |
| Segurança do sistema instalado (firewall ativo, `INPUT DROP`) | ⚠️ softfail | ⚠️ softfail |
| Atualização do sistema instalado: `pacman -Syu`, instalar e remover pacote, integridade dos pacotes, reinício e nova sessão | ✅ (VM local, KVM) | — |

O softfail de segurança registra escolhas da base BigLinux listadas em
"Limitações conhecidas". A atualização (módulo `bigwm_update`) foi validada
localmente e entra no pipeline a partir do commit
[`641281a`](https://github.com/big-windowmaker/build-iso/commit/641281a).
Não testados ainda: vários monitores, áudio com dispositivo real.

Observação da atualização: o `pacman -Qkk` acusa os `.desktop` do
`windowmaker` e do `wlmaker` como alterados. É o `render-menu-options.sh` da
BigLinux, que no primeiro boot acrescenta a ação "Software Render" a todo
`.desktop` do sistema; os pacotes `big-wm-*` saem íntegros.

## P0 — bloqueadores

| Problema | Causa raiz | Correção |
|---|---|---|
| A sessão live entrava em loop no login | `startbiglive` só conhecia Plasma, GNOME, Hyprland, XFCE e Cinnamon e caía em "reiniciar o display manager" | Suporte ao Window Maker no `biglinux-livecd` ([`261b16f`](https://github.com/big-windowmaker/biglinux-livecd/commit/261b16f), branch `window-maker`), empacotado temporariamente em `packages/biglinux-livecd` ([`73bb274`](https://github.com/big-windowmaker/packages/commit/73bb274)) até entrar no upstream |
| Build da ISO: `target not found: wmclock, wmmemload, wmsystemtray` | O servidor atual da BigLinux (`packages.biglinux.com.br`) não tem mais esses dockapps; só o espelho antigo tem | Compilados no `big-dockapps` ([`24609ee`](https://github.com/big-windowmaker/packages/commit/24609ee)) |
| Falhas de pacote só apareciam depois de minutos de build privilegiado | Nenhuma checagem prévia da resolução das listas | Job `resolve`: simula com `pacman -Sp` (banco vazio) as 425 entradas da edição ([`414246a`](https://github.com/big-windowmaker/build-iso/commit/414246a)) |
| Branch testing não resolvia `lib32-*` | No Manjaro testing o multilib exigiu `expat`/`pcre2` que os espelhos ainda não tinham | ISO padrão em stable ([`414246a`](https://github.com/big-windowmaker/build-iso/commit/414246a)) |
| Lint reprovava a edição | Pacotes esperados procurados só em `Packages-Desktop`; o `biglinux-livecd` vem de `Packages-Live` com restrição de versão | [`e2c4297`](https://github.com/big-windowmaker/build-iso/commit/e2c4297) |
| ISO gerada era reprovada e não publicada | O verificador só lia a lista do sistema instalado, não a camada live | Confere o banco do pacman dentro do `livefs.sfs` ([`640a238`](https://github.com/big-windowmaker/build-iso/commit/640a238)) |
| Teste de instalação não iniciava no GitHub | O `run-plan.sh` da BigLinux precisa de `ruby`, ausente no runner | [`b8ad6bb`](https://github.com/big-windowmaker/build-iso/commit/b8ad6bb) |

## P1 — críticos

| Problema | Causa raiz | Correção |
|---|---|---|
| Sistema instalado sem firewall, com Samba e dnsmasq escutando em todas as interfaces | O instalador habilita `ufw.service`, mas o `ufw` não era instalado e, no Arch, vem com `ENABLED=no` | `ufw` na edição, ligado, negando entradas exceto Samba (CIFS) e mDNS ([`71c1cd0`](https://github.com/big-windowmaker/iso-profiles/commit/71c1cd0)) |
| Janelas novas invisíveis em VMs e GPUs sem aceleração | picom com `backend = glx` e vsync não consegue ativar o vsync com GL por software | `backend = xrender` ([`9befe49`](https://github.com/big-windowmaker/big-wm/commit/9befe49)) |
| A sessão Wayland abortava ao iniciar | `localectl` devolve `(unset)` e o `Config.plist` recebia `Layout = "(unset)"` | Auxiliar `big-wm-keyboard.sh` ([`9befe49`](https://github.com/big-windowmaker/big-wm/commit/9befe49)) |
| Sessão X11 instalada com teclado US e console ABNT2 | O Xorg só aplica o layout do systemd-localed, que fica `(unset)` | A sessão traduz o teclado do console pela `kbd-model-map` e aplica com `setxkbmap` ([`9befe49`](https://github.com/big-windowmaker/big-wm/commit/9befe49)) |
| `WMWindowAttributes` inteiro ignorado | A WINGs só aceita letras, números e `. _ / +` sem aspas | [`19c8548`](https://github.com/big-windowmaker/big-wm/commit/19c8548); o validador do CI aplica a mesma regra |
| Monitor de rede do Dock não abria | O `wmnd` do BigLinux está ligado a `libsnmp.so.40`, que não existe mais | Troca pelo `wmnet` ([`26bd876`](https://github.com/big-windowmaker/big-wm/commit/26bd876), [`a259d9c`](https://github.com/big-windowmaker/packages/commit/a259d9c)) |
| `wmnet` e `wmsystemtray` abortavam (`BadName`) | Precisam das fontes bitmap do X, e o servidor só as enxerga com `xorg-mkfontscale` (gera o `fonts.dir`) | [`e99ff8a`](https://github.com/big-windowmaker/big-wm/commit/e99ff8a) |
| Nenhum serviço da sessão iniciava (notificações, polkit, bandeja, bloqueio) | `X-GNOME-Autostart-Phase` faz o `systemd-xdg-autostart-generator` ignorar a entrada | Removido antes do primeiro commit; o CI garante que não volta |

## P2 — altos

| Problema | Causa raiz | Correção |
|---|---|---|
| Dock à esquerda, embaixo do Clip | `Position = "-64,0"` herdado: o Window Maker põe o Dock à esquerda quando x fica abaixo do meio da tela | [`44ccf62`](https://github.com/big-windowmaker/big-wm/commit/44ccf62) |
| `wmix` abortando sem dispositivo de áudio | Assert em `mixer-alsa.c` quando não há mixer ALSA | `big-wm-mixer` só inicia o `wmix` com placa de som ou PipeWire ([`816b105`](https://github.com/big-windowmaker/big-wm/commit/816b105)) |
| Erro intermitente do Window Maker ao executar o `autostart` | O `autostart` vazio fazia o Window Maker chamar `system()` na partida | Sem `autostart`/`exitscript` padrão ([`02ab726`](https://github.com/big-windowmaker/big-wm/commit/02ab726)) |
| Aviso "icon doesn't exist" | Ícone do Brave fixo mesmo sem o Brave instalado | Ícones do Clip só para apps instalados ([`eb82a51`](https://github.com/big-windowmaker/big-wm/commit/eb82a51)) |

## P3 — integração e experiência

| Problema | Correção |
|---|---|
| Atalhos do Clip com o cubo genérico | Ícones dos pacotes ([`fdb9543`](https://github.com/big-windowmaker/big-wm/commit/fdb9543), [`eb82a51`](https://github.com/big-windowmaker/big-wm/commit/eb82a51)) |
| Relógio do Dock sempre em inglês | `big-wm-clock` com o idioma da sessão ([`3b547a8`](https://github.com/big-windowmaker/big-wm/commit/3b547a8)) |
| Capturas da tecla Print escondidas em `~/GNUstep` | Ligadas a *Imagens/Capturas de tela* ([`8c08224`](https://github.com/big-windowmaker/big-wm/commit/8c08224)) |

## Desempenho medido

Sistema instalado pelo Calamares, VM BIOS do GitHub Actions (QEMU/KVM, 4 GB
de RAM, 2 vCPU, disco virtio de 30 GB, vídeo sem aceleração), sessão
Big WindowMaker — X11, run
[40296600822](https://github.com/big-windowmaker/build-iso/actions/runs/40296600822)
(BIOS; o UEFI do run 40302996482 deu 23,2 s de boot e 946–1027 MB):

| Medida | Valor |
|---|---|
| Boot (`systemd-analyze`) | 22,6 s (kernel 1,6 s + espaço de usuário 20,9 s); `graphical.target` em 10,9 s |
| Memória usada logo após o login | 1022 MB |
| Memória usada após 5 min ocioso | 955 MB |
| Processos após o login / após 5 min | 196 / 214 |
| RSS do `wmaker` | 26 MB |
| RSS do `picom` (backend xrender) | fora dos 15 maiores processos (< 13 MB); com glx eram 131 MB |
| Espaço ocupado pelo sistema instalado | 5,4 GB |

Os maiores consumidores da sessão não são do Window Maker: `blueman-applet`
(62 MB), `indicator-sound-switcher` (61 MB) e `nm-applet` (47 MB), que vêm da
lista de aplicativos herdada da edição XFCE.

## Limitações conhecidas (não corrigidas aqui)

- **Wayland (wlmaker 0.8):** sem xdg-activation, métodos de entrada (IME) e
  bandeja. O compartilhamento de tela pelo portal exige GPU (linux-dmabuf).
- **Vários monitores no X11:** sem teste automatizado; o QEMU sem interface só
  ativa a segunda saída do virtio-gpu quando um cliente de exibição a liga.
- **Identidade visual do boot:** GRUB e instalador ainda usam a marca
  BigCommunity, forçada pelo motor de ISO da BigLinux (fase 2).
- **Repositório de teste:** a ISO de teste usa o `[bigwm-local]` sem
  assinatura; uma release estável depende de repositório e chave próprios ou da
  publicação dos pacotes no repositório da BigCommunity.
- **Imagem do isotovideo:** espelhada em `ghcr.io/big-windowmaker` com o mesmo
  digest ([`mirror-openqa-image.yml`](https://github.com/big-windowmaker/build-iso/blob/main/.github/workflows/mirror-openqa-image.yml));
  o registro do openSUSE fica só como origem.
- **Processo zumbi na sessão Wayland:** o wlmaker 0.8 só recolhe os processos
  do `Autostart` ao encerrar; o `big-wm-session-ctl start` fica `<defunct>`
  enquanto a sessão dura (inofensivo).
- **Segurança herdada da base BigLinux** (registrado pelo teste
  `installed_security`): um `sudo` sem senha (`biglinux-backlight-restore`),
  dois espelhos HTTP (os pacotes continuam com assinatura obrigatória),
  AppArmor desligado e disco sem criptografia por padrão.

