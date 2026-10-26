# Como contribuir

1. Abra uma issue descrevendo o problema ou a proposta antes de mudanças grandes.
2. Trabalhe num branch próprio e abra um pull request para `main`.
3. Um PR faz **uma** coisa. Commits pequenos, com mensagem no imperativo, em português.
4. O CI precisa passar. Em `big-wm`, rode `make check` antes de enviar.
5. Correções no Window Maker ou no wlmaker devem ser enviadas também ao upstream:
   - Window Maker: patches pela lista `wmaker-dev@googlegroups.com` (o GitHub do upstream é só espelho);
   - wlmaker: pull request em [phkaeser/wlmaker](https://github.com/phkaeser/wlmaker).

## Regras do projeto

- Pacotes **nunca** escrevem em `/etc/skel`, em `/home`, no GRUB ou no initramfs, não reiniciam
  a máquina e não chamam `pacman` em scripts de instalação.
- Nada instalado pelo Big WindowMaker pode afetar outros ambientes (Plasma, XFCE, GNOME):
  autostart sempre com `OnlyShowIn=WindowMaker;` e/ou `wlmaker;`.
- Fontes de PKGBUILD fixadas em tag ou commit. Actions do GitHub fixadas por SHA.
- Segredos só em jobs de publicação, nunca em jobs que compilam código.
- Arte e temas só entram com autoria e licença declaradas.
