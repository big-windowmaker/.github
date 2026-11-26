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
| Licenças | `tabbed-dock` e `iso-profiles` não têm LICENSE. O GitHub não reconhece a licença de nenhum repositório. | Falta clareza legal para redistribuir. |

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

Estado: ✅ feito · 🔄 em andamento · ⏳ a fazer · 👤 com o mantenedor

### 1. Repositório pacman assinado
- ⏳ Gerar a chave (primária offline + subchave na CI) e gravar a subchave como segredo do `repo`.
- ⏳ Pacote `big-wm-keyring` no `packages`.
- ⏳ Repo `big-windowmaker/repo`: workflow de publicação (assina o banco e os pacotes, com `repo-add` sem rede) e README com a instalação.
- ⏳ `windowmaker`: `epoch=1`.
- ⏳ `iso-profiles`: `[big-wm]` no `pacman.conf` da edição, sem o `IgnorePkg`; `big-wm-keyring` na lista de pacotes.
- ⏳ Teste: um sistema limpo faz `pacman -Sy` e `pacman -S big-wm-session` com a assinatura conferida, e uma assinatura adulterada é recusada.

### 2. Retorno dos usuários
- ⏳ Issues ativadas em todos os repositórios.
- ⏳ `big-wm-report` (menu + Welcome) e modelo de issue que pede o relatório.
- ⏳ Coredump ligado na edição.

### 3. Upstream
- ⏳ Triagem dos patches do wlmaker em três grupos: genéricos, funcionalidades aceitáveis no upstream e específicos do Big WM (`packages/wlmaker/UPSTREAM.md`).
- ⏳ Primeiros PRs ao phkaeser/wlmaker: as correções pequenas e genéricas.
- Meta: metade dos patches fora do `packages` em 3 meses.

### 4. Revisão humana
- 👤 Convidar revisores da comunidade BigLinux.
- Revisão obrigatória pelo menos em bloqueio, PAM, instalador, `pacman.conf`, polkit e chave do repositório.

### 5. Ordem local
- ⏳ `limpar-worktrees`: remove worktrees de branches já mergeados (só com a árvore limpa), lista os branches sem upstream e deixa cada checkout principal no `main`. Por padrão só mostra o que faria (simulação).

### 6. Guia do usuário e versões
- ⏳ `big-wm/docs/guia-do-usuario.md`: atalhos, Dock, Clip, zonas, bloqueio, atualizações, relatar problema, FAQ.
- ⏳ Versão semântica no big-wm e notas de versão por ISO.

### 7. Legal
- ⏳ LICENSE no `tabbed-dock` e no `iso-profiles`, com a licença que os arquivos já declaram.

### 8. Erros abertos
- ✅ (branch) A tela de bloqueio piscava com "INCOMPATIBLE COMPOSITOR" ao acordar os monitores (`big-wm-x11-repaint`).
- ⏳ `authproto_pam`: "pam_unix(system-auth:account): setuid failed".
- ⏳ `BadWindow` em `X_GetWindowAttributes` nos módulos do bloqueio quando os monitores mudam com a tela bloqueada.
- ⏳ Teste: se o módulo de autenticação cair, a tela continua bloqueada.

## Depois dos 30 dias
- openQA da ISO: boot → instalação → login → bloqueio (já existe o workflow `mirror-openqa-image` no build-iso).
- Acessibilidade: validar o Orca de ponta a ponta no X11 e no Wayland.
- Dividir o `big-wm/tests/run.sh` (3786 linhas) por componente.
- Arquivar os diários de missão de `big-wm/docs`.
