# Ambiente das screenshots do README: a imagem oficial do vhs (Debian 13, com Chromium,
# ffmpeg e ttyd) com o lvl9 instalado de verdade pelo boot.sh, como numa máquina nova.
# Uso: tools/screenshots.sh
FROM ghcr.io/charmbracelet/vhs:latest

RUN apt-get update -qq \
 && apt-get install -y -qq sudo ca-certificates curl git bsdutils locales >/dev/null \
 && sed -i 's/^# *\(pt_BR.UTF-8 UTF-8\)/\1/' /etc/locale.gen && locale-gen >/dev/null \
 && useradd -m -s /bin/bash -u 1000 lvl9 \
 && echo 'lvl9 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/lvl9

COPY --chown=lvl9:lvl9 . /lvl9-src
USER lvl9
# O container não tem interface gráfica (seria modo servidor): as telas mostram o desktop
ENV LANG=pt_BR.UTF-8 TERM=xterm-256color LVL9_MODO=desktop
# Padrões da tela: todos os grupos, tokyo-night, sem Tailscale, com Claude Code
RUN LVL9_AUTO=1 LVL9_ORIGEM=/lvl9-src bash /lvl9-src/boot.sh

# Um projeto com git para as cenas do prompt
RUN mkdir -p ~/projetos/api && cd ~/projetos/api \
 && git init -q -b main && printf '# api\n' > README.md \
 && printf 'services:\n  api:\n    image: nginx:alpine\n    ports: ["8080:80"]\n' > compose.yaml \
 && git add . && git -c user.name=lvl9 -c user.email=lvl9@9level.com.br commit -qm "primeiro commit" \
 && printf 'node_modules/\n' > .gitignore && echo '    restart: unless-stopped' >> compose.yaml

WORKDIR /vhs
