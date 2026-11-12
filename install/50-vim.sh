# Vim com o halcyon-vim (commit fixado), vim-plug e :FZF, no usuário e no root
executa() {
  local tmp alvo h antes depois
  apt_instala vim git
  tmp=$(mktemp -d)

  # halcyon-vim: o hash do commit no lock garante que o conteúdo é exatamente o revisado
  lock_le halcyon-vim
  git clone -q "$LOCK_URL" "$tmp/halcyon"
  git -C "$tmp/halcyon" -c advice.detachedHead=false checkout -q "$LOCK_SHA"
  [[ $(git -C "$tmp/halcyon" rev-parse HEAD) == "$LOCK_SHA" ]] || { falha "commit do halcyon-vim não confere"; return 1; }
  baixa_verificado vim-plug "$tmp/plug.vim"
  baixa_verificado fzf-vim "$tmp/fzf.vim"
  copia "$tmp/fzf.vim" "$LVL9_SISTEMA/vim/fzf.vim"

  for alvo in usuario root; do
    h=$(home_de "$alvo")
    copia "$tmp/halcyon/.vimrc" "$h/.vimrc"
    copia "$tmp/halcyon/colors/halcyon.vim" "$h/.vim/colors/halcyon.vim"
    copia "$tmp/plug.vim" "$h/.vim/autoload/plug.vim"
    copia config/vim/lvl9-fzf.vim "$h/.vim/plugin/lvl9-fzf.vim"
    copia config/vim/lvl9-node.vim "$h/.vim/plugin/lvl9-node.vim"
    como_alvo "$alvo" rm -f "$h/.vim/plugin/fzf-debian.vim"   # versão anterior ao lvl9
    antes=$(como_alvo "$alvo" ls "$h/.vim/plugged" 2>/dev/null | wc -l)
    como_alvo "$alvo" vim -E -s -u "$h/.vimrc" -i NONE -c 'PlugInstall --sync' -c 'qa!' </dev/null \
      || aviso "$alvo: PlugInstall terminou com aviso (rode :PlugInstall no vim se faltar algo)"
    depois=$(como_alvo "$alvo" ls "$h/.vim/plugged" | wc -l)
    info "$alvo: $depois plugins"
    (( antes == depois )) || mudou "$alvo: plugins do vim, de $antes para $depois"
  done
  rm -rf "$tmp"
}
