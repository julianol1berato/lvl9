# lib/saude.sh — saúde do host: serviços com falha, relatórios de crash e reinício pendente.
# Usado pelo "lvl9 doctor" (com os detalhes) e pelo rc (uma linha ao abrir o terminal).
#
# O lvl9 avisa, não conserta: aqui só se lê, sem sudo, sem rede e sem nada em segundo plano.
# Uma checagem só entra se for instantânea, se der para agir sobre ela e se nenhum outro
# lugar já a mostrar. Vale igual no desktop e no servidor: nada aqui depende de interface.

# Unidades do systemd com falha, do sistema e do usuário, uma por linha
saude_servicos() {
  local r=${LVL9_RAIZ:-}   # só os testes trocam a raiz
  [[ -d $r/run/systemd/system ]] && command -v systemctl &>/dev/null || return 0
  { systemctl --failed --no-legend --plain 2>/dev/null
    systemctl --user --failed --no-legend --plain 2>/dev/null   # sem sessão (sudo -i), fica vazio
  } | awk 'NF {print $1}' | sort -u
}

# Programas com relatório de crash pendente em /var/crash (apport), um por linha
saude_crashes() {
  local r=${LVL9_RAIZ:-} f n
  while IFS= read -r f; do
    n=${f##*/}; n=${n%.crash}; n=${n%.*}   # _usr_bin_wireplumber.105.crash → _usr_bin_wireplumber
    echo "${n##*_}"
  done < <(compgen -G "$r/var/crash/*.crash")
}

# O sistema pede um reinício (kernel, libc ou firmware novos)?
saude_reinicio() { [[ -e ${LVL9_RAIZ:-}/var/run/reboot-required ]]; }

# Uma linha com o que há de errado; nada quando está tudo bem
saude_resumo() {
  local s c partes=()
  s=$(saude_servicos | grep -c .)
  c=$(saude_crashes | grep -c .)
  if (( s == 1 )); then partes+=("1 serviço com falha"); elif (( s > 1 )); then partes+=("$s serviços com falha"); fi
  if (( c == 1 )); then partes+=("1 relatório de crash"); elif (( c > 1 )); then partes+=("$c relatórios de crash"); fi
  if saude_reinicio; then partes+=("reinício pendente"); fi
  (( ${#partes[@]} )) || return 0
  printf '%s' "${partes[0]}"
  if (( ${#partes[@]} > 1 )); then printf ' · %s' "${partes[@]:1}"; fi
  printf '\n'
}
