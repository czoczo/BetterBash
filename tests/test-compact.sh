#!/bin/bash
#
# The compact prompt of BetterBash, and the Alt+t that switches it.
#
#   ./tests/test-compact.sh
#
# The frame is two lines and one of them is spent on the machine rather than on the
# command being typed, so Alt+t takes that line away and keeps the other. Two things
# are held here: the shape of what is left - the second line of the frame and nothing
# else, opened by a corner that has no line hanging from it any more - and the key,
# which is tried in a real interactive shell in a pseudo terminal, because a binding
# of a shell that has no readline is not a binding at all.
#
# Both shapes are drawn by bash itself, with the same ${PS1@P} an interactive shell
# expands, and compared with each other: what the compact line shows has to be what
# the second line of the frame shows, glyph for glyph, or the two shapes of one
# prompt would disagree about the machine they stand in.
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

# ${...@P} of an older bash cannot expand a prompt, and without it neither shape can
# be looked at - the same guard tests/test-timer.sh makes.
prompt_expands() {
  [ "${BASH_VERSINFO[0]}" -gt 4 ] ||
    { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 4 ]; }
}
if ! prompt_expands; then
  fail "bash ${BASH_VERSION} cannot expand a prompt with \${PS1@P}"
  exit "$FAILURES"
fi

# drawn - PS1 as an interactive shell would have expanded it, with the \[ \] of bash
# (which become \001 and \002 once a prompt is expanded) and the escapes of the
# terminal left out, so that what is compared is what is painted.
drawn() {
  __prompt_command
  _p=${PS1@P}
  _p=${_p//$'\001'/}
  _p=${_p//$'\002'/}
  _p=${_p//$'\016'/}
  _p=${_p//$'\017'/}
  printf '%s' "$_p" | sed -e "s/${ESC}\[[0-9;]*[a-zA-Z]//g"
}

# lines_of TEXT - the lines a drawn prompt paints. Every shape of the prompt opens
# with the newline that moves it off the output before it, and that one is not one of
# the lines it paints.
lines_of() {
  printf '%s' "$1" | awk 'END { print NR - 1 }'
}

# last_line TEXT - the line the cursor stands on, i.e. the last of a drawn prompt.
last_line() {
  _t=$1
  printf '%s' "${_t##*$'\n'}"
}

printf '==> sourcing prompt/bb.sh of %s\n' "$BB_DIR"

# Sourced by a script, the prompt has no readline to bind Alt+t on, and has to keep
# quiet about it: scripts and tests source this file all the time.
_noise=$(bash -c ". '$BB_DIR/bb.sh'" 2>&1 >/dev/null)
if [ -z "$_noise" ]; then
  ok 'a shell with no readline is sourced without a word about the binding'
else
  fail "a shell with no readline is sourced without a word about the binding (got: $_noise)"
fi

COLUMNS=120
export COLUMNS

printf '==> the two shapes\n'

# The default is the frame as it has always been: two lines, of which the top one is
# the frame and the bottom one the prompt.
unset BB_COMPACT
. "$BB_DIR/bb.sh" >/dev/null 2>&1
if [ "${BB_COMPACT:-unset}" = 0 ]; then
  ok 'BB_COMPACT starts at 0, so a shell wears the frame it always wore'
else
  fail "BB_COMPACT starts at 0, so a shell wears the frame it always wore (it is ${BB_COMPACT:-unset})"
fi

frame=$(drawn)
expect_eq 'the frame is two lines' 2 "$(lines_of "$frame")"
bottom_of_frame=$(last_line "$frame")

BB_COMPACT=1
compact=$(drawn)
expect_eq 'the compact prompt is one line' 1 "$(lines_of "$compact")"

case $compact in
  *'┌'* | *'└'*) fail 'the compact prompt holds no frame' ;;
  *) ok 'the compact prompt holds no frame' ;;
esac

# What is kept of the prompt is its second line, and only its opening glyph differs:
# a corner needs the line that hung from it.
if [ "$(last_line "$compact")" = "${bottom_of_frame/└/┈}" ]; then
  ok 'the compact line is the second line of the frame, opened by half a dash'
else
  fail 'the compact line is the second line of the frame, opened by half a dash'
  printf '       frame    %s\n       compact line %s\n' "$(last_line "$compact")" "${bottom_of_frame/└/┈}"
fi

# The shape of the line, read as it is painted: half a dash, a directory, the
# prompt of the shell, and the arrow that asks for a command.
if printf '%s' "$(last_line "$compact")" | grep -qE '^┈─\(.*)─\(.*)-> $'; then
  ok 'the compact line opens with ┈─ and closes with the arrow'
else
  fail "the compact line opens with ┈─ and closes with the arrow (it is: $(last_line "$compact"))"
fi

# The frame measures its terminal to size the fill between its two halves; the
# compact line has no fill to size, so it is one line in a narrow terminal too.
_narrow=$(COLUMNS=40 drawn)
_wide=$(COLUMNS=200 drawn)
expect_eq 'the compact line does not care how wide the terminal is' \
  "$(last_line "$_wide")" "$(last_line "$_narrow")"

printf '==> toggling it back\n'

# The function below is what the key runs; it is called directly here, and the key
# itself is pressed in an interactive shell further down.
BB_COMPACT=1
# Called directly, not in a subshell: the toggle is a change of this shell's state,
# and a subshell would toggle its own copy of it and report nothing.
__bb_toggle_prompt >"$WORK/note" 2>&1
note=$(cat "$WORK/note")
expect_eq 'the frame is back on after the second toggle' 0 "$BB_COMPACT"
case $note in
  *'frame prompt'*) ok 'toggling back says which shape came back' ;;
  *) fail "toggling back says which shape came back (it said: $note)" ;;
esac
expect_eq 'the frame is two lines again' 2 "$(lines_of "$(drawn)")"

BB_COMPACT=0
__bb_toggle_prompt >"$WORK/note" 2>&1
expect_eq 'and the compact prompt is on after the first one' 1 "$BB_COMPACT"
if grep -q 'compact prompt' "$WORK/note"; then
  ok 'a toggle says which shape it turned on, and that comes with the next prompt'
else
  fail 'a toggle says which shape it turned on, and that comes with the next prompt'
fi

# --- an interactive shell, with the key pressed ---------------------------

# One bash with the prompt of this tree and the readline block of it, in a pseudo
# terminal, because whether Alt+t is bound at all is bash's and readline's doing and
# cannot be driven from a script. The commands it runs are markers: the prompts drawn
# between two of them belong to that stretch, and a toggle shows only there.
interactive_shell() {
  cat >"$WORK/rc" <<RC
export BB_DIR=$BB_DIR
. "\$BB_DIR/bb.sh"
bind -f $REPO_ROOT/.inputrc
RC

  # What is typed, in the order it is typed. The two Alt+t presses are bytes in the
  # stream of keystrokes, which is the only place a key exists.
  {
    printf 'echo MARK_A\necho MARK_B\n'
    printf '\Et\n'
    printf 'echo MARK_C\necho MARK_D\necho MARK_E\n'
    printf '\Et\n'
    printf 'echo MARK_F\necho MARK_G\n'
    # A line typed but not entered, the key pressed on top of it, and then entered:
    # the key runs a function and has to leave what was typed alone. The answer is
    # spelled apart from the question, so that only the answer is one word.
    printf 'echo u""nchanged'
    printf '\Et'
    printf '\n'
    # The bindings, asked of the shell that holds them. A shell command bound to a
    # key is listed by bind -X and a readline function by bind -p, and both are asked
    # to answer with a word split from the command that asks, so that the echo of the
    # typing cannot be mistaken for the answer.
    printf '%s\n' 'bind -X | grep -qF "\"\\et\": \"__bb_toggle_prompt\"" && echo B""OUND'
    printf 'bind -p | grep -q history-search-backward && echo S""EARCHED\n'
    printf 'exit\n'
  } >"$WORK/typed"

  script -qec "bash --rcfile $WORK/rc" /dev/null <"$WORK/typed" >"$WORK/pty" 2>&1

  # cleaned - the output of the terminal, with the escapes it moved its cursor with
  # and the carriage returns and shift codes of the frame taken out.
  cleaned() {
    sed -e "s/${ESC}\[[0-9;?]*[a-zA-Z]//g" "$WORK/pty" | tr -d '\r\016\017'
  }

  # between FIRST LAST - what the terminal printed between the line that answers
  # FIRST and the line that answers LAST, neither of them included. The escapes the
  # terminal moved its cursor with are taken out first, because a line of a terminal
  # begins with one of them rather than with what was printed. The echo of what was
  # typed carries a marker too, so a marker is matched as a line of its own.
  between() {
    cleaned |
      awk -v a="$1" -v b="$2" '
        { sub(/[ \t]+$/, "") }
        $0 == a { on = 1; next }
        $0 == b { on = 0 }
        on
      '
  }

  count_between() { between "$1" "$2" | grep -c "$3"; }

  # MARK_B to MARK_C: the key was pressed and its note printed. The prompt of the
  # line MARK_C was typed on is still the frame, because bash cannot redraw the
  # prompt that already stands on the screen - which is why the note is printed.
  if between MARK_B MARK_C | grep -q 'BetterBash: compact prompt'; then
    ok 'the key answers with the shape it turned on'
  else
    fail 'the key answers with the shape it turned on'
  fi

  # MARK_C to MARK_D: the first prompt drawn after the key, which is the compact
  # one, so the frame is gone with it.
  _frames=$(count_between MARK_C MARK_D '┌')
  _halves=$(count_between MARK_C MARK_D '┈')
  if [ "$_frames" = 0 ] && [ "$_halves" -ge 1 ]; then
    ok 'the prompt after the key is one line, opened by half a dash'
  else
    fail "the prompt after the key is one line, opened by half a dash (frames: $_frames, halves: $_halves)"
  fi

  # MARK_E to MARK_F: the second press, whose note comes before any new shape.
  if between MARK_E MARK_F | grep -q 'frame prompt'; then
    ok 'the key answers with the frame it turned back on'
  else
    fail 'the key answers with the frame it turned back on'
  fi

  # MARK_F to MARK_G: and the frame is drawn again, two lines as before the key.
  _frames=$(count_between MARK_F MARK_G '┌')
  _bottoms=$(count_between MARK_F MARK_G '└')
  if [ "$_frames" -ge 1 ] && [ "$_bottoms" -ge 1 ]; then
    ok 'the prompt after the second press is the frame again'
  else
    fail "the prompt after the second press is the frame again (top: $_frames, bottom: $_bottoms)"
  fi

  # The line that was typed when the key was pressed, answered.
  if cleaned | grep -q '^unchanged$'; then
    ok 'the key leaves what is typed on the line where it was'
  else
    fail 'the key leaves what is typed on the line where it was'
  fi

  # The key is bound with \e rather than \M-, because a terminal sends Alt and t as
  # Escape followed by t, while \M-t is the single byte a terminal only produces when
  # it is 8-bit clean.
  if cleaned | grep -q '^BOUND$'; then
    ok 'Alt+t is bound to the toggle in a shell that has readline'
  else
    fail 'Alt+t is bound to the toggle in a shell that has readline'
  fi

  # The arrow keys of ~/.inputrc are read after the prompt, which is what ~/.bashrc
  # does, and neither binding may take the other away: the two shapes of the prompt
  # and the search of the history have to be bound in the same shell at once.
  if cleaned | grep -q '^SEARCHED$'; then
    ok 'Alt+t and the history search of the arrow keys hold each other'
  else
    fail 'Alt+t and the history search of the arrow keys hold each other'
  fi
}

printf '==> an interactive shell\n'

if command -v script >/dev/null 2>&1; then
  interactive_shell
else
  ok 'no script(1) here, so no interactive shell was run'
fi

if [ "$FAILURES" = 0 ]; then
  printf '\nAlt+t collapses the prompt to its second line and back\n'
else
  printf '\n%d check(s) failed\n' "$FAILURES" >&2
fi
exit "$FAILURES"
