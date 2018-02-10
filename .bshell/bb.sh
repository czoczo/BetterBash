#!/bin/bash

source ~/.bshell/git-prompt.sh

arrchar=('\u25B2' '\u25B6' '\u25BC' '\u25C0')
arrfg=( 31 32 33 34 35 36 90 97 )
arrbg=( 41 42 43 44 45 46 100 107 )

function getChar {
  char=$(( n % 4 )) && n=$(( n / 4 ))
  colfg=$(( n % 8 )) && n=$(( n / 8 ))
  colbg=$(( n % 8 ))
  [[ "$1" -eq 1 && ( "$char" -eq 1 || "$char" -eq 3 ) ]] && char=$(( (char + 2) % 4 )) # mirror horizontal arrows
  echo -en "\e[1;${arrfg[$colfg]};${arrbg[$colbg]}m${arrchar[$char]}"
}

function hashColor {
  n=$(md5sum <<< "$1") 		# get hash
  n=$((0x${n%% *}))		# convert to decimal
  n=$(echo "$n" | tr -d - )	# get absolute value
  count="$2"
  i=0
  echo -en '\e[1;97m'
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
  echo -en '\e[0m'
  echo -e '\e[1;97m'
}

CH=$(hashColor "$(hostname)" 4)

temp="$(tty)"
#   Chop off the first five chars of tty (ie /dev/):
cur_tty="${temp:5}"
unset temp

PR_HBAR="─"
PR_ULCORNER="┌"
PR_LLCORNER="└"
#PR_HBAR="━"
#PR_ULCORNER="┏"
#PR_LLCORNER="┗"
#PR_HBAR="═"
#PR_ULCORNER="╔"
#PR_LLCORNER="╚"

GREEN='\[\033[00;92m\]'
GREENB='\[\033[00;92;1m\]'
BLUE='\[\033[00;36;1m\]'
MAGENTA='\[\033[00;95;1m\]'
GREY='\[\033[00;90m\]'
YELLOW='\[\033[00;93m\]'
YELLOWB='\[\033[00;93;1m\]'
RED='\[\033[00;31m\]'
REDB='\[\033[00;31;1m\]'
WHITE='\[\033[00;97;1m\]'
WHITEB='\[\033[00;97;1m\]'
RST='\[\033[0m\]'
BOLD='\[\033[1m\]'
BORDCOL='\[\033[00;90;1m\]'
BGPROCCOL=$GREEN
USERCOL=$MAGENTA

export GIT_PS1_SHOWCOLORHINTS=true # Option for git-prompt.sh to show branch name in color
export GIT_PS1_SHOWDIRTYSTATE=true
export GIT_PS1_SHOWUNTRACKEDFILES=true
export GIT_PS1_SHOWUPSTREAM="auto"
#export PROMPT_COMMAND='__git_ps1 "\w" "\n\\\$ "' # Git branch (relies on git-prompt.sh)

export PROMPT_COMMAND=__prompt_command


function __prompt_command() {
  local RETURN_CODE="$?"
  PS1=""
  RCOL="$GREEN"
  EXIT="$PR_HBAR$PR_HBAR$PR_HBAR$PR_HBAR$PR_HBAR"
  if [[ $RETURN_CODE != 0 ]]; then
     EXIT="$WHITEB($RED$RETURN_CODE ↵$WHITEB)"
     RCOL="$RED"
  fi
  USER=$(whoami)
  if [ $UID -eq "0" ]; then
     USERCOL='\033[00;41;97;1m'
#    BORDCOL=$REDB
     USER="${USER^^}"
  fi
  PROCCNT=$(jobs -p 2>/dev/null | wc -l )
  if [ $PROCCNT -gt "0" ]; then
    BGPROCCOL=$RED
  else
    BGPROCCOL=$MAGENTA
  fi
  HOSTNAM=$(hostname -s)
  USERNAM=$(whoami)
  GITPROMPT=$(__git_ps1 " on$GREEN %s")
  LEFT="\n$BORDCOL\[\016\]$PR_ULCORNER$PR_HBAR\[\017\]$WHITEB($USERCOL$USER$WHITEB@$GREEN\h:$cur_tty$WHITEB)$BORDCOL$PR_HBAR$PR_HBAR$PR_HBAR$PR_HBAR$WHITEB($GREEN\$(/bin/ls -1 | /usr/bin/wc -l | /bin/sed 's: ::g') files, \$(/bin/ls -lah | /bin/grep -m 1 total | /bin/sed 's/total //')b$WHITEB)$BORDCOL$PR_HBAR$PR_HBAR$WHITEB($BGPROCCOL\j ↻$WHITEB)"
  RIGHT="$EXIT$BORDCOL$PR_HBAR$WHITEB($CH$WHITEB)$BORDCOL$PR_HBAR$PR_HBAR$WHITEB($YELLOWB\d$WHITEB)$BORDCOL$PR_HBAR$PR_HBAR$PR_HBAR$WHITEB($RCOL\t$WHITEB)$BORDCOL$PR_HBAR$PR_HBAR$PR_HBAR$PR_HBAR$BORDCOL\n\[\016\]$PR_LLCORNER\[\017\]$PR_HBAR$WHITEB(\w)$BORDCOL$PR_HBAR$WHITEB($GREEN\\\$$RST$GITPROMPT$WHITEB)$BORDCOL-> \[\e[0m\]"
  #WIDTH=$(tput cols)
  L_LEN="$USERNAM$HOSTNAM$CH$(/bin/ls -1 | /usr/bin/wc -l | /bin/sed 's: ::g')$(/bin/ls -lah | /bin/grep -m 1 total | /bin/sed 's/total //')b\j"
  R_LEN="XXX XXX XX, XX:XX:XX$RETURN_CODE"
  L_LEN=${#L_LEN}
  R_LEN=${#R_LEN}
#echo "$L_LEN"
  let WIDTH=$(tput cols)-${R_LEN}-${L_LEN}+49
  FILL=$BORDCOL$PR_HBAR
  for ((x = 0; x < $WIDTH; x++)); do
    FILL="$FILL$PR_HBAR"
  done

  PS1="$LEFT$FILL$RIGHT"

}
