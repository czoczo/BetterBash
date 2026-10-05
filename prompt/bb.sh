#!/bin/bash

# Where BetterBash keeps its files; the installer installs into the same variable.
BB_DIR="${BB_DIR:-$HOME/.bb}"

# --- a fetched tree installs itself, once ------------------------------------
# The fetch commands of the WebUI leave a tree in ~/.bb and do nothing else there.
# Sourcing its prompt/bb.sh installs it: the install-pending file next to this one is
# what says the tree was never installed, and the install takes the flag away, so
# every later sourcing costs one test for a file that is not there.
#
# The install runs in a subshell - installbb.sh defines functions and options of its
# own, and the shell that wears the prompt should not be the one that installed it.
#
# Only the tree that $BB_DIR is installs: a checkout of this project, or any other
# copy of these files, stays a directory of files. The installed prompt and the copy
# inside the tree are told apart by the directory above them (the home, or ~/.bb).
# The tree is found from this file, so it is the tree whose prompt was sourced.
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
  # A tree that was fetched and left alone (answered n, or never run). A shell
  # starting does not install it, so it is only mentioned, once per shell.
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
# Half a dash: the lower half of HBAR. Drawn where the frame ends instead of turning,
# and as the corner of a prompt with no frame above it (Alt+c, see below).
HALF_HBAR="┈"
PR_LLCORNER_COMPACT=$HALF_HBAR

# The theme of this machine: ~/.bb/theme.sh, written by the installer from the theme
# code and decoded there by prompt/bb-theme.sh. Read before the defaults below, so an
# install that has no theme file keeps working.
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

# The dashes between the segments of the frame, and the run that closes its top line
# (three dashes and a half, so the frame ends rather than turning back). Named and not
# written out at hand, because the WebUI preview copies them glyph for glyph and
# tests/test-frame.mjs compares the frame of the page with the frame of the prompt.
FRAME_SEP=$BORDCOL$HBAR$HBAR
FRAME_TAIL=$BORDCOL$HBAR$HBAR$HBAR$HALF_HBAR
FRAME_TAIL_WIDTH=4

export GIT_PS1_SHOWCOLORHINTS=true
export GIT_PS1_SHOWDIRTYSTATE=true
export GIT_PS1_SHOWUNTRACKEDFILES=true
export GIT_PS1_SHOWUPSTREAM="auto"

# --- how long the last command ran ---------------------------------------
# Measured with the two hooks the shell offers: the DEBUG trap, which records the
# moment in $SECONDS (the shell's own counter, so no `date` and no fractional
# arithmetic), and PROMPT_COMMAND, which subtracts from it just before PS1 is drawn.
#
# A start is recorded only when none is held, so a line of several commands (`make &&
# make install`) is measured from its first one. The trap also runs before every
# command of the prompt itself, which is why the start is only let go at the very end
# of __prompt_command. Two things the hook cannot see are shown as 0s: a command in a
# subshell, and one put in the background.
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
  # No start - the first prompt of a shell, or a DEBUG trap somebody else took over.
  # Nothing to measure, and 0s beats a number out of thin air.
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

# Lets go of the start, so the next command to begin is the one recorded. The last
# thing the prompt does - see above.
function __bb_timer_reset {
  unset BB_TIMER
}

# The trap is taken rather than shared, as PROMPT_COMMAND below is: a prompt that
# measures the last command has to know when each one starts.
trap '__bb_timer_start' DEBUG

export PROMPT_COMMAND=__prompt_command

# --- the compact prompt, Alt+c ---------------------------------------------
# Alt+c takes the frame line (who, where, when, how long) away and keeps the line the
# command is typed on. The corner that opens the kept line loses its frame, so it is
# drawn as the lower half of a dash.
#
# bash does not redraw the prompt that already stands on the screen, so the key also
# asks for a new one, which only accepting the line does. Alt+c is three keys, each
# one a thing a user could do by hand:
#
#   \C-x\C-p  put the typed line aside, empty it, flip the shape (all via `bind -x`);
#   \C-m      accept-line: the line is empty, so nothing runs and PS1 is drawn again;
#   \C-x\C-b  give the line back, cursor where it stood.
#
# An accepted empty line is not a command and never enters the history. The two
# program keys live under readline's \C-x prefix, both free of defaults there, and
# are bound in interactive shells only - `bind` in a script has no readline, and a
# warning about it would be noise in somebody else's output.
#
# Alt+c is spelled \ec and not \M-c: a terminal sends Alt and c as Escape then c,
# while \M-c is the single byte of an 8-bit clean terminal. The key is taken from
# readline's capitalize-word.
#
# bash older than 4.4 gives a `bind -x` command no READLINE_LINE, so a key that
# accepted the line would run what the user typed there. Those shells get a key that
# flips the shape and prints which one came on.
BB_COMPACT=${BB_COMPACT:-0}

function __bb_toggle_prompt {
  if [ "$BB_COMPACT" = 1 ]; then
    BB_COMPACT=0
  else
    BB_COMPACT=1
  fi
}

# The line and the cursor, held between the two halves of the key.
BB_LINE=''
BB_POINT=0

function __bb_line_take {
  BB_LINE=${READLINE_LINE-}
  BB_POINT=${READLINE_POINT-0}
  READLINE_LINE=''
  READLINE_POINT=0
  __bb_toggle_prompt
}

function __bb_line_give {
  READLINE_LINE=$BB_LINE
  READLINE_POINT=$BB_POINT
}

# The key of an older bash: the flip, and the word about which shape came on.
function __bb_toggle_prompt_note {
  __bb_toggle_prompt
  if [ "$BB_COMPACT" = 1 ]; then
    printf 'BetterBash: compact prompt - the next prompt is one line (Alt+c for the frame)\n'
  else
    printf 'BetterBash: frame prompt - the next prompt is two lines again (Alt+c for one line)\n'
  fi
}

# 4.4 is both the bash whose ${PS1@P} lets a prompt be looked at at all - which this
# file and its tests rely on - and the first one whose `bind -x` commands get
# READLINE_LINE back from the line they were called on.
BB_PROMPT_KEYS=1
if [ "${BASH_VERSINFO[0]}" -lt 4 ] ||
  { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 4 ]; }; then
  BB_PROMPT_KEYS=0
fi

case $- in
  *i*)
    if [ "$BB_PROMPT_KEYS" = 1 ]; then
      bind -x '"\C-x\C-p": __bb_line_take' 2>/dev/null || true
      bind -x '"\C-x\C-b": __bb_line_give' 2>/dev/null || true
      bind '"\ec": "\C-x\C-p\C-m\C-x\C-b"' 2>/dev/null || true
    else
      bind -x '"\ec": __bb_toggle_prompt_note' 2>/dev/null || true
    fi
    ;;
esac

# --- which elements of the top line the theme shows ----------------------
# Every element of the first line is optional and the theme says which show;
# prompt/bb-theme.sh decodes them from the theme code of the install command. A theme
# that does not mention an element shows it, so an older theme.sh (the avatar alone)
# and a machine without a theme still work.
#
# PROMPT_FILL is the tenth and last flag: the border fill, the dashes between the
# elements and the run that reaches the line to the width of the terminal. It is
# asked for and hidden like an element but is not one - see __prompt_command.
[ -z "${PROMPT_USER}" ] && PROMPT_USER='true'
[ -z "${PROMPT_HOST}" ] && PROMPT_HOST='true'
[ -z "${PROMPT_TTY}" ] && PROMPT_TTY='true'
[ -z "${PROMPT_JOBS}" ] && PROMPT_JOBS='true'
[ -z "${PROMPT_EXIT}" ] && PROMPT_EXIT='true'
[ -z "${PROMPT_DURATION}" ] && PROMPT_DURATION='true'
[ -z "${PROMPT_DATE}" ] && PROMPT_DATE='true'
[ -z "${PROMPT_CLOCK}" ] && PROMPT_CLOCK='true'
[ -z "${PROMPT_FILL}" ] && PROMPT_FILL='true'

# Whether the theme asks for an element: only 'true' shows it; 'false', an empty
# value and an unknown word all hide it.
function __bb_shown {
  case ${!1} in
    true | 1) return 0 ;;
    *) return 1 ;;
  esac
}

# A run of frame dashes of the asked length, without colour: the fill of the top
# line, and the width an element hands back when it does not show.
function __bb_dashes {
  if [ "${1:-0}" -le 0 ]; then
    __bb_dashes_out=''
  else
    local _run
    printf -v _run '%*s' "$1" ''
    __bb_dashes_out=${_run// /$HBAR}
  fi
}

# What an element that does not show leaves in its place: nothing while the fill can
# take its width back, frame dashes of exactly that width once the fill is gone. Needs
# ROOM, so it is called after the width of the line has been worked out.
function __bb_hidden {
  if [ "$BB_TOP_NARROW" = 1 ]; then
    __bb_dashes "$1"
    __bb_hidden_out="$BORDCOL$__bb_dashes_out"
  else
    __bb_hidden_out=''
  fi
}

CH=''
CHLINE=''
# The avatar with its brackets is ten glyphs, counted here and not from CH, whose
# length is mostly colour escapes - a length of escapes is not a width. With the two
# dashes of its separator it takes twelve glyphs out of the line, twelve while it
# shows and twelve handed back when the theme hides it.
AVATAR_GLYPHS=10
AVATAR_NATURAL=$(( AVATAR_GLYPHS + 2 ))
AVATAR_WIDTH=0
if __bb_shown AVATAR; then
  CH=$(hashColor "$(cat /etc/hostname)" 4)
  CHLINE="$SEPARATOR_COLOR($CH$SEPARATOR_COLOR)"
  AVATAR_WIDTH=$AVATAR_NATURAL
fi

function __prompt_command() {
  local RETURN_CODE="$?"
  PS1=""
  # The return code. Its width is the digits, the arrow and a bracket each; a command
  # that ended well is drawn as five dashes in the colour of the border, so they read
  # as the frame and not as an alarm. Hiding the code hides those dashes too - they
  # are the code.
  RCOL="${PRIMARY_COLOR}"
  EXIT_NATURAL=5
  if [[ $RETURN_CODE != 0 ]]; then
    RCOL="${ERR_COLOR}"
    EXIT_NATURAL=$(( ${#RETURN_CODE} + 4 ))
  fi
  if __bb_shown PROMPT_EXIT; then
    EXIT_WIDTH=$EXIT_NATURAL
  else
    EXIT_WIDTH=0
  fi

  # The seconds the last command ran, always in the primary colour: the exit code
  # segment already carries ERR_COLOR, and two alarms side by side read as one.
  __bb_timer_stop
  # Its visible width - separator dashes, brackets, digits and the s - so the fill
  # gives up exactly what the segment takes.
  TIMER_NATURAL=$(( ${#BB_TIMER_SHOW} + 5 ))
  if __bb_shown PROMPT_DURATION; then
    TIMER_WIDTH=$TIMER_NATURAL
  else
    TIMER_WIDTH=0
  fi

  USER=$(whoami)
  if [ $UID -eq "0" ]; then
     USERCOL=$ROOT_COLOR
     USER="${USER^^}"
  fi

  # The background process counter, rebuilt for every prompt so a job that ended
  # takes its segment away. Drawn as it was counted rather than through \j, so the
  # segment and its width cannot disagree about the digits.
  PROCCNT=$(jobs -p 2>/dev/null | wc -l)
  # Some wc pad the number they print, and a padded number is not a width.
  PROCCNT=$(( PROCCNT ))
  # Counted whether shown or not, so hiding it hands back a width the line knows. A
  # machine with no jobs hands back nothing.
  PROC_NATURAL=0
  if [ "$PROCCNT" -ne "0" ]; then
    # Separator dashes, a bracket each, the space and the arrow, and the digits.
    PROC_NATURAL=$(( ${#PROCCNT} + 6 ))
  fi
  if [ "$PROC_NATURAL" -ne 0 ] && __bb_shown PROMPT_JOBS; then
    PROC_WIDTH=$PROC_NATURAL
  else
    PROC_WIDTH=0
  fi

  # \h of PS1 prints the host up to its first dot, so the name counted for the width
  # of the line is cut the same way.
  HOSTNAM="$(cat /etc/hostname)"
  HOSTNAM=${HOSTNAM%%.*}

  GITPROMPT=$(__git_ps1 " on${PRIMARY_COLOR} %s")

  # The second line of the prompt, and the only one in the compact shape. Built once
  # for both, so the shapes cannot disagree; only the corner differs, and it is a
  # corner only while there is a frame above it.
  PR_CORNER=$PR_LLCORNER
  if [ "$BB_COMPACT" = 1 ]; then
    PR_CORNER=$PR_LLCORNER_COMPACT
  fi
  BOTTOM="\n$BORDCOL\[\016\]$PR_CORNER\[\017\]$BORDCOL$HBAR$SEPARATOR_COLOR(${PATH_COLOR}\w${SEPARATOR_COLOR})$BORDCOL$HBAR$SEPARATOR_COLOR(${PRIMARY_COLOR}\\\$$RST$GITPROMPT$SEPARATOR_COLOR)$BORDCOL-> \[\e[0m\]"

  # The compact prompt is the line the cursor stands on and nothing else - no frame,
  # no measuring for its fill.
  if [ "$BB_COMPACT" = 1 ]; then
    PS1="$BOTTOM"
    __bb_timer_reset
    return 0
  fi

  # (user@host:tty), the only element with parts of its own. The @ stands between a
  # name and a host when both show; the : belongs to the tty and is dropped when the
  # tty comes first, since the brackets would else open with it. The three share one
  # pair of brackets, and the brackets go with the last of them.
  ID='' ID_BODY_WIDTH=0 ID_FIRST=1
  if __bb_shown PROMPT_USER; then
    ID="$USERCOL$USER" ID_BODY_WIDTH=${#USER} ID_FIRST=0
  fi
  if __bb_shown PROMPT_HOST; then
    if [ "$ID_FIRST" -eq 0 ]; then
      ID="$ID$SEPARATOR_COLOR@" ID_BODY_WIDTH=$(( ID_BODY_WIDTH + 1 ))
    fi
    ID="${ID}${PRIMARY_COLOR}$HOSTNAM" ID_BODY_WIDTH=$(( ID_BODY_WIDTH + ${#HOSTNAM} ))
    ID_FIRST=0
  fi
  if __bb_shown PROMPT_TTY; then
    if [ "$ID_FIRST" -eq 0 ]; then
      ID="$ID$SEPARATOR_COLOR:" ID_BODY_WIDTH=$(( ID_BODY_WIDTH + 1 ))
    fi
    # The tty stands in the colour of the host: it says which machine this is as
    # much as the name does.
    ID="$ID$PRIMARY_COLOR$cur_tty" ID_BODY_WIDTH=$(( ID_BODY_WIDTH + ${#cur_tty} ))
  fi
  if [ -z "$ID" ]; then
    IDENTITY='' ID_WIDTH=0
  else
    IDENTITY="$SEPARATOR_COLOR($ID$SEPARATOR_COLOR)"
    ID_WIDTH=$(( ID_BODY_WIDTH + 2 ))
  fi
  # The brackets, the @ and the : of a whole (user@host:tty), over the names between.
  ID_NATURAL=$(( 4 + ${#USER} + ${#HOSTNAM} + ${#cur_tty} ))

  # Every segment of the right half stands behind two separator dashes. bash draws \d
  # as "Fri Sep 25" and \t as "17:52:36" - ten and eight glyphs - each in a bracket.
  DATE_NATURAL=$(( 10 + 2 + 2 ))
  CLOCK_NATURAL=$(( 8 + 2 + 2 ))
  if __bb_shown PROMPT_DATE; then
    DATE_WIDTH=$DATE_NATURAL
  else
    DATE_WIDTH=0
  fi
  if __bb_shown PROMPT_CLOCK; then
    CLOCK_WIDTH=$CLOCK_NATURAL
  else
    CLOCK_WIDTH=0
  fi

  # The fill is whatever width the terminal leaves between the two halves, so the top
  # line is as wide as the terminal less the four columns always left empty at its
  # right end: a line exactly as wide as the terminal wraps, and a frame that wraps
  # stops being a frame. Everything the shell can change (host, tty, digits of a
  # duration or a code) is measured above, so only the fill moves.
  # ROOM is what the fill would have were every element shown, so ROOM and not WIDTH
  # says when the frame has run out of terminal - a frame with three elements and one
  # with seven break at the same width. A hidden element hands its width to the fill;
  # once the fill is gone it draws its own width in frame dashes instead. The parts of
  # (user@host:tty) are the exception: a bracket full of dashes where a name stood
  # reads as a name of dashes, so there the line is simply shorter.
  LEFT_NATURAL=$(( 2 + ID_NATURAL + AVATAR_NATURAL + PROC_NATURAL ))
  RIGHT_NATURAL=$(( EXIT_NATURAL + TIMER_NATURAL + DATE_NATURAL + CLOCK_NATURAL + FRAME_TAIL_WIDTH ))
  ROOM=$(( $(tput cols) - 4 - LEFT_NATURAL - RIGHT_NATURAL ))
  BB_TOP_NARROW=0
  if ! __bb_shown PROMPT_FILL; then
    # No fill asked for: the line is only what it holds, and the width it does not
    # use belongs to the terminal.
    FILL=''
  elif [ "$ROOM" -le 0 ]; then
    BB_TOP_NARROW=1
    FILL=''
  else
    # What the hidden elements would have taken, on top of what the terminal leaves.
    HIDDEN=$(( ID_NATURAL - ID_WIDTH + AVATAR_NATURAL - AVATAR_WIDTH +\
      PROC_NATURAL - PROC_WIDTH + EXIT_NATURAL - EXIT_WIDTH +\
      TIMER_NATURAL - TIMER_WIDTH + DATE_NATURAL - DATE_WIDTH +\
      CLOCK_NATURAL - CLOCK_WIDTH ))
    __bb_dashes $(( ROOM + HIDDEN ))
    FILL="$BORDCOL$__bb_dashes_out"
  fi

  # The bodies of the elements, drawn now that the line knows its width: the segment
  # where the theme asks for it, the width handed back where it does not.
  if [ -z "$ID" ]; then
    __bb_hidden "$ID_NATURAL"
    IDENTITY=$__bb_hidden_out
  fi
  if [ -n "$CHLINE" ]; then
    AVATARSEG="$FRAME_SEP$CHLINE"
  else
    __bb_hidden "$AVATAR_NATURAL"
    AVATARSEG=$__bb_hidden_out
  fi
  if [ "$PROC_WIDTH" -ne 0 ]; then
    #BGPROCCOL='\033[1;95;5m'
    BGPROCCOL="$FRAME_SEP$SEPARATOR_COLOR(${SECONDARY_COLOR}$PROCCNT ↻$SEPARATOR_COLOR)"
  else
    __bb_hidden "$PROC_NATURAL"
    BGPROCCOL=$__bb_hidden_out
  fi
  if [ "$EXIT_WIDTH" -ne 0 ]; then
    if [[ $RETURN_CODE != 0 ]]; then
      EXIT="$SEPARATOR_COLOR(${ERR_COLOR}$RETURN_CODE ↵$SEPARATOR_COLOR)"
    else
      EXIT="$BORDCOL$HBAR$HBAR$HBAR$HBAR$HBAR"
    fi
    # The exit code is the one element with no separator of its own - the fill always
    # ran up to it. Without the fill it needs the two dashes the others carry.
    if ! __bb_shown PROMPT_FILL; then EXIT="$FRAME_SEP$EXIT"; fi
  else
    __bb_hidden "$EXIT_NATURAL"
    EXIT=$__bb_hidden_out
  fi
  if [ "$TIMER_WIDTH" -ne 0 ]; then
    TIMERSEG="$FRAME_SEP$SEPARATOR_COLOR(${PRIMARY_COLOR}${BB_TIMER_SHOW}s$SEPARATOR_COLOR)"
  else
    __bb_hidden "$TIMER_NATURAL"
    TIMERSEG=$__bb_hidden_out
  fi
  if [ "$DATE_WIDTH" -ne 0 ]; then
    DATESEG="$FRAME_SEP$SEPARATOR_COLOR($TIME_COLOR\d$SEPARATOR_COLOR)"
  else
    __bb_hidden "$DATE_NATURAL"
    DATESEG=$__bb_hidden_out
  fi
  # The clock takes the colour of an error when the last command left one, whether or
  # not the theme shows the exit code: without it the clock keeps silent about it.
  if [ "$CLOCK_WIDTH" -ne 0 ]; then
    CLOCKSEG="$FRAME_SEP$SEPARATOR_COLOR($RCOL\t$SEPARATOR_COLOR)"
  else
    __bb_hidden "$CLOCK_NATURAL"
    CLOCKSEG=$__bb_hidden_out
  fi

  LEFT="\n$BORDCOL\[\016\]$PR_ULCORNER$HBAR\[\017\]$IDENTITY$AVATARSEG$BGPROCCOL"
  RIGHT="$EXIT$TIMERSEG$DATESEG$CLOCKSEG$FRAME_TAIL"

  PS1="$LEFT$FILL$RIGHT$BOTTOM"

  __bb_timer_reset
}
