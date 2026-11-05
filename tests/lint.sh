#!/usr/bin/env bash
# tests/lint.sh — shellcheck em todos os scripts do lvl9. Roda no GitHub e no tools/ci.sh.
# Sem o shellcheck instalado, usa a imagem oficial dele em Docker.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
arquivos=(boot.sh install.sh bin/lvl9 lib/*.sh install/*.sh tools/*.sh tests/*.sh
          config/bash/rc config/bash/prompt.bash)
opcoes=(-x -S warning --shell=bash -e "SC2034,SC2088,SC2164")
if command -v shellcheck >/dev/null; then
  shellcheck "${opcoes[@]}" "${arquivos[@]}"
else
  docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:stable "${opcoes[@]}" "${arquivos[@]}"
fi
echo "shellcheck ok: ${#arquivos[@]} arquivos"
