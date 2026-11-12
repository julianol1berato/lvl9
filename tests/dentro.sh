#!/usr/bin/env bash
# Roda dentro do container (como root): cria um usuário com sudo, instala o lvl9 como ele
# pelo boot.sh, respondendo "sim" a tudo, e depois roda as verificações. O LVL9_MODO
# (desktop|servidor) escolhe o modo; sem ele vale a detecção (container = servidor).
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq sudo ca-certificates curl git bsdutils >/dev/null
# LVL9_SIMULA=gnome: a máquina passa a ter uma sessão do GNOME (e nada de XFCE), para conferir
# que o lvl9 instala as fontes e não coloca o XFCE ao lado sem ninguém pedir
if [[ ${LVL9_SIMULA:-} == gnome ]]; then
  mkdir -p /usr/share/wayland-sessions && : > /usr/share/wayland-sessions/gnome.desktop
fi
useradd -m -s /bin/bash teste
echo 'teste ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/teste
# sem LVL9_AUTO: o container não tem terminal, e o instalador precisa perceber isso sozinho e
# seguir sem perguntas (é o caminho de quem instala pelo Claude Code ou por automação)
su - teste -c "LVL9_MODO=${LVL9_MODO:-} LVL9_AUTO_RESPOSTA=sim LVL9_ORIGEM=/lvl9 bash /lvl9/boot.sh"
instalou=$?
echo "== install.sh terminou com $instalou =="
su - teste -c 'cat ~/.local/state/lvl9/install.log' | tail -n 60
su - teste -c 'bash /lvl9/tests/verifica.sh'
verificou=$?
exit $(( instalou != 0 || verificou != 0 ))
