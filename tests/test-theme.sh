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

  for script in "$LIB" "$REPO_ROOT/getbb.sh" "$REPO_ROOT/removebb.sh" "$0"; do
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
    ok "decoded $_records codes byte for byte like the Go backend"
  else
    fail "decoded output differs from tests/golden/theme-golden.txt"
    sed 's/^/       /' "$WORK/golden.diff" | head -20
  fi
}

# --- validation ---------------------------------------------------------

validation() {
  printf '==> validation\n'

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

  # A code that fails validation must never become a file.
  _dir=$WORK/val-dir
  mkdir -p "$_dir"
  bb_theme_write 'no!' "$_dir" >/dev/null 2>&1
  check_fail "bb_theme_write leaves no theme.sh for an invalid code" test -f "$_dir/theme.sh"
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

  # Every line exactly eight theme code characters.
  if grep -v -E '^[A-Za-z0-9_-]{8}$' "$_out" >"$WORK/bad-codes.txt"; then :; fi
  if [ -s "$WORK/bad-codes.txt" ]; then
    fail "every generated code is ${BB_THEME_CODE_LENGTH} theme code characters"
    sed 's/^/       /' "$WORK/bad-codes.txt" | head -5
  else
    ok "every generated code is ${BB_THEME_CODE_LENGTH} theme code characters"
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

  _true=$(grep -c "AVATAR='true'" "$WORK/random-decoded.txt")
  _false=$(grep -c "AVATAR='false'" "$WORK/random-decoded.txt")
  if [ "$_true" -gt 0 ] && [ "$_false" -gt 0 ]; then
    ok "avatar flag comes up both ways (true: $_true, false: $_false)"
  else
    fail "avatar flag comes up both ways (true: $_true, false: $_false)"
  fi
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

  if ( . "$_dir/theme.sh" >/dev/null 2>&1 && [ -n "${PRIMARY_COLOR:-}" ] && [ -n "${AVATAR:-}" ] ); then
    ok "theme.sh is sourceable and defines the components"
  else
    fail "theme.sh is sourceable and defines the components"
  fi

  check "no leftover .new files" test ! -e "$_dir/theme.sh.new" -a ! -e "$_dir/theme-code.new"

  _second=$(bb_theme_resolve "$BB_THEME_RANDOM" "$_codefile")
  check "a second rand install keeps the stored code" test "$_second" = "$_first"

  BB_THEME_REROLL=1
  _third=$(bb_theme_resolve "$BB_THEME_RANDOM" "$_codefile")
  unset BB_THEME_REROLL
  check "BB_THEME_REROLL=1 draws a different code" test "$_third" != "$_first"

  printf 'not a code\n' >"$_codefile"
  _fourth=$(bb_theme_resolve "$BB_THEME_RANDOM" "$_codefile")
  check "a corrupt theme-code file falls back to a fresh draw" bb_theme_validate "$_fourth"

  check_fail "bb_theme_write refuses a missing directory" bb_theme_write 'vN-y_5uA' "$WORK/nope"
}

# Show a possibly empty or odd value on one line in a report.
_show() {
  _value=${1:-}
  [ -n "$_value" ] || _value='<empty>'
  printf '%s' "$_value"
}

# --- run ----------------------------------------------------------------

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
