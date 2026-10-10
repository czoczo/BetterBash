#!/bin/bash
#
# The duration prompt/bb.sh shows for the command that drew a prompt.
#
#   ./tests/test-timer.sh
#
# The measurement hangs on bash deciding when to run the DEBUG trap, so both halves
# are checked: the functions, driven directly, and one real interactive shell in a
# pseudo terminal, which is the only place where the trap firing at all can be seen.
#
# What the functions are held to: the start of a command is recorded once, so a
# line of several commands is measured from its first one; a duration is never
# negative; a shell with no start to measure says 0s rather than invent a number;
# the segment is drawn between the exit code and the date and stays in the primary
# colour whatever the command ended with; and the width of the line does not
# depend on how many digits the duration has, because the fill gives up what the
# segment takes.
#
# prompt/bb.sh is bash, so this test is bash too and not POSIX shell - see
# tests/test-shellcheck.sh.

# No `set -u` here: prompt/bb.sh writes PRIMARY_COLOR=$PRIMARY_COLOR... whether or
# not a theme file of this machine defined those colours first, so nounset would
# stop it at the sourcing.

TESTS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
BB_DIR=$REPO_ROOT/prompt
export BB_DIR

FAILURES=0
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM

ok() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$1"
  FAILURES=$(( FAILURES + 1 ))
}

expect_eq() {
  _what=$1
  _want=$2
  _got=$3
  if [ "$_want" = "$_got" ]; then
    ok "$_what: $_want"
  else
    fail "$_what: want $_want, got $_got"
  fi
}

ESC=$(printf '\033')

# ${...@P} of an older bash cannot expand a prompt, and with it neither the width
# nor the drawing of a segment can be looked at.
prompt_expands() {
  [ "${BASH_VERSINFO[0]}" -gt 4 ] ||
    { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 4 ]; }
}

# first_index NEEDLE - characters of PS1 before NEEDLE, or -1 when it is not there.
first_index() {
  if [[ $PS1 != *"$1"* ]]; then
    printf -- '-1'
    return 0
  fi
  _prefix=${PS1%%"$1"*}
  printf '%s' "${#_prefix}"
}

# visible_top_width - what the first line of the drawn frame shows, i.e. with the
# escapes left out. \[ and \] of PS1 become \001 and \002 once it is expanded.
visible_top_width() {
  _line=${PS1@P}
  _line=${_line#*$'\n'}  # past the newline that starts the frame
  _line=${_line%%$'\n'*} # up to the newline ending the top line
  _line=${_line//$'\001'/}
  _line=${_line//$'\002'/}
  _line=${_line//$'\016'/}
  _line=${_line//$'\017'/}
  _line=$(printf '%s' "$_line" | sed -e "s/${ESC}\[[0-9;]*[a-zA-Z]//g")
  printf '%s' "${#_line}"
}

# draw DURATION RETURN_CODE - the prompt of a command that ran DURATION seconds and
# ended with RETURN_CODE, as bash would have built it for that command.
draw() {
  _d=$1
  BB_TIMER=$(( SECONDS - _d ))
  case $2 in
    0) true ;;
    *) false ;;
  esac
  __prompt_command
}

. "$BB_DIR/bb.sh" >/dev/null 2>&1

printf '==> the timer of %s\n' "$BB_DIR/bb.sh"

# One command, the seconds it ran.
unset BB_TIMER BB_TIMER_SHOW
__bb_timer_start
sleep 1
__bb_timer_stop
expect_eq "a one second command" 1 "$BB_TIMER_SHOW"

# Several commands drawn for one prompt (`make && make install`, a loop): the start
# of the first one is kept, so all of them are measured.
unset BB_TIMER BB_TIMER_SHOW
__bb_timer_start
sleep 1
__bb_timer_start
sleep 1
__bb_timer_stop
expect_eq "two commands of one line" 2 "$BB_TIMER_SHOW"

# Once the start is let go there is nothing to measure, and the clock the shell
# started at must not be used instead - that would be the age of the shell.
__bb_timer_reset
__bb_timer_stop
expect_eq "no start held" 0 "$BB_TIMER_SHOW"

# A command that reset SECONDS itself would measure backwards.
__bb_timer_start
# shellcheck disable=SC2034 # the timer of prompt/bb.sh is the one reading this
BB_TIMER=$(( SECONDS + 30 ))
__bb_timer_stop
expect_eq "a backwards clock" 0 "$BB_TIMER_SHOW"

if ! prompt_expands; then
  fail "bash ${BASH_VERSION} cannot expand a prompt with \${PS1@P}"
  exit "$FAILURES"
fi

printf '==> the segment it draws\n'

draw 42 1
DUR_INDEX=$(first_index '42s')
EXIT_INDEX=$(first_index '↵')
DATE_INDEX=$(first_index '\d')
if [ "$EXIT_INDEX" -ge 0 ] && [ "$DUR_INDEX" -gt "$EXIT_INDEX" ] &&
  [ "$DATE_INDEX" -gt "$DUR_INDEX" ]; then
  ok 'the duration is drawn after the exit code and before the date'
else
  fail "the duration is drawn after the exit code and before the date (exit=$EXIT_INDEX duration=$DUR_INDEX date=$DATE_INDEX)"
fi

# The colour of the duration does not follow the exit code: the exit code has a
# segment of its own to speak in ERR_COLOR, and the seconds say nothing of it.
for rc in 0 1; do
  draw 42 "$rc"
  case $PS1 in
    *"$PRIMARY_COLOR"'42s'*) ok "a command ending in $rc leaves the duration in PRIMARY_COLOR" ;;
    *) fail "a command ending in $rc leaves the duration in PRIMARY_COLOR" ;;
  esac
done

# The digits of a duration are not known in advance, so the fill has to give up as
# many dashes as the segment carries, whatever the number of digits is.
COLUMNS=120
export COLUMNS
WIDTHS=()
for duration in 9 42 1234; do
  draw "$duration" 0
  WIDTHS+=("$duration:$(visible_top_width)")
done
_same=1
for _w in "${WIDTHS[@]}"; do
  [ "${_w#*:}" = "${WIDTHS[0]#*:}" ] || _same=0
done
if [ "$_same" = 1 ]; then
  ok "the line is ${WIDTHS[0]#*:} wide over ${WIDTHS[*]}"
else
  fail "the line keeps its width over ${WIDTHS[*]}"
fi

# A frame too wide for the terminal is drawn on two lines and stops being a frame,
# so the fill is what has to give way first.
_width=${WIDTHS[0]#*:}
if [ "$_width" -le "$COLUMNS" ]; then
  ok "the frame fits $COLUMNS columns ($_width)"
else
  fail "the frame fits $COLUMNS columns ($_width)"
fi

# interactive_shell - one bash with the prompt of this tree, in a pseudo terminal.
# What it measured is read back from the shell itself, and the frames it drew are
# counted in its own output.
interactive_shell() {
  cat >"$WORK/rc" <<RC
export BB_DIR=$BB_DIR
. "\$BB_DIR/bb.sh"
RC

  printf 'sleep 3\necho MEASURED=%s@\nexit\n' '${BB_TIMER_SHOW}' >"$WORK/cmds"
  script -qec "bash --rcfile $WORK/rc" /dev/null <"$WORK/cmds" >"$WORK/pty" 2>&1

  _measured=$(sed -nE 's/.*MEASURED=([0-9]+)@.*/\1/p' "$WORK/pty" | head -1 | tr -d '\r')
  case ${_measured:-} in
    3 | 4) ok "sleep 3 of an interactive shell measured ${_measured}s" ;;
    *) fail "sleep 3 of an interactive shell measured ${_measured:-nothing}" ;;
  esac

  _seen=$(sed -e "s/${ESC}\[[0-9;?]*[a-zA-Z]//g" "$WORK/pty" |
    tr -d '\r' | grep -c '([0-9]\{1,3\}s)')
  if [ "$_seen" -ge 2 ]; then
    ok "$_seen prompts drew a duration of their own"
  else
    fail "the prompts draw a duration of their own (seen $_seen)"
  fi
}

printf '==> an interactive shell\n'

# Whether the DEBUG trap runs before the commands of an interactive shell is bash's
# doing, and cannot be driven from a script.
if command -v script >/dev/null 2>&1; then
  interactive_shell
else
  ok 'no script(1) here, so no interactive shell was run'
fi

if [ "$FAILURES" = 0 ]; then
  printf '\nthe last command is measured and its seconds are drawn\n'
else
  printf '\n%d check(s) failed\n' "$FAILURES" >&2
fi
exit "$FAILURES"
