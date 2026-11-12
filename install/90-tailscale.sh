# Tailscale pelo instalador oficial (adiciona o repositório apt assinado da Tailscale)
executa() {
  if tem tailscale; then
    info "tailscale já instalado: $(tailscale version | head -1)"
  else
    curl -fsSL https://tailscale.com/install.sh | como_root sh
    mudou "tailscale instalado"
  fi
  if tem_systemd; then servico_ativa tailscaled; fi
  info "para conectar: sudo tailscale up"
}
