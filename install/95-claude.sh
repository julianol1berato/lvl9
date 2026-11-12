# Claude Code + statusbar-claude + herdr, no usuário e no root.
# Claude Code e herdr vêm dos instaladores oficiais (conferem o próprio sha256 e se atualizam
# sozinhos); a statusbar vem do commit fixado no versions.lock.
executa() {
  local alvo h tmp
  tmp=$(mktemp -d)
  lock_le statusbar
  git clone -q "$LOCK_URL" "$tmp/statusbar"
  git -C "$tmp/statusbar" -c advice.detachedHead=false checkout -q "$LOCK_SHA"
  [[ $(git -C "$tmp/statusbar" rev-parse HEAD) == "$LOCK_SHA" ]] || { falha "commit da statusbar não confere"; return 1; }
  chmod -R a+rX "$tmp"   # o root também lê esta cópia

  for alvo in usuario root; do
    h=$(home_de "$alvo")
    if como_alvo "$alvo" test -x "$h/.local/bin/claude"; then
      info "$alvo: Claude Code já instalado"
    else
      # no root é de propósito: o instalador oficial exige essa confirmação para rodar com sudo
      como_alvo "$alvo" env CLAUDE_INSTALL_ALLOW_SUDO=1 bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
      mudou "$alvo: Claude Code instalado"
    fi
    if como_alvo "$alvo" test -x "$h/.local/bin/herdr"; then
      info "$alvo: herdr já instalado"
    else
      como_alvo "$alvo" sh -c 'curl -fsSL https://herdr.dev/install.sh | sh'
      mudou "$alvo: herdr instalado"
    fi
    como_alvo "$alvo" "$h/.local/bin/herdr" integration install claude \
      || aviso "$alvo: integração herdr ↔ Claude não instalada (rode: herdr integration install claude)"
    # A statusbar faz backup e só mexe na chave statusLine do ~/.claude/settings.json
    como_alvo "$alvo" bash "$tmp/statusbar/install.sh"
  done
  rm -rf "$tmp"
}
