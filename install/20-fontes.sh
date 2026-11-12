# Nerd Fonts (JetBrainsMono e CaskaydiaMono) em /usr/local/share/fonts/lvl9, para todos os usuários
executa() {
  local nome pasta dir tmp novas=0
  apt_instala xz-utils fontconfig
  for nome in jetbrainsmono caskaydiamono; do
    pasta=$(awk -v n="$nome" '$1 == n {print $7}' "$LVL9_REPO/ferramentas.tsv")
    dir=/usr/local/share/fonts/lvl9/$pasta
    if bin_atualizado "$nome" && [[ -d $dir ]]; then info "$pasta já está na versão do lock"; continue; fi
    tmp=$(mktemp -d)
    baixa_verificado "$nome" "$tmp/fonte.tar.xz"
    extrai "$tmp/fonte.tar.xz" "$tmp/x" fonte.tar.xz
    como_root rm -rf "$dir"
    como_root mkdir -p "$dir"
    find "$tmp/x" -name '*.ttf' -print0 | xargs -0 sudo -n install -m 644 -t "$dir"
    rm -rf "$tmp"
    marca_versao "$nome"
    info "$pasta Nerd Font $LOCK_VERSAO ($(find "$dir" -name '*.ttf' | wc -l) arquivos)"
    mudou "$pasta Nerd Font $LOCK_VERSAO"; novas=1
  done
  if (( novas )); then como_root fc-cache -f /usr/local/share/fonts/lvl9 >/dev/null; fi
}
