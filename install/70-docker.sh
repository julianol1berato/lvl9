# Docker Engine pelo repositório oficial da Docker (chave conferida pela fingerprint)
DOCKER_FPR=9DC858229FC7DD38854AE2D88D81803C0EBFCD88

executa() {
  lvl9_os
  if tem docker; then
    info "docker já instalado: $(docker --version)"
  elif curl -fsI "https://download.docker.com/linux/$OS_ID/dists/$OS_CODINOME/Release" >/dev/null; then
    local tmp fpr
    tmp=$(mktemp -d)
    curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" -o "$tmp/docker.asc"
    fpr=$(gpg --show-keys --with-colons "$tmp/docker.asc" 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')
    [[ $fpr == "$DOCKER_FPR" ]] || { rm -rf "$tmp"; falha "chave da Docker com fingerprint inesperada: $fpr"; return 1; }
    como_root install -D -m 644 "$tmp/docker.asc" /etc/apt/keyrings/docker.asc
    rm -rf "$tmp"
    printf 'Types: deb\nURIs: https://download.docker.com/linux/%s\nSuites: %s\nComponents: stable\nSigned-By: /etc/apt/keyrings/docker.asc\n' \
      "$OS_ID" "$OS_CODINOME" | como_root tee /etc/apt/sources.list.d/docker.sources >/dev/null
    como_root apt-get update -q -o DPkg::Lock::Timeout=300   # repositório novo: aqui tem de dar certo
    echo "$LVL9_CARIMBO" > "$LVL9_ESTADO/apt-indices"
    apt_instala docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    # Versão nova demais para o repositório da Docker: usa o pacote da própria distro
    aviso "a Docker ainda não publica pacotes para $OS_NOME; usando o docker.io da distro"
    apt_instala docker.io
    apt_instala_existentes docker-compose-v2 docker-buildx
  fi

  # Grupo docker: dispensa o sudo (equivale a acesso root; vale a partir do próximo login)
  grupo_poe "$USER" docker
  if tem_systemd; then servico_ativa docker; fi
}
