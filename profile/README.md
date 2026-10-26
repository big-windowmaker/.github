# Big WindowMaker

Uma edição do [BigLinux](https://www.biglinux.com.br) / [BigCommunity](https://communitybig.org)
com o **Window Maker**: a experiência clássica do NeXTSTEP, com sessões X11 e Wayland,
integração completa com o sistema e instalação pelo Calamares.

| Repositório | Função |
|---|---|
| [big-wm](https://github.com/big-windowmaker/big-wm) | Sessões X11 e Wayland, configuração padrão, temas e integração do desktop |
| [packages](https://github.com/big-windowmaker/packages) | PKGBUILDs: Window Maker, wlmaker, dockapps e dependências |
| [build-iso](https://github.com/big-windowmaker/build-iso) | Perfil da edição e geração/teste das ISOs |
| [wmaker](https://github.com/big-windowmaker/wmaker) | Fork do [Window Maker](https://www.windowmaker.org/) (X11) para correções enviadas ao upstream |
| [wlmaker](https://github.com/big-windowmaker/wlmaker) | Fork do [wlmaker](https://github.com/phkaeser/wlmaker) (Wayland) para correções enviadas ao upstream |
| [.github](https://github.com/big-windowmaker/.github) | Documentação, decisões de arquitetura e padrões da organização |

**Sessões:** *Big WindowMaker — X11* é a sessão padrão e estável. *Big WindowMaker — Wayland
(experimental)* usa o compositor nativo wlmaker e ainda está em desenvolvimento.

Decisões de arquitetura: [ADR-0001](https://github.com/big-windowmaker/.github/blob/main/docs/adr/0001-arquitetura.md).
