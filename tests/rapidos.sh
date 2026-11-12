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
    source "$0/lib/comum.sh" && source "$0/lib/ui.sh" && source "$0/lib/saude.sh" || exit 99
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

# A parte gráfica é só para XFCE: outra interface não vira desktop sem a pessoa pedir
echo "== XFCE ou nada gráfico =="
gnome_xfce=$(maquina gnomexfce usr/share/wayland-sessions/gnome.desktop usr/bin/xfce4-session)
confere "sessão xfce.desktop: tem XFCE" lvl9 LVL9_RAIZ="$xfce" -- tem_xfce
confere "xfce4-session instalado: tem XFCE" lvl9 LVL9_RAIZ="$binxfce" -- tem_xfce
confere "GNOME: não tem XFCE" lvl9 LVL9_RAIZ="$gnome" -- ! tem_xfce
confere "só display manager: não tem XFCE" lvl9 LVL9_RAIZ="$dm" -- ! tem_xfce
confere "GNOME sem XFCE é outra interface" lvl9 LVL9_RAIZ="$gnome" -- outra_interface
confere "GNOME com XFCE não é outra interface" lvl9 LVL9_RAIZ="$gnome_xfce" -- ! outra_interface
confere "servidor não é outra interface" lvl9 LVL9_RAIZ="$servidor" -- ! outra_interface
confere "GNOME sem XFCE → servidor (só terminal)" igual servidor lvl9 LVL9_RAIZ="$gnome" -- lvl9_modo
confere "GNOME sem XFCE: quer as Nerd Fonts" lvl9 LVL9_RAIZ="$gnome" -- quer_fontes
confere "XFCE: quer as Nerd Fonts" lvl9 LVL9_RAIZ="$xfce" -- quer_fontes
confere "servidor: não quer fontes" lvl9 LVL9_RAIZ="$servidor" -- ! quer_fontes
confere "servidor com LVL9_MODO=desktop: quer fontes" lvl9 LVL9_RAIZ="$servidor" LVL9_MODO=desktop -- quer_fontes
confere "display manager sem XFCE → servidor" igual servidor lvl9 LVL9_RAIZ="$dm" -- lvl9_modo
confere "xfce4-session instalado → desktop" igual desktop lvl9 LVL9_RAIZ="$binxfce" -- lvl9_modo
confere "GNOME com XFCE ao lado → desktop" igual desktop lvl9 LVL9_RAIZ="$gnome_xfce" -- lvl9_modo
confere "no GNOME, LVL9_MODO=desktop vale (a pedido)" igual desktop lvl9 LVL9_RAIZ="$gnome" LVL9_MODO=desktop -- lvl9_modo
confere "sem ambiente nem escolhas: modo não foi escolhido" lvl9 LVL9_RAIZ="$gnome" -- ! lvl9_modo_escolhido
confere "LVL9_MODO no ambiente: modo escolhido" lvl9 LVL9_RAIZ="$gnome" LVL9_MODO=servidor -- lvl9_modo_escolhido
printf 'LVL9_MODO=servidor\n' > "$escolhas"
confere "modo salvo (já respondeu antes): não pergunta de novo" lvl9 LVL9_RAIZ="$gnome" -- lvl9_modo_escolhido
rm -f "$escolhas"
pergunta_segura() {   # a pergunta do XFCE: padrão "não", nunca sem terminal, e só ela liga o desktop
  local trecho; trecho=$(sed -n '/^if (( pergunta_xfce )); then$/,/^fi$/p' "$raiz/install.sh")
  [[ -n $trecho ]] || { echo "pergunta do XFCE não encontrada no install.sh"; return 1; }
  grep -q '! auto && ui_confirma "Instalar o XFCE ao lado.*" nao' <<< "$trecho" || { echo "a pergunta precisa de terminal e de padrão não"; return 1; }
  grep -q 'outra_interface && ! lvl9_modo_escolhido' "$raiz/install.sh" || { echo "condição da pergunta mudou"; return 1; }
  # fora do passo de desktop, nenhum passo instala o XFCE
  ! grep -ln 'apt_instala.*xfce4' "$raiz"/install/*.sh | grep -v '80-desktop.sh' || { echo "XFCE instalado fora do 80-desktop.sh"; return 1; }
}
confere "XFCE ao lado de outra interface: só com um sim, no terminal" pergunta_segura

# ─── Passos da instalação ───────────────────────────────────────────
echo "== passos de cada modo =="
passos() { lvl9 "$@" -- lvl9_passos | cut -d'|' -f2 | tr '\n' ' '; }
tudo=(LVL9_GRUPOS="base dev sysadmin rede" LVL9_TAILSCALE=sim LVL9_CLAUDE=sim)
confere "servidor: nada de fontes, XFCE ou xrdp" igual \
  "00-sistema.sh 10-ferramentas.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 60-git.sh 70-docker.sh 90-tailscale.sh 95-claude.sh " \
  passos LVL9_MODO=servidor LVL9_RAIZ="$servidor" "${tudo[@]}"
confere "outra interface (GNOME): fontes sim, XFCE e xrdp não" igual \
  "00-sistema.sh 10-ferramentas.sh 20-fontes.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 60-git.sh 70-docker.sh 90-tailscale.sh 95-claude.sh " \
  passos LVL9_RAIZ="$gnome" LVL9_MODO=servidor "${tudo[@]}"
confere "desktop: com fontes, XFCE e xrdp" igual \
  "00-sistema.sh 10-ferramentas.sh 20-fontes.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 60-git.sh 70-docker.sh 80-desktop.sh 85-xrdp.sh 90-tailscale.sh 95-claude.sh " \
  passos LVL9_MODO=desktop "${tudo[@]}"
confere "só o base, sem opcionais" igual \
  "00-sistema.sh 10-ferramentas.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh " \
  passos LVL9_MODO=servidor LVL9_RAIZ="$servidor" LVL9_GRUPOS=base LVL9_TAILSCALE=nao LVL9_CLAUDE=nao
existem() {
  local f lista; lista=$(passos LVL9_MODO=desktop "${tudo[@]}")
  [[ $(wc -w <<< "$lista") -ge 10 ]] || { echo "lista de passos vazia: $lista"; return 1; }
  for f in $lista; do [[ -f $raiz/install/$f ]] || { echo "falta install/$f"; return 1; }; done
}
confere "todo passo listado existe em install/" existem
sem_grafico() {   # os passos de servidor não instalam pacote gráfico
  local f lista; lista=$(passos LVL9_MODO=servidor LVL9_RAIZ="$servidor" "${tudo[@]}")
  [[ $(wc -w <<< "$lista") -ge 8 ]] || { echo "lista de passos vazia: $lista"; return 1; }
  for f in $lista; do
    if grep -nE 'apt_instala.*\b(xfce4|xrdp|xorgxrdp|flameshot|fontconfig|dbus-x11)\b|apt_instala [^#]*\bxclip\b' "$raiz/install/$f" \
       | grep -v 'modo_desktop'; then echo "em install/$f"; return 1; fi
  done
}
confere "nenhum passo de servidor instala pacote gráfico" sem_grafico

# ─── Saúde do host ──────────────────────────────────────────────────
echo "== saúde do host =="
# systemctl falso: devolve o que estiver em $FALSO/sistema e $FALSO/usuario
mkdir -p "$tmp/bin" "$tmp/falso"
cat > "$tmp/bin/systemctl" <<'EOF'
#!/bin/sh
case " $* " in *" --user "*) cat "$FALSO/usuario" 2>/dev/null ;; *) cat "$FALSO/sistema" 2>/dev/null ;; esac
EOF
chmod +x "$tmp/bin/systemctl"
com_falso=(PATH="$tmp/bin:/usr/bin:/bin" FALSO="$tmp/falso")
saudavel=$(maquina saudavel usr/share/doc/leia-me); mkdir -p "$saudavel/run/systemd/system" "$saudavel/var/crash"
doente=$(maquina doente var/crash/_usr_bin_wireplumber.105.crash var/crash/_usr_share_spotify_spotify.1000.crash \
  var/crash/_usr_bin_x.1000.upload var/run/reboot-required); mkdir -p "$doente/run/systemd/system"
um_crash=$(maquina umcrash var/crash/_usr_libexec_xfce4-screensaver_slideshow.1000.crash); mkdir -p "$um_crash/run/systemd/system"
sem_systemd=$(maquina semsystemd var/run/reboot-required)

: > "$tmp/falso/sistema"; : > "$tmp/falso/usuario"
confere "máquina saudável: nenhuma linha" igual "" lvl9 "${com_falso[@]}" LVL9_RAIZ="$saudavel" -- saude_resumo
confere "sem falhas: lista de serviços vazia" igual "" lvl9 "${com_falso[@]}" LVL9_RAIZ="$saudavel" -- saude_servicos
confere "um relatório de crash, no singular" igual "1 relatório de crash" \
  lvl9 "${com_falso[@]}" LVL9_RAIZ="$um_crash" -- saude_resumo
confere "o programa sai do nome do relatório" igual "slideshow" lvl9 "${com_falso[@]}" LVL9_RAIZ="$um_crash" -- saude_crashes
confere "só .crash conta (não .upload)" igual $'wireplumber\nspotify' lvl9 "${com_falso[@]}" LVL9_RAIZ="$doente" -- saude_crashes
confere "reinício pendente aparece sozinho" igual "reinício pendente" lvl9 "${com_falso[@]}" LVL9_RAIZ="$sem_systemd" -- saude_resumo

echo "fwupd-refresh.service loaded failed failed Refresh fwupd metadata" > "$tmp/falso/sistema"
confere "um serviço com falha, no singular" igual "1 serviço com falha" \
  lvl9 "${com_falso[@]}" LVL9_RAIZ="$saudavel" -- saude_resumo
echo "snap.firmware-updater.firmware-notifier.service loaded failed failed Service for snap" > "$tmp/falso/usuario"
confere "serviços do sistema e do usuário, pelo nome" igual \
  $'fwupd-refresh.service\nsnap.firmware-updater.firmware-notifier.service' \
  lvl9 "${com_falso[@]}" LVL9_RAIZ="$saudavel" -- saude_servicos
confere "tudo junto, numa linha só" igual "2 serviços com falha · 2 relatórios de crash · reinício pendente" \
  lvl9 "${com_falso[@]}" LVL9_RAIZ="$doente" -- saude_resumo
confere "sem systemd (container), não consulta serviços" igual "reinício pendente" \
  lvl9 "${com_falso[@]}" LVL9_RAIZ="$sem_systemd" -- saude_resumo
mkdir -p "$tmp/sem-systemctl"   # um PATH com o básico, mas sem o systemctl
for b in bash dirname id date tput; do [[ -x /usr/bin/$b ]] && ln -s "/usr/bin/$b" "$tmp/sem-systemctl/$b"; done
confere "sem systemctl no PATH, não quebra" igual "" lvl9 PATH="$tmp/sem-systemctl" LVL9_RAIZ="$saudavel" -- saude_servicos

# O aviso do terminal: aparece com problema, some sem problema e quando desligado
aviso_rc() {   # aviso_rc raiz [avisos=off] → o que o rc mostraria ao abrir o terminal
  local r=$1 pref=${2:-}
  mkdir -p "$tmp/sis/lib" "$tmp/home/.config/lvl9"
  cp "$raiz/lib/saude.sh" "$tmp/sis/lib/"
  printf '%s\n' "$pref" > "$tmp/home/.config/lvl9/config"
  env -i HOME="$tmp/home" "${com_falso[@]}" LVL9_RAIZ="$r" bash -c '
    eval "$(sed -n "/^__lvl9_pref()/p; /^__lvl9_avisos()/,/^}/p" "$0/config/bash/rc")"
    LVL9_SISTEMA=$1; __lvl9_pref avisos && __lvl9_avisos
    declare -F saude_resumo >/dev/null && echo "VAZOU: função no terminal"; true' "$raiz" "$tmp/sis" \
    | sed 's/\x1b\[[0-9;]*m//g'
}
confere "terminal: avisa quando há problema" igual \
  " ⚠  sistema: 2 serviços com falha · 2 relatórios de crash · reinício pendente — lvl9 doctor mostra os detalhes" \
  aviso_rc "$doente"
: > "$tmp/falso/sistema"; : > "$tmp/falso/usuario"
confere "terminal: silêncio quando está tudo bem" igual "" aviso_rc "$saudavel"
confere "terminal: lvl9 avisos off desliga" igual "" aviso_rc "$doente" "avisos=off"
rm -f "$tmp/home/.config/lvl9/config"

# O ajuste do firmware-notifier é só para quem já tem o snap, e só no desktop
so_com_snap() {
  grep -q 'if \[\[ -e \$notificador \]\]' "$raiz/install/80-desktop.sh" || { echo "80-desktop.sh instala o ajuste sem testar o snap"; return 1; }
  ! grep -rn 'snap install\|apt_instala.*snapd' "$raiz/install" || { echo "um passo instala snap"; return 1; }
  ! grep -ln '10-lvl9-notificacoes' "$raiz"/install/*.sh | grep -v '80-desktop.sh' || { echo "ajuste fora do passo de desktop"; return 1; }
}
confere "ajuste do firmware-notifier: só com o snap e só no desktop" so_com_snap
confere "ajuste do firmware-notifier: uma condição só, com busctl" bash -c '[[ $(grep -c "^ExecCondition=" "$1") == 1 ]] && grep -q "busctl --user call .* NameHasOwner s org.freedesktop.Notifications" "$1"' _ "$raiz/config/systemd/10-lvl9-notificacoes.conf"

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
