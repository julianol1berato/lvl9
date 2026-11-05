# Node.js LTS via mise, no usuário e no root (o coc.nvim do vim precisa dele)
executa() {
  local alvo
  # o binário oficial do Node 26 (LTS desde out/2026) liga dinamicamente na libatomic
  apt_instala libatomic1
  for alvo in usuario root; do
    como_alvo "$alvo" env MISE_YES=1 /usr/local/bin/mise use -g node@lts
    info "$alvo: node $(como_alvo "$alvo" /usr/local/bin/mise exec -- node --version)"
  done
}
