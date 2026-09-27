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
# The corner of a prompt that has no frame above it: the lower left quarter of a
# dash, which is what is left of └ once the line it hung from is gone (Alt+t, see
# the compact prompt below).
PR_LLCORNER_COMPACT="┈"

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

# The dashes between the segments of the frame, and the four dashes that close its
# top line. They are named rather than written out where they are used, because
# the preview of the prompt on the WebUI copies them glyph for glyph and
# tests/test-frame.mjs compares the frame of the page with the frame the prompt
# draws.
FRAME_SEP=$BORDCOL$HBAR$HBAR
FRAME_TAIL=$BORDCOL$HBAR$HBAR$HBAR$HBAR
FRAME_TAIL_WIDTH=4

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

# --- the compact prompt, Alt+t ---------------------------------------------
# A prompt of two lines spends one of them on the machine: who, where, when, how
# long. Alt+t takes that line away and keeps only the one the command is typed on,
# for a small terminal, a crowded one, or a reader who has just seen all of that
# above. The corner that opens the kept line loses its frame, so it is drawn as the
# lower half of a dash instead of a corner.
#
# The key is bound with `bind -x`, which runs a shell function without touching what
# is typed on the line and without leaving a command in the history; a macro in
# .inputrc typing `bb-compact` and a newline would do both of those, and would also
# bind the key in every other readline program, python included. It is spelled \et
# and not \M-t, because a terminal sends Alt and t as Escape followed by t, while
# \M-t is the single byte a terminal only produces when it is 8-bit clean. The key
# is taken from readline's transpose-words.
#
# What bash will not do is redraw the prompt that already stands on the screen: the
# new shape comes with the next prompt. A key that changes nothing you can see looks
# broken, so the function says which shape is on and when it shows.
BB_COMPACT=${BB_COMPACT:-0}

function __bb_toggle_prompt {
  if [ "$BB_COMPACT" = 1 ]; then
    BB_COMPACT=0
    printf 'BetterBash: frame prompt - the next prompt is two lines again (Alt+t for one line)\n'
  else
    BB_COMPACT=1
    printf 'BetterBash: compact prompt - the next prompt is one line (Alt+t for the frame)\n'
  fi
}

# Only for an interactive shell: sourcing this file from a script has no readline to
# bind on, and a warning about it there is noise in somebody else's output.
case $- in
  *i*) bind -x '"\et": __bb_toggle_prompt' 2>/dev/null || true ;;
esac

CH=''
CHLINE=''
# The avatar with its brackets is ten glyphs, and it is counted here rather than
# from CH, whose length is mostly the escapes that colour its eight glyphs - and
# a length of escapes is not a width of a line. AVATAR_GAP is the same ten glyphs
# as dashes, for a prompt that has switched the avatar off and has no fill left
# to take them back (see __prompt_command).
AVATAR_GLYPHS=10
AVATAR_WIDTH=0
AVATAR_GAP=''

if [ "$AVATAR" == 'true' ]; then
  CH=$(hashColor "$(cat /etc/hostname)" 4)
  CHLINE="$SEPARATOR_COLOR($CH$SEPARATOR_COLOR)"
  AVATAR_WIDTH=$AVATAR_GLYPHS
else
  # The same ten glyphs as dashes, for the case that needs them.
  AVATAR_GAP=$BORDCOL
  for ((g = 0; g < AVATAR_GLYPHS; g++)); do
    AVATAR_GAP="$AVATAR_GAP$HBAR"
  done
fi

function __prompt_command() {
  local RETURN_CODE="$?"
  PS1=""
  # Handling the return code. The width of the segment is the code, its arrow and
  # a bracket each; the five dashes that stand for a command that ended well are
  # drawn in the colour of the border, so that they read as the frame and not as
  # an alarm - they are drawn whether or not the fill before them carried that
  # colour.
  RCOL="${PRIMARY_COLOR}"
  EXIT="$BORDCOL$HBAR$HBAR$HBAR$HBAR$HBAR"
  EXIT_WIDTH=5
  if [[ $RETURN_CODE != 0 ]]; then
     EXIT="$SEPARATOR_COLOR(${ERR_COLOR}$RETURN_CODE ↵$SEPARATOR_COLOR)"
     EXIT_WIDTH=$(( ${#RETURN_CODE} + 4 ))
     RCOL="${ERR_COLOR}"
  fi

  # The seconds the command that drew this prompt ran, and always in the primary
  # colour. Which command left which code is told by the segment of the exit
  # code, in ERR_COLOR; a duration wearing that colour too would say the same
  # thing twice, and the two of them would read as one alarm rather than as a
  # number of seconds next to a code.
  __bb_timer_stop
  TIMERSEG="$FRAME_SEP$SEPARATOR_COLOR(${PRIMARY_COLOR}${BB_TIMER_SHOW}s$SEPARATOR_COLOR)"
  # Its visible width - the two dashes of its separator, the brackets, the digits
  # and the s - so the fill gives up exactly what the segment takes, as
  # PROC_WIDTH does for the background process counter.
  TIMER_WIDTH=$(( ${#BB_TIMER_SHOW} + 5 ))

  USER=$(whoami)
  if [ $UID -eq "0" ]; then
     USERCOL=$ROOT_COLOR
     USER="${USER^^}"
  fi

  # Handle background process counter. The counter is rebuilt for every prompt, so
  # a job that has ended takes its segment away instead of leaving it painted there
  # ever after. The number is drawn as it was counted rather than through \j, so
  # that the segment and the width given it cannot disagree about how many digits
  # they have.
  PROCCNT=$(jobs -p 2>/dev/null | wc -l)
  # Some wc pad the number they print, and a padded number is not a width.
  PROCCNT=$(( PROCCNT ))
  PROC_WIDTH=0
  BGPROCCOL=''
  if [ "$PROCCNT" -ne "0" ]; then
    #BGPROCCOL='\033[1;95;5m'
    BGPROCCOL="$FRAME_SEP$SEPARATOR_COLOR(${SECONDARY_COLOR}$PROCCNT ↻$SEPARATOR_COLOR)"
    # Two dashes of its separator, a bracket each, the space and the arrow, and
    # the digits of the count.
    PROC_WIDTH=$(( ${#PROCCNT} + 6 ))
  fi

  # \h of PS1 prints the host name up to its first dot, so the name that is
  # counted for the width of the line is cut the same way.
  HOSTNAM="$(cat /etc/hostname)"
  HOSTNAM=${HOSTNAM%%.*}

  GITPROMPT=$(__git_ps1 " on${PRIMARY_COLOR} %s")

  # The second line of the prompt, and in the compact shape the only one. It is
  # built once for both, so the two shapes cannot come to disagree about the
  # segments they hold; what differs is the corner, which is a corner only while
  # there is a frame above it (see the compact prompt above).
  PR_CORNER=$PR_LLCORNER
  if [ "$BB_COMPACT" = 1 ]; then
    PR_CORNER=$PR_LLCORNER_COMPACT
  fi
  BOTTOM="\n$BORDCOL\[\016\]$PR_CORNER\[\017\]$BORDCOL$HBAR$SEPARATOR_COLOR(${PATH_COLOR}\w${SEPARATOR_COLOR})$BORDCOL$HBAR$SEPARATOR_COLOR(${PRIMARY_COLOR}\\\$$RST$GITPROMPT$SEPARATOR_COLOR)$BORDCOL-> \[\e[0m\]"

  RIGHT="$EXIT$TIMERSEG$FRAME_SEP$SEPARATOR_COLOR($TIME_COLOR\d$SEPARATOR_COLOR)$FRAME_SEP$SEPARATOR_COLOR($RCOL\t$SEPARATOR_COLOR)$FRAME_TAIL"

  # The compact prompt is the line the cursor stands on and nothing else: neither
  # the frame above it nor all the measuring the fill of that frame needs.
  if [ "$BB_COMPACT" = 1 ]; then
    PS1="$BOTTOM"
    __bb_timer_reset
    return 0
  fi

  # Eight glyphs of the left half are the frame itself, the brackets of
  # (user@host:tty) and the two dashes in front of the avatar; the rest of it is
  # measured by what it shows.
  LEFT_WIDTH=$(( 8 + ${#USER} + ${#HOSTNAM} + ${#cur_tty} + AVATAR_WIDTH + PROC_WIDTH ))

  # Every segment of the right half stands behind two dashes, the separator of
  # the frame, and the top line closes with four dashes of its own. bash draws \d
  # as "Fri Sep 25" and \t as "17:52:36" - ten and eight glyphs - each of them
  # between a bracket and behind its two dashes.
  DATE_WIDTH=$(( 10 + 2 + 2 ))
  CLOCK_WIDTH=$(( 8 + 2 + 2 ))
  RIGHT_WIDTH=$(( EXIT_WIDTH + TIMER_WIDTH + DATE_WIDTH + CLOCK_WIDTH + FRAME_TAIL_WIDTH ))

  # The fill is whatever width the terminal has left between the two halves, so
  # the top line is as wide as the terminal less the four columns it has always
  # left empty at its right end: a line exactly as wide as the terminal wraps,
  # and a frame that wraps stops being a frame. Whatever the shell can change - a
  # longer host, another tty, a duration of four digits, an exit code of two - is
  # measured above, so the fill is the only thing that moves with them and the
  # line keeps its length. When no width is left the fill is dropped altogether
  # rather than keeping the dash it would otherwise carry, because that dash
  # would push the frame onto the next line and the frame would stop being one
  # line.
  # ROOM is what would be left for the fill if the avatar stood - whether it
  # shows or not - and so it is ROOM, and not WIDTH, that says when the frame has
  # run out of terminal: the two of them, an avatar on and an avatar off, break
  # at the same width and the line stays one length.
  WIDTH=$(( $(tput cols) - 4 - LEFT_WIDTH - RIGHT_WIDTH ))
  ROOM=$(( WIDTH - AVATAR_GLYPHS + AVATAR_WIDTH ))
  GAP=$AVATAR_GAP
  if [ "$ROOM" -le 0 ]; then
    FILL=''
  else
    # The ten glyphs of an avatar that is off are given to the fill, which is why
    # the gap is only drawn where there is no fill to carry it.
    GAP=''
    FILL=$BORDCOL
    for ((x = 0; x < WIDTH; x++)); do
      FILL="$FILL$HBAR"
    done
  fi

  LEFT="\n$BORDCOL\[\016\]$PR_ULCORNER$HBAR\[\017\]$SEPARATOR_COLOR($USERCOL$USER$SEPARATOR_COLOR@${PRIMARY_COLOR}\h:$cur_tty$SEPARATOR_COLOR)$FRAME_SEP$CHLINE$GAP$BGPROCCOL"

  PS1="$LEFT$FILL$RIGHT$BOTTOM"

  __bb_timer_reset
}
