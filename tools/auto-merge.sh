#!/usr/bin/env bash
# tools/auto-merge.sh — merge automático dos PRs do próprio dono do repositório.
#
# Entra sozinho o PR para a main que:
#   · foi aberto pelo dono do repositório ou pelo bot de versões (o workflow deste repo);
#   · vem de uma branch deste repositório, não de fork (só quem tem escrita faz push nela);
#   · não é rascunho e não tem o rótulo "segurar";
#   · está há ESPERA_HORAS (24) sem commits novos: é a sua janela para olhar ou segurar;
#   · tem os testes do GitHub (shellcheck e testes rápidos) rodados e todos verdes.
# PRs de outras pessoas nunca entram sozinhos: ficam para a sua aprovação e o seu merge.
# PRs que mexem em .github/workflows também ficam para o merge manual: o token do Actions
# não pode alterar workflows (e é bom que um workflow não mude os outros sozinho).
#
# Uso: tools/auto-merge.sh [--simula]   (no GitHub Actions roda de hora em hora)
set -euo pipefail
espera=${ESPERA_HORAS:-24}
simula=0; [[ ${1:-} == --simula ]] && simula=1
repo=${GH_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}
dono=${repo%%/*}
corte=$(( $(date +%s) - espera * 3600 ))
falhas=0
log() { printf '%s\n' "$*"; }

# estado dos checks do commit mais recente do PR: verde | rodando | falhou | sem-testes
checks() {
  gh pr view "$1" -R "$repo" --json statusCheckRollup --jq '
    [.statusCheckRollup[] | {
       n: (.name // .context),
       s: (.status // (if (.state == "PENDING" or .state == "EXPECTED") then "PENDING" else "COMPLETED" end)),
       c: (.conclusion // .state)}] as $c
    | if any($c[]; .s != "COMPLETED") then "rodando"
      elif any($c[]; .c | IN("SUCCESS", "SKIPPED", "NEUTRAL") | not) then "falhou"
      elif (any($c[]; .n == "shellcheck") and any($c[]; .n | startswith("testes"))) then "verde"
      else "sem-testes" end'
}

while IFS=$'\t' read -r n autor fork rascunho segurar sha branch titulo; do
  pr="#$n $titulo"
  if [[ $autor != "$dono" && $autor != app/github-actions ]]; then log "· $pr: de $autor, espera a sua aprovação"; continue; fi
  if [[ $fork == true ]]; then log "· $pr: vem de fork, espera a sua aprovação"; continue; fi
  if [[ $rascunho == true ]]; then log "· $pr: rascunho"; continue; fi
  if [[ $segurar == true ]]; then log "· $pr: segurado (rótulo segurar)"; continue; fi
  ultimo=$(gh api "repos/$repo/commits/$sha" --jq .commit.committer.date)
  if (( $(date -d "$ultimo" +%s) > corte )); then
    log "· $pr: último commit em $ultimo, ainda dentro das ${espera}h"; continue
  fi
  if [[ $(gh pr view "$n" -R "$repo" --json files --jq '[.files[].path | select(startswith(".github/workflows/"))] | length') != 0 ]]; then
    log "· $pr: mexe em .github/workflows, merge manual"; continue
  fi
  estado=$(checks "$n")
  if [[ $estado != verde ]]; then log "· $pr: testes $estado"; continue; fi
  if (( simula )); then log "✔ $pr: entraria agora (simulação)"; continue; fi
  # o sha garante que entra exatamente o commit avaliado (um push no meio faz o merge falhar)
  if gh api -X PUT "repos/$repo/pulls/$n/merge" -f merge_method=rebase -f sha="$sha" >/dev/null; then
    gh api -X DELETE "repos/$repo/git/refs/heads/$branch" >/dev/null 2>&1 || true
    log "✔ $pr: merge feito"
  else
    log "✘ $pr: o merge falhou (conflito com a main?)"; (( falhas++ )) || true
  fi
done < <(gh pr list -R "$repo" --base main --state open --limit 50 \
  --json number,author,isCrossRepository,isDraft,labels,headRefOid,headRefName,title \
  --jq '.[] | [.number, .author.login, .isCrossRepository, .isDraft,
               ([.labels[].name] | index("segurar") != null),
               .headRefOid, .headRefName, .title] | @tsv')

(( falhas == 0 ))
