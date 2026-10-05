#!/bin/sh
#
# Tests for prompt/bb-theme.sh, the POSIX shell decoder of BetterBash theme
# codes. They are run under dash and bash in CI and must not use bashisms.
#
#   ./tests/test-theme.sh              # everything
#   ./tests/test-theme.sh --quick      # skip the syntax sweep of every script
#
# The golden fixture in tests/golden/ is the output of the retired Go backend,
# so a theme code keeps producing the colours every install command published
# so far produced. tests/golden/README.md explains how to regenerate it.
#
# Besides that, what is checked is what the library promises: that a code of
# either format is read for what it is and anything else refused; that the
# elements of the top line of the prompt come over from the theme a draw replaces
# instead of coming up with the colours; that flags written as bits are read back
# as the assignments prompt/bb.sh sources; and that resolving and writing a theme
# leave exactly the two files they are supposed to leave.

set -u

TESTS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
LIB="$REPO_ROOT/prompt/bb-theme.sh"
CODES="$REPO_ROOT/tests/golden/theme-codes.txt"
GOLDEN="$REPO_ROOT/tests/golden/theme-golden.txt"
FAILURES=0
QUICK=0
RANDOM_SAMPLES=${RANDOM_SAMPLES:-60}

[ "${1:-}" = "--quick" ] && QUICK=1

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM

ok() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$1"
  FAILURES=$(( FAILURES + 1 ))
}

# check DESCRIPTION COMMAND...
check() {
  _description=$1
  shift
  if "$@" >"$WORK/last.out" 2>"$WORK/last.err"; then
    ok "$_description"
  else
    fail "$_description"
    sed 's/^/       /' "$WORK/last.err"
  fi
}

# check_fail DESCRIPTION COMMAND... - the command has to fail
check_fail() {
  _description=$1
  shift
  if "$@" >"$WORK/last.out" 2>"$WORK/last.err"; then
    fail "$_description (command unexpectedly succeeded)"
  else
    ok "$_description"
  fi
}

# --- syntax -------------------------------------------------------------

# The theme library and the installer have to parse under a strict POSIX shell,
# because they run before it is known which shell the user has. The prompt
# itself is bash only (arrays, ${var:5}, ${USER^^}) and is only checked against
# bash, so that a bashism there never hides in the POSIX part.
syntax_sweep() {
  printf '==> syntax\n'

  if [ "$QUICK" = "1" ]; then
    ok "syntax sweep skipped (--quick)"
    return
  fi

  for script in "$LIB" "$REPO_ROOT/removebb.sh" "$0"; do
    for shell in sh dash bash; do
      command -v "$shell" >/dev/null 2>&1 || continue
      check "$(basename "$script") parses under $shell" "$shell" -n "$script"
    done
  done

  for script in "$REPO_ROOT/prompt/bb.sh" "$REPO_ROOT/prompt/git-prompt.sh"; do
    command -v bash >/dev/null 2>&1 || continue
    check "$(basename "$script") parses under bash" bash -n "$script"
  done
}

# --- golden output ------------------------------------------------------

golden_matches() {
  printf '==> golden output of every code in the corpus\n'

  if [ ! -f "$GOLDEN" ] || [ ! -f "$CODES" ]; then
    fail "golden fixture present (tests/golden/)"
    return
  fi

  # One shell process for the whole corpus: decoding is builtins only.
  while IFS= read -r _code; do
    [ -n "$_code" ] || continue
    printf '### %s\n' "$_code"
    if ! bb_theme_decode "$_code"; then
      fail "decode $_code"
      return
    fi
  done <"$CODES" >"$WORK/actual.txt"

  # The fixture carries a comment header; records start at the first '###'.
  sed -n '/^### /,$p' "$GOLDEN" >"$WORK/expected.txt"

  _records=$(grep -c '^### ' "$WORK/expected.txt")
  if diff -u "$WORK/expected.txt" "$WORK/actual.txt" >"$WORK/golden.diff"; then
    ok "decoded $_records codes byte for byte like tests/golden"
  else
    fail "decoded output differs from tests/golden/theme-golden.txt"
    sed 's/^/       /' "$WORK/golden.diff" | head -20
  fi
}

# --- validation ---------------------------------------------------------

validation() {
  printf '==> validation\n'

  # Some of these are meant to look like shell syntax: they are input, and the
  # decoder must not react to any of them. Neither the command substitution of
  # one nor the quotes of another are code of this script - every word below is
  # handed to the decoder as an argument and never run - so the two findings that
  # read them as shell of this script are silenced here and only here.
  # shellcheck disable=SC2016,SC2089
  for _code in '' 'rand' 'vN-y_5u' 'vN-y_5uA!' 'vN-y_5uA/' 'vN-y_5uA+' \
               'vN y_5uA' 'vN-y_5uAB' 'AAAAAAAA=' '..' '/etc/passwd' '$(id)' "'; rm -rf /;'"; do
    if bb_theme_decode "$_code" >"$WORK/val.out" 2>"$WORK/val.err"; then
      fail "rejects '$(_show "$_code")'"
    else
      ok "rejects '$(_show "$_code")'"
    fi
    if [ -s "$WORK/val.out" ]; then
      fail "  and prints nothing for '$_code'"
    fi
  done

  if bb_theme_validate 'vN-y_5uA' 2>/dev/null; then
    ok "accepts a well formed theme code"
  else
    fail "accepts a well formed theme code"
  fi

  # The v1 format. The payload of all zero bits is a legal code: no colours and no
  # elements. Around it, the three things that make thirteen characters not one.
  if bb_theme_validate "$(_v1_code 000000000 0 0)" 2>/dev/null; then
    ok "accepts a well formed v1 code"
  else
    fail "accepts a well formed v1 code"
  fi
  _rejects_thirteen 'refuses a thirteen character code of another version' '2AAAAAAAAAAAA'
  # 120 ranks the five elements of the left half, so 120 is already no rank, and
  # 24 ranks the four of the right. The last rank of each is a rank.
  _rejects_thirteen 'refuses an ordering rank the left half has no name for' \
    "$(_v1_code 000000000 120 0)"
  _rejects_thirteen 'refuses an ordering rank the right half has no name for' \
    "$(_v1_code 000000000 0 24)"
  _rejects_thirteen 'refuses a reserved bit that version 1 leaves zero' \
    "$(_v1_code 000000000 0 0 1)"
  if bb_theme_validate "$(_v1_code 000000000 119 23)" 2>/dev/null; then
    ok "accepts the last rank of each half, which is a rank and not a mistake"
  else
    fail "accepts the last rank of each half, which is a rank and not a mistake"
  fi

  # The flags are the assignments prompt/bb.sh sources, in the order of BB_FLAGS:
  # a bit of one hides one element and no other. The last of the ten is the border
  # fill, and a code that says nothing about it - the one here - shows it.
  _want='010001101' # host, exit, duration and clock; no user, tty, avatar, jobs, date
  _flags_out=$(sh "$LIB" decode "$(_v1_code "$_want" 0 0)" | grep '^PROMPT_\|^AVATAR=')
  _want_out=$(printf "%s\n" \
    "PROMPT_USER='false'" "PROMPT_HOST='true'" "PROMPT_TTY='false'" "AVATAR='false'" \
    "PROMPT_JOBS='false'" "PROMPT_EXIT='true'" "PROMPT_DURATION='true'" \
    "PROMPT_DATE='false'" "PROMPT_CLOCK='true'" "PROMPT_FILL='true'")
  if [ "$_flags_out" = "$_want_out" ]; then
    ok "the flags of a code become the assignments prompt/bb.sh sources"
  else
    fail "the flags of a code become the assignments prompt/bb.sh sources"
    printf '       want %s\n       got  %s\n' "$(printf '%s' "$_want_out" | tr '\n' ' ')" "$(printf '%s' "$_flags_out" | tr '\n' ' ')"
  fi

  # The tenth flag, and the only one of them held against its name: the zero its
  # bit carries by default is the fill showing, and only a one takes it away - and
  # takes nothing else with it.
  _fills=$(_v1_code 111111111 0 0)
  _nofill=$(_v1_code 111111111 0 0 0 1)
  _fill_flags=$(bb_theme_flags "$_nofill")
  _fill_said=$(bb_theme_decode "$_nofill" | grep "^${BB_FILL}=")
  if [ "$(bb_theme_flags "$_fills")" = "$BB_FLAGS_ALL" ] &&
    [ "$_fill_flags" = '1111111110' ] && [ "$_fill_said" = "${BB_FILL}='false'" ]; then
    ok "a code asking for no fill takes the fill and nothing else ($_nofill)"
  else
    fail "a code asking for no fill takes the fill and nothing else ($_nofill)"
    printf '       flags %s, assignment %s\n' "$_fill_flags" "$_fill_said"
  fi

  # A code of eight characters says nothing about the fill either, and means the
  # line it always drew: stretched to the edge of the terminal.
  if [ "$(bb_theme_flags 'vN-y_5uA')" = "$BB_FLAGS_ALL" ] &&
    ! bb_theme_decode 'vN-y_5uA' | grep -q "^${BB_FILL}="; then
    ok "a code of eight characters shows the fill and does not mention it"
  else
    fail "a code of eight characters shows the fill and does not mention it"
  fi

  # A code that fails validation must never become a file.
  _dir=$WORK/val-dir
  mkdir -p "$_dir"
  bb_theme_write 'no!' "$_dir" >/dev/null 2>&1
  check_fail "bb_theme_write leaves no theme.sh for an invalid code" test -f "$_dir/theme.sh"
}

# _v1_code FLAGS LEFT RIGHT RESERVED NOFILL - a v1 code saying those things, built
# with the library's own encoder: nine flag bits as they are written in BB_ELEMENTS
# order, the two ordering ranks as numbers, the border fill as a code holds it - a
# one meaning it does not fill - and the reserved field as a number for the one
# check that means to set it. The colours are zero bits, because they are not what
# any of these checks is about. A check names the field it means rather than a
# code, so that a wrong encoder shows up as disagreeing with the other checks
# instead of agreeing with itself.
#
# The _bbt_*_out of the body are written by the helpers of the library this test
# sourced; a linter that does not follow a sourced shell function reads them as
# never assigned.
# shellcheck disable=SC2154
_v1_code() {
  _bbt_zeros "$BB_THEME_COLOR_BITS"; _vc_bits=$_bbt_bits_out
  _bbt_cut "$1" 0 "$BB_THEME_FLAG_COUNT"; _vc_bits="$_vc_bits$_bbt_cut_out"
  _bbt_bits_of_num "$2" "$BB_THEME_ORDER_LEFT_WIDTH"; _vc_bits="$_vc_bits$_bbt_bits_out"
  _bbt_bits_of_num "$3" "$BB_THEME_ORDER_RIGHT_WIDTH"; _vc_bits="$_vc_bits$_bbt_bits_out"
  _bbt_bits_of_num "${5:-0}" 1; _vc_bits="$_vc_bits$_bbt_bits_out"
  _bbt_bits_of_num "${4:-0}" "$BB_THEME_RESERVED_BITS"; _vc_bits="$_vc_bits$_bbt_bits_out"
  _bbt_bits_to_code "$_vc_bits" || return 1
  printf '%s%s' "$BB_THEME_VERSION" "$_bbt_code_out"
}

_rejects_thirteen() {
  _rt_what=$1 _rt_code=$2
  if bb_theme_validate "$_rt_code" 2>/dev/null; then
    fail "$_rt_what ($_rt_code)"
  else
    ok "$_rt_what ($_rt_code)"
  fi
}

# --- random codes -------------------------------------------------------

random_codes() {
  printf '==> random theme codes\n'

  _out=$WORK/random.txt
  : >"$_out"
  _i=0
  while [ "$_i" -lt "$RANDOM_SAMPLES" ]; do
    if ! bb_random_theme_code >>"$_out"; then
      fail "bb_random_theme_code returns a code"
      return
    fi
    _i=$((_i + 1))
  done

  if [ "$(wc -l <"$_out")" -eq "$RANDOM_SAMPLES" ]; then
    ok "generated $RANDOM_SAMPLES codes"
  else
    fail "generated $RANDOM_SAMPLES codes"
  fi

  # Every line a code of the current format: the digit of this version and its
  # payload, and nothing that validation would refuse.
  if grep -v -E "^${BB_THEME_VERSION}[A-Za-z0-9_-]{${BB_THEME_V1_PAYLOAD}}$" "$_out" >"$WORK/bad-codes.txt"; then :; fi
  if [ -s "$WORK/bad-codes.txt" ]; then
    fail "every generated code is a v${BB_THEME_VERSION} code of ${BB_THEME_V1_LENGTH} characters"
    sed 's/^/       /' "$WORK/bad-codes.txt" | head -5
  else
    ok "every generated code is a v${BB_THEME_VERSION} code of ${BB_THEME_V1_LENGTH} characters"
  fi

  # One bad code per line, in a file rather than in one word of the script: a
  # report split by spaces would make two faults of a code that holds a space.
  _bad=$WORK/bad-random.txt
  : >"$_bad"
  while IFS= read -r _code; do
    bb_theme_validate "$_code" 2>/dev/null || printf 'invalid: %s\n' "$_code" >>"$_bad"
    # A draw with no theme to replace says nothing about the elements of the
    # prompt, which is the same as showing all of them.
    [ "$(bb_theme_flags "$_code")" = "$BB_FLAGS_ALL" ] || printf 'flags: %s\n' "$_code" >>"$_bad"
  done <"$_out"
  if [ ! -s "$_bad" ]; then
    ok "every generated code validates and shows every element"
  else
    fail "every generated code validates and shows every element"
    sed 's/^/       /' "$_bad"
  fi

  _distinct=$(sort -u "$_out" | wc -l)
  if [ "$_distinct" -gt $(( RANDOM_SAMPLES * 3 / 4 )) ]; then
    ok "generated codes are mostly distinct ($_distinct unique)"
  else
    fail "generated codes are mostly distinct ($_distinct unique)"
  fi

  while IFS= read -r _code; do
    bb_theme_decode "$_code"
  done <"$_out" >"$WORK/random-decoded.txt"

  if grep -q ';30m' "$WORK/random-decoded.txt"; then
    fail "no plain black component in generated themes"
  else
    ok "no plain black component in generated themes"
  fi

# What a draw is not: a new set of elements. The two formats carry their elements
  # differently - v1 in nine bits and the fill in a bit of its own, v0 in the avatar
  # bit alone - and neither way may a draw turn the elements into part of the
  # colours it is drawing.
  # Everything but the host, the jobs and the clock, once with the fill and once
  # without: the fill of the theme a draw replaces is kept along with the elements.
  for _kept_flags in '1001011001' '1001011000'; do
    _bbt_cut "$_kept_flags" 9 1 || return 1
    # The fill goes into its bit against its name, as every encoder of this release
    # does: a flag of one shows it, and the bit of it stays zero.
    _kept=$(_v1_code "$_kept_flags" 0 0 0 "$(( 1 - _bbt_cut_out ))")
    _drawn=$(bb_theme_flags "$(bb_random_theme_code "$_kept")")
    if [ "$_drawn" = "$_kept_flags" ]; then
      ok "rand keeps the elements and the fill of the v1 code it replaces ($_kept)"
    else
      fail "rand keeps the elements and the fill of the v1 code it replaces ($_kept -> $_drawn)"
    fi
  done

  # vN-y_5uA has its avatar bit set and 02iBiOlH has not; the other eight elements
  # were never written down in either, and so show in both.
  for _v0 in 'vN-y_5uA' '02iBiOlH'; do
    _want=$(bb_theme_flags "$_v0")
    _drawn=$(bb_theme_flags "$(bb_random_theme_code "$_v0")")
    if [ "$_drawn" = "$_want" ]; then
      ok "rand keeps what the v0 code $_v0 said about its elements ($_want)"
    else
      fail "rand keeps what the v0 code $_v0 said about its elements ($_want -> $_drawn)"
    fi
  done

  # The word may carry a code with it, behind a colon: `rand:CODE`. The colours of
  # that code are drawn over - they are what a draw draws - and everything else it
  # says is worn: the ten boxes of the top line and the order of its two halves.
  # This is the form the WebUI writes while its Random box is ticked, so the boxes
  # ticked on the page reach a machine whose colours come from /dev/urandom.
  for _wear_flags in '1001011001' '0110100110' "$BB_FLAGS_ALL"; do
    _bbt_cut "$_wear_flags" 9 1 || return 1
    _wear=$(_v1_code "$_wear_flags" 0 0 0 "$(( 1 - _bbt_cut_out ))")
    _request="$BB_THEME_RANDOM:$_wear"

    bb_theme_is_random "$_request" && _says=yes || _says=no
    check "the word with a code behind it still asks for a draw ($_request)" test "$_says" = yes

    _tail=$(bb_theme_random_tail "$_request")
    if [ "$_tail" = "$_wear" ]; then
      ok "the code behind the word is read out of it ($_wear)"
    else
      fail "the code behind the word is read out of it ($_wear)"
    fi

    _drawn=$(bb_theme_resolve "$_request" "$WORK/absent-code-file")
    _drawn_flags=$(bb_theme_flags "$_drawn" 2>/dev/null)
    if bb_theme_validate "$_drawn" 2>/dev/null && [ "$_drawn_flags" = "$_wear_flags" ]; then
      ok "rand:$_wear draws colours over the elements of the code ($_wear_flags)"
    else
      fail "rand:$_wear draws colours over the elements of the code ($_wear_flags -> $_drawn_flags)"
    fi
  done

  # A request of that form is not a code, and never becomes one: it is refused as
  # what it is, and not quietly read as the bare word.
  _bad_requests='rand: rand:zz rand:AAAAAAAAAAAAB rand:vN-y_5uA/x'
  for _request in $_bad_requests; do
    if bb_theme_resolve "$_request" "$WORK/absent-code-file" >"$WORK/req.out" 2>"$WORK/req.err"; then
      fail "refuses '$_request'"
    else
      ok "refuses '$_request'"
    fi
    if [ -s "$WORK/req.out" ]; then
      fail "  and prints nothing for $_request"
    fi
  done

  # What the page draws with the same flags it hands over: the colours of a request
  # differ from run to run, its elements do not. Two runs of one request.
  _wear=$(_v1_code '1001011001' 0 0 0 0)
  _one=$(bb_theme_resolve "$BB_THEME_RANDOM:$_wear" "$WORK/absent-code-file")
  _two=$(bb_theme_resolve "$BB_THEME_RANDOM:$_wear" "$WORK/absent-code-file")
  check "a request worn over a code draws a theme twice over" test "$_one" != "$_two"
  check "and both of them wear the same elements" test "$(bb_theme_flags "$_one")" = "$(bb_theme_flags "$_two")"
}

# --- resolve and write --------------------------------------------------

resolve_and_write() {
  printf '==> resolving and writing themes\n'

  _dir=$WORK/bb
  mkdir -p "$_dir"
  _codefile="$_dir/theme-code"

  _passed=$(bb_theme_resolve 'vN-y_5uA' "$WORK/absent-code-file")
  check "resolve passes a real code through" test "$_passed" = 'vN-y_5uA'

  _first=$(bb_theme_resolve "$BB_THEME_RANDOM" "$_codefile")
  check "rand draws a theme code" bb_theme_validate "$_first"
  check "rand draws without writing anything down" test ! -f "$_codefile"

  check "bb_theme_write writes the theme" bb_theme_write "$_first" "$_dir"
  check "theme-code file holds the code" test "$(cat "$_codefile")" = "$_first"
  check "theme.sh exists" test -f "$_dir/theme.sh"
  check "theme.sh carries the code it came from" grep -q "# bb-theme-code: $_first" "$_dir/theme.sh"

  bb_theme_decode "$_first" >"$WORK/expected-theme.txt"
  sed -n '/^PRIMARY_COLOR=/,$p' "$_dir/theme.sh" >"$WORK/actual-theme.txt"
  if diff -u "$WORK/expected-theme.txt" "$WORK/actual-theme.txt" >"$WORK/write.diff"; then
    ok "theme.sh assignments are exactly what decode prints"
  else
    fail "theme.sh assignments are exactly what decode prints"
    sed 's/^/       /' "$WORK/write.diff" | head -20
  fi

  # shellcheck source=/dev/null
  if ( . "$_dir/theme.sh" >/dev/null 2>&1 && [ -n "${PRIMARY_COLOR:-}" ] && [ -n "${AVATAR:-}" ] ); then
    ok "theme.sh is sourceable and defines the components"
  else
    fail "theme.sh is sourceable and defines the components"
  fi

  check "no leftover .new files" test ! -e "$_dir/theme.sh.new" -a ! -e "$_dir/theme-code.new"

  # What a machine already wears is what "keep" and no code stand for.
  check "bb_theme_stored reads the code back" test "$(bb_theme_stored "$_codefile")" = "$_first"
  _kept=$(bb_theme_resolve "$BB_THEME_KEEP" "$_codefile")
  check "keep resolves to the stored code" test "$_kept" = "$_first"
  _noarg=$(bb_theme_resolve '' "$_codefile")
  check "no code at all resolves to the stored code" test "$_noarg" = "$_first"

  # A request that carries a code wears that code's elements and not the ones the
  # machine happens to hold: the boxes written into the request were written for
  # this run, and ~/.bb/theme-code is what the last one happened to leave.
  _wear=$(_v1_code '0110100111' 0 0 0 0)
  _worn=$(bb_theme_resolve "$BB_THEME_RANDOM:$_wear" "$_codefile")
  check "rand:CODE wears the elements of CODE and not of this machine" \
    test "$(bb_theme_flags "$_worn")" = '0110100111'

  # The point of rand: it is a draw, not a lookup of what is already there.
  _second=$(bb_theme_resolve "$BB_THEME_RANDOM" "$_codefile")
  check "a second rand draws a code" bb_theme_validate "$_second"
  check "a second rand draws another theme than $_first" test "$_second" != "$_first"

  # Ten draws in a row, each of them against the code the previous one left
  # behind: no run of rand may come back with the theme it is replacing.
  _same=0 _tries=0
  while [ "$_tries" -lt 10 ]; do
    _again=$(bb_theme_resolve "$BB_THEME_RANDOM" "$_codefile")
    [ "$_again" = "$_second" ] && _same=$((_same + 1))
    bb_theme_write "$_again" "$_dir" && _second=$_again
    _tries=$((_tries + 1))
  done
  check "rand never redraws the theme it is replacing" test "$_same" = 0

  # Read by bb_theme_resolve through the environment, for the callers of older
  # releases that only ever knew this way of asking for a new theme.
  # shellcheck disable=SC2034
  BB_THEME_REROLL=1
  _third=$(bb_theme_resolve '' "$_codefile")
  unset BB_THEME_REROLL
  check "BB_THEME_REROLL=1 with no code draws a different code" test "$_third" != "$_second"

  printf 'not a code\n' >"$_codefile"
  _fourth=$(bb_theme_resolve "$BB_THEME_RANDOM" "$_codefile")
  check "a corrupt theme-code file falls back to a fresh draw" bb_theme_validate "$_fourth"
  _fifth=$(bb_theme_resolve '' "$_codefile")
  check "a corrupt theme-code file falls back to a fresh draw without a code too" \
    bb_theme_validate "$_fifth"
  check "bb_theme_stored says nothing about a corrupt file" test -z "$(bb_theme_stored "$_codefile" 2>/dev/null)"

  check_fail "bb_theme_write refuses a missing directory" bb_theme_write 'vN-y_5uA' "$WORK/nope"
}

# Show a possibly empty or odd value on one line in a report.
_show() {
  _value=${1:-}
  [ -n "$_value" ] || _value='<empty>'
  printf '%s' "$_value"
}

# --- run ----------------------------------------------------------------

# shellcheck source=../prompt/bb-theme.sh
. "$LIB"

printf 'BetterBash theme library tests (%s)\n' "$(basename "$0")"
syntax_sweep
golden_matches
validation
random_codes
resolve_and_write

echo
if [ "$FAILURES" = "0" ]; then
  echo "prompt/bb-theme.sh passes every check"
else
  echo "$FAILURES check(s) failed"
fi
exit "$FAILURES"
