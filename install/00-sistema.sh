# Pacotes base do sistema, fuso America/Sao_Paulo com NTP e locale pt_BR.UTF-8
executa() {
  lvl9_os
  # (os índices do apt são atualizados pelo apt_instala, e só quando falta algum pacote)
  apt_instala curl wget git unzip xz-utils bzip2 ca-certificates gnupg vim tmux bash-completion \
    iproute2 tzdata locales python3 less man-db file procps psmisc lsof rsync tree

  # Fuso horário: timedatectl quando há systemd; senão (container), o link do /etc/localtime
  if [[ $(readlink -f /etc/localtime) == */America/Sao_Paulo ]]; then
    :   # já está no fuso
  elif tem_systemd && tem timedatectl; then
    como_root timedatectl set-timezone America/Sao_Paulo
    mudou "fuso horário: America/Sao_Paulo"
  else
    como_root ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
    echo America/Sao_Paulo | como_root tee /etc/timezone >/dev/null
    mudou "fuso horário: America/Sao_Paulo"
  fi
  if tem_systemd && tem timedatectl; then
    apt_instala_existentes systemd-timesyncd
    if [[ $(timedatectl show -p NTP --value 2>/dev/null) != yes ]]; then
      if como_root timedatectl set-ntp true; then mudou "NTP ligado"; else aviso "não foi possível ligar o NTP"; fi
    fi
  fi
  info "fuso: $(readlink -f /etc/localtime | sed 's|.*/zoneinfo/||') ($(date +%Z))"

  # Gera o pt_BR.UTF-8 se faltar (não muda o idioma padrão do sistema)
  if ! locale -a 2>/dev/null | grep -qiE '^pt_BR\.utf-?8$'; then
    if [[ $OS_ID == ubuntu ]]; then
      como_root locale-gen pt_BR.UTF-8
    else
      como_root sed -i 's/^# *\(pt_BR\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
      grep -q '^pt_BR\.UTF-8 UTF-8' /etc/locale.gen || echo 'pt_BR.UTF-8 UTF-8' | como_root tee -a /etc/locale.gen >/dev/null
      como_root locale-gen
    fi
    mudou "locale pt_BR.UTF-8 gerado"
  fi
  info "locale pt_BR.UTF-8 disponível"
}
