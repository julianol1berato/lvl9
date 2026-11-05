# tmux com tema Tokyo Night e prefixo Ctrl+a, no usuário e no root
executa() {
  local alvo
  apt_instala tmux
  # xclip: o que o tmux copia vai também para a área de transferência do X (só no desktop)
  if modo_desktop; then apt_instala xclip; fi
  for alvo in usuario root; do
    copia config/tmux.conf "$(home_de "$alvo")/.tmux.conf"
  done
  info "tmux.conf instalado (prefixo Ctrl+a)"
}
