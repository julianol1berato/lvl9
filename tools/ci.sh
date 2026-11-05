#!/usr/bin/env bash
# tools/ci.sh — o CI do lvl9 roda na sua máquina. Com tudo verde, faz o push e marca o commit
# com o status "signoff" verde no GitHub, que a main exige para o merge.
#
# Testa o commit (HEAD), não a pasta: os testes rodam numa cópia dele (git archive), então dá
# para continuar editando enquanto rodam. Nesta ordem:
#   1. tests/lint.sh      shellcheck (o mesmo do GitHub)
#   2. tests/rapidos.sh   testes rápidos, sem internet (os mesmos do GitHub)
#   3. tests/docker.sh    instalação completa nas 4 imagens, servidor e desktop em paralelo
#                         (~40 min). Cada imagem que falha ganha uma segunda tentativa, porque
#                         às vezes um download falha sozinho.
# Passou tudo: push do commit testado (se ele ainda não está no GitHub) e "signoff" verde.
# Falhou: "signoff" vermelho (se o commit já está no GitHub) e nada de push.
# O status é o mesmo do gh signoff (github.com/basecamp/gh-signoff): os dois se entendem.
#
# Uso: tools/ci.sh            tudo, sobre o commit; no fim, push + signoff
#      tools/ci.sh --rapido   só lint e rápidos, sobre a pasta: sem Docker, sem push e sem signoff
#      PR do bot de versões ou de outra pessoa: gh pr checkout N && tools/ci.sh
set -euo pipefail
rapido=0
case ${1:-} in
  "") ;;
  --rapido) rapido=1 ;;
  *) echo "uso: tools/ci.sh [--rapido]" >&2; exit 2 ;;
esac
cd -- "$(dirname -- "$0")/.."
imagens=(debian:12 debian:13 ubuntu:24.04 ubuntu:26.04)
dir=${XDG_CACHE_HOME:-$HOME/.cache}/lvl9-ci
sha=$(git rev-parse HEAD)
branch=$(git symbolic-ref --short -q HEAD || true)
quem=$(git config user.name || echo "?")
erro() { printf '✘ %s\n' "$*" >&2; exit 1; }

if (( ! rapido )); then
  [[ -z $(git status --porcelain) ]] || erro "há mudanças fora do commit: o CI testa o commit, então faça o commit antes"
  [[ -n $branch && $branch != main ]] || erro "rode numa branch de PR, não na main (git switch -c nome)"
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
fi
no_github() { gh api "repos/$repo/commits/$sha" --silent 2>/dev/null; }
sinal() {   # sinal success|failure descrição → status "signoff" no commit testado
  gh api "repos/$repo/statuses/$sha" -f state="$1" -f context=signoff -f description="${2:0:140}" --silent
}
falhou() {
  if (( ! rapido )) && no_github; then sinal failure "$quem: tools/ci.sh falhou em $1" || true; fi
  erro "$1 falhou: sem push e sem signoff"
}

if (( rapido )); then
  fonte=$PWD   # o --rapido serve para ir testando: vale a pasta, com o que ainda não tem commit
  echo "== pasta $(git rev-parse --show-toplevel) (com o que não tem commit) =="
else
  rm -rf "$dir"; mkdir -p "$dir"
  git archive HEAD | tar -x -C "$dir"
  fonte=$dir
  echo "== ${sha:0:7} ($branch): $(git log -1 --format=%s) =="
fi
inicio=$SECONDS

echo "== lint =="
"$fonte/tests/lint.sh" || falhou "lint"
echo "== testes rápidos =="
"$fonte/tests/rapidos.sh" || falhou "testes rápidos"
if (( rapido )); then echo "✔ lint e rápidos ok (sem Docker: sem push e sem signoff)"; exit 0; fi

roda_modo() {   # roda_modo modo → uma linha do tests/docker.sh por imagem
  local modo=$1 img t saida log
  for img in "${imagens[@]}"; do
    log="$dir/tests/logs/${img//[:\/]/-}-$modo.log"
    for t in 1 2; do
      if saida=$(LVL9_MODO=$modo "$dir/tests/docker.sh" "$img"); then
        if (( t == 2 )); then saida+="  (2ª tentativa)"; fi
        echo "$saida"; break
      fi
      if (( t == 1 )); then mv "$log" "${log%.log}-1a-tentativa.log"; else echo "$saida"; fi
    done
  done
}
echo "== instalação completa: ${imagens[*]}, servidor e desktop em paralelo (~40 min) =="
echo "   logs em $dir/tests/logs/"
roda_modo servidor | tee "$dir/servidor.txt" &
roda_modo desktop | tee "$dir/desktop.txt" &
wait
ok=$(cat "$dir/servidor.txt" "$dir/desktop.txt" | grep -c '✔' || true)
total=$(( ${#imagens[@]} * 2 ))
(( ok == total )) || falhou "instalação completa ($ok de $total)"
minutos=$(( (SECONDS - inicio) / 60 ))

if ! no_github; then
  echo "== push =="
  # o commit testado, mesmo que você tenha feito outros commits enquanto os testes rodavam
  git push -q origin "$sha:refs/heads/$branch"
  git rev-parse -q --verify "$branch@{upstream}" >/dev/null || git branch -q --set-upstream-to="origin/$branch" "$branch"
fi
sinal success "$quem: tools/ci.sh passou: lint, rápidos e $total instalações (${minutos}min)"
echo "✔ tudo verde em ${minutos}min: ${sha:0:7} está no GitHub com o signoff verde"
gh pr view "$branch" --json url -q .url 2>/dev/null || echo "   abra o PR: gh pr create"
