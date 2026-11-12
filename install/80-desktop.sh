# XFCE: terminal com Nerd Font e Tokyo Night, flameshot no PrintScreen e em Super+Shift+S
executa() {
  # shellcheck source=../lib/desktop.sh
  source "$LVL9_REPO/lib/desktop.sh"
  # Só chega aqui sem XFCE quem pediu: "sim" na tela de escolhas ou LVL9_MODO=desktop
  if ! tem xfce4-session; then
    info "XFCE não encontrado; instalando (a pedido)"
    apt_instala xfce4 xfce4-terminal dbus-x11
  fi
  apt_instala xfce4-terminal flameshot

  # Esquema de cores também como preset em Preferências → Cores do xfce4-terminal
  copia config/xfce/lvl9-tokyo-night.theme /usr/share/xfce4/terminal/colorschemes/lvl9-tokyo-night.theme

  # Só onde o snap firmware-updater já existe (Ubuntu desktop): o lvl9 não instala o snap,
  # só evita que o notificador dele fique marcado como falha antes do login gráfico
  local notificador=/etc/systemd/user/snap.firmware-updater.firmware-notifier.service
  if [[ -e $notificador ]]; then
    copia config/systemd/10-lvl9-notificacoes.conf "$notificador.d/10-lvl9-notificacoes.conf"
    systemctl --user daemon-reload 2>/dev/null || true
    info "firmware-notifier: não falha mais sem serviço de notificações"
  fi

  if desktop_aplica; then
    rm -f "$HOME/.config/autostart/lvl9-desktop.desktop"
    info "aplicado na sessão XFCE atual"
  else
    # Instalação fora da sessão gráfica (SSH, TTY): aplica sozinho no próximo login
    copia config/xfce/lvl9-desktop.desktop "$HOME/.config/autostart/lvl9-desktop.desktop"
    info "sem sessão XFCE aberta: os ajustes serão aplicados no próximo login"
  fi
}
