#!/bin/sh
#
# BetterBash end to end installation tests.
#
# Every download method of getbb.sh is run against a staging of this working
# copy, in a throwaway home directory, and the result is checked: the files that
# land in ~/.bb, the theme that was decoded, the hook in ~/.bashrc, the readline
# block in ~/.inputrc, and the prompt prompt/bb.sh finally builds. removebb.sh is
# run afterwards and has to leave nothing behind.
#
#   ./test-install-methods.sh                       # all methods, every shell
#   ./test-install-methods.sh --code vN-y_5uA       # theme code to install
#   ./test-install-methods.sh --live URL            # test a deployed site instead
#   ./test-install-methods.sh --method curl         # one method only
#   ./test-install-methods.sh --shell dash          # one shell only
#   ./test-install-methods.sh --keep                # keep the test homes
#
# --live is how this checks a deployment (GitHub Pages) rather than a working
# copy; it needs no server and no certificate:
#
#   ./test-install-methods.sh --live https://betterbash.cz0.cz --code vN-y_5uA
#
# The staging served locally is produced by tests/stage-downloads.sh, the same
# script the Pages workflow uses, so the layout cannot drift apart from it. A
# self signed certificate is generated for the openssl method.
#
# The commands the WebUI prints are rendered by tests/install-commands.mjs and
# run verbatim, so "what is on the page" and "what installs" are the same thing.

set -u

REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
BB_TEST_CODE=${BB_TEST_CODE:-vN-y_5uA}
BB_TEST_METHODS=${BB_TEST_METHODS:-curl wget openssl}
BB_TEST_SHELLS=${BB_TEST_SHELLS:-sh bash dash}
BB_LIVE_URL=""
BB_KEEP=0
BB_HTTP_PORT=0
BB_HTTPS_PORT=0
BB_SERVE_DIR=$REPO_ROOT

PASS=0
FAIL=0

# --- helpers ----------------------------------------------------------------

log_info() {
  printf '\n\033[36m>> %s\033[0m\n' "$*"
}

log_success() {
  printf '\033[32m     PASS\033[0m %s\n' "$*"
  PASS=$(( PASS + 1 ))
}

log_error() {
  printf '\033[31m     FAIL\033[0m %s\n' "$*"
  FAIL=$(( FAIL + 1 ))
}

# expect_file PATH DESCRIPTION
expect_file() {
  if [ -f "$1" ]; then
    log_success "$2"
  else
    log_error "$2 (missing $1)"
  fi
}

# expect_grep PATTERN FILE DESCRIPTION
expect_grep() {
  if grep -q -- "$1" "$2" 2>/dev/null; then
    log_success "$3"
  else
    log_error "$3 (no '$1' in $2)"
  fi
}

expect_not_grep() {
  if grep -q -- "$1" "$2" 2>/dev/null; then
    log_error "$2 still contains '$1' ($3)"
  else
    log_success "$3"
  fi
}

# new_home -> echoes a fresh home directory, exported as $HOME for the run
new_home() {
  _home=$(mktemp -d)
  # The two files getbb.sh appends to have to exist, like on a normal machine.
  : >"$_home/.bashrc"
  : >"$_home/.inputrc"
  printf '%s' "$_home"
}

while [ $# -gt 0 ]; do
  case $1 in
    --code) BB_TEST_CODE=${2:-}; shift ;;
    --dir) BB_SERVE_DIR=$(cd "${2:-}" && pwd); shift ;;
    --live) BB_LIVE_URL=${2:-}; shift ;;
    --method) BB_TEST_METHODS=${2:-}; shift ;;
    --shell | --shells) BB_TEST_SHELLS=${2:-}; shift ;;
    --http-port) BB_HTTP_PORT=${2:-}; shift ;;
    --https-port) BB_HTTPS_PORT=${2:-}; shift ;;
    --keep) BB_KEEP=1 ;;
    -h | --help)
      awk 'NR <= 2 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

case $BB_TEST_CODE in
  rand) ;;
  ????????) ;;
  *)
    printf '%s is not a theme code (eight characters of A-Za-z0-9_-, or "rand")\n' "$BB_TEST_CODE" >&2
    exit 2
    ;;
esac

WORK=$(mktemp -d)
SERVER_PID=""
HOMES=""

# shellcheck disable=SC2317
# The trap handler looks unreachable to shellcheck.
cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null
  [ -n "$HOMES" ] || return 0
  if [ "$BB_KEEP" = "1" ]; then
    printf '\nKept test homes:%s\n' "$(printf '%s' "$HOMES" | tr '\n' ' ')"
    return 0
  fi
  for _h in $HOMES; do rm -rf "$_h"; done
}
trap cleanup EXIT INT TERM

# --- staging and server -----------------------------------------------------

STAGE=$WORK/downloads
BASES=""

if [ -n "$BB_LIVE_URL" ]; then
  log_info "testing the deployment at $BB_LIVE_URL"
  BASES=$BB_LIVE_URL
  # The installers of the deployment are what the user runs, so they are fetched
  # rather than taken from this working copy.
  mkdir -p "$WORK/live"
  for _f in getbb.sh removebb.sh; do
    if ! curl -fsSL "$BB_LIVE_URL/$_f" >"$WORK/live/$_f" 2>"$WORK/fetch.log"; then
      log_error "could not download $_f from $BB_LIVE_URL"
      sed 's/^/       /' "$WORK/fetch.log"
      exit 1
    fi
  done
  SCRIPT_GET=$WORK/live/getbb.sh
  SCRIPT_REMOVE=$WORK/live/removebb.sh
else
  SCRIPT_GET=$STAGE/getbb.sh
  SCRIPT_REMOVE=$STAGE/removebb.sh
  log_info "staging the files of $BB_SERVE_DIR"
  if ! "$REPO_ROOT/tests/stage-downloads.sh" "$STAGE"; then
    log_error "staging failed"
    exit 1
  fi

  # TLS for the openssl method, with a certificate that is valid for one day and
  # for localhost only.
  CERT=$WORK/localhost.pem
  KEY=$WORK/localhost.key
  HTTPS_ENABLED=1
  if ! openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
    -keyout "$KEY" -out "$CERT" -subj /CN=localhost \
    -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' >"$WORK/openssl.log" 2>&1; then
    HTTPS_ENABLED=0
    log_error "could not create the self signed certificate, the openssl method will be skipped"
    cat "$WORK/openssl.log"
  fi

  # Ports 0 asks the kernel for free ones; the server reports them.
  if [ "$HTTPS_ENABLED" = "1" ]; then
    _https_port=$BB_HTTPS_PORT
  else
    _https_port=-
  fi
  if ! command -v node >/dev/null 2>&1; then
    log_error "node is needed to serve the staged files locally (or use --live URL)"
    exit 1
  fi
  node "$REPO_ROOT/tests/static-server.mjs" "$STAGE" "$BB_HTTP_PORT" \
    "$_https_port" "$CERT" "$KEY" >"$WORK/server.log" 2>&1 &
  SERVER_PID=$!

  _waited=0
  while [ $_waited -lt 50 ]; do
    grep -q 'listening https ' "$WORK/server.log" 2>/dev/null && break
    grep -q 'static server failed' "$WORK/server.log" 2>/dev/null && break
    sleep 0.1
    _waited=$((_waited + 1))
  done

  HTTP_PORT=$(sed -n 's/^listening http 127\.0\.0\.1:\([0-9]*\)$/\1/p' "$WORK/server.log")
  HTTPS_PORT=$(sed -n 's/^listening https 127\.0\.0\.1:\([0-9]*\)$/\1/p' "$WORK/server.log")

  if [ -z "$HTTP_PORT" ]; then
    log_error "the static server did not start:"
    sed 's/^/       /' "$WORK/server.log"
    exit 1
  fi
  BASES="http://127.0.0.1:$HTTP_PORT"
  [ -n "$HTTPS_PORT" ] && BASES="$BASES https://localhost:$HTTPS_PORT"

  # curl, wget and openssl each need to be told to trust the test certificate.
  CURL_CA_BUNDLE=$CERT
  export CURL_CA_BUNDLE
  # wget reads its config from $WGETRC; the value of ca_certificate is taken
  # literally, so it must not be quoted.
  printf 'ca_certificate = %s\n' "$CERT" >"$WORK/wgetrc"
  WGETRC=$WORK/wgetrc
  export WGETRC

  log_info "serving $(printf '%s\n' "$BASES" | tr '\n' ' ')"
fi

# --- the checks -------------------------------------------------------------

# A run installs into HOME and returns the exit status of the installer.
run_install() {
  _shell=$1
  _base=$2
  _method=$3
  shift 3
  HOME=$_target_home BB_DIR=$_target_home/.bb "$_shell" "$_script" \
    --base-url "$_base" "$_method" "$@" >"$_log" 2>&1
}

# check_theme HOME: the decoded theme has to be the one the code stands for, and
# it has to be the theme prompt/bb.sh actually uses.
check_theme() {
  _home=$1
  _code=$2

  if [ ! -f "$_home/.bb/theme.sh" ]; then
    log_error "theme written for $_code"
    return
  fi

  # A random install is checked through the code it drew and stored.
  if [ "$_code" = rand ]; then
    _code=$(cat "$_home/.bb/theme-code" 2>/dev/null)
  fi

  # Decode the code with the library that was installed and compare.
  # shellcheck source=/dev/null
  ( . "$_home/.bb/bb-theme.sh" && bb_theme_decode "$_code" ) >"$WORK/expected-theme" 2>/dev/null
  sed -n '/^PRIMARY_COLOR=/,$p' "$_home/.bb/theme.sh" >"$WORK/actual-theme"
  if diff -q "$WORK/expected-theme" "$WORK/actual-theme" >"$WORK/theme.diff" 2>&1; then
    log_success "theme of $_code decoded by the installed library matches ~/.bb/theme.sh"
  else
    log_error "theme of $_code does not match what the installed library decodes"
    sed 's/^/       /' "$WORK/theme.diff"
  fi

  if [ "$2" = "rand" ]; then
    _stored=$(cat "$_home/.bb/theme-code" 2>/dev/null)
    expect_grep '^[A-Za-z0-9_-]\{8\}$' "$_home/.bb/theme-code" "a random install remembers its code"
    # shellcheck source=/dev/null
    if ( . "$_home/.bb/bb-theme.sh" && bb_theme_decode "$_stored" ) 2>/dev/null |
      diff -q - "$WORK/actual-theme" >/dev/null 2>&1; then
      log_success "the remembered code $_stored decodes to the installed theme"
    else
      log_error "the remembered code $_stored decodes to the installed theme"
    fi
  fi

  # The prompt is the whole point: source bb.sh and build PS1.
  _ps1=$(HOME=$_home BB_DIR=$_home/.bb bash -c \
    '. "$HOME/.bb/bb.sh" >/dev/null 2>&1; __prompt_command; printf "%s" "$PS1"' 2>/dev/null)
  if [ -n "$_ps1" ]; then
    log_success "prompt/bb.sh builds a PS1 ($_base $_method)"
  else
    log_error "prompt/bb.sh builds a PS1 ($_base $_method)"
  fi
  # The theme reached the prompt: every colour in PS1 has to come from theme.sh.
  _theme_color=$(sed -n 's/^PRIMARY_COLOR=.*033\[\([0-9;]*\)m.*/\1/p' "$_home/.bb/theme.sh")
  _needle="033[${_theme_color}m"
  case $_ps1 in
    *"$_needle"*) log_success "PS1 uses the colour $_theme_color of the theme" ;;
    *)
      log_error "PS1 uses the colour $_theme_color of the theme"
      printf '       PS1: %s\n' "$(printf '%s' "$_ps1" | cat -v | head -c 200)"
      ;;
  esac
}

# check_installed_files HOME
check_installed_files() {
  _home=$1
  expect_file "$_home/.bb/bb.sh" "prompt/bb.sh installed"
  expect_file "$_home/.bb/git-prompt.sh" "prompt/git-prompt.sh installed"
  expect_file "$_home/.bb/bb-theme.sh" "prompt/bb-theme.sh installed (the decoder travels with the prompt)"
  expect_file "$_home/.bb/theme.sh" "theme.sh installed"
  expect_file "$_home/.bb/theme-code" "theme-code installed (the code that produced it)"
  expect_grep '__prompt_command' "$_home/.bb/bb.sh" "installed prompt/bb.sh is the BetterBash prompt"
  expect_grep 'BetterBash' "$_home/.bashrc" "hook added to ~/.bashrc"
  expect_grep 'history-search-backward' "$_home/.inputrc" "readline block added to ~/.inputrc"

  # Nothing half written may be left in the directory the prompt is sourced from.
  _leftovers=$(find "$_home/.bb" -mindepth 1 -maxdepth 1 \
    ! -name bb.sh ! -name bb-theme.sh ! -name git-prompt.sh \
    ! -name theme.sh ! -name theme-code 2>/dev/null | sed "s|^$_home/.bb/||")
  if [ -z "$_leftovers" ]; then
    log_success ".bb holds only the files of the installation"
  else
    log_error ".bb holds only the files of the installation (found: $_leftovers)"
  fi
}

check_uninstalled() {
  _home=$1
  if [ -d "$_home/.bb" ]; then
    log_error ".bb removed by removebb.sh"
  else
    log_success ".bb removed by removebb.sh"
  fi
  expect_not_grep 'BetterBash' "$_home/.bashrc" ".bashrc cleaned"
  expect_not_grep 'BetterBash' "$_home/.inputrc" ".inputrc cleaned"
}

# --- every method and shell --------------------------------------------------

for _base in $BASES; do
  for _shell in $BB_TEST_SHELLS; do
    command -v "$_shell" >/dev/null 2>&1 || continue
    for _method in $BB_TEST_METHODS; do
      case $_method in
        openssl)
          # The openssl method speaks TLS, so it only makes sense on https.
          case $_base in
            https://*) ;;
            *) continue ;;
          esac
          ;;
      esac

      log_info "$_shell + $_method from $_base, theme code $BB_TEST_CODE"
      _target_home=$(new_home)
      HOMES="$HOMES $_target_home"
      _script=$SCRIPT_GET
      _log=$WORK/install.log

      if run_install "$_shell" "$_base" "$_method" "$BB_TEST_CODE"; then
        log_success "getbb.sh finished without error"
      else
        log_error "getbb.sh failed"
        sed 's/^/       /' "$_log"
        continue
      fi

      check_installed_files "$_target_home"
      check_theme "$_target_home" "$BB_TEST_CODE"

      log_info "$_shell + $_method uninstall"
      if HOME=$_target_home BB_DIR=$_target_home/.bb "$_shell" "$SCRIPT_REMOVE" \
        "$_method" >"$WORK/remove.log" 2>&1; then
        log_success "removebb.sh finished without error"
      else
        log_error "removebb.sh failed"
        sed 's/^/       /' "$WORK/remove.log"
      fi
      check_uninstalled "$_target_home"
    done
  done
done

# --- the commands of the WebUI, run as they are printed ----------------------

# The first shell of the list is enough for the sections below.
PIPE_SHELL=""
for _shell in $BB_TEST_SHELLS; do
  command -v "$_shell" >/dev/null 2>&1 && PIPE_SHELL=$_shell && break
done

# src/config.js builds the three commands shown on the page, and
# tests/install-commands.mjs renders them outside a browser. They are then run
# verbatim, because the command a user copies has to be the one that installs -
# not a shell test that only looks similar. Plain node is used for the rendering,
# which is why a --live run without node skips this.
if command -v node >/dev/null 2>&1; then
  # BASES is a space separated list with the plain origin first and, when the
  # server speaks TLS too, that one last. A --live URL has a single entry.
  PLAIN_BASE=${BASES%% *}
  TLS_BASE=${BASES##* }

  for _method in $BB_TEST_METHODS; do
    if ! node "$REPO_ROOT/tests/install-commands.mjs" --origin "$PLAIN_BASE" \
      --tls-base-url "$TLS_BASE" --code "$BB_TEST_CODE" --field "$_method" \
      >"$WORK/$_method.cmd" 2>"$WORK/$_method.err"; then
      log_error "the page renders no $_method command"
      sed 's/^/       /' "$WORK/$_method.err"
      continue
    fi

    log_info "$PLAIN_BASE: the $_method command exactly as the page prints it"
    sed 's/^/         /' "$WORK/$_method.cmd"
    expect_grep "bash -s -- $_method $BB_TEST_CODE" "$WORK/$_method.cmd" \
      "$_method passes the theme code after --"
    expect_grep ". ~/.bashrc" "$WORK/$_method.cmd" "$_method reloads the shell"

    _target_home=$(new_home)
    HOMES="$HOMES $_target_home"
    # bash and not $PIPE_SHELL: the command is written for the shell it gets
    # pasted into, which offers `echo -e` and reads ~/.bashrc.
    if HOME=$_target_home bash -c "$(cat "$WORK/$_method.cmd")" >"$WORK/$_method.log" 2>&1; then
      log_success "$_method installs with the command of the page"
    else
      log_error "$_method failed to install with the command of the page"
      sed 's/^/       /' "$WORK/$_method.log"
    fi
    check_installed_files "$_target_home"
  done

  # The uninstaller downloads nothing, so it neither needs a theme code nor an
  # origin of its own.
  if node "$REPO_ROOT/tests/install-commands.mjs" --origin "$PLAIN_BASE" \
    --script removebb.sh --field curl >"$WORK/remove.cmd" 2>"$WORK/remove.err"; then
    node "$REPO_ROOT/tests/install-commands.mjs" --origin "$PLAIN_BASE" \
      --tls-base-url "$TLS_BASE" --script removebb.sh --field openssl \
      >"$WORK/remove-openssl.cmd" 2>"$WORK/remove-openssl.err"
    for _cmd in remove remove-openssl; do
      # curl pipes the script it downloaded, openssl asks for it by name.
      expect_grep "bash -s --" "$WORK/$_cmd.cmd" \
        "the $_cmd command of the page runs the installer without a theme code"
      expect_grep 'removebb.sh' "$WORK/$_cmd.cmd" "the $_cmd command fetches the uninstaller"
      expect_not_grep "$BB_TEST_CODE" "$WORK/$_cmd.cmd" \
        "the $_cmd command of the page does not mention the theme code"
    done
  fi
else
  log_info 'node is not available, the commands of the page are not checked'
fi

# --- random themes ------------------------------------------------------------

for _base in $BASES; do
  log_info "$_base: a random theme is drawn once and kept"
  _target_home=$(new_home)
  HOMES="$HOMES $_target_home"
  _script=$SCRIPT_GET
  _shell=$PIPE_SHELL
  [ -n "$_shell" ] || break

  HOME=$_target_home "$_shell" "$_script" --base-url "$_base" curl rand >"$WORK/rand.log" 2>&1
  _first=$(cat "$_target_home/.bb/theme-code" 2>/dev/null)
  HOME=$_target_home "$_shell" "$_script" --base-url "$_base" curl rand >"$WORK/rand2.log" 2>&1
  _second=$(cat "$_target_home/.bb/theme-code" 2>/dev/null)
  HOME=$_target_home BB_THEME_REROLL=1 "$_shell" "$_script" --base-url "$_base" curl rand \
    >"$WORK/rand3.log" 2>&1
  _third=$(cat "$_target_home/.bb/theme-code" 2>/dev/null)

  if [ -n "$_first" ] && [ "$_first" = "$_second" ]; then
    log_success "two random installs keep the theme $_first of the first one"
  else
    log_error "two random installs keep one theme (got '$_first' then '$_second')"
  fi
  if [ -n "$_third" ] && [ "$_third" != "$_first" ]; then
    log_success "BB_THEME_REROLL=1 draws a new theme ($_third)"
  else
    log_error "BB_THEME_REROLL=1 draws a new theme (got '$_third')"
  fi
  check_theme "$_target_home" rand
  break
done

# The command of older releases, without a theme code: reinstalling has to keep
# the theme that is already installed rather than replace it with another one.
for _base in $BASES; do
  log_info "$_base: an install command without a theme code keeps the theme"
  _target_home=$(new_home)
  HOMES="$HOMES $_target_home"
  _script=$SCRIPT_GET
  _shell=$PIPE_SHELL
  [ -n "$_shell" ] || break

  HOME=$_target_home "$_shell" "$_script" --base-url "$_base" curl >"$WORK/nocode.log" 2>&1
  _first=$(cat "$_target_home/.bb/theme-code" 2>/dev/null)
  HOME=$_target_home "$_shell" "$_script" --base-url "$_base" curl >"$WORK/nocode2.log" 2>&1
  _second=$(cat "$_target_home/.bb/theme-code" 2>/dev/null)

  if [ -n "$_first" ] && [ "$_first" = "$_second" ]; then
    log_success "a reinstall without a code keeps theme $_first"
  else
    log_error "a reinstall without a code keeps one theme (got '$_first' then '$_second')"
  fi
  check_installed_files "$_target_home"
  break
done

# --- bad input ----------------------------------------------------------------

log_info 'refusing bad input before downloading anything'
for _bad in 'nope' 'vN-y_5uA/' '../../etc/passwd' ''; do
  _target_home=$(new_home)
  HOMES="$HOMES $_target_home"
  if HOME=$_target_home sh "$SCRIPT_GET" --base-url http://127.0.0.1:1 curl "$_bad" \
    >"$WORK/bad.log" 2>&1; then
    log_error "'$_bad' is refused"
  else
    log_success "'$_bad' is refused"
  fi
  if [ -e "$_target_home/.bb/bb.sh" ]; then
    log_error "'$_bad' is refused before anything is downloaded"
  else
    log_success "'$_bad' is refused before anything is downloaded"
  fi
done

# A host that does not answer must not leave a half installed prompt behind.
_target_home=$(new_home)
HOMES="$HOMES $_target_home"
if HOME=$_target_home sh "$SCRIPT_GET" --base-url http://127.0.0.1:1 curl "$BB_TEST_CODE" \
  >"$WORK/dead.log" 2>&1; then
  log_error "a dead download host is reported as a failure"
else
  log_success "a dead download host is reported as a failure"
fi
if [ -e "$_target_home/.bb/bb.sh" ] || [ -e "$_target_home/.bb/theme.sh" ] ||
  grep -q BetterBash "$_target_home/.bashrc"; then
  log_error "a dead download host leaves nothing installed"
else
  log_success "a dead download host leaves nothing installed"
fi

# --- summary -----------------------------------------------------------------

echo
echo "Tests passed: $PASS"
echo "Tests failed: $FAIL"
exit "$FAIL"
