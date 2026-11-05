# Pacotes base do sistema, fuso America/Sao_Paulo com NTP e locale pt_BR.UTF-8
executa() {
  lvl9_os
  como_root apt-get update -q -o DPkg::Lock::Timeout=300
  apt_instala curl wget git unzip xz-utils bzip2 ca-certificates gnupg vim tmux bash-completion \
    iproute2 tzdata locales python3 less man-db file procps psmisc lsof rsync tree

  # Fuso horário: timedatectl quando há systemd; senão (container), o link do /etc/localtime
  if tem_systemd && tem timedatectl; then
    como_root timedatectl set-timezone America/Sao_Paulo
    apt_instala_existentes systemd-timesyncd
    como_root timedatectl set-ntp true || aviso "não foi possível ligar o NTP"
  else
    como_root ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
    echo America/Sao_Paulo | como_root tee /etc/timezone >/dev/null
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
  fi
  info "locale pt_BR.UTF-8 disponível"
}
