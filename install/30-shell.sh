# Bash do lvl9 (usuário e root): rc compartilhado, prompt com temas, aliases, comando lvl9
executa() {
  local f alvo h
  # Cópia do lvl9 usada por todos, em /usr/local/share/lvl9 (do root: o root nunca lê
  # config de um home, porque temas do starship podem executar comandos)
  for f in rc prompt.bash comandos.tsv; do copia "config/bash/$f" "$LVL9_SISTEMA/bash/$f"; done
  for f in "$LVL9_REPO"/config/starship/*.toml; do copia "$f" "$LVL9_SISTEMA/starship/${f##*/}"; done
  copia config/fastfetch.jsonc "$LVL9_SISTEMA/fastfetch.jsonc"
  for f in lib/comum.sh lib/ui.sh lib/desktop.sh lib/saude.sh ferramentas.tsv versions.lock; do
    copia "$f" "$LVL9_SISTEMA/$f"
  done
  copia bin/lvl9 /usr/local/bin/lvl9 755
  git -C "$LVL9_REPO" describe --tags --always 2>/dev/null | como_root tee "$LVL9_SISTEMA/VERSAO" >/dev/null || true

  for alvo in usuario root; do
    h=$(home_de "$alvo")
    # ~/.bashrc: só é criado se ainda não carrega o lvl9 (depois disso é do usuário)
    if como_alvo "$alvo" grep -qs 'lvl9/bash/rc' "$h/.bashrc"; then
      info "$alvo: ~/.bashrc já carrega o lvl9 (mantido)"
    else
      copia config/bash/bashrc "$h/.bashrc"
      info "$alvo: ~/.bashrc criado (o anterior foi para o backup)"
    fi
    # Tema do prompt e preferências (fastfetch/dicas/avisos ligados por padrão)
    como_alvo "$alvo" mkdir -p "$h/.config/lvl9"
    echo "${LVL9_TEMA:-tokyo-night}" | como_alvo "$alvo" tee "$h/.config/lvl9/tema" >/dev/null
    como_alvo "$alvo" test -f "$h/.config/lvl9/config" \
      || printf 'fastfetch=on\ndicas=on\navisos=on\n' | como_alvo "$alvo" tee "$h/.config/lvl9/config" >/dev/null
    como_alvo "$alvo" rm -f "$h/.config/starship/tema-atual"   # formato anterior ao lvl9
  done

  # Versão anterior ao lvl9 (prompt em /usr/local/share/starship): já migrada
  # (terminais já abertos ainda apontam para os temas antigos: fica um link até reabrirem)
  if [[ -d /usr/local/share/starship && ! -L /usr/local/share/starship/temas ]]; then
    faz_backup /usr/local/share/starship
    como_root rm -rf /usr/local/share/starship
    como_root mkdir -p /usr/local/share/starship
    como_root ln -s "$LVL9_SISTEMA/starship" /usr/local/share/starship/temas
    como_root ln -s "$LVL9_SISTEMA/bash/prompt.bash" /usr/local/share/starship/prompt.bash
  fi
  info "tema do prompt: ${LVL9_TEMA:-tokyo-night}"
}
