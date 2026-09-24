#!/bin/bash

# Where BetterBash keeps its files; the installer installs into the same variable.
BB_DIR="${BB_DIR:-$HOME/.bb}"

# --- a fetched tree installs itself, once ------------------------------------
# The fetch commands of the WebUI leave a BetterBash tree in ~/.bb/bb and nothing
# else about it happens there until that tree is asked to install itself, which is
# what sourcing its prompt/bb.sh does. A tree that has not been installed carries
# the file install-pending next to it, so the flag - and not a guess about whether
# this file is the installed one or a fetched one - is what says: install, then
# build the prompt. The flag is removed by the install, so every later sourcing of
# this file costs one test for a file that is not there.
#
# The install is run in a subshell on purpose: installbb.sh defines functions and
# options a shell of its own, and the shell that ends up wearing the prompt should
# not be the one that installed it.
#
# Only a tree under $BB_DIR installs, which is the second test: a checkout of this
# project worked on, or any other copy of these files, stays a directory of files.
#
# The tree is found from this file, so it is the tree whose prompt was sourced -
# wherever that was, and with whatever name.
BB_SELF=${BASH_SOURCE[0]}
case $BB_SELF in
  */*) BB_TREE=$(cd -- "${BB_SELF%/*}/.." 2>/dev/null && pwd -P) ;;
  # Sourced by its bare name, from inside prompt/ of the tree itself.
  *) BB_TREE=$(cd -- "$(pwd -P)/.." 2>/dev/null && pwd -P) ;;
esac
if [ -f "$BB_TREE/install-pending" ] && [ "$BB_TREE" = "$BB_DIR/bb" ]; then
  # BB_SOURCED_BY_PROMPT tells the installer that the shell it installed for is the
  # shell asking, i.e. the one that is about to build its prompt here.
  if ! (. "$BB_TREE/installbb.sh" && BB_SOURCED_BY_PROMPT=1 bb_install "$BB_TREE" ${1:+"$1"}); then
    printf 'BetterBash: the tree in %s did not install, so the prompt is not loaded\n' "$BB_TREE" >&2
    return 1
  fi
elif [ -f "$BB_DIR/bb/install-pending" ] && [ -f "$BB_DIR/bb/prompt/bb.sh" ]; then
  # The installed prompt found a tree that was fetched and left alone - because
  # the question was answered with n, or because nobody ran it. It is not
  # installed by a shell starting, so it is only mentioned, once per shell.
  case $- in
    *i*)
      printf 'BetterBash: %s/bb was fetched but not installed; install it with: . %s/bb/prompt/bb.sh\n' \
        "$BB_DIR" "$BB_DIR" >&2
      ;;
  esac
fi

# git-prompt.sh is the upstream prompt helper of git; it is not linted here.
# shellcheck source=/dev/null
source "$BB_DIR/git-prompt.sh"

#arrchar=('\u25B2' '\u25B6' '\u25BC' '\u25C0')
arrchar=('\u25B2' '\u25B6' '\u25BC' '\u25C0' '\u25C6' '\u25CF' '\u25E2' '\u25E3' '\u25E4' '\u25E5' '\u25AC' '\u25AE' '\u25A0')
arrfg=( 31 32 33 34 35 36 90 97 )
# Background colours of the arrows, computed by getChar and currently unused by
# the prompt itself; kept because they can be used in a custom PS1.
# shellcheck disable=SC2034
arrbg=( 41 42 43 44 45 46 100 107 )

function getChar {
  #char=$(( n % 4 )) && n=$(( n / 4 ))
  char=$(( n % 13 )) && n=$(( n / 13 ))
  colfg=$(( n % 8 )) && n=$(( n / 8 ))
  # shellcheck disable=SC2034
  colbg=$(( n % 8 ))
  # mirror horizontal arrows
  if [[ "$1" -eq 1 ]]; then
    case $char in
      1) char=3 ;;
      3) char=1 ;;
      6) char=7 ;;
      7) char=6 ;;
      8) char=9 ;;
      9) char=8 ;;
    esac
  fi
  #echo -en "\[\033[1;${arrfg[$colfg]};${arrbg[$colbg]}m${arrchar[$char]}\]"
  echo -en "\[\033[1;${arrfg[$colfg]}m${arrchar[$char]}\]"
}

function hashColor {
  n=$(md5sum <<< "$1") 		# get hash
  n=$((0x${n%% *}))		# convert to decimal
  n=$(echo "$n" | tr -d - )	# get absolute value
  count="$2"
  i=0
  echo -en '\[\033[1;97m\]'
  while [ "$i" -lt "$count" ]; do
    i=$(( i+1 ))
    charstep[$i]=$n
    getChar 0
  done
  while [ "$i" -gt 0 ]; do
    n="${charstep[$i]}"
    getChar 1
    i=$(( i-1 ))
  done
  echo -en '\[\033[0m\]'
  echo -e '\[\033[1;97m\]'
}


temp="$(tty)"
#   Chop off the first five chars of tty (ie /dev/):
cur_tty="${temp:5}"
unset temp

HBAR="─"
PR_ULCORNER="┌"
PR_LLCORNER="└"

# The theme of this machine. getbb.sh writes ~/.bb/theme.sh from the theme code
# of the install command, and prompt/bb-theme.sh is what decoded it there. It is
# read before the defaults below, so an install without a theme file - or an
# older one, where the backend injected the assignments into this file - keeps
# working.
BB_THEME_FILE="$BB_DIR/theme.sh"
# shellcheck source=/dev/null
[ -f "$BB_THEME_FILE" ] && . "$BB_THEME_FILE"

# Defaults:
[ -z "${PRIMARY_COLOR}" ] && PRIMARY_COLOR='\[\033[00;92m\]'
[ -z "${SECONDARY_COLOR}" ] && SECONDARY_COLOR='\[\033[00;95;1m\]'
[ -z "${ROOT_COLOR}" ] && ROOT_COLOR='\[\033[00;31;1m\]'
[ -z "${TIME_COLOR}" ] && TIME_COLOR='\[\033[00;93;1m\]'
[ -z "${ERR_COLOR}" ] && ERR_COLOR='\[\033[00;31;1m\]'
[ -z "${SEPARATOR_COLOR}" ] && SEPARATOR_COLOR='\[\033[00;97;1m\]'
[ -z "${RST=}" ] && RST='\[\033[0m\]'
[ -z "${BORDCOL}" ] && BORDCOL='\[\033[00;90;1m\]'
[ -z "${PATH_COLOR}" ] && PATH_COLOR='\[\033[00;97;1m\]'
[ -z "${AVATAR}" ] && AVATAR='true'
USERCOL=$SECONDARY_COLOR

export GIT_PS1_SHOWCOLORHINTS=true
export GIT_PS1_SHOWDIRTYSTATE=true
export GIT_PS1_SHOWUNTRACKEDFILES=true
export GIT_PS1_SHOWUPSTREAM="auto"

export PROMPT_COMMAND=__prompt_command

CH=''
CHLINE=''

if [ "$AVATAR" == 'true' ]; then
  CH=$(hashColor "$(cat /etc/hostname)" 4)
  CHLINE="$SEPARATOR_COLOR($CH$SEPARATOR_COLOR)"
fi

function __prompt_command() {
  local RETURN_CODE="$?"
  PS1=""
  # Handling returne code
  RCOL="${PRIMARY_COLOR}"
  EXIT="$HBAR$HBAR$HBAR$HBAR$HBAR"
  if [[ $RETURN_CODE != 0 ]]; then
     EXIT="$SEPARATOR_COLOR(${ERR_COLOR}$RETURN_CODE ↵$SEPARATOR_COLOR)"
     RCOL="${ERR_COLOR}"
  fi

  USER=$(whoami)
  if [ $UID -eq "0" ]; then
     USERCOL=$ROOT_COLOR
     USER="${USER^^}"
  fi

  # Handle background process counter
  PROCCNT=$(jobs -p 2>/dev/null | wc -l )
    PROC_WIDTH=0
  if [ "$PROCCNT" -ne "0" ]; then
    #BGPROCCOL='\033[1;95;5m'
    BGPROCCOL="$BORDCOL$HBAR$HBAR$SEPARATOR_COLOR(${SECONDARY_COLOR}\j ↻$SEPARATOR_COLOR)"
  fi

  [ -n "${BGPROCCOL}" ] && PROC_WIDTH=7

  HOSTNAM="$(cat /etc/hostname)"

  GITPROMPT=$(__git_ps1 " on${PRIMARY_COLOR} %s")

  LEFT="\n$BORDCOL\[\016\]$PR_ULCORNER$HBAR\[\017\]$SEPARATOR_COLOR($USERCOL$USER$SEPARATOR_COLOR@${PRIMARY_COLOR}\h:$cur_tty$SEPARATOR_COLOR)$BORDCOL$HBAR$HBAR$CHLINE$BGPROCCOL"

  RIGHT="$EXIT$BORDCOL$HBAR$HBAR$HBAR$SEPARATOR_COLOR($TIME_COLOR\d$SEPARATOR_COLOR)$BORDCOL$HBAR$HBAR$HBAR$SEPARATOR_COLOR($RCOL\t$SEPARATOR_COLOR)$BORDCOL$HBAR$HBAR$HBAR$HBAR\n$BORDCOL\[\016\]$PR_LLCORNER\[\017\]$BORDCOL$HBAR$SEPARATOR_COLOR(${PATH_COLOR}\w${SEPARATOR_COLOR})$BORDCOL$HBAR$SEPARATOR_COLOR(${PRIMARY_COLOR}\\\$$RST$GITPROMPT$SEPARATOR_COLOR)$BORDCOL-> \[\e[0m\]"

  L_LEN="$USER$HOSTNAM$CH"
  R_LEN="XXX XXX XX, XX:XX:XX$RETURN_CODE"
  L_LEN=${#L_LEN}
  R_LEN=${#R_LEN}
  let WIDTH=$(tput cols)-${R_LEN}-${L_LEN}-${PROC_WIDTH}+83
  if [ "$AVATAR" != 'true' ]; then
    let WIDTH=${WIDTH}-116
  fi
  FILL=$BORDCOL$HBAR
  for ((x = 0; x < $WIDTH; x++)); do
    FILL="$FILL$HBAR"
  done

  PS1="$LEFT$FILL$RIGHT"

}
