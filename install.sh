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
# Modo: sem interface gráfica instalada, o lvl9 é de servidor e não instala nada gráfico
LVL9_MODO=$(lvl9_modo)
case $LVL9_MODO in
  servidor)
    ui_check ok "Modo" "servidor (nada gráfico é instalado)" ;;
  desktop)
    ui_check ok "Modo" "desktop"
    if tem xfce4-session; then ui_check ok "Desktop" "XFCE"; else ui_check aviso "Desktop" "XFCE não encontrado (será instalado)"; fi
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

ui_secao "Componentes"
ui_texto "Sempre instalados: starship · eza · bat · fd · rg · fzf · zoxide · jq · fastfetch · btop"
if [[ $LVL9_MODO == desktop ]]; then
  ui_texto "gum · mise + Node · gh · Nerd Fonts · vim halcyon · tmux · XFCE · xrdp · flameshot"
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
passos=(
  "Sistema, fuso e locale|00-sistema.sh"
  "Ferramentas (versões fixadas)|10-ferramentas.sh"
)
# Fontes e desktop só onde há interface gráfica: num servidor quem desenha é o terminal do cliente
[[ $LVL9_MODO == desktop ]] && passos+=("Nerd Fonts|20-fontes.sh")
passos+=(
  "Bash, prompt e comando lvl9|30-shell.sh"
  "mise + Node LTS|40-mise.sh"
  "Vim halcyon|50-vim.sh"
  "tmux|55-tmux.sh"
)
grupo_ativo dev && passos+=("Git com delta|60-git.sh")
grupo_ativo sysadmin && passos+=("Docker Engine|70-docker.sh")
[[ $LVL9_MODO == desktop ]] && passos+=("XFCE, terminal e flameshot|80-desktop.sh" "xrdp|85-xrdp.sh")
[[ $LVL9_TAILSCALE == sim ]] && passos+=("Tailscale|90-tailscale.sh")
[[ $LVL9_CLAUDE == sim ]] && passos+=("Claude Code + statusbar + herdr|95-claude.sh")

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
