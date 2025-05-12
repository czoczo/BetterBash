#!/bin/bash

source ~/.bb/git-prompt.sh

#arrchar=('\u25B2' '\u25B6' '\u25BC' '\u25C0')
arrchar=('\u25B2' '\u25B6' '\u25BC' '\u25C0' '\u25C6' '\u25CF' '\u25E2' '\u25E3' '\u25E4' '\u25E5' '\u25AC' '\u25AE')
arrfg=( 31 32 33 34 35 36 90 97 )
arrbg=( 41 42 43 44 45 46 100 107 )

function getChar {
  #char=$(( n % 4 )) && n=$(( n / 4 ))
  char=$(( n % 12 )) && n=$(( n / 12 ))
  colfg=$(( n % 8 )) && n=$(( n / 8 ))
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

CH=$(hashColor "$(cat /etc/hostname)" 4)

temp="$(tty)"
#   Chop off the first five chars of tty (ie /dev/):
cur_tty="${temp:5}"
unset temp

HBAR="─"
PR_ULCORNER="┌"
PR_LLCORNER="└"

PRIMARY_COLOR='\[\033[00;92m\]'
SECONDARY_COLOR='\[\033[00;95;1m\]'
ROOT_COLOR='\033[00;41;97;1m'
TIME_COLOR='\[\033[00;93;1m\]'
ERR_COLOR='\[\033[00;31;1m\]'
WHITEB='\[\033[00;97;1m\]'
RST='\[\033[0m\]'
BOLD='\[\033[1m\]'
BORDCOL='\[\033[00;90;1m\]'
USERCOL=$SECONDARY_COLOR
PATH_COLOR=$WHITEB

export GIT_PS1_SHOWCOLORHINTS=true
export GIT_PS1_SHOWDIRTYSTATE=true
export GIT_PS1_SHOWUNTRACKEDFILES=true
export GIT_PS1_SHOWUPSTREAM="auto"

export PROMPT_COMMAND=__prompt_command

function __prompt_command() {
  local RETURN_CODE="$?"
  PS1=""
  # Handling returne code
  RCOL="${PRIMARY_COLOR}"
  EXIT="$HBAR$HBAR$HBAR$HBAR$HBAR"
  if [[ $RETURN_CODE != 0 ]]; then
     EXIT="$WHITEB(${ERR_COLOR}$RETURN_CODE ↵$WHITEB)"
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
    BGPROCCOL="$BORDCOL$HBAR$HBAR$WHITEB(${SECONDARY_COLOR}\j ↻$WHITEB)"
  fi

  [ -n "${BGPROCCOL}" ] && PROC_WIDTH=7

  HOSTNAM="$(cat /etc/hostname)"

  GITPROMPT=$(__git_ps1 " on${PRIMARY_COLOR} %s")

  LEFT="\n$BORDCOL\[\016\]$PR_ULCORNER$HBAR\[\017\]$WHITEB($USERCOL$USER$WHITEB@${PRIMARY_COLOR}\h:$cur_tty$WHITEB)$BORDCOL$HBAR$HBAR$WHITEB($CH$WHITEB)$BGPROCCOL"

  RIGHT="$EXIT$BORDCOL$HBAR$HBAR$HBAR$WHITEB($TIME_COLOR\d$WHITEB)$BORDCOL$HBAR$HBAR$HBAR$WHITEB($RCOL\t$WHITEB)$BORDCOL$HBAR$HBAR$HBAR$HBAR\n$BORDCOL\[\016\]$PR_LLCORNER\[\017\]$BORDCOL$HBAR$WHITEB(${PATH_COLOR}\w${WHITE})$BORDCOL$HBAR$WHITEB(${PRIMARY_COLOR}\\\$$RST$GITPROMPT$WHITEB)$BORDCOL-> \[\e[0m\]"

  L_LEN="$USER$HOSTNAM$CH"
  R_LEN="XXX XXX XX, XX:XX:XX$RETURN_CODE"
  L_LEN=${#L_LEN}
  R_LEN=${#R_LEN}
  let WIDTH=$(tput cols)-${R_LEN}-${L_LEN}-${PROC_WIDTH}+83
  FILL=$BORDCOL$HBAR
  for ((x = 0; x < $WIDTH; x++)); do
    FILL="$FILL$HBAR"
  done

  PS1="$LEFT$FILL$RIGHT"

}
