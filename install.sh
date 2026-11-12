#!/usr/bin/env bash
# install.sh — instalador do lvl9: verificações, escolhas, execução dos passos e resumo.
# Chamado pelo boot.sh (curl | bash) e pelo "lvl9 update". Pode rodar de novo quantas vezes
# quiser: cada passo só mexe no que mudou e faz backup do que substitui.
set -uo pipefail

LVL9_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export LVL9_REPO
# shellcheck source=lib/comum.sh
source "$LVL9_REPO/lib/comum.sh"
# shellcheck source=lib/ui.sh
source "$LVL9_REPO/lib/ui.sh"
LVL9_VERSAO=$(git -C "$LVL9_REPO" describe --tags --always 2>/dev/null || echo dev)

# Via curl | bash a entrada é o pipe: a tela precisa ler o teclado do /dev/tty
if ! auto && [[ ! -t 0 ]] && { true </dev/tty; } 2>/dev/null; then exec </dev/tty; fi

mkdir -p "$LVL9_ESTADO" "$LVL9_CONFIG"
: > "$LVL9_LOG"
ln -sfn "$LVL9_LOG" "$LVL9_ESTADO/install.log"

# ─── 1. Verificações ────────────────────────────────────────────────
auto || clear
ui_banner
ui_secao "Verificando o sistema"
lvl9_os
ARCH=$(lvl9_arch)

if (( EUID == 0 )); then
  ui_check erro "Usuário" "root"
  ui_texto "Rode como o seu usuário: o lvl9 configura ele e também o root (via sudo)."
  exit 1
fi
ui_check ok "Usuário" "$USER"

if [[ $OS_ID != debian && $OS_ID != ubuntu ]]; then
  ui_check erro "Sistema" "$OS_NOME"; ui_texto "O lvl9 é para Debian e Ubuntu."; exit 1
elif lvl9_os_suportado; then
  ui_check ok "Sistema" "$OS_NOME"
else
  ui_check aviso "Sistema" "$OS_NOME (versão não testada)"
fi

if [[ $ARCH == nao-suportada ]]; then ui_check erro "Arquitetura" "$(uname -m)"; exit 1; fi
ui_check ok "Arquitetura" "$ARCH"
# Modo: desktop só onde o XFCE já está instalado; senão é de servidor e nada gráfico é instalado.
# Com outra interface (GNOME, KDE...), o XFCE só entra se a pessoa pedir: pergunta nas escolhas.
pergunta_xfce=0
if outra_interface && ! lvl9_modo_escolhido; then pergunta_xfce=1; fi
LVL9_MODO=$(lvl9_modo)
case $LVL9_MODO in
  servidor)
    if outra_interface; then
      ui_check ok "Modo" "terminal e Nerd Fonts (sem XFCE nem xrdp)"
      ui_check aviso "Desktop" "outra interface, sem XFCE: a parte gráfica do lvl9 é só para XFCE"
    else
      ui_check ok "Modo" "servidor (nada gráfico é instalado)"
    fi ;;
  desktop)
    ui_check ok "Modo" "desktop"
    if tem_xfce; then ui_check ok "Desktop" "XFCE"; else ui_check aviso "Desktop" "XFCE não encontrado (será instalado, a pedido)"; fi
    if [[ -n ${XRDP_SESSION:-} ]]; then ui_check ok "Sessão" "xrdp"
    elif [[ -n ${DISPLAY:-} ]]; then ui_check ok "Sessão" "gráfica local"
    else ui_check aviso "Sessão" "fora da sessão gráfica (ajustes do XFCE no próximo login)"; fi ;;
  *)
    ui_check erro "Modo" "$LVL9_MODO"; ui_texto "Use LVL9_MODO=desktop ou LVL9_MODO=servidor."; exit 1 ;;
esac
export LVL9_MODO
tem_systemd && ui_check ok "Init" "systemd" || ui_check aviso "Init" "sem systemd (container?)"

# sudo: pede a senha uma vez e mantém viva enquanto o instalador roda
if ! sudo -n true 2>/dev/null; then
  printf '\n'
  ui_texto "Preciso do sudo para instalar pacotes e configurar o root. Sua senha:"
  sudo -v || { ui_erro "sem sudo não dá para continuar"; exit 1; }
fi
ui_check ok "sudo" "liberado"
( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
SUDO_VIVO=$!
trap 'kill $SUDO_VIVO 2>/dev/null' EXIT

# gum: a própria tela do instalador (versão do lock, sha256 conferido)
if ! bin_atualizado gum || ! tem gum; then
  ui_texto "instalando o gum (interface do instalador)..."
  if instala_bin gum >> "$LVL9_LOG" 2>&1 && marca_versao gum >> "$LVL9_LOG" 2>&1; then
    ui_check ok "gum" "$LOCK_VERSAO"
  else
    ui_check erro "gum" "falhou (veja $LVL9_LOG)"; exit 1
  fi
fi

# ─── 2. Escolhas ────────────────────────────────────────────────────
# Padrões: o que foi escolhido da última vez (ou tudo marcado, na primeira)
LVL9_GRUPOS="base dev sysadmin rede" LVL9_TEMA=tokyo-night LVL9_TAILSCALE=nao LVL9_CLAUDE=sim
modo=$LVL9_MODO
# shellcheck disable=SC1091
[[ -f $LVL9_CONFIG/escolhas ]] && source "$LVL9_CONFIG/escolhas"
LVL9_MODO=$modo   # já decidido nas verificações (o LVL9_MODO do ambiente vale mais que o salvo)

# Outra interface gráfica: o XFCE só é instalado com um "sim" de quem está na frente da tela.
# Sem terminal (automação) não se pergunta nem se instala: para isso existe o LVL9_MODO=desktop.
if (( pergunta_xfce )); then
  ui_secao "Interface gráfica"
  ui_texto "Esta máquina usa outra interface gráfica e não tem o XFCE."
  ui_texto "A parte gráfica do lvl9 (xfce4-terminal, atalhos, xrdp) é feita e testada só no XFCE."
  ui_texto "As Nerd Fonts são instaladas de qualquer forma, para o prompt aparecer direito."
  printf '\n'
  if ! auto && ui_confirma "Instalar o XFCE ao lado da interface atual? (ela não é removida)" nao; then
    LVL9_MODO=desktop; ui_ok "XFCE será instalado"
  else
    ui_texto "  XFCE (não): terminal e Nerd Fonts. Para mudar depois: LVL9_MODO=desktop lvl9 update"
  fi
  export LVL9_MODO
fi

ui_secao "Componentes"
ui_texto "Sempre instalados: starship · eza · bat · fd · rg · fzf · zoxide · jq · fastfetch · btop"
if [[ $LVL9_MODO == desktop ]]; then
  ui_texto "gum · mise + Node · gh · Nerd Fonts · vim halcyon · tmux · XFCE · xrdp · flameshot"
elif quer_fontes; then
  ui_texto "gum · mise + Node · gh · Nerd Fonts · vim halcyon · tmux · sem XFCE nem xrdp"
else
  ui_texto "gum · mise + Node · gh · vim halcyon · tmux · sem nada gráfico (modo servidor)"
fi
printf '\n'
sel=()
for g in dev sysadmin rede; do grupo_ativo "$g" && sel+=("$g"); done
declare -A ROTULO=(
  [dev]="Dev        delta · lazygit · tldr · yq"
  [sysadmin]="Sysadmin   Docker · lazydocker · dust · duf · procs"
  [rede]="Rede       nmap · doggo · gping · trippy · bandwhich · tcpdump"
)
sel_rot=(); for g in "${sel[@]}"; do sel_rot+=("${ROTULO[$g]}"); done
escolhidos=$(IFS=,; ui_multipla "Grupos extras (x marca/desmarca · enter confirma)" "${sel_rot[*]}" \
  "${ROTULO[dev]}:dev" "${ROTULO[sysadmin]}:sysadmin" "${ROTULO[rede]}:rede") || exit 130
LVL9_GRUPOS="base $(echo $escolhidos)"
for g in dev sysadmin rede; do
  if grupo_ativo "$g"; then ui_ok "${ROTULO[$g]}"; else ui_texto "  ${ROTULO[$g]%% *} (não)"; fi
done

ui_secao "Prompt"
declare -A TEMAS=(
  [tokyo-night]="tokyo-night   powerline Tokyo Night, 2 linhas, IP e relógio à direita"
  [gruvbox]="gruvbox       powerline com cantos arredondados, cores quentes"
  [parrot]="parrot        estilo ParrotOS  ┌─[user]─[~/pasta] … [hora]  └──╼ \$"
  [bash-parrot]="bash-parrot   estilo ParrotOS em bash puro (sem starship)"
  [omarchy]="omarchy       minimalista do Akita, 1 linha"
)
LVL9_TEMA=$(ui_uma "Tema do prompt (troca depois com: lvl9 tema)" "${TEMAS[$LVL9_TEMA]:-${TEMAS[tokyo-night]}}" \
  "${TEMAS[tokyo-night]}:tokyo-night" "${TEMAS[gruvbox]}:gruvbox" "${TEMAS[parrot]}:parrot" \
  "${TEMAS[bash-parrot]}:bash-parrot" "${TEMAS[omarchy]}:omarchy") || exit 130
[[ -n $LVL9_TEMA ]] || LVL9_TEMA=tokyo-night
ui_ok "${TEMAS[$LVL9_TEMA]}"

ui_secao "Opcionais"
padrao=nao; [[ $LVL9_TAILSCALE == sim ]] && padrao=sim
if ui_confirma "Instalar o Tailscale (VPN mesh)?" "$padrao"; then LVL9_TAILSCALE=sim; ui_ok "Tailscale"; else LVL9_TAILSCALE=nao; ui_texto "  Tailscale (não)"; fi
padrao=nao; [[ $LVL9_CLAUDE == sim ]] && padrao=sim
if ui_confirma "Instalar Claude Code + statusbar-claude + herdr (usuário e root)?" "$padrao"; then
  LVL9_CLAUDE=sim; ui_ok "Claude Code + statusbar-claude + herdr"
else LVL9_CLAUDE=nao; ui_texto "  Claude Code (não)"; fi

# ─── 3. Confirmação ─────────────────────────────────────────────────
sim_nao() { if [[ $1 == sim ]]; then echo sim; else echo não; fi; }
printf '\n'
ui_caixa "$(cor "$C_AZUL")${NEG}Pronto para instalar$RST" "" \
  "modo       $LVL9_MODO" \
  "grupos     $LVL9_GRUPOS" \
  "prompt     $LVL9_TEMA" \
  "tailscale  $(sim_nao "$LVL9_TAILSCALE")" \
  "claude     $(sim_nao "$LVL9_CLAUDE")" \
  "" \
  "$(cor "$C_CINZA")usuário $USER e root · backups em ~/.local/state/lvl9/backups$RST"
printf '\n'
ui_confirma "Começar?" sim || { ui_texto "nada foi alterado."; exit 0; }

printf 'LVL9_MODO=%s\nLVL9_GRUPOS="%s"\nLVL9_TEMA=%s\nLVL9_TAILSCALE=%s\nLVL9_CLAUDE=%s\n' \
  "$LVL9_MODO" "$LVL9_GRUPOS" "$LVL9_TEMA" "$LVL9_TAILSCALE" "$LVL9_CLAUDE" > "$LVL9_CONFIG/escolhas"
export LVL9_GRUPOS LVL9_TEMA LVL9_TAILSCALE LVL9_CLAUDE

# ─── 4. Instalação ──────────────────────────────────────────────────
ui_secao "Instalando"
mapfile -t passos < <(lvl9_passos)

falhas=0 inicio=$SECONDS
for p in "${passos[@]}"; do
  if ! ui_passo "${p%%|*}" "${p#*|}"; then
    (( falhas++ ))
    auto && continue
    ui_confirma "Continuar com os próximos passos?" sim || break
  fi
done
total=$(( SECONDS - inicio ))

# ─── 5. Tailscale: conectar agora? ──────────────────────────────────
if [[ $LVL9_TAILSCALE == sim ]] && ! auto && tem tailscale && ! tailscale status &>/dev/null; then
  printf '\n'
  if ui_confirma "Conectar o Tailscale agora? (abre um link de login)" sim; then
    sudo tailscale up || ui_aviso "não conectou; depois rode: sudo tailscale up"
  fi
fi

# ─── 6. Resumo ──────────────────────────────────────────────────────
printf '\n'
proximos=("abra um terminal novo para ver o prompt, o fastfetch e a dica do dia")
grupo_ativo sysadmin && proximos+=("faça logout/login para usar o docker sem sudo")
[[ $LVL9_CLAUDE == sim ]] && proximos+=("rode claude para fazer login no Claude Code")
proximos+=("Alt+H ou lvl9 ajuda: todos os comandos · lvl9 doctor: diagnóstico")
linhas=()
for p in "${proximos[@]}"; do linhas+=("  › $p"); done
if (( falhas == 0 )); then titulo="$(cor "$C_VERDE")${NEG}✔ lvl9 instalado em $(( total / 60 ))min $(( total % 60 ))s$RST"
else titulo="$(cor "$C_AMARELO")${NEG}! lvl9 instalado com $falhas passo(s) com erro$RST"; fi
ui_caixa "$titulo" "" "${linhas[@]}" "" \
  "$(cor "$C_CINZA")log:     ~/.local/state/lvl9/install.log$RST" \
  "$(cor "$C_CINZA")backups: ~/.local/state/lvl9/backups/$LVL9_CARIMBO (root: /root/.local/state/lvl9/backups)$RST"
printf '\n'

# O shell de onde o curl | bash foi chamado ainda tem a configuração antiga: oferece abrir
# um novo, já com o lvl9 (sair dele com "exit" volta para o anterior)
if ! auto && (( falhas == 0 )); then
  if ui_confirma "Abrir agora um terminal com o lvl9?" sim; then
    kill "$SUDO_VIVO" 2>/dev/null
    exec bash -l
  fi
  ui_texto "abra um terminal novo (ou digite: exec bash) para ver o lvl9"
fi
(( falhas == 0 ))
