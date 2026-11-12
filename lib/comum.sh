# lib/comum.sh — funções compartilhadas pelo install.sh, pelos passos (install/*.sh) e pelo lvl9.
# Não executa nada ao ser carregado: só define variáveis e funções.

LVL9_REPO=${LVL9_REPO:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
# $USER nem sempre existe (Docker, cron, alguns su); o nome vem do próprio processo
USER=${USER:-$(id -un)}
export USER
LVL9_SISTEMA=/usr/local/share/lvl9            # cópia do lvl9 usada por todos os usuários (do root)
LVL9_CONFIG="$HOME/.config/lvl9"              # escolhas e preferências deste usuário
LVL9_ESTADO="$HOME/.local/state/lvl9"         # logs, backups e lista de arquivos instalados
LVL9_CARIMBO=${LVL9_CARIMBO:-$(date +%Y%m%d-%H%M%S)}
LVL9_LOG=${LVL9_LOG:-$LVL9_ESTADO/install-$LVL9_CARIMBO.log}
LVL9_LOCK="$LVL9_REPO/versions.lock"
LVL9_MUDANCAS="$LVL9_ESTADO/mudancas"         # o que esta rodada mudou de verdade na máquina
export LVL9_REPO LVL9_CARIMBO LVL9_LOG

# ─── Sistema ────────────────────────────────────────────────────────
# Preenche OS_ID (debian|ubuntu), OS_VERSAO (13, 24.04...), OS_CODINOME e OS_NOME
lvl9_os() {
  local ID='' ID_LIKE='' VERSION_ID='' VERSION_CODENAME='' PRETTY_NAME=''
  # shellcheck disable=SC1091
  [[ -r /etc/os-release ]] && . /etc/os-release
  OS_ID=$ID OS_VERSAO=$VERSION_ID OS_CODINOME=$VERSION_CODENAME OS_NOME=${PRETTY_NAME:-$ID}
  [[ $OS_ID != debian && $OS_ID != ubuntu && $ID_LIKE == *ubuntu* ]] && OS_ID=ubuntu
  [[ $OS_ID != debian && $OS_ID != ubuntu && $ID_LIKE == *debian* ]] && OS_ID=debian
  return 0   # os testes acima não podem virar o código de saída (os passos rodam com set -e)
}

# Debian 12/13 e Ubuntu 24.04/26.04; outras versões instalam, mas com aviso
lvl9_os_suportado() {
  case "$OS_ID:$OS_VERSAO" in
    debian:12|debian:13|ubuntu:24.04|ubuntu:26.04) return 0 ;;
    *) return 1 ;;
  esac
}

lvl9_arch() {
  case $(uname -m) in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) echo "nao-suportada" ;;
  esac
}

tem_systemd() { [[ -d /run/systemd/system ]]; }
tem() { command -v "$1" &>/dev/null; }

# Interface gráfica já instalada: sessão X/Wayland de algum desktop ou window manager, display
# manager ou o XFCE. Não olha o $DISPLAY: num servidor o ssh -X também o define.
tem_interface_grafica() {
  local r=${LVL9_RAIZ:-}   # só os testes trocam a raiz
  compgen -G "$r/usr/share/xsessions/*.desktop" >/dev/null \
    || compgen -G "$r/usr/share/wayland-sessions/*.desktop" >/dev/null \
    || [[ -e $r/etc/X11/default-display-manager || -x $r/usr/bin/xfce4-session ]]
}

# XFCE instalado? A parte gráfica do lvl9 é feita e testada só no XFCE.
tem_xfce() {
  local r=${LVL9_RAIZ:-}   # só os testes trocam a raiz
  [[ -x $r/usr/bin/xfce4-session ]] || compgen -G "$r/usr/share/xsessions/xfce*.desktop" >/dev/null
}

# Outra interface gráfica (GNOME, KDE...) e nada de XFCE: o lvl9 fica só no terminal, a não
# ser que a pessoa aceite o XFCE ao lado (tela de escolhas) ou peça com LVL9_MODO=desktop.
outra_interface() { tem_interface_grafica && ! tem_xfce; }

# Modo da instalação: desktop (XFCE, flameshot e, se escolhido, xrdp) ou servidor (nada disso).
# Vale o LVL9_MODO do ambiente; senão o da última instalação; senão o que a máquina já tem:
# desktop só onde o XFCE já está instalado. O lvl9 nunca coloca interface gráfica numa máquina
# que não tinha uma, nem o XFCE ao lado de outra interface sem a pessoa pedir.
lvl9_modo() {
  local salvo
  if [[ -n ${LVL9_MODO:-} ]]; then echo "$LVL9_MODO"; return; fi
  salvo=$(sed -n 's/^LVL9_MODO=//p' "$LVL9_CONFIG/escolhas" 2>/dev/null)
  if [[ -n $salvo ]]; then echo "$salvo"
  elif tem_xfce; then echo desktop
  else echo servidor; fi
}
# xrdp é uma escolha de quem instala: ele abre a área de trabalho na rede (porta 3389), então o
# lvl9 não o liga por conta própria. Vale o LVL9_XRDP (do ambiente ou das escolhas salvas); as
# escolhas de versões anteriores não têm essa resposta, e aí vale o que a máquina já faz hoje:
# sim se o serviço está habilitado, não se não está (ou se foi desabilitado).
lvl9_xrdp() {
  if [[ ${LVL9_XRDP:-} == sim || ${LVL9_XRDP:-} == nao ]]; then echo "$LVL9_XRDP"
  elif systemctl is-enabled -q xrdp 2>/dev/null; then echo sim
  else echo nao; fi
}

# Nerd Fonts: no modo desktop e em toda máquina que já tem interface gráfica
quer_fontes() { [[ $(lvl9_modo) == desktop ]] || tem_interface_grafica; }

# O modo veio do ambiente ou da última instalação (e não da detecção)?
lvl9_modo_escolhido() {
  [[ -n ${LVL9_MODO:-} ]] || grep -qs '^LVL9_MODO=' "$LVL9_CONFIG/escolhas"
}
modo_desktop() { [[ $(lvl9_modo) == desktop ]]; }

# Passos da instalação para as escolhas atuais (LVL9_MODO, LVL9_GRUPOS, LVL9_TAILSCALE,
# LVL9_CLAUDE), um "título|arquivo em install/" por linha, na ordem em que rodam.
# XFCE só no modo desktop, e o xrdp só se foi escolhido (LVL9_XRDP=sim). As Nerd Fonts vão para qualquer máquina com interface gráfica
# (também GNOME, KDE...): sem elas o prompt não aparece direito, e fonte não muda o desktop de
# ninguém. Num servidor nada disso: quem desenha é o terminal do cliente.
lvl9_passos() {
  local desktop=0; [[ ${LVL9_MODO:-} == desktop ]] && desktop=1
  echo "Sistema, fuso e locale|00-sistema.sh"
  echo "Ferramentas (versões fixadas)|10-ferramentas.sh"
  quer_fontes && echo "Nerd Fonts|20-fontes.sh"
  echo "Bash, prompt e comando lvl9|30-shell.sh"
  echo "mise + Node LTS|40-mise.sh"
  echo "Vim halcyon|50-vim.sh"
  echo "tmux|55-tmux.sh"
  grupo_ativo dev && echo "Git com delta|60-git.sh"
  grupo_ativo sysadmin && echo "Docker Engine|70-docker.sh"
  (( desktop )) && echo "XFCE, terminal e flameshot|80-desktop.sh"
  (( desktop )) && [[ ${LVL9_XRDP:-nao} == sim ]] && echo "xrdp|85-xrdp.sh"
  [[ ${LVL9_TAILSCALE:-nao} == sim ]] && echo "Tailscale|90-tailscale.sh"
  [[ ${LVL9_CLAUDE:-nao} == sim ]] && echo "Claude Code + statusbar + herdr|95-claude.sh"
  return 0
}

# ─── Mensagens (os passos escrevem no log; o install.sh cuida da tela) ──
info()  { printf '  · %s\n' "$*"; }
aviso() { printf '  ! %s\n' "$*"; }
falha() { printf '  ✘ %s\n' "$*" >&2; return 1; }

# ─── root ───────────────────────────────────────────────────────────
# O instalador roda como o usuário; o que é do sistema vai por sudo -n (a senha é pedida
# uma vez no início e mantida viva pelo install.sh).
como_root() { sudo -n "$@"; }

# mudou "o que mudou" → registra uma mudança de verdade na máquina. O instalador conta por passo
# e lista no resumo: rodar de novo sem nada novo tem de terminar com zero mudanças.
mudou() { mkdir -p "$LVL9_ESTADO"; printf '%s\n' "$*" >> "$LVL9_MUDANCAS"; }

# apt_falta pacote... → os que ainda não estão instalados, um por linha
apt_falta() {
  local p
  for p in "$@"; do
    [[ $(dpkg-query -W -f='${db:Status-Status}' "$p" 2>/dev/null) == installed ]] || echo "$p"
  done
}

# Índices do apt: uma vez por rodada, e só quando há pacote para instalar. Um repositório fora
# do ar ou um download corrompido vira aviso: os índices antigos costumam bastar, e se não
# bastarem é a instalação do pacote que falha, com o erro certo.
apt_indices() {
  [[ $(cat "$LVL9_ESTADO/apt-indices" 2>/dev/null) == "$LVL9_CARIMBO" ]] && return 0
  mkdir -p "$LVL9_ESTADO"; echo "$LVL9_CARIMBO" > "$LVL9_ESTADO/apt-indices"
  como_root apt-get update -q -o DPkg::Lock::Timeout=300 \
    || aviso "apt-get update falhou em algum repositório; seguindo com os índices que já existem"
}

# Instala o que falta. Com tudo já instalado não chama o apt: não usa a rede, não atualiza
# pacote de ninguém e não parece uma reinstalação.
apt_instala() {
  local faltam
  mapfile -t faltam < <(apt_falta "$@")
  (( ${#faltam[@]} )) || return 0
  apt_indices
  como_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    -o DPkg::Lock::Timeout=300 -o Dpkg::Options::=--force-confold "${faltam[@]}"
  mudou "pacotes instalados: ${faltam[*]}"
}

# Instala só os pacotes que existem nesta distro/versão (os nomes mudam entre Debian e Ubuntu)
apt_instala_existentes() {
  local p ok=() faltam
  mapfile -t faltam < <(apt_falta "$@")
  (( ${#faltam[@]} )) || return 0
  apt_indices
  for p in "${faltam[@]}"; do
    apt-cache show "$p" &>/dev/null && ok+=("$p") || aviso "pacote $p não existe em $OS_NOME; pulando"
  done
  if (( ${#ok[@]} )); then apt_instala "${ok[@]}"; fi
}

# servico_ativa unidade → habilita e inicia, se ainda não estiver assim
servico_ativa() {
  if systemctl is-enabled -q "$1" 2>/dev/null && systemctl is-active -q "$1"; then
    info "$1 já está ativo"; return 0
  fi
  como_root systemctl enable --now "$1"
  mudou "serviço ativado: $1"
}

# grupo_poe usuário grupo → coloca no grupo, se ainda não estiver
grupo_poe() {
  if id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; then info "$1 já está no grupo $2"; return 0; fi
  como_root usermod -aG "$2" "$1"
  mudou "$1 entrou no grupo $2"
}

# ─── versions.lock ──────────────────────────────────────────────────
# lock_le nome → LOCK_VERSAO, LOCK_URL, LOCK_SHA (procura a arquitetura atual, depois "all")
lock_le() {
  local nome=$1 arch n a v u s
  arch=$(lvl9_arch)
  LOCK_VERSAO='' LOCK_URL='' LOCK_SHA=''
  while read -r n a v u s; do
    [[ $n == "$nome" && ( $a == "$arch" || $a == all ) ]] || continue
    LOCK_VERSAO=$v LOCK_URL=$u LOCK_SHA=$s
    return 0
  done < <(grep -v '^#' "$LVL9_LOCK")
  falha "$nome ($arch) não está no versions.lock"
}

# baixa_verificado nome destino → baixa a URL do lock e aborta se o sha256 não bater
baixa_verificado() {
  local nome=$1 destino=$2 sha
  lock_le "$nome" || return 1
  curl -fsSL --retry 3 --connect-timeout 15 -o "$destino" "$LOCK_URL" || falha "download de $nome falhou: $LOCK_URL" || return 1
  sha=$(sha256sum "$destino" | cut -d' ' -f1)
  if [[ $sha != "$LOCK_SHA" ]]; then
    rm -f "$destino"
    falha "sha256 de $nome não confere (esperado $LOCK_SHA, veio $sha) — download recusado"
    return 1
  fi
}

# Extrai um asset (tar.gz, tar.xz, tbz, zip ou binário solto) para uma pasta
extrai() {
  local arq=$1 dir=$2
  mkdir -p "$dir"
  case $3 in
    *.tar.gz|*.tgz) tar -xzf "$arq" -C "$dir" ;;
    *.tar.xz)       tar -xJf "$arq" -C "$dir" ;;
    *.tbz|*.tar.bz2) tar -xjf "$arq" -C "$dir" ;;
    *.zip)          unzip -q -o "$arq" -d "$dir" ;;
    *)              cp "$arq" "$dir/@" ;;   # binário solto
  esac
}

# Executável de verdade? Os pacotes trazem outros arquivos com o mesmo nome (o do fastfetch
# tem o script de autocomplete "fastfetch"), e a ordem do find muda entre sistemas de arquivos.
e_elf() { [[ $(head -c4 "$1" 2>/dev/null | od -An -c | tr -d ' ') == '177ELF' ]]; }

# instala_bin nome → instala em /usr/local/bin os binários listados no ferramentas.tsv
instala_bin() {
  local nome=$1 spec item origem destino tmp achado
  spec=$(awk -v n="$nome" '$1 == n && $3 == "bin" {print $7}' "$LVL9_REPO/ferramentas.tsv")
  [[ -n $spec ]] || { falha "$nome não é um binário do ferramentas.tsv"; return 1; }
  tmp=$(mktemp -d)
  baixa_verificado "$nome" "$tmp/asset" || { rm -rf "$tmp"; return 1; }
  extrai "$tmp/asset" "$tmp/x" "${LOCK_URL##*/}"
  IFS=, read -ra itens <<< "$spec"
  for item in "${itens[@]}"; do
    origem=${item%%:*} destino=${item#*:}
    [[ $item == *:* ]] || destino=$origem
    achado=''
    while IFS= read -r -d '' f; do e_elf "$f" && { achado=$f; break; }; done \
      < <(find "$tmp/x" -type f -name "$origem" -print0)
    [[ -n $achado ]] || { rm -rf "$tmp"; falha "executável $origem não encontrado no pacote de $nome"; return 1; }
    como_root install -m 755 "$achado" "/usr/local/bin/$destino"
  done
  rm -rf "$tmp"
  info "$nome $LOCK_VERSAO"
  mudou "$nome $LOCK_VERSAO"
}

# Versão do lock já instalada? (marcador gravado em /usr/local/share/lvl9/versoes)
bin_atualizado() {
  local spec item
  lock_le "$1" 2>/dev/null || return 1
  grep -qx "$1 $LOCK_VERSAO $LOCK_SHA" "$LVL9_SISTEMA/versoes" 2>/dev/null || return 1
  # binários: confere que cada um instalado é executável de verdade (conserta instalações antigas)
  spec=$(awk -v n="$1" '$1 == n && $3 == "bin" {print $7}' "$LVL9_REPO/ferramentas.tsv")
  IFS=, read -ra itens <<< "$spec"
  for item in "${itens[@]}"; do e_elf "/usr/local/bin/${item#*:}" || return 1; done
}
marca_versao() {
  lock_le "$1" || return 1
  como_root mkdir -p "$LVL9_SISTEMA"
  { grep -v "^$1 " "$LVL9_SISTEMA/versoes" 2>/dev/null; echo "$1 $LOCK_VERSAO $LOCK_SHA"; } \
    | como_root tee "$LVL9_SISTEMA/versoes.novo" >/dev/null
  como_root mv "$LVL9_SISTEMA/versoes.novo" "$LVL9_SISTEMA/versoes"
}

# ─── Arquivos ───────────────────────────────────────────────────────
# Destinos fora do $HOME do usuário (/root, /usr, /etc) são gravados como root
e_do_sistema() { [[ $1 != "$HOME"/* ]]; }

# Backup com a árvore de diretórios original, em ~/.local/state/lvl9/backups/<carimbo>/
# (arquivos do root vão para /root/.local/state/lvl9/backups/, que só o root lê)
faz_backup() {
  local alvo=$1 dir
  # (sem cp --parents: no coreutils 9.1 do Debian 12 ele falha com caminhos absolutos)
  if e_do_sistema "$alvo"; then
    dir=/root/.local/state/lvl9/backups/$LVL9_CARIMBO
    como_root mkdir -p "$(dirname "$dir$alvo")" && como_root cp -a "$alvo" "$dir$alvo"
  else
    dir=$LVL9_ESTADO/backups/$LVL9_CARIMBO
    mkdir -p "$(dirname "$dir$alvo")" && cp -a "$alvo" "$dir$alvo"
  fi
  info "backup: $alvo → $dir$alvo"
}

# copia origem destino [modo] → copia com backup do que existia (se diferente) e registra
# no arquivos.tsv para o "lvl9 diff". A origem é relativa ao repositório ou absoluta.
copia() {
  local src=$1 dst=$2 modo=${3:-644} r=() como=novo
  [[ $src == /* ]] || src="$LVL9_REPO/$src"
  e_do_sistema "$dst" && r=(sudo -n)
  if "${r[@]}" test -e "$dst"; then
    if "${r[@]}" cmp -s "$src" "$dst"; then registra "$src" "$dst"; return 0; fi
    faz_backup "$dst"; como=atualizado
  fi
  "${r[@]}" install -D -m "$modo" "$src" "$dst"
  registra "$src" "$dst"
  mudou "${dst/#"$HOME"/\~} ($como)"
}

registra() {
  [[ $1 == "$LVL9_REPO"/* ]] || return 0   # baixados (vim-plug, halcyon) não têm o que comparar
  local rel=${1#"$LVL9_REPO"/}
  mkdir -p "$LVL9_ESTADO"
  touch "$LVL9_ESTADO/arquivos.tsv"
  grep -qxF "$rel	$2" "$LVL9_ESTADO/arquivos.tsv" || printf '%s\t%s\n' "$rel" "$2" >> "$LVL9_ESTADO/arquivos.tsv"
}

# ─── Usuário e root ─────────────────────────────────────────────────
# Tudo o que é configuração pessoal (bashrc, vim, tmux, Claude) vai para os dois.
# como_alvo usuario|root comando... → roda com o HOME certo
como_alvo() {
  local alvo=$1; shift
  if [[ $alvo == root ]]; then sudo -n -H env PATH="/usr/local/bin:/root/.local/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$@"
  else "$@"
  fi
}
home_de() { if [[ $1 == root ]]; then echo /root; else echo "$HOME"; fi; }

# ─── Escolhas ───────────────────────────────────────────────────────
# Grupos escolhidos na tela (LVL9_GRUPOS="base dev sysadmin rede")
grupo_ativo() { [[ " $LVL9_GRUPOS " == *" $1 "* ]]; }
