# Node.js LTS via mise, no usuário e no root (o coc.nvim do vim precisa dele)
executa() {
  local alvo
  # o binário oficial do Node 26 (LTS desde out/2026) liga dinamicamente na libatomic
  apt_instala libatomic1
  local antes depois
  for alvo in usuario root; do
    antes=$(como_alvo "$alvo" /usr/local/bin/mise exec -- node --version 2>/dev/null || true)
    como_alvo "$alvo" env MISE_YES=1 /usr/local/bin/mise use -g node@lts
    depois=$(como_alvo "$alvo" /usr/local/bin/mise exec -- node --version)
    info "$alvo: node $depois"
    [[ $antes == "$depois" ]] || mudou "$alvo: node ${antes:-(nenhum)} → $depois"
  done
}
