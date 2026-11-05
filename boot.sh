#!/usr/bin/env bash
# lvl9 — pré-setup Debian/Ubuntu + XFCE + xrdp no estilo Omarchy (https://github.com/julianol1berato/lvl9)
#
#   curl -fsSL https://raw.githubusercontent.com/julianol1berato/lvl9/main/boot.sh | bash
#
# Instala o git, clona o lvl9 em ~/.local/share/lvl9 e abre o instalador.
# Tudo fica dentro de main(), chamada só na última linha: se o download for interrompido
# no meio, o bash não executa um script pela metade.
set -euo pipefail

main() {
  local repo=${LVL9_URL:-https://github.com/julianol1berato/lvl9.git}
  local ref=${LVL9_REF:-main}
  local destino="$HOME/.local/share/lvl9"
  local roxo=$'\e[38;2;187;154;247m' cinza=$'\e[38;2;86;95;137m' verm=$'\e[38;2;247;118;142m' rst=$'\e[0m'

  printf '\n %s▌lvl9%s %spreparando a instalação…%s\n\n' "$roxo" "$rst" "$cinza" "$rst"
  erro() { printf ' %s✘%s %s\n' "$verm" "$rst" "$*" >&2; exit 1; }

  [[ $(uname -s) == Linux ]] || erro "o lvl9 é para Linux (Debian/Ubuntu)"
  (( EUID != 0 )) || erro "rode como o seu usuário, não como root: o lvl9 configura os dois"
  grep -qsE '^(ID|ID_LIKE)=.*(debian|ubuntu)' /etc/os-release || erro "o lvl9 é para Debian e Ubuntu"
  command -v sudo >/dev/null || erro "instale o sudo e coloque seu usuário no grupo sudo"

  # Teclado vem do /dev/tty (a entrada padrão é o próprio script, via curl | bash)
  if ! sudo -n true 2>/dev/null; then
    printf ' %ssenha do sudo (uma vez só):%s\n' "$cinza" "$rst"
    if [[ -t 0 ]]; then sudo -v; else sudo -v </dev/tty; fi
  fi

  if ! command -v git >/dev/null || ! command -v curl >/dev/null; then
    printf ' %sinstalando git e curl…%s\n' "$cinza" "$rst"
    sudo -n apt-get update -qq
    sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git curl ca-certificates >/dev/null
  fi

  if [[ -n ${LVL9_ORIGEM:-} ]]; then
    # Testes: usa uma cópia local do repositório em vez do GitHub
    rm -rf "$destino"; mkdir -p "${destino%/*}"; cp -a "$LVL9_ORIGEM" "$destino"
  elif [[ -d $destino/.git ]]; then
    git -C "$destino" fetch -q --depth 1 origin "$ref"
    git -C "$destino" checkout -q -B "$ref" FETCH_HEAD
  else
    rm -rf "$destino"
    git clone -q --depth 1 --branch "$ref" "$repo" "$destino"
  fi
  printf ' %s✔%s lvl9 em %s\n' "$roxo" "$rst" "$destino"

  if [[ ${LVL9_AUTO:-} == 1 || -t 0 ]]; then exec bash "$destino/install.sh"
  else exec bash "$destino/install.sh" </dev/tty
  fi
}

main "$@"
