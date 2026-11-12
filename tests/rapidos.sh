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
  local trecho; trecho=$(sed -n '/^if (( pergunta_xfce && ! atualiza )); then$/,/^fi$/p' "$raiz/install.sh")
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
tudo=(LVL9_GRUPOS="base dev sysadmin rede" LVL9_XRDP=sim LVL9_TAILSCALE=sim LVL9_CLAUDE=sim)
confere "servidor: nada de fontes, XFCE ou xrdp" igual \
  "00-sistema.sh 10-ferramentas.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 60-git.sh 70-docker.sh 90-tailscale.sh 95-claude.sh " \
  passos LVL9_MODO=servidor LVL9_RAIZ="$servidor" "${tudo[@]}"
confere "outra interface (GNOME): fontes sim, XFCE e xrdp não" igual \
  "00-sistema.sh 10-ferramentas.sh 20-fontes.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 60-git.sh 70-docker.sh 90-tailscale.sh 95-claude.sh " \
  passos LVL9_RAIZ="$gnome" LVL9_MODO=servidor "${tudo[@]}"
confere "desktop: com fontes, XFCE e xrdp" igual \
  "00-sistema.sh 10-ferramentas.sh 20-fontes.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 60-git.sh 70-docker.sh 80-desktop.sh 85-xrdp.sh 90-tailscale.sh 95-claude.sh " \
  passos LVL9_MODO=desktop "${tudo[@]}"
confere "desktop sem xrdp escolhido: XFCE sim, xrdp não" igual \
  "00-sistema.sh 10-ferramentas.sh 20-fontes.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 80-desktop.sh " \
  passos LVL9_MODO=desktop LVL9_GRUPOS=base LVL9_XRDP=nao LVL9_TAILSCALE=nao LVL9_CLAUDE=nao
confere "desktop sem resposta sobre o xrdp: não instala" igual \
  "00-sistema.sh 10-ferramentas.sh 20-fontes.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh 80-desktop.sh " \
  passos LVL9_MODO=desktop LVL9_GRUPOS=base LVL9_TAILSCALE=nao LVL9_CLAUDE=nao
confere "xrdp escolhido num servidor não vale: é só do desktop" igual \
  "00-sistema.sh 10-ferramentas.sh 30-shell.sh 40-mise.sh 50-vim.sh 55-tmux.sh " \
  passos LVL9_MODO=servidor LVL9_RAIZ="$servidor" LVL9_GRUPOS=base LVL9_XRDP=sim LVL9_TAILSCALE=nao LVL9_CLAUDE=nao
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

# ─── Rodar de novo não reinstala ────────────────────────────────────
echo "== apt só quando falta pacote =="
# dpkg-query, sudo e apt-get falsos: "instalado" é o que está em $FALSO/instalados
cat > "$tmp/bin/dpkg-query" <<'EOF2'
#!/bin/sh
for p; do :; done   # o pacote é o último argumento
grep -qx "$p" "$FALSO/instalados" 2>/dev/null && printf installed
EOF2
cat > "$tmp/bin/sudo" <<'EOF2'
#!/bin/sh
[ "$1" = -n ] && shift
exec "$@"
EOF2
cat > "$tmp/bin/apt-get" <<'EOF2'
#!/bin/sh
echo "apt-get $*" >> "$FALSO/chamadas"
case " $* " in
  *" update "*) [ -e "$FALSO/update-falha" ] && exit 100; exit 0 ;;
  *" install "*) for p; do case $p in -*|install) ;; *) echo "$p" >> "$FALSO/instalados" ;; esac; done ;;
esac
EOF2
chmod +x "$tmp/bin/dpkg-query" "$tmp/bin/sudo" "$tmp/bin/apt-get"
zera() { rm -rf "$tmp/home/.local/state/lvl9" "$tmp/falso/chamadas" "$tmp/falso/update-falha"; printf '%s\n' "$@" > "$tmp/falso/instalados"; }
chamadas() { if [[ -e $tmp/falso/chamadas ]]; then grep -c "$1" "$tmp/falso/chamadas" || true; else echo 0; fi; }
mudancas() { cat "$tmp/home/.local/state/lvl9/mudancas" 2>/dev/null; }

zera vim tmux
confere "apt_falta lista só o que não está instalado" igual $'git\ncurl' lvl9 "${com_falso[@]}" -- apt_falta vim git tmux curl
lvl9 "${com_falso[@]}" -- apt_instala vim tmux >/dev/null 2>&1
confere "tudo instalado: o apt nem é chamado" igual "0" chamadas apt-get
confere "tudo instalado: nenhuma mudança registrada" igual "" mudancas
lvl9 "${com_falso[@]}" LVL9_CARIMBO=rodada1 -- apt_instala vim git curl >/dev/null 2>&1
confere "faltando pacote: um apt-get update antes" igual "1" chamadas "apt-get update"
confere "faltando pacote: instala só os que faltam" bash -c 'grep -q "install .* git curl$" "$1" && ! grep -q "install.* vim" "$1"' _ "$tmp/falso/chamadas"
confere "faltando pacote: a mudança é registrada" igual "pacotes instalados: git curl" mudancas
lvl9 "${com_falso[@]}" LVL9_CARIMBO=rodada1 -- apt_instala htop >/dev/null 2>&1
confere "mesma rodada: o apt-get update não se repete" igual "1" chamadas "apt-get update"
zera vim; : > "$tmp/falso/update-falha"
update_falha() {
  local s r; s=$(lvl9 "${com_falso[@]}" LVL9_CARIMBO=rodada2 -- apt_instala git 2>&1); r=$?
  grep -q '^  ! apt-get update falhou' <<< "$s" && [[ $r == 0 ]] || { echo "saída $r: $s"; return 1; }
}
confere "apt-get update com erro vira aviso e a instalação segue" update_falha
confere "…e o pacote foi instalado mesmo assim" grep -qx git "$tmp/falso/instalados"
sem_update_solto() {   # só o passo do Docker (repositório novo) chama apt-get update direto
  ! grep -ln 'apt-get update' "$raiz"/install/*.sh | grep -v '70-docker.sh' || { echo "apt-get update fora do apt_indices"; return 1; }
}
confere "nenhum passo roda apt-get update por conta própria" sem_update_solto

echo "== o que mudou de verdade =="
zera
echo um > "$tmp/origem.txt"
copia_duas() { lvl9 -- copia "$tmp/origem.txt" "$tmp/home/destino.txt" >/dev/null 2>&1; }
copia_duas
confere "arquivo novo: uma mudança" igual "~/destino.txt (novo)" mudancas
copia_duas
confere "copiar de novo o mesmo conteúdo: nada muda" igual "~/destino.txt (novo)" mudancas
echo dois > "$tmp/origem.txt"; copia_duas
confere "conteúdo diferente: atualizado, com backup" bash -c '[[ $(tail -n 1 "$1/.local/state/lvl9/mudancas") == "~/destino.txt (atualizado)" ]] && ls "$1"/.local/state/lvl9/backups/*/"$1"/destino.txt >/dev/null' _ "$tmp/home"

# ui_passo: mostra quantas mudanças o passo fez e os avisos dele
passo_falso() {   # passo_falso corpo → roda um passo de mentira e devolve a linha que a tela mostra
  mkdir -p "$tmp/repo/install" "$tmp/repo/lib"; cp "$raiz"/lib/*.sh "$tmp/repo/lib/"
  printf 'executa() {\n%s\n}\n' "$1" > "$tmp/repo/install/99-teste.sh"
  env -i HOME="$tmp/home" PATH=/usr/bin:/bin LVL9_AUTO=1 LVL9_REPO="$tmp/repo" bash -c '
    source "$LVL9_REPO/lib/comum.sh"; source "$LVL9_REPO/lib/ui.sh"; mkdir -p "$LVL9_ESTADO"; : > "$LVL9_LOG"; : > "$LVL9_MUDANCAS"
    ui_passo "Teste" 99-teste.sh' 2>&1 | sed 's/\x1b\[[0-9;]*m//g; s/ [0-9]*s$/ Ns/; s/\.\.\.*/…/'
}
confere "passo que não muda nada: sem mudanças" igual "   ✔ Teste … sem mudanças · Ns" passo_falso 'info "nada a fazer"'
confere "passo com uma mudança" igual "   ✔ Teste … 1 mudança · Ns" passo_falso 'mudou "uma coisa"'
confere "passo com duas mudanças e um aviso" igual $'   ✔ Teste … 2 mudanças · Ns\n       ! repositório fora do ar' \
  passo_falso 'mudou a; mudou b; aviso "repositório fora do ar"'

echo "== xrdp é uma escolha =="
# systemctl falso para o "is-enabled xrdp": habilitado só se existir $FALSO/xrdp-habilitado
cat > "$tmp/bin/systemctl" <<'EOF2'
#!/bin/sh
case " $* " in
  *" is-enabled "*) [ -e "$FALSO/xrdp-habilitado" ] ;;
  *" --user "*) cat "$FALSO/usuario" 2>/dev/null ;;
  *) cat "$FALSO/sistema" 2>/dev/null ;;
esac
EOF2
rm -f "$tmp/falso/xrdp-habilitado"
confere "LVL9_XRDP=sim vale" igual sim lvl9 "${com_falso[@]}" LVL9_XRDP=sim -- lvl9_xrdp
confere "LVL9_XRDP=nao vale, mesmo com o serviço habilitado" bash -c ': > "$1/xrdp-habilitado"; shift; [[ $("$@") == nao ]]' _ "$tmp/falso" \
  env -i HOME="$tmp/home" "${com_falso[@]}" LVL9_XRDP=nao bash -c 'source "$0/lib/comum.sh"; lvl9_xrdp' "$raiz"
confere "escolhas antigas, serviço habilitado: continua sim" igual sim lvl9 "${com_falso[@]}" -- lvl9_xrdp
rm -f "$tmp/falso/xrdp-habilitado"
confere "escolhas antigas, serviço desabilitado: fica não" igual nao lvl9 "${com_falso[@]}" -- lvl9_xrdp
confere "máquina nova, sem resposta: não" igual nao lvl9 "${com_falso[@]}" -- lvl9_xrdp
xrdp_pergunta() {
  grep -q 'ui_confirma "Instalar o xrdp (área de trabalho remota: abre a porta 3389 na rede)?" "$LVL9_XRDP"' "$raiz/install.sh" || { echo "falta a pergunta do xrdp"; return 1; }
  grep -q 'LVL9_XRDP=%s' "$raiz/install.sh" || { echo "a resposta do xrdp não é salva nas escolhas"; return 1; }
  grep -q '\$modo == desktop && \$(lvl9_xrdp) == sim' "$raiz/bin/lvl9" || { echo "o doctor cobra o xrdp de quem não escolheu"; return 1; }
}
confere "o instalador pergunta, salva, e o doctor só cobra de quem escolheu" xrdp_pergunta

echo "== lvl9 update não é uma reinstalação =="
update_enxuto() {
  grep -q 'LVL9_ATUALIZA=1 exec bash "$CLONE/install.sh"' "$raiz/bin/lvl9" || { echo "o lvl9 update não liga o modo de atualização"; return 1; }
  ! sed -n '/^cmd_update()/,/^}/p' "$raiz/bin/lvl9" | grep -nE 'ui_confirma|--[a-z]' | grep -v 'git \|--ff-only\|--oneline\|--abbrev-ref\|--tags\|--always' || { echo "o lvl9 update pergunta algo ou tem flag"; return 1; }
  grep -q 'if (( atualiza )); then ui_secao "Atualizando"; else ui_secao "Instalando"; fi' "$raiz/install.sh" || { echo "a seção não muda de nome na atualização"; return 1; }
  # as perguntas ficam todas dentro do "else" da atualização
  awk '/^if \(\( atualiza \)\); then$/ {d=1} /^fi   # fim das perguntas/ {d=0} !d && /ui_(multipla|uma) |ui_confirma "(Instalar o Tailscale|Instalar Claude|Começar)/' "$raiz/install.sh" | grep . && { echo "pergunta fora do bloco pulado na atualização"; return 1; }
  return 0
}
confere "update: usa as escolhas salvas, sem perguntas, e diz Atualizando" update_enxuto

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
