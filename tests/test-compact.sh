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
# The key is three keys: it puts the typed line aside, accepts the empty line that is
# left - which is what makes bash draw a prompt, of the new shape, right there - and
# gives the line back. Four things follow from that and are held to as well: the new
# prompt stands on the screen before anything else was entered, the line and the
# cursor come back, nothing of the key reaches the history, and the key says nothing
# in words of its own, since the prompt that appears is the whole of the message.
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
# The other line of the frame, the one the fill is drawn on: a drawn prompt opens
# with the newline that moves it off the output before it, so the top line is the
# second one.
top_of_frame=$(printf '%s' "$frame" | sed -n '2p')

# Where the frame ends rather than turns, it ends with half a dash: the top line
# closes with three of them and then ┈, the same glyph the compact line opens with.
if printf '%s' "$top_of_frame" | grep -q '───┈$'; then
  ok 'the top line of the frame closes with three dashes and half a dash'
else
  fail 'the top line of the frame closes with three dashes and half a dash'
  printf '       top line %s\n' "$top_of_frame"
fi

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

# The functions below are what the key runs around an accept-line; they are called
# directly here, and the key itself is pressed in an interactive shell further down.
# Called directly, not in a subshell: the toggle is a change of this shell's state,
# and a subshell would toggle its own copy of it and report nothing.
BB_COMPACT=1
__bb_toggle_prompt
expect_eq 'the frame is back on after the second toggle' 0 "$BB_COMPACT"
expect_eq 'the frame is two lines again' 2 "$(lines_of "$(drawn)")"
BB_COMPACT=0
__bb_toggle_prompt
expect_eq 'and the compact prompt is on after the first one' 1 "$BB_COMPACT"

printf '==> the two halves of the key\n'

# Take empties the line - so that the accept-line the key types runs nothing at all -
# and keeps both the line and the cursor for give to put back. Outside a bind -x
# command READLINE_LINE is a variable like any other, so it is written here by hand.
BB_COMPACT=0
READLINE_LINE='echo typed and not entered'
READLINE_POINT=5
__bb_line_take
expect_eq 'the take flips the shape on' 1 "$BB_COMPACT"
expect_eq 'the take empties the line the accept-line runs' '' "$READLINE_LINE"
expect_eq 'the take keeps the line' 'echo typed and not entered' "$BB_LINE"
expect_eq 'the take keeps the cursor' 5 "$BB_POINT"
__bb_line_give
expect_eq 'the give puts the line back' 'echo typed and not entered' "$READLINE_LINE"
expect_eq 'the give puts the cursor back' 5 "$READLINE_POINT"
BB_COMPACT=0
unset READLINE_LINE READLINE_POINT

# The older key, for the bash that gives a bind -x command no line to keep: it says
# which shape came on, because there the new shape comes with the next prompt only
# and a key that changed nothing you could see would look broken.
BB_COMPACT=0
__bb_toggle_prompt_note >"$WORK/note" 2>&1
if grep -q 'compact prompt' "$WORK/note"; then
  ok 'the older key says which shape it turned on'
else
  fail "the older key says which shape it turned on (it said: $(cat "$WORK/note"))"
fi
BB_COMPACT=1
__bb_toggle_prompt_note >"$WORK/note" 2>&1
if grep -q 'frame prompt' "$WORK/note"; then
  ok 'and which shape it turned back on'
else
  fail "and which shape it turned back on (it said: $(cat "$WORK/note"))"
fi
BB_COMPACT=0

if [ "$BB_PROMPT_KEYS" = 1 ]; then
  ok 'a bash of this age gets the key that moves to a new line and draws it'
else
  fail 'a bash of this age gets the key that moves to a new line and draws it'
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
# A history of this session alone: the history of the machine running the test has
# other things in it, and the question asked below is about what this shell ran.
HISTFILE=$WORK/history
HISTSIZE=100
RC

  # What is typed, in the order it is typed. The Alt+t presses are bytes in the
  # stream of keystrokes, which is the only place a key exists.
  {
    printf 'echo MARK_A\n'
    # A line typed but not entered, the key pressed on top of it, and then entered:
    # the key takes the line away, draws the other shape, and gives the line back on
    # it. The answer is spelled apart from the question, so that only the answer is
    # one word.
    printf 'echo MARK_B'
    printf '\Et'
    printf '\n'
    printf 'echo MARK_C\n'
    # The same press from the other shape round: the prompt MARK_D was typed on is a
    # compact line, so the single top line of a frame printed between MARK_C and
    # MARK_D belongs to the key, and to nothing else.
    printf 'echo MARK_D'
    printf '\Et'
    printf '\n'
    printf 'echo MARK_E\n'
    # The key on an empty line - and on one whose kill ring still holds text, so
    # that a key which killed the line and yanked it back would walk that old text
    # onto the new line here and MARK_F would never be printed. \025 is what C-u
    # sends, and killing is what C-u does to what precedes the cursor.
    printf 'STALE'
    printf '\025'
    printf '\n'
    printf '\Et'
    printf 'echo MARK_F\n'
    # The history, asked whether the key left anything in it: the line the key
    # accepts is empty and an empty line is no command at all, so neither of its two
    # functions belongs there. The pattern carries one of its b-s inside a class, so
    # that it cannot count the very line that asks.
    printf '%s\n' 'echo HISTS="$(history | tail -n 10 | grep -c "__b[b]_")"'
    # The bindings, asked of the shell that holds them. A shell command bound to a
    # key is listed by bind -X and a macro by bind -s, and each is asked to answer
    # with a word split from the command that asks, so that the echo of the typing
    # cannot be mistaken for the answer.
    printf '%s\n' 'bind -X | grep -qF "\"\\C-x\\C-p\": \"__bb_line_take\"" && echo T""AKE'
    printf '%s\n' 'bind -X | grep -qF "\"\\C-x\\C-b\": \"__bb_line_give\"" && echo G""IVE'
    printf '%s\n' 'bind -s | grep -qF "\"\\et\": \"\\C-x\\C-p\\C-m\\C-x\\C-b\"" && echo M""ACRO'
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

  # MARK_A to MARK_B: the frame that MARK_B's prompt would have been - one top and
  # one bottom, drawn when MARK_A finished - and then, with the key pressed on the
  # empty line of that frame and before MARK_B ran, a single half line. Nothing was
  # entered in between, so the shape changed on the screen and not in a variable.
  # The half dash is counted as the opening of a line and not anywhere in one, since
  # the top line of the frame ends with it too (see the two shapes above).
  _tops=$(count_between MARK_A MARK_B '┌')
  _bottoms=$(count_between MARK_A MARK_B '└')
  _halves=$(between MARK_A MARK_B | grep -c '^┈─')
  if [ "$_tops" = 1 ] && [ "$_bottoms" = 1 ] && [ "$_halves" = 1 ]; then
    ok 'the key draws the one-line prompt itself, there and then'
  else
    fail "the key draws the one-line prompt itself, there and then (top: $_tops, bottom: $_bottoms, half: $_halves)"
  fi

  # MARK_C to MARK_D: and the other way round, where what the key draws is a frame no
  # command asked for. The prompt MARK_D was typed on is a compact line, so the one
  # top line of a frame in between is the key's; none would be the older key, which
  # waited for the next prompt to show anything at all.
  _frames=$(count_between MARK_C MARK_D '┌')
  _bottoms=$(count_between MARK_C MARK_D '└')
  if [ "$_frames" = 1 ] && [ "$_bottoms" = 1 ]; then
    ok 'the frame comes with the key, not with the next command'
  else
    fail "the frame comes with the key, not with the next command (top: $_frames, bottom: $_bottoms)"
  fi

  # That MARK_F was printed at all says the line typed after the key held MARK_F and
  # nothing else: the key was pressed on an empty line, and a key that killed the
  # line and yanked it back would have put STALE in front of it, and run no MARK_F.
  if cleaned | grep -qx 'MARK_F'; then
    ok 'the key gives back nothing it did not take, and an empty line stays empty'
  else
    fail 'the key gives back nothing it did not take, and an empty line stays empty'
  fi

  # The key is worth seeing, so it says nothing of itself: what changed is the prompt
  # standing where a note would have had to be.
  _notes=$(cleaned | grep -c 'BetterBash:')
  if [ "$_notes" = 0 ]; then
    ok 'the key leaves no note among what it drew'
  else
    fail "the key leaves no note among what it drew ($_notes of them)"
  fi

  # The line the key accepts is empty, and an empty line is not a command, so of the
  # two functions it runs nothing reaches the history.
  if cleaned | grep -qx 'HISTS=0'; then
    ok 'the accepted empty line leaves no trace in the history'
  else
    fail 'the accepted empty line leaves no trace in the history'
  fi

  # The three keys of the key, asked of the shell that holds them: the two halves
  # bound to shell functions with bind -x, and Alt+t bound to the macro that runs
  # them around an accept-line. Alt+t is spelled \e rather than \M- because a terminal
  # sends Alt and t as Escape followed by t, while \M-t is the single byte a terminal
  # only produces when it is 8-bit clean.
  for _answer in TAKE GIVE MACRO; do
    if cleaned | grep -qx "$_answer"; then
      ok "Alt+t is bound to the pair and an accept-line ($_answer)"
    else
      fail "Alt+t is bound to the pair and an accept-line ($_answer missing)"
    fi
  done

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
