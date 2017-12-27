#!/bin/bash


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

PR_HBAR="─"
PR_ULCORNER="┌"
PR_LLCORNER="└"
#PR_HBAR="━"
#PR_ULCORNER="┏"
#PR_LLCORNER="┗"
#PR_HBAR="═"
#PR_ULCORNER="╔"
#PR_LLCORNER="╚"

GREEN='\033[00;92m'
BLUE='\033[00;94m'
GREY='\033[00;90;1m'
YELLOW='\033[00;93m'
RED='\033[00;31m'
WHITE='\033[00;97;1m'
RST='\033[0m'
BOLD='\033[1m'


export PROMPT_COMMAND=__prompt_command

function __prompt_command() {
  local EXIT="$?"
  PS1=""
  RCOL=""
    if [[ $EXIT != 0 ]]; then
        RCOL="$RED"
    fi
  if [ $UID -eq "0" ]; then
    GREY=$RED
  fi
  PS1="\n$GREY\[\016\]$PR_ULCORNER\[\017\]$WHITE(\[\e[34;1m\]\u$WHITE@$GREEN\h$WHITE)$GREY$PR_HBAR$PR_HBAR$WHITE($CH$WHITE)$GREY$PR_HBAR$PR_HBAR$WHITE($GREEN\$(/bin/ls -1 | /usr/bin/wc -l | /bin/sed 's: ::g') files, \$(/bin/ls -lah | /bin/grep -m 1 total | /bin/sed 's/total //')b$WHITE)$GREY$PR_HBAR$PR_HBAR$WHITE($GREEB\j ↻$WHITE)$GREY$PR_HBAR$PR_HBAR$WHITE($YELLOW$RCOL\d, \t$WHITE)$GREY$PR_HBAR$PR_HBAR$WHITE($GREEN$RCOL$EXIT ↵$WHITE)$GREY$PR_HBAR$PR_HBAR>$GREY\n\[\016\]$PR_LLCORNER\[\017\]$PR_HBAR$WHITE(\w)$GREY$PR_HBAR> \[\e[0m\]"

}
