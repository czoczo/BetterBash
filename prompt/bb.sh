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
# Half a dash: the lower half of HBAR. It is drawn where the frame ends instead of
# turning - at the far end of its top line, and at the corner of a prompt that has
# no frame above it, where it is what is left of └ once the line it hung from is
# gone (Alt+c, see the compact prompt below).
HALF_HBAR="┈"
PR_LLCORNER_COMPACT=$HALF_HBAR

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

# The dashes between the segments of the frame, and the run that closes its top
# line: three dashes and half a dash, so that the frame ends where it ends rather
# than turning back. They are named rather than written out where they are used,
# because the preview of the prompt on the WebUI copies them glyph for glyph and
# tests/test-frame.mjs compares the frame of the page with the frame the prompt
# draws.
FRAME_SEP=$BORDCOL$HBAR$HBAR
FRAME_TAIL=$BORDCOL$HBAR$HBAR$HBAR$HALF_HBAR
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

# --- the compact prompt, Alt+c ---------------------------------------------
# A prompt of two lines spends one of them on the machine: who, where, when, how
# long. Alt+c takes that line away and keeps only the one the command is typed on,
# for a small terminal, a crowded one, or a reader who has just seen all of that
# above. The corner that opens the kept line loses its frame, so it is drawn as the
# lower half of a dash instead of a corner.
#
# A prompt is drawn once, out of PS1, and bash will not redraw the one that already
# stands on the screen: a new shape comes with the next prompt and with no other.
# So the key does not only flip the switch - it asks bash for a prompt, which it can
# be asked for exactly one way: by accepting the line. Alt+c is three keys, and each
# of them is a thing a user could do by hand:
#
#   \C-x\C-p  the line being typed is put aside and the line emptied, and the shape
#             is flipped - all in the shell, through `bind -x`;
#   \C-m      accept-line: the line is empty, so nothing runs and bash expands PS1
#             again, drawing the new shape right here;
#   \C-x\C-b  the line is given back, with the cursor where it stood.
#
# Nothing typed is lost and nothing is executed: an accepted empty line is not a
# command, and bash never puts one in the history. The two keys of the pair are
# taken from readline's \C-x prefix, which is where a program puts keys of its own,
# and both are free of defaults there; they are bound in bash, and in its interactive
# shells only - `bind` in a script has no readline to bind on, and a warning about
# that would be noise in somebody else's output.
#
# Alt+c is spelled \ec and not \M-c, because a terminal sends Alt and c as Escape
# followed by c, while \M-c is the single byte a terminal only produces when it is
# 8-bit clean. The key is taken from readline's capitalize-word.
#
# A bash older than 4.4 hands a `bind -x` command no READLINE_LINE to put the typed
# text aside in, and a key that accepted the line would then run whatever the user
# had typed there. Such a shell gets the older key: it flips the shape and says so,
# because a shape that only shows with the next prompt would otherwise look broken.
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
# The first line of the frame is a row of elements and every one of them is
# optional. The theme says which of them show: prompt/bb-theme.sh decodes them
# from the theme code of the install command, and AVATAR - the host hashed into
# eight glyphs - is the one of them that was there before the rest had names. A
# theme that does not mention an element shows it: the theme.sh of an older
# install names the avatar alone, and a machine without a theme shows everything.
#
# PROMPT_FILL is the tenth flag, and the last of them: the border fill, the dashes
# between the elements and the run of them that reaches the line to the width of
# the terminal. It is asked for like an element and hidden like one, but it is not
# one - see __prompt_command for what a line without it looks like.
[ -z "${PROMPT_USER}" ] && PROMPT_USER='true'
[ -z "${PROMPT_HOST}" ] && PROMPT_HOST='true'
[ -z "${PROMPT_TTY}" ] && PROMPT_TTY='true'
[ -z "${PROMPT_JOBS}" ] && PROMPT_JOBS='true'
[ -z "${PROMPT_EXIT}" ] && PROMPT_EXIT='true'
[ -z "${PROMPT_DURATION}" ] && PROMPT_DURATION='true'
[ -z "${PROMPT_DATE}" ] && PROMPT_DATE='true'
[ -z "${PROMPT_CLOCK}" ] && PROMPT_CLOCK='true'
[ -z "${PROMPT_FILL}" ] && PROMPT_FILL='true'

# Whether the theme asks for an element. The flags are the strings the theme file
# holds, and only 'true' shows an element; 'false', an empty value and a word
# nobody wrote all hide it.
function __bb_shown {
  case ${!1} in
    true | 1) return 0 ;;
    *) return 1 ;;
  esac
}

# A run of dashes of the frame, as many as are asked for, and no colour: the fill
# between the two halves of the top line is such a run, and so is the width an
# element hands back when it does not show (see __prompt_command).
function __bb_dashes {
  if [ "${1:-0}" -le 0 ]; then
    __bb_dashes_out=''
  else
    local _run
    printf -v _run '%*s' "$1" ''
    __bb_dashes_out=${_run// /$HBAR}
  fi
}

# What an element that does not show leaves in its place: nothing where the fill
# is there to take its width back, and dashes of the frame of exactly that width
# where the fill has gone, so that the line is as long either way. It is called
# after the width of the line has been worked out, because it needs ROOM.
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
# The avatar with its brackets is ten glyphs, and it is counted here rather than
# from CH, whose length is mostly the escapes that colour its eight glyphs - and a
# length of escapes is not a width of a line. Behind those ten stand the two dashes
# of the avatar's separator, so twelve glyphs is what the avatar takes out of the
# line: twelve while it shows, and twelve handed back when the theme hides it (see
# __prompt_command).
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
  # Handling the return code. The width of the segment is the code, its arrow and
  # a bracket each; the five dashes that stand for a command that ended well are
  # drawn in the colour of the border, so that they read as the frame and not as
  # an alarm - they are drawn whether or not the fill before them carried that
  # colour. A theme that hides the code hides those dashes with it, because they
  # are the code and not something next to it.
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

  # The seconds the command that drew this prompt ran, and always in the primary
  # colour. Which command left which code is told by the segment of the exit
  # code, in ERR_COLOR; a duration wearing that colour too would say the same
  # thing twice, and the two of them would read as one alarm rather than as a
  # number of seconds next to a code.
  __bb_timer_stop
  # Its visible width - the two dashes of its separator, the brackets, the digits
  # and the s - so the fill gives up exactly what the segment takes, as
  # PROC_WIDTH does for the background process counter.
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

  # Handle background process counter. The counter is rebuilt for every prompt, so
  # a job that has ended takes its segment away instead of leaving it painted there
  # ever after. The number is drawn as it was counted rather than through \j, so
  # that the segment and the width given it cannot disagree about how many digits
  # they have.
  PROCCNT=$(jobs -p 2>/dev/null | wc -l)
  # Some wc pad the number they print, and a padded number is not a width.
  PROCCNT=$(( PROCCNT ))
  # Counted whether the theme shows the counter or not, so that hiding it hands
  # back a width the line knows instead of one it has to guess at. A machine with
  # no background jobs has no counter to hide, and hands back nothing.
  PROC_NATURAL=0
  if [ "$PROCCNT" -ne "0" ]; then
    # Two dashes of its separator, a bracket each, the space and the arrow, and
    # the digits of the count.
    PROC_NATURAL=$(( ${#PROCCNT} + 6 ))
  fi
  if [ "$PROC_NATURAL" -ne 0 ] && __bb_shown PROMPT_JOBS; then
    PROC_WIDTH=$PROC_NATURAL
  else
    PROC_WIDTH=0
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

  # The compact prompt is the line the cursor stands on and nothing else: neither
  # the frame above it nor all the measuring the fill of that frame needs.
  if [ "$BB_COMPACT" = 1 ]; then
    PS1="$BOTTOM"
    __bb_timer_reset
    return 0
  fi

  # (user@host:tty), the first element of the line and the only one with parts of
  # its own. The @ belongs to a name and a host together and stands between them
  # when both do; the : belongs to the tty, and is dropped when the tty comes
  # first in the brackets, which would else open with it. None of the three is a
  # segment of the line on its own: they share one pair of brackets, and the
  # brackets go with the last of them.
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
    # The terminal of the line stands in the colour of the host. `tty` says which
    # machine this is as much as its name does - the two are one thought about
    # where the command runs, not a name followed by a note about it.
    ID="$ID$PRIMARY_COLOR$cur_tty" ID_BODY_WIDTH=$(( ID_BODY_WIDTH + ${#cur_tty} ))
  fi
  if [ -z "$ID" ]; then
    IDENTITY='' ID_WIDTH=0
  else
    IDENTITY="$SEPARATOR_COLOR($ID$SEPARATOR_COLOR)"
    ID_WIDTH=$(( ID_BODY_WIDTH + 2 ))
  fi
  # The two brackets, the @ and the : of a whole (user@host:tty), over the names
  # it holds between them.
  ID_NATURAL=$(( 4 + ${#USER} + ${#HOSTNAM} + ${#cur_tty} ))

  # Every segment of the right half stands behind two dashes, the separator of
  # the frame, and the top line closes with four dashes of its own. bash draws \d
  # as "Fri Sep 25" and \t as "17:52:36" - ten and eight glyphs - each of them
  # between a bracket and behind its two dashes.
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
  # ROOM is what would be left for the fill were every element of the line shown -
  # the theme asks for some and hides others - and so it is ROOM, and not WIDTH,
  # that says when the frame has run out of terminal: a frame with three elements
  # and a frame with seven break at the same width and the line stays one length.
  # An element the theme hides hands its width to the fill, which grows by exactly
  # that; where the fill is gone because the terminal is too narrow for the whole
  # row, an element that hides draws its own width in dashes of the frame instead,
  # in the place it would have stood. The parts of (user@host:tty) are the one
  # exception: they stand inside a bracket, and a bracket full of dashes where a
  # name stood reads as a name of dashes, so below the break a line missing half of
  # its identity is shorter by what it is missing rather than padded.
  LEFT_NATURAL=$(( 2 + ID_NATURAL + AVATAR_NATURAL + PROC_NATURAL ))
  RIGHT_NATURAL=$(( EXIT_NATURAL + TIMER_NATURAL + DATE_NATURAL + CLOCK_NATURAL + FRAME_TAIL_WIDTH ))
  ROOM=$(( $(tput cols) - 4 - LEFT_NATURAL - RIGHT_NATURAL ))
  BB_TOP_NARROW=0
  if ! __bb_shown PROMPT_FILL; then
    # The theme asked for no fill, so the line is only what it holds: every element
    # that shows, two dashes between its neighbours, and no run of them reaching
    # the edge of the terminal. There is no fill to hand the width of a hidden
    # element to, so nothing is handed back and nothing padded - the line is simply
    # shorter, and the width it does not use belongs to the terminal.
    FILL=''
  elif [ "$ROOM" -le 0 ]; then
    BB_TOP_NARROW=1
    FILL=''
  else
    # What the elements the theme hides would have taken, on top of what the
    # terminal leaves over.
    HIDDEN=$(( ID_NATURAL - ID_WIDTH + AVATAR_NATURAL - AVATAR_WIDTH +\
      PROC_NATURAL - PROC_WIDTH + EXIT_NATURAL - EXIT_WIDTH +\
      TIMER_NATURAL - TIMER_WIDTH + DATE_NATURAL - DATE_WIDTH +\
      CLOCK_NATURAL - CLOCK_WIDTH ))
    __bb_dashes $(( ROOM + HIDDEN ))
    FILL="$BORDCOL$__bb_dashes_out"
  fi

  # The bodies of the elements, drawn now that the line knows how wide it is: the
  # segment where the theme asks for it, and what an element hands back where it
  # does not show.
  # A whole hidden identity hands its width back like every other element; a half
  # shown one is drawn as it is, and the width it is short is measured out of the
  # fill rather than padded with dashes that would read as a name of dashes.
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
    # The exit code is the one element of the line that carries no separator of its
    # own: the fill always ran up to it. Where there is no fill, the two dashes the
    # other elements carry are what joins it to what stands before it.
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
  # The clock is drawn in the colour of an error when the command that drew this
  # prompt left one, whether or not the theme asks for the exit code too: that
  # colour is what says the last command was an error, and without it the clock
  # would keep silent about it.
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
