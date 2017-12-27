#!/bin/bash
install () {
  OSID=$(cat /etc/*-release 2>/dev/null | awk -F'=' '/^ID=/ { print $2; count++ } END { if (!count) print "Unknown" }')
  case "$OSID" in
  debian|osmc|linuxmint)
    [[ $EUID -ne 0 ]] && sudo apt-get -y install zsh || apt-get -y install zsh
    ;;
  arch|archarm)
    [[ $EUID -ne 0 ]] && sudo pacman -S --noconfirm zsh || pacman -S --noconfirm zsh
    ;;
  *)
    echo "Distribution $OSID not supported"
esac
}

#command -v zsh >/dev/null 2>&1 || install
#[[ $EUID -ne 0 ]] && sudo usermod -s /bin/zsh $USER || usermod -s /bin/zsh $USER
#wget cz0.cz/chozsh-latest.tar.gz -q -O - | tar --owner=$UID --group=$GID --no-same-owner -xz -C ~
wget cz0.cz/bettershell-latest.tar.gz -q -O - | tar -xz -C ~
#echo -e 'export SHELL=`which zsh`'"\n"'[ -z "$ZSH_VERSION" ] && exec "$SHELL" -l' > ~/.profile

CMD='[ -f ~/bshell/bb.sh ] && . ~/bshell/bb.sh'
grep -q "$CMD" ~/.bashrc || echo "$CMD" >> ~/.bashrc
