#!/usr/bin/env bash
# tests/comandos.sh — roda cada comando do lvl9 num terminal interativo de verdade (pty) e
# confere o código de saída e o que ele mostra. Funciona na máquina instalada e nos containers.
#   bash tests/comandos.sh
set -uo pipefail

SISTEMA=/usr/local/share/lvl9
ok=0 erro=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# roda "descrição" "comando" "regex esperada na saída"
roda() {
  local desc=$1 cmd=$2 espera=${3:-.} saida
  saida=$(cd "$tmp" && LVL9_SILENCIO=1 timeout 60 script -qc "bash -i -c $(printf '%q' "$cmd; echo __SAIDA=\$?")" /dev/null 2>&1 \
          | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b\][^\a]*\a//g')
  if [[ $saida == *"__SAIDA=0"* ]] && grep -qE -- "$espera" <<< "$saida"; then
    printf '  ✔ %s\n' "$desc"; (( ok++ ))
  else
    printf '  ✘ %s\n' "$desc"; grep -v '__SAIDA' <<< "$saida" | tail -4 | sed 's/^/      /'; (( erro++ ))
  fi
}

echo "== executáveis (ELF de verdade e respondem --version) =="
while read -r nome _ tipo _ _ _ instala; do
  [[ -z $nome || $nome == \#* || $tipo != bin ]] && continue
  for b in ${instala//,/ }; do
    b=/usr/local/bin/${b#*:}
    [[ -e $b ]] || continue   # grupo não escolhido
    # (sem "| grep -q": com pipefail, o grep fecha o pipe e o programa "falha" por SIGPIPE)
    if [[ $(head -c4 "$b" | od -An -c | tr -d ' ') == '177ELF' ]] && v=$(timeout 10 "$b" --version 2>&1) && [[ -n $v ]]; then
      printf '  ✔ %s\n' "${b##*/}"; (( ok++ ))
    else
      printf '  ✘ %s (não é executável ou não responde --version)\n' "$b"; (( erro++ ))
    fi
  done
done < "$SISTEMA/ferramentas.tsv"

echo "== aliases do catálogo (inglês e pt-BR) =="
while IFS=$'\t' read -r tipo en pt cmd _; do
  [[ $tipo == alias ]] || continue
  exe=${cmd#sudo }; exe=${exe%% *}
  for a in "$en" "$pt"; do
    [[ $a == - || $a == "$cmd" ]] && continue
    roda "alias $a → $cmd" "type $exe >/dev/null && alias $a" "$a="
  done
done < <(grep -v '^#' "$SISTEMA/bash/comandos.tsv")

echo "== comandos rodando de verdade =="
mkdir -p "$tmp/proj/sub" && echo 'echo oi' > "$tmp/proj/arq.sh" && git -C "$tmp/proj" init -q
roda "sys / sistema (fastfetch)"   "sys"                        "sistema"
roda "sistema"                      "sistema"                    "kernel"
roda "disk / disco (duf)"           "disco"                      "[Mm]ounted|MOUNTED|local device"
roda "usage / pasta (dust)"         "pasta -d 1 $SISTEMA"        "starship"
roda "proc / processos (procs)"     "processos --pager disable bash" "bash"
roda "ports / portas (ss)"          "portas"                     "Netid|State|LISTEN"
roda "examples / exemplos (tldr)"   "exemplos tar"               "tar"
roda "scan / varrer (nmap)"         "varrer 127.0.0.1"           "Nmap"
roda "dns (doggo)"                  "dns example.com"            "example.com"
roda "atualiza-ip"                  "atualiza-ip"                "LAN:"
roda "tema (preview dos temas)"     "tema"                       "tokyo-night"
roda "compactar + extrair"          "cd proj && compactar sub && command rm -r sub && extrair sub.tar.gz && test -d sub" .
roda "ls (eza)"                     "ls $SISTEMA"                "bash"
roda "lt (árvore)"                  "lt $SISTEMA/bash"           "rc"
roda "cat (bat)"                    "cat proj/arq.sh"            "echo oi"
roda "top → btop"                   "alias top"                  "btop"
roda "cd com zoxide"                "zoxide add $SISTEMA && cd ~ && cd lvl9 && pwd" "share/lvl9"
roda "zoxide ligado ao prompt"      "echo \"\$PROMPT_COMMAND\""   "__zoxide_hook"
roda "histórico gravado a cada comando" "echo \"\$PROMPT_COMMAND\"" "history -a"
roda "mkcd"                         "mkcd novo/fundo && pwd"     "novo/fundo"
roda "bak"                          "bak proj/arq.sh && ls proj" "arq.sh.bak-"
roda "gs (git status)"              "cd proj && gs"              "No commits|##"
roda "Alt+H: lista do catálogo"     "__lvl9_ajuda_lista"         "disco"
roda "Alt+H: tecla ligada"          "bind -X"                    "__lvl9_ajuda_widget"
roda "Ctrl+R/Ctrl+T do fzf"         "bind -X"                    "fzf"
roda "dica do dia"                  "__lvl9_dica"                "dica"
roda "prompt (starship ou bash-parrot)" "declare -F starship_precmd __prompt_parrot" "starship_precmd|__prompt_parrot"
roda "lvl9 versao"                  "lvl9 versao"                "lvl9"
roda "lvl9 dicas off/on"            "lvl9 dicas off && lvl9 dicas on" "dicas: on"
roda "lvl9 fastfetch off/on"        "lvl9 fastfetch off && lvl9 fastfetch on" "fastfetch: on"
roda "lvl9 avisos off/on"           "lvl9 avisos off && lvl9 avisos on" "avisos: on"
roda "aviso de saúde não deixa funções no terminal" "__lvl9_avisos; ! declare -F saude_resumo"
roda "lvl9 diff"                    "lvl9 diff"                  "iguais"
# numa máquina de verdade pode haver aviso do sistema (reinício pendente...): não é problema do lvl9
roda "lvl9 doctor"                  "lvl9 doctor"                "tudo certo|lvl9 em ordem"

echo "RESULTADO COMANDOS: $ok ok, $erro erro(s)"
exit $(( erro > 0 ))
