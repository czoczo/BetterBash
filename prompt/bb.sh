#!/bin/bash

# Where BetterBash keeps its files; the installer installs into the same variable.
BB_DIR="${BB_DIR:-$HOME/.bb}"

# --- a fetched tree installs itself, once ------------------------------------
# The fetch commands of the WebUI leave a BetterBash tree in ~/.bb and nothing else
# about it happens there until that tree is asked to install itself, which is what
# sourcing its prompt/bb.sh does. A tree that has not been installed carries the
# file install-pending next to it, so the flag - and not a guess about whether this
# file is the installed one or a fetched one - is what says: install, then build the
# prompt. The flag is removed by the install, so every later sourcing of this file
# costs one test for a file that is not there.
#
# The install is run in a subshell on purpose: installbb.sh defines functions and
# options a shell of its own, and the shell that ends up wearing the prompt should
# not be the one that installed it.
#
# Only the tree that $BB_DIR itself is installs, which is the second test: a
# checkout of this project worked on, or any other copy of these files, stays a
# directory of files. The two copies of this file that a machine holds - the
# installed prompt ~/.bb/bb.sh and ~/.bb/prompt/bb.sh of the tree it was copied out
# of - are told apart by the directory above them: one level up from the tree's
# prompt is ~/.bb, one level up from the installed copy is the home directory.
#
# The tree is found from this file, so it is the tree whose prompt was sourced -
# wherever that was, and with whatever name.
BB_SELF=${BASH_SOURCE[0]}
case $BB_SELF in
  */*) BB_TREE=$(cd -- "${BB_SELF%/*}/.." 2>/dev/null && pwd -P) ;;
  # Sourced by its bare name, from inside prompt/ of the tree itself.
  *) BB_TREE=$(cd -- "$(pwd -P)/.." 2>/dev/null && pwd -P) ;;
esac
if [ -f "$BB_TREE/install-pending" ] && [ "$BB_TREE" = "$BB_DIR" ]; then
  # BB_SOURCED_BY_PROMPT tells the installer that the shell it installed for is the
  # shell asking, i.e. the one that is about to build its prompt here.
  if ! (. "$BB_TREE/installbb.sh" && BB_SOURCED_BY_PROMPT=1 bb_install "$BB_TREE" ${1:+"$1"}); then
    printf 'BetterBash: the tree in %s did not install, so the prompt is not loaded\n' "$BB_TREE" >&2
    return 1
  fi
elif [ -f "$BB_DIR/install-pending" ] && [ -f "$BB_DIR/prompt/bb.sh" ]; then
  # The installed prompt found a tree that was fetched and left alone - because
  # the question was answered with n, or because nobody ran it. It is not
  # installed by a shell starting, so it is only mentioned, once per shell.
  case $- in
    *i*)
      printf 'BetterBash: %s was fetched but not installed; install it with: . %s/prompt/bb.sh\n' \
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

# --- how long the last command ran ---------------------------------------
# The shell never says how long a command took, so the prompt measures it with the
# two hooks it offers: the DEBUG trap, which runs just before bash executes a
# command and leaves that moment in $SECONDS - the shell's own counter, so no
# external `date` and no fractional arithmetic - and PROMPT_COMMAND, which runs
# once the command is over and just before PS1 is drawn, where the seconds that
# passed are subtracted from it.
#
# A start is recorded only when none is held, so that a line of several commands
# (`make && make install`, a loop) is measured from its first one, which is the
# command the next prompt answers for. The trap runs before every command, those
# the prompt itself executes (whoami, jobs, git) included, which is why the start
# is only let go at the very end of __prompt_command: held across those, it stays
# the start of the user's command, so the prompt measures that one and not itself.
# Two things the hook cannot see are taken as they are: a command run in a
# subshell (`( make )`) never runs the trap of its parent, and a command put in the
# background has not run when the prompt is drawn - both are shown as 0s.
BB_TIMER=''
BB_TIMER_SHOW=''

function __bb_timer_start {
  # Returns 0 either way, because a DEBUG trap that fails is a command bash
  # refuses to run whenever someone has switched extdebug on.
  if [ -z "$BB_TIMER" ]; then
    BB_TIMER=$SECONDS
  fi
}

# The seconds the command that drew this prompt ran, as a number. Read early, so
# the prompt can build its segment from it: reading is harmless whenever it
# happens, only letting go of the start would confuse the commands that follow.
function __bb_timer_stop {
  # The first prompt of a shell holds no start, and neither does one whose DEBUG
  # trap somebody else took over; either way there is nothing to measure, and 0s is
  # closer to the truth than a number out of thin air.
  if [ -z "$BB_TIMER" ]; then
    BB_TIMER_SHOW=0
  else
    BB_TIMER_SHOW=$(( SECONDS - BB_TIMER ))
    # A command that reset SECONDS itself would otherwise measure backwards.
    if [ "$BB_TIMER_SHOW" -lt 0 ]; then
      BB_TIMER_SHOW=0
    fi
  fi
}

# Lets go of the start, so that the next command to begin is the one recorded. The
# last thing the prompt does, and only then - see above.
function __bb_timer_reset {
  unset BB_TIMER
}

# The trap is taken rather than shared, as PROMPT_COMMAND below is: a prompt that
# measures the last command has to know when every command starts.
trap '__bb_timer_start' DEBUG

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

  # The seconds the command that drew this prompt ran, and in the colour of that
  # command: RCOL is PRIMARY_COLOR when it succeeded and ERR_COLOR when not.
  __bb_timer_stop
  TIMERSEG="$BORDCOL$HBAR$HBAR$HBAR$SEPARATOR_COLOR(${RCOL}${BB_TIMER_SHOW}s$SEPARATOR_COLOR)"
  # Its visible width - three dashes, the brackets, the digits and the s - so the
  # fill gives up exactly what the segment takes, as PROC_WIDTH does for the
  # background process counter.
  TIMER_WIDTH=$(( ${#BB_TIMER_SHOW} + 6 ))

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

  RIGHT="$EXIT$TIMERSEG$BORDCOL$HBAR$HBAR$HBAR$SEPARATOR_COLOR($TIME_COLOR\d$SEPARATOR_COLOR)$BORDCOL$HBAR$HBAR$HBAR$SEPARATOR_COLOR($RCOL\t$SEPARATOR_COLOR)$BORDCOL$HBAR$HBAR$HBAR$HBAR\n$BORDCOL\[\016\]$PR_LLCORNER\[\017\]$BORDCOL$HBAR$SEPARATOR_COLOR(${PATH_COLOR}\w${SEPARATOR_COLOR})$BORDCOL$HBAR$SEPARATOR_COLOR(${PRIMARY_COLOR}\\\$$RST$GITPROMPT$SEPARATOR_COLOR)$BORDCOL-> \[\e[0m\]"

  L_LEN="$USER$HOSTNAM$CH"
  R_LEN="XXX XXX XX, XX:XX:XX$RETURN_CODE"
  L_LEN=${#L_LEN}
  R_LEN=${#R_LEN}
  let WIDTH=$(tput cols)-${R_LEN}-${L_LEN}-${PROC_WIDTH}-${TIMER_WIDTH}+83
  if [ "$AVATAR" != 'true' ]; then
    let WIDTH=${WIDTH}-116
  fi
  # The fill is whatever width the terminal has left between the two halves. When
  # there is none left it is dropped altogether rather than keeping the dash it
  # would otherwise carry, because that dash would push the frame onto the next
  # line and the frame would stop being one line.
  if [ "$WIDTH" -le 0 ]; then
    FILL=''
  else
    FILL=$BORDCOL$HBAR
    for ((x = 0; x < $WIDTH; x++)); do
      FILL="$FILL$HBAR"
    done
  fi

  PS1="$LEFT$FILL$RIGHT"

  __bb_timer_reset
}
