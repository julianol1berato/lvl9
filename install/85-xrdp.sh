# xrdp com sessão XFCE, som pelo RDP e sem o pedido de senha do colord
executa() {
  apt_instala xrdp xorgxrdp dbus-x11
  apt_instala_existentes pipewire-module-xrdp
  # o xrdp lê o certificado do ssl-cert
  if id xrdp &>/dev/null; then grupo_poe xrdp ssl-cert; else aviso "usuário xrdp não encontrado"; fi

  # Sessão: XFCE num D-Bus próprio, para não brigar com a sessão do console
  copia config/xrdp/startwm.sh "$HOME/startwm.sh" 755
  # Sem isso, toda sessão xrdp pede senha para "create a color managed device"
  copia config/xrdp/45-lvl9-colord.rules /etc/polkit-1/rules.d/45-lvl9-colord.rules

  if tem_systemd; then
    servico_ativa xrdp
    info "xrdp na porta 3389"
  else
    info "sem systemd: xrdp instalado, mas não iniciado"
  fi
}
