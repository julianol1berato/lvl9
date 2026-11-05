# lib/ui.sh — tela do instalador: gum com as cores Tokyo Night.
# Com LVL9_AUTO=1 nada é perguntado: valem as escolhas salvas ou o padrão. Liga sozinho quando
# não há terminal nenhum (Claude Code, CI, ssh sem -t), onde o gum não teria onde desenhar.

# ─── Paleta Tokyo Night ─────────────────────────────────────────────
C_AZUL='#7aa2f7' C_CIANO='#7dcfff' C_ROXO='#bb9af7' C_VERDE='#9ece6a'
C_AMARELO='#e0af68' C_VERMELHO='#f7768e' C_CINZA='#565f89' C_TEXTO='#c0caf5' C_FUNDO='#1a1b26'

# truecolor direto, para o que é desenhado sem o gum
cor() { local h=${1#\#}; printf '\e[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
RST=$'\e[0m' NEG=$'\e[1m'

# Estilo padrão de todos os componentes do gum
export GUM_CHOOSE_CURSOR_FOREGROUND=$C_ROXO GUM_CHOOSE_HEADER_FOREGROUND=$C_AZUL
export GUM_CHOOSE_SELECTED_FOREGROUND=$C_VERDE GUM_CHOOSE_ITEM_FOREGROUND=$C_TEXTO
export GUM_CONFIRM_PROMPT_FOREGROUND=$C_AZUL GUM_CONFIRM_SELECTED_BACKGROUND=$C_ROXO
export GUM_CONFIRM_SELECTED_FOREGROUND=$C_FUNDO GUM_CONFIRM_UNSELECTED_BACKGROUND='#24283b'
export GUM_CONFIRM_UNSELECTED_FOREGROUND=$C_TEXTO
export GUM_SPIN_SPINNER_FOREGROUND=$C_ROXO GUM_SPIN_TITLE_FOREGROUND=$C_TEXTO
export GUM_SPIN_SPINNER=minidot

auto() { [[ ${LVL9_AUTO:-} == 1 ]]; }
if ! auto && [[ ! -t 0 ]] && ! { true </dev/tty; } 2>/dev/null; then export LVL9_AUTO=1; fi

# ─── Banner ─────────────────────────────────────────────────────────
# "LVL9" em blocos com degradê azul → roxo, linha a linha
ui_banner() {
  local -a arte=(
    '██╗     ██╗   ██╗██╗      █████╗ '
    '██║     ██║   ██║██║     ██╔══██╗'
    '██║     ██║   ██║██║     ╚██████║'
    '██║     ╚██╗ ██╔╝██║      ╚═══██║'
    '███████╗ ╚████╔╝ ███████╗ █████╔╝'
    '╚══════╝  ╚═══╝  ╚══════╝ ╚════╝ '
  )
  local -a grad=('#7aa2f7' '#7f9cf5' '#8a95f3' '#998ef1' '#a993ee' '#bb9af7')
  local i
  printf '\n'
  for i in "${!arte[@]}"; do printf '   %s%s%s\n' "$(cor "${grad[i]}")" "${arte[i]}" "$RST"; done
  printf '\n   %s9LEVEL%s %s·%s pré-setup Debian/Ubuntu + XFCE + xrdp %s·%s %s%s%s\n' \
    "$NEG$(cor "$C_ROXO")" "$RST" "$(cor "$C_CINZA")" "$RST" "$(cor "$C_CINZA")" "$RST" \
    "$(cor "$C_CINZA")" "${LVL9_VERSAO:-dev}" "$RST"
}

# Linha de status do sistema, estilo "boot": [ OK ] item ........ valor
ui_check() {   # ui_check ok|aviso|erro "rótulo" "valor"
  local estado=$1 rot=$2 val=$3 marca cor_m pontos
  case $estado in
    ok)    marca=' OK ' cor_m=$C_VERDE ;;
    aviso) marca='AVISO' cor_m=$C_AMARELO ;;
    *)     marca='ERRO' cor_m=$C_VERMELHO ;;
  esac
  printf -v pontos '%*s' $(( 26 - ${#rot} )) ''
  printf '   %s[%-5s]%s %s %s%s%s %s\n' "$(cor "$cor_m")" "$marca" "$RST" "$rot" \
    "$(cor "$C_CINZA")" "${pontos// /.}" "$RST" "$val"
}

ui_secao() {
  local t=" $1 " linha
  printf -v linha '%*s' $(( 62 - ${#t} )) ''
  printf '\n %s━━%s%s%s%s%s\n\n' "$(cor "$C_ROXO")" "$NEG$(cor "$C_AZUL")" "$t" "$RST" \
    "$(cor "$C_ROXO")" "${linha// /━}$RST"
}

ui_ok()    { printf '   %s✔%s %s\n' "$(cor "$C_VERDE")" "$RST" "$*"; }
ui_aviso() { printf '   %s!%s %s\n' "$(cor "$C_AMARELO")" "$RST" "$*"; }
ui_erro()  { printf '   %s✘%s %s\n' "$(cor "$C_VERMELHO")" "$RST" "$*"; }
ui_texto() { printf '   %s%s%s\n' "$(cor "$C_CINZA")" "$*" "$RST"; }

# ─── Perguntas ──────────────────────────────────────────────────────
# ui_confirma "pergunta" sim|nao → 0 = sim
ui_confirma() {
  local padrao=${2:-sim}
  if auto; then [[ ${LVL9_AUTO_RESPOSTA:-$padrao} == sim ]]; return; fi
  local args=(--affirmative "Sim" --negative "Não" --padding "0 3")
  [[ $padrao == nao ]] && args+=(--default=false)
  gum confirm "${args[@]}" "$1"
}

# ui_multipla "cabeçalho" "selecionados,separados,por,vírgula" "rótulo:valor"... → valores, um por linha
ui_multipla() {
  local cab=$1 sel=$2; shift 2
  if auto; then local o; for o in "$@"; do [[ ",$sel," == *",${o%:*},"* ]] && echo "${o##*:}"; done; return 0; fi
  gum choose --no-limit --header "$cab" --selected "$sel" --label-delimiter ":" \
    --cursor-prefix "○ " --selected-prefix "◉ " --unselected-prefix "○ " \
    --padding "0 3" --height 12 "$@"
}

# ui_uma "cabeçalho" "selecionado" "rótulo:valor"... → valor
ui_uma() {
  local cab=$1 sel=$2 o; shift 2
  if auto; then
    for o in "$@"; do [[ ${o%:*} == "$sel" ]] && { echo "${o##*:}"; return; }; done
    echo "${1##*:}"; return
  fi
  gum choose --header "$cab" --selected "$sel" --label-delimiter ":" --cursor "▸ " \
    --padding "0 3" --height 10 "$@"
}

# Caixa com borda arredondada (resumo das escolhas e tela final)
ui_caixa() {
  if auto; then printf '%s\n' "$@"; return; fi
  gum style --border rounded --border-foreground "$C_ROXO" --padding "1 3" --margin "0 3" "$@"
}

# ─── Passos ─────────────────────────────────────────────────────────
# ui_passo "Título" arquivo_do_passo → roda o passo com spinner; a saída vai para o log
PASSOS_RESULTADO=()
ui_passo() {
  local titulo=$1 arquivo=$2 ini fim seg estado=0 pontos
  ini=$SECONDS
  printf '\n=== %s (%s) ===\n' "$titulo" "$arquivo" >> "$LVL9_LOG"
  local cmd=(bash -c 'source "$LVL9_REPO/lib/comum.sh"; source "$LVL9_REPO/install/$1"; set -e; executa' _ "$arquivo")
  if auto || ! tem gum; then
    "${cmd[@]}" >> "$LVL9_LOG" 2>&1 || estado=$?
  else
    gum spin --title " $titulo" -- bash -c '"$@" >> "$LVL9_LOG" 2>&1' _ "${cmd[@]}" || estado=$?
  fi
  fim=$SECONDS seg=$(( fim - ini ))
  printf -v pontos '%*s' $(( 44 - ${#titulo} )) ''
  if (( estado == 0 )); then
    printf '   %s✔%s %s %s%s %ss%s\n' "$(cor "$C_VERDE")" "$RST" "$titulo" "$(cor "$C_CINZA")" "${pontos// /.}" "$seg" "$RST"
    PASSOS_RESULTADO+=("ok|$titulo|$seg")
    return 0
  fi
  printf '   %s✘%s %s %s%s falhou%s\n' "$(cor "$C_VERMELHO")" "$RST" "$titulo" "$(cor "$C_CINZA")" "${pontos// /.}" "$RST"
  PASSOS_RESULTADO+=("erro|$titulo|$seg")
  printf '%s' "$(cor "$C_CINZA")"; tail -n 8 "$LVL9_LOG" | sed 's/^/       │ /'; printf '%s' "$RST"
  return 1
}
