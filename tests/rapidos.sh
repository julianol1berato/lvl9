#!/usr/bin/env bash
# tests/rapidos.sh — testes rápidos, sem internet e sem sudo: só leem o repositório.
# É o que o GitHub Actions roda a cada mudança. A instalação completa, que baixa as
# ferramentas, roda só local, em Docker: tests/docker.sh.
set -uo pipefail
raiz=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ok=0 erro=0

confere() {   # confere "descrição" comando...
  local d=$1; shift
  if "$@" &>"$tmp/saida"; then echo "  ✔ $d"; (( ok++ ))
  else echo "  ✘ $d"; sed 's/^/      /' "$tmp/saida" | tail -5; (( erro++ )); fi
}
igual() {   # igual "esperado" comando...  → a saída do comando é exatamente o esperado
  local esperado=$1 obtido; shift
  obtido=$("$@" 2>&1)
  [[ $obtido == "$esperado" ]] || { printf 'esperado: %q\nobtido:   %q\n' "$esperado" "$obtido"; return 1; }
}
# roda uma função do lvl9 num bash limpo, com a lib carregada e o ambiente dado.
# A função roda nesse mesmo bash (um "bash -c" novo não teria as funções da lib);
# "!" na frente inverte o resultado.
lvl9() {   # lvl9 VAR=valor... -- [!] função args...
  local amb=()
  while [[ $1 != -- ]]; do amb+=("$1"); shift; done; shift
  env -i HOME="$tmp/home" PATH=/usr/bin:/bin "${amb[@]}" bash -c '
    source "$0/lib/comum.sh" && source "$0/lib/ui.sh" || exit 99
    if [[ $1 == "!" ]]; then shift; ! "$@"; else "$@"; fi' "$raiz" "$@" </dev/null
}
mkdir -p "$tmp/home/.config/lvl9"

# ─── Interface gráfica e modo ───────────────────────────────────────
echo "== detecção da interface gráfica =="
maquina() {   # maquina nome arquivo... → raiz falsa com esses arquivos
  local r="$tmp/raiz-$1" f; shift
  mkdir -p "$r"
  for f in "$@"; do mkdir -p "$r/${f%/*}"; : > "$r/$f"; [[ $f == usr/bin/* ]] && chmod +x "$r/$f"; done
  echo "$r"
}
servidor=$(maquina servidor usr/share/doc/leia-me)
xsessions_vazio=$(maquina vazio usr/share/doc/leia-me); mkdir -p "$xsessions_vazio/usr/share/xsessions"
xfce=$(maquina xfce usr/share/xsessions/xfce.desktop)
gnome=$(maquina gnome usr/share/wayland-sessions/gnome.desktop)
dm=$(maquina dm etc/X11/default-display-manager)
binxfce=$(maquina binxfce usr/bin/xfce4-session)
confere "servidor sem nada gráfico: sem interface" lvl9 LVL9_RAIZ="$servidor" -- ! tem_interface_grafica
confere "pasta xsessions vazia não conta" lvl9 LVL9_RAIZ="$xsessions_vazio" -- ! tem_interface_grafica
confere "sessão X do XFCE: com interface" lvl9 LVL9_RAIZ="$xfce" -- tem_interface_grafica
confere "sessão Wayland do GNOME: com interface" lvl9 LVL9_RAIZ="$gnome" -- tem_interface_grafica
confere "display manager: com interface" lvl9 LVL9_RAIZ="$dm" -- tem_interface_grafica
confere "xfce4-session instalado: com interface" lvl9 LVL9_RAIZ="$binxfce" -- tem_interface_grafica
confere "o \$DISPLAY (ssh -X) não conta" lvl9 LVL9_RAIZ="$servidor" DISPLAY=localhost:10.0 -- ! tem_interface_grafica

echo "== escolha do modo =="
escolhas="$tmp/home/.config/lvl9/escolhas"
confere "sem interface → servidor" igual servidor lvl9 LVL9_RAIZ="$servidor" -- lvl9_modo
confere "com interface → desktop" igual desktop lvl9 LVL9_RAIZ="$xfce" -- lvl9_modo
confere "LVL9_MODO=desktop vale num servidor" igual desktop lvl9 LVL9_RAIZ="$servidor" LVL9_MODO=desktop -- lvl9_modo
printf 'LVL9_MODO=servidor\nLVL9_GRUPOS="base"\n' > "$escolhas"
confere "o modo salvo vale mais que a detecção" igual servidor lvl9 LVL9_RAIZ="$xfce" -- lvl9_modo
confere "o LVL9_MODO do ambiente vale mais que o salvo" igual desktop lvl9 LVL9_RAIZ="$xfce" LVL9_MODO=desktop -- lvl9_modo
printf 'LVL9_GRUPOS="base dev"\nLVL9_TEMA=tokyo-night\n' > "$escolhas"
confere "escolhas antigas, sem modo: vale a detecção" igual desktop lvl9 LVL9_RAIZ="$xfce" -- lvl9_modo
rm -f "$escolhas"

# ─── Passos da instalação ───────────────────────────────────────────
echo "== passos de cada modo =="
passos() { lvl9 "$@" -- lvl9_passos | cut -d'|' -f2 | tr '\n' ' '; }
tudo=(LVL9_GRUPOS="base dev sysadmin rede" LVL9_TAILSCALE=sim LVL9_CLAUDE=sim)
confere "servidor: nada de fontes, XFCE ou xrdp" igual \
  "00-sistema.sh 10-ferramentas.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 60-git.sh 70-docker.sh 90-tailscale.sh 95-claude.sh " \
  passos LVL9_MODO=servidor "${tudo[@]}"
confere "desktop: com fontes, XFCE e xrdp" igual \
  "00-sistema.sh 10-ferramentas.sh 20-fontes.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 60-git.sh 70-docker.sh 80-desktop.sh 85-xrdp.sh 90-tailscale.sh 95-claude.sh " \
  passos LVL9_MODO=desktop "${tudo[@]}"
confere "só o base, sem opcionais" igual \
  "00-sistema.sh 10-ferramentas.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh " \
  passos LVL9_MODO=servidor LVL9_GRUPOS=base LVL9_TAILSCALE=nao LVL9_CLAUDE=nao
existem() {
  local f lista; lista=$(passos LVL9_MODO=desktop "${tudo[@]}")
  [[ $(wc -w <<< "$lista") -ge 10 ]] || { echo "lista de passos vazia: $lista"; return 1; }
  for f in $lista; do [[ -f $raiz/install/$f ]] || { echo "falta install/$f"; return 1; }; done
}
confere "todo passo listado existe em install/" existem
sem_grafico() {   # os passos de servidor não instalam pacote gráfico
  local f lista; lista=$(passos LVL9_MODO=servidor "${tudo[@]}")
  [[ $(wc -w <<< "$lista") -ge 8 ]] || { echo "lista de passos vazia: $lista"; return 1; }
  for f in $lista; do
    if grep -nE 'apt_instala.*\b(xfce4|xrdp|xorgxrdp|flameshot|fontconfig|dbus-x11)\b|apt_instala [^#]*\bxclip\b' "$raiz/install/$f" \
       | grep -v 'modo_desktop'; then echo "em install/$f"; return 1; fi
  done
}
confere "nenhum passo de servidor instala pacote gráfico" sem_grafico

# ─── Sem terminal (Claude Code, CI) ─────────────────────────────────
echo "== sem terminal =="
sem_tty() { setsid -w env -i HOME="$tmp/home" PATH=/usr/bin:/bin bash -c 'source "$0/lib/ui.sh"; echo "${LVL9_AUTO:-}"' "$raiz" </dev/null; }
confere "sem terminal, liga o automático sozinho" igual 1 sem_tty
confere "múltipla escolha mantém o que estava marcado" igual $'a\nc' \
  lvl9 LVL9_AUTO=1 -- ui_multipla "grupos" "A,C" "A:a" "B:b" "C:c"
confere "múltipla escolha sem nada marcado" igual "" \
  lvl9 LVL9_AUTO=1 -- ui_multipla "grupos" "" "A:a" "B:b"
confere "escolha única fica com a marcada" igual b \
  lvl9 LVL9_AUTO=1 -- ui_uma "tema" "B" "A:a" "B:b" "C:c"
confere "escolha única sem marcada fica com a primeira" igual a \
  lvl9 LVL9_AUTO=1 -- ui_uma "tema" "X" "A:a" "B:b"
confere "confirmação usa o padrão (não)" lvl9 LVL9_AUTO=1 -- ! ui_confirma "?" nao
confere "confirmação usa o padrão (sim)" lvl9 LVL9_AUTO=1 -- ui_confirma "?" sim
confere "LVL9_AUTO_RESPOSTA=sim responde sim" lvl9 LVL9_AUTO=1 LVL9_AUTO_RESPOSTA=sim -- ui_confirma "?" nao

# ─── versions.lock × ferramentas.tsv ────────────────────────────────
echo "== versions.lock =="
lock_completo() {   # cada ferramenta tem as entradas certas, com URL https e sha256 (ou commit)
  local nome tipo archs a linha n=0
  while read -r nome _ tipo _; do
    [[ -z $nome || $nome == \#* ]] && continue
    archs=all; [[ $tipo == bin ]] && archs="amd64 arm64"
    for a in $archs; do
      linha=$(awk -v n="$nome" -v a="$a" '$1 == n && $2 == a' "$raiz/versions.lock")
      [[ $(grep -c . <<< "$linha") == 1 ]] || { echo "$nome $a: $(grep -c . <<< "$linha") entradas"; return 1; }
      read -r _ _ _ url sha <<< "$linha"
      [[ $url == https://* ]] || { echo "$nome $a: url $url"; return 1; }
      if [[ $tipo == git ]]; then [[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo "$nome: commit $sha"; return 1; }
      else [[ $sha =~ ^[0-9a-f]{64}$ ]] || { echo "$nome $a: sha256 $sha"; return 1; }; fi
      (( n++ ))
    done
  done < "$raiz/ferramentas.tsv"
  [[ $(grep -cv '^#' "$raiz/versions.lock") == "$n" ]] || { echo "o lock tem entradas que o ferramentas.tsv não lista"; return 1; }
}
confere "toda ferramenta tem versão, URL e sha256 no lock" lock_completo

echo "RESULTADO: $ok ok, $erro erro(s)"
exit $(( erro > 0 ))
