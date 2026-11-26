# Plano da plataforma — dezembro de 2026

O código do Big WindowMaker está bem cuidado: as correções têm causa raiz,
laboratório e teste antes do merge. O que falta é o caminho entre o código e
quem usa a distribuição:

- como uma correção chega a quem já instalou;
- como um bug de outra pessoa chega até nós;
- quanto custa manter os forks;
- quem revisa o trabalho;
- a desordem local que já provoca erros.

Este plano registra o levantamento de 2026-11-25, as decisões e o andamento.
Ele é atualizado a cada etapa concluída.

## Levantamento (medido em 2026-11-25)

| Tema | Fato | Consequência |
| --- | --- | --- |
| Atualizações | Os pacotes só existem como artefatos da CI. Não há repositório pacman. Numa máquina instalada, `pacman -Qm` lista 69 pacotes estrangeiros. | Quem instala uma ISO nunca recebe correções: o único jeito é reinstalar. |
| `windowmaker` | `0.96.0.r130.g558e67f` é **menor** que o `0.96.0-5` do extra no `vercmp`, porque um segmento com letra perde para o fim da string. A ISO escondia isso com `IgnorePkg = windowmaker`. | O pamac trocava o nosso Window Maker pelo oficial. Com o `IgnorePkg`, o pacote não recebe nenhuma atualização, nem as nossas. |
| Forks | 179 patches sobre o wlmaker, 31 sobre o Window Maker e 21 no big-dockapps. Zero PRs ou issues enviados ao upstream. | Cada rebase custa uma rodada. Uma mudança grande no upstream pode nos prender a uma versão velha. |
| Retorno dos usuários | Nenhuma issue aberta até hoje, contra cerca de 210 PRs. Issues desativadas no wlmaker e no iso-profiles. Coredumps desligados (`Storage=none`). | Só ficamos sabendo de bugs nas nossas 3 máquinas. O bug do bloqueio aconteceu 1028 vezes em um mês sem que ninguém relatasse. |
| Revisão | Desde outubro, 518 commits no big-wm e 205 no packages, todos de uma só pessoa. Os PRs são aprovados pelo próprio autor. Há cerca de 5 mil linhas de C próprias no caminho da senha (bloqueio). | Fator ônibus (bus factor) = 1. Código de segurança sem segunda revisão. |
| Desordem local | 119 worktrees, 51 branches sem upstream, 9 GB de worktrees e 101 pastas em `packages/out`. | Já houve código editado em checkout velho (146 commits atrás do `main`). Uma correção do TTS ficou 17 dias sem publicar. |
| Documentação | 344 arquivos em `big-wm/docs`, a maior parte capturas e diários de missão. Não há guia do usuário. | Quem usa não encontra atalhos, Dock, Clip, zonas e bloqueio num só lugar. |
| Versões | O big-wm é versionado por data e hora (`26.11.24-2333`), sem tags e sem changelog. | O usuário não sabe o que mudou entre uma ISO e outra. |
| Licenças | Doze dos 13 repositórios têm a licença reconhecida pelo GitHub. O `iso-profiles` não tem, porque o projeto de origem (big-comm/iso-profiles) não declara licença. O biglinux/iso-profiles adotou GPL-3.0-or-later em 2026-10-02. | Os arquivos herdados não podem ser redistribuídos com segurança enquanto o BigCommunity não declarar uma licença. |

## Decisões

1. **O repositório pacman `[big-wm]` vive no repo `big-windowmaker/repo` e é hospedado no GitHub Releases** (release fixo `x86_64`). O workflow de publicação reúne os pacotes dos artefatos de CI do `main`, os mesmos que a ISO usa, assina e substitui os arquivos do release. O pacman usa `Server = https://github.com/big-windowmaker/repo/releases/download/$arch`. Os nomes de arquivo já trocam `:` por `_`, porque o GitHub muda `:` nos anexos.
2. **Assinatura com subchave.** A chave primária (Ed25519, só certifica) fica offline com o mantenedor. A CI recebe apenas a subchave de assinatura, com validade de 2 anos. Se a CI vazar, revoga-se a subchave e a identidade continua a mesma. O pacote `big-wm-keyring` instala a chave pública e roda `pacman-key --populate big-wm`, como o `archlinux-keyring`. O banco e os pacotes são assinados (`SigLevel = Required`).
3. **`windowmaker` com `epoch=1`, sem renomear o pacote.** As dependências continuam iguais, o oficial nunca parece mais novo e o `IgnorePkg` sai da ISO. Instalações antigas precisam remover a linha `IgnorePkg = windowmaker` uma vez (o guia explica).
4. **O `[big-wm]` vem antes dos repositórios da distribuição** no `pacman.conf` da edição. Para um nome que existe nos dois, o pacman usa o primeiro repositório.
5. **"Relatar problema"** é o `big-wm-report`, no menu e no Welcome. Ele gera o diagnóstico (versões, sessão, GPU, monitores, erros do journal), mostra o texto para o usuário conferir e abre a issue já preenchida. Nada é enviado sem a ação do usuário.
6. **Coredumps ligados na edição** com `systemd-coredump` (`Storage=external`, limite de tamanho), para o `coredumpctl` ter o que mostrar no relato.
7. **Upstream primeiro.** Correções genéricas vão como PR ao wlmaker (phkaeser) e ao Window Maker. O patch só sai do `packages` quando entra no upstream.
8. **Versões semânticas no big-wm** (`epoch=1`, tags `vX.Y.Z`), com notas de versão em cada ISO geradas a partir dos PRs mergeados.

## Frentes de trabalho

Estado: ✅ feito (no `main` em 2026-11-26) · ⏳ a fazer · 👤 com o mantenedor

### 1. Repositório pacman assinado
- ✅ Chave criada em 2026-11-26: primária `2F36 D64F 633B BA80 052F  4893 4AF5 FC29 61C2 E4AF` (Ed25519, só certifica, até 2031) e subchave de assinatura `2C5B E454 0995 63AB 4C78  3205 173E 2C09 FC18 33B0` (até 2028). Só a subchave está na CI (segredo `REPO_SIGNING_KEY`).
- 👤 A chave primária e o certificado de revogação estão em `~/.local/share/big-wm/chave-repositorio/` na máquina do mantenedor. **Copiar para mídia offline**, pôr senha (`gpg --homedir … --edit-key … passwd`) e apagar a cópia do disco.
- ✅ [big-windowmaker/repo](https://github.com/big-windowmaker/repo): workflow `publicar` (assina pacotes e banco num contêiner sem rede; o release é a fonte da verdade; verificação num Manjaro limpo, que recusa pacote adulterado). Publicado em 2026-11-26: num Manjaro limpo, a CI confia na chave, sincroniza e instala, e recusa um pacote adulterado ("invalid or corrupted package (PGP signature)").
- ✅ packages#59: `big-wm-keyring`; `windowmaker` com `epoch=1`; `wdm` exigindo `windowmaker>=1:…`; patch 0032 (o `check()` do Window Maker quebrava com o automake 1.20).
- ✅ iso-profiles#31 (`[big-wm]` no `pacman.conf`, sem `IgnorePkg`), biglinux-livecd#19 (Calamares popula a chave), build-iso#20 (chaveiro obrigatório na ISO). Entraram depois do primeiro run verde do `publicar`.
- ✅ packages#61: `biglinux-livecd` 20 com essa mudança.
- ⏳ Próxima ISO: a primeira com o `[big-wm]`; conferir no sistema instalado que `pacman -Syu` atualiza pelo repositório.

### 2. Retorno dos usuários
- ✅ Issues ativadas em todos os 13 repositórios (2026-11-26). Os modelos da organização (`bug.yml`, `feature.yml`) valem para todos.
- ✅ big-wm#71: **Sessão > Relatar problema** (`big-wm-doctor --report`), um relatório sem dados pessoais que abre a issue já preenchida.
- ✅ iso-profiles#30: coredumps ligados na edição, com limite (o BigLinux os desliga para os jogos).

### 3. Upstream
- ✅ packages#60: triagem dos 179 patches do wlmaker (`wlmaker/UPSTREAM.md`).
- ✅ Enviados ao phkaeser/wlmaker: #575, #576, #577, #578 e #579, rebaseados e testados sobre o `main` do upstream (`ctest` 26/26).
- ⏳ Mandar o 0032 do Window Maker ao upstream (window-maker/wmaker).
- Meta: metade dos patches fora do `packages` em 3 meses.

### 4. Revisão humana
- 👤 Convidar revisores da comunidade BigLinux.
- Revisão obrigatória pelo menos em bloqueio, PAM, instalador, `pacman.conf`, polkit e chave do repositório.

### 5. Ordem local
- ✅ `tools/limpar-trabalho-local.sh` (este repositório). Executado em 2026-11-26: 228 worktrees e branches já incorporados removidos, de 119 worktrees para 44. Os branches com trabalho fora do `main` foram só listados.
- 👤 Decidir os 46 itens listados (worktrees dos forks com alterações, branches antigos não enviados), a imagem de VM de 5,5 GB em `~/.cache/bwm-wt/readme/vm` e os 42 GB de `~/.cache/bwm-perf`.

### 6. Guia do usuário e versões
- ✅ big-wm#72: `docs/guia-do-usuario.md`.
- ✅ build-iso#19: a seção "O que mudou" das notas de cada ISO passa a ser gerada (pacotes e PRs desde a ISO anterior). O texto fixo de antes estava semanas desatualizado.
- ⏳ Versão semântica no big-wm, num PR próprio: `epoch=1` nos 11 pacotes, `pkgver` a partir da tag `vX.Y.Z` (`git describe`) e a primeira tag `v1.0.0`. Hoje cada build vira uma "versão" nova (`AA.MM.DD-HHMM`), mesmo sem mudança no código.

### 7. Legal
- 👤 Pedir ao BigCommunity (big-comm/iso-profiles) que declare a licença, como o BigLinux fez (GPL-3.0-or-later). Depois disso, o `iso-profiles` ganha o LICENSE.

### 8. Erros abertos
- ✅ big-wm#69: a tela de bloqueio piscava com "INCOMPATIBLE COMPOSITOR" ao acordar os monitores. O `big-wm-x11-repaint` mandava SIGUSR1 ao picom com a tela bloqueada.
- ✅ big-wm#70: `BadWindow` no `saver_big_wm` quando os monitores mudam com a tela bloqueada. Testado: se o módulo de autenticação cair (SIGSEGV, SIGKILL), a tela continua bloqueada.
- ✅ `authproto_pam` "setuid failed": não é erro. O PAM 1.7.3 registra em nível debug e segue. Os erros de nível alto daquele dia vieram de testes de laboratório.

## Depois dos 30 dias
- openQA da ISO: boot → instalação → login → bloqueio (já existe o workflow `mirror-openqa-image` no build-iso).
- Acessibilidade: validar o Orca de ponta a ponta no X11 e no Wayland.
- Dividir o `big-wm/tests/run.sh` (3786 linhas) por componente.
- Arquivar os diários de missão de `big-wm/docs`.
