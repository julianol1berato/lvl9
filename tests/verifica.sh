#!/usr/bin/env bash
# Verificações depois da instalação (roda como o usuário de teste, dentro do container)
set -uo pipefail
# shellcheck source=../lib/comum.sh
source ~/.local/share/lvl9/lib/comum.sh
ok=0 erro=0
modo=$(lvl9_modo)
confere() {   # confere "descrição" comando...
  local d=$1; shift
  if "$@" &>/tmp/verifica.out; then echo "  ✔ $d"; (( ok++ ))
  else echo "  ✘ $d"; sed 's/^/      /' /tmp/verifica.out | tail -5; (( erro++ )); fi
}
sem_erros() { ! grep -qiE 'erro|error|not found|não encontrad|command not found|syntax|line [0-9]+:' "$1"; }
shell_interativo() {   # abre bash -i num pty (como um terminal de verdade) e captura a saída
  script -qc "bash -i -c 'alias disco >/dev/null && type prompt-tema >/dev/null && echo SHELL_OK'" /dev/null
}

echo "== binários do lock =="
while read -r nome grupo tipo _ _ _ instala; do
  [[ -z $nome || $nome == \#* || $tipo != bin ]] && continue
  confere "$nome" bin_atualizado "$nome"
  for b in ${instala//,/ }; do confere "  /usr/local/bin/${b#*:}" test -x "/usr/local/bin/${b#*:}"; done
done < ~/.local/share/lvl9/ferramentas.tsv

echo "== sistema =="
confere "fuso America/Sao_Paulo" bash -c '[[ $(readlink -f /etc/localtime) == */America/Sao_Paulo ]]'
confere "locale pt_BR.UTF-8" bash -c 'locale -a | grep -qiE "^pt_BR\.utf-?8$"'
[[ $modo == desktop ]] && confere "Nerd Fonts" bash -c 'fc-list | grep -q "JetBrainsMono Nerd Font" && fc-list | grep -q "CaskaydiaMono Nerd Font"'

echo "== shell =="
confere "bashrc do usuário carrega o lvl9" grep -q 'lvl9/bash/rc' ~/.bashrc
confere "bashrc do root carrega o lvl9" sudo grep -q 'lvl9/bash/rc' /root/.bashrc
shell_interativo > /tmp/shell-usuario.txt 2>&1
confere "shell interativo do usuário sem erros" bash -c 'grep -q SHELL_OK /tmp/shell-usuario.txt && ! grep -qiE "erro|command not found|syntax|: line [0-9]" /tmp/shell-usuario.txt'
script -qc "sudo -i bash -i -c 'type prompt-tema >/dev/null && echo SHELL_OK'" /dev/null > /tmp/shell-root.txt 2>&1
confere "shell interativo do root sem erros" bash -c 'grep -q SHELL_OK /tmp/shell-root.txt && ! grep -qiE "erro|command not found|syntax|: line [0-9]" /tmp/shell-root.txt'
for t in /usr/local/share/lvl9/starship/*.toml; do
  confere "tema $(basename "$t" .toml) renderiza" bash -c "STARSHIP_CONFIG=$t starship prompt >/dev/null"
done
confere "fastfetch com a config do lvl9" fastfetch -c /usr/local/share/lvl9/fastfetch.jsonc --pipe

echo "== vim, node, tmux =="
confere "node LTS via mise (usuário)" mise exec -- node --version
confere "node LTS via mise (root)" sudo -H /usr/local/bin/mise exec -- node --version
confere "vim: halcyon + :FZF + 10 plugins" bash -c 'vim -E -s -u ~/.vimrc -c "if !exists(\":FZF\") | cquit | endif" -c "if g:colors_name !=# \"halcyon\" | cquit | endif" -c "qa!" </dev/null && [[ $(ls ~/.vim/plugged | wc -l) -ge 10 ]]'
confere "vim do root: plugins" sudo bash -c '[[ $(ls /root/.vim/plugged | wc -l) -ge 10 ]]'
confere "sudo vim: coc.nvim acha o node" sudo vim -E -s -u /root/.vimrc -c 'if !executable(get(g:, "coc_node_path", "node")) | cquit | endif' -c 'qa!' </dev/null
confere "tmux.conf válido" tmux -f ~/.tmux.conf start-server \; kill-server

if [[ $modo == desktop ]]; then
  echo "== desktop =="
  confere "xrdp + xorgxrdp" dpkg -s xrdp xorgxrdp
  confere "flameshot" dpkg -s flameshot
  confere "XFCE" command -v xfce4-session
  confere "esquema Tokyo Night do terminal" test -f /usr/share/xfce4/terminal/colorschemes/lvl9-tokyo-night.theme
  confere "ajuste do XFCE agendado para o login" test -f ~/.config/autostart/lvl9-desktop.desktop
  confere "regra polkit do colord" sudo test -f /etc/polkit-1/rules.d/45-lvl9-colord.rules
  confere "ajuste do firmware-notifier só onde o snap existe" bash -c 'u=/etc/systemd/user/snap.firmware-updater.firmware-notifier.service
    if [[ -e $u ]]; then test -f "$u.d/10-lvl9-notificacoes.conf"; else ! test -e "$u.d"; fi'
else
  echo "== servidor: nada gráfico =="
  confere "modo servidor salvo nas escolhas" grep -qx 'LVL9_MODO=servidor' ~/.config/lvl9/escolhas
  confere "continua sem interface gráfica" bash -c 'source ~/.local/share/lvl9/lib/comum.sh; ! tem_interface_grafica'
  confere "nenhum pacote gráfico" bash -c 'for p in xserver-xorg-core xorg xfce4 xfce4-session xrdp xorgxrdp flameshot xclip fontconfig libgtk-3-0 libgtk-3-0t64 dbus-x11; do
    dpkg-query -W -f="\${Status}" "$p" 2>/dev/null | grep -q "ok installed" && { echo "instalado: $p"; exit 1; }; done; exit 0'
  confere "sem Nerd Fonts nem ajuste do XFCE" bash -c '! test -e /usr/local/share/fonts/lvl9 && ! test -e ~/.config/autostart/lvl9-desktop.desktop'
  confere "tmux sem xclip carrega limpo" bash -c 'tmux -f ~/.tmux.conf new-session -d -s t && tmux show -s copy-command | grep -qv xclip; r=$?; tmux kill-server; exit $r'
fi
echo "== serviços =="
confere "docker" command -v docker
confere "usuário no grupo docker" bash -c 'getent group docker | grep -qw teste'
confere "tailscale" command -v tailscale

echo "== Claude Code =="
confere "claude (usuário)" ~/.local/bin/claude --version
confere "claude (root)" sudo test -x /root/.local/bin/claude
confere "statusbar no settings.json (usuário)" jq -e '.statusLine.command | test("statusline")' ~/.claude/settings.json
confere "statusbar no settings.json (root)" sudo jq -e '.statusLine.command | test("statusline")' /root/.claude/settings.json
confere "herdr (usuário e root)" bash -c 'test -x ~/.local/bin/herdr && sudo test -x /root/.local/bin/herdr'

echo "== saúde do host =="
confere "lib/saude.sh instalada para todos" test -r /usr/local/share/lvl9/lib/saude.sh
confere "avisos ligados por padrão" grep -qx 'avisos=on' ~/.config/lvl9/config
confere "resumo roda sem erro (usuário)" bash -c 'source /usr/local/share/lvl9/lib/saude.sh && saude_resumo >/dev/null'
confere "resumo roda sem erro (root)" sudo bash -c 'source /usr/local/share/lvl9/lib/saude.sh && saude_resumo >/dev/null'

echo "== comando lvl9 =="
confere "lvl9 versao" lvl9 versao
confere "lvl9 diff" lvl9 diff
# sem systemd no container a seção de serviços é pulada; o resto precisa estar 100%
confere "lvl9 doctor sem problemas" lvl9 doctor

echo "== cada comando num terminal interativo =="
bash ~/.local/share/lvl9/tests/comandos.sh || (( erro++ ))

echo "RESULTADO: $ok ok, $erro erro(s)"
exit $(( erro > 0 ))
