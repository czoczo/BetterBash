#!/bin/sh
#
# BetterBash installation tests: fetch the tree, answer, install.
#
# The commands under test are the ones the WebUI prints. They are rendered by
# tests/install-commands.mjs (that is src/config.js, the code of the page) and run
# verbatim, so "what is on the page" and "what installs" cannot drift apart. Every
# command fetches the BetterBash tree with one of its four methods, asks whether to
# go on, and runs installbb.sh from the tree it fetched.
#
#   ./test-install.sh                       # every method, every check
#   ./test-install.sh --code vN-y_5uA       # theme code to install
#   ./test-install.sh --live URL            # test a deployed site instead
#   ./test-install.sh --method curl         # one fetch method only
#   ./test-install.sh --keep                # keep the test homes
#
# What is checked:
#
#   * the four fetch methods of the page, in throwaway homes, install and
#     uninstall: the files in ~/.bb, the theme that was decoded, the colour that
#     reaches PS1
#   * answering the question with n, or having no terminal at all, installs nothing
#   * the package: its checksum, and the openssl method delivering it byte for byte
#   * installbb.sh refusing a tree it should not copy (planted, incomplete, faked)
#   * installbb.sh working from a script, under sh, bash and dash, and the
#     uninstaller working from ~/.bb without fetching anything
#   * the theme rules: rand keeps its code, a reroll draws a new one, another code
#     replaces it, and an upgrade removes files this release no longer writes
#
# The staging served locally is produced by tests/stage-downloads.sh, the same
# script the Pages workflow uses, so the layout cannot drift apart from it. The git
# method is tested against a local bare repository tagged like a release, and
# curl/wget/openssl against a local file server with a self signed certificate - so
# nothing here needs a network, and nothing is written into the /tmp of the machine
# running the tests (the commands name a directory of their own instead of /tmp/bb).

set -u

REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
BB_TEST_CODE=${BB_TEST_CODE:-vN-y_5uA}
BB_TEST_METHODS=${BB_TEST_METHODS:-git curl wget openssl}
BB_TEST_SHELLS=${BB_TEST_SHELLS:-sh bash dash}
BB_LIVE_URL=""
BB_KEEP=0
BB_HTTP_PORT=0
BB_HTTPS_PORT=0

PASS=0
FAIL=0

RELEASE_REF=$(sed -n '1p' "$REPO_ROOT/VERSION_APP.txt" 2>/dev/null)
[ -n "$RELEASE_REF" ] || RELEASE_REF=main

GITHUB_REPO_URL=https://github.com/czoczo/BetterBash

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

expect_file() {
  if [ -f "$1" ]; then
    log_success "$2"
  else
    log_error "$2 (missing $1)"
  fi
}

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

# new_home: a throwaway home directory; the two files the installer appends to
# have to exist in it, like on a normal machine.
new_home() {
  _home=$(mktemp -d)
  : >"$_home/.bashrc"
  : >"$_home/.inputrc"
  printf '%s' "$_home"
}

while [ $# -gt 0 ]; do
  case $1 in
    --code) BB_TEST_CODE=${2:-}; shift ;;
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
  if [ "$BB_KEEP" = "1" ]; then
    [ -n "$HOMES" ] && printf '\nKept test homes:%s\n' "$(printf '%s' "$HOMES" | tr '\n' ' ')"
    return 0
  fi
  for _h in $HOMES; do rm -rf "$_h"; done
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

# --- the package, the git fixture and the file server ------------------------

# PKG / PKG_SHA_FILE: the package the fetch commands are answered with, and its
# checksum. TREE: one extracted copy of it, used wherever a test wants the
# installer of a release rather than the working copy.
STAGED=$WORK/downloads
PKG=""
PKG_SHA_FILE=""
REPO_URL=""
PLAIN_BASE=""
TLS_BASE=""

if [ -n "$BB_LIVE_URL" ]; then
  log_info "testing the deployment at $BB_LIVE_URL"
  PLAIN_BASE=$BB_LIVE_URL
  # The openssl method speaks TLS to a host that answers, so it is only tested
  # against an origin that is https (a local http dev server is not).
  case $BB_LIVE_URL in
    https://*) TLS_BASE=$BB_LIVE_URL ;;
    *)
      TLS_BASE=""
      BB_TEST_METHODS=$(printf '%s\n' "$BB_TEST_METHODS" | grep -v '^openssl$' || true)
      log_info "$BB_LIVE_URL is not https, the openssl method is not tested"
      ;;
  esac
  mkdir -p "$WORK/live" || exit 1
  for _f in bb.tgz bb.tgz.sha256; do
    if ! curl -fsSL "$BB_LIVE_URL/$_f" -o "$WORK/live/$_f" 2>"$WORK/fetch.log"; then
      log_error "could not download $BB_LIVE_URL/$_f"
      sed 's/^/       /' "$WORK/fetch.log"
      exit 1
    fi
  done
  PKG=$WORK/live/bb.tgz
  PKG_SHA_FILE=$WORK/live/bb.tgz.sha256
  # The git method of a deployment would clone the published tag of this project;
  # that is checked against a local repository tagged the same way whenever this
  # runs without --live.
  BB_TEST_METHODS=$(printf '%s\n' "$BB_TEST_METHODS" | grep -v '^git$' || true)
else
  log_info "staging the files of $REPO_ROOT"
  if ! "$REPO_ROOT/tests/stage-downloads.sh" "$STAGED"; then
    log_error "staging failed"
    exit 1
  fi
  PKG=$STAGED/bb.tgz
  PKG_SHA_FILE=$STAGED/bb.tgz.sha256

  # The git method, without a network: the package itself becomes a tagged
  # repository, so the fixture holds exactly the files a release carries.
  log_info "building a local git fixture tagged $RELEASE_REF"
  mkdir -p "$WORK/git" && tar -C "$WORK/git" -xzf "$PKG" || exit 1
  git -C "$WORK/git/bb" init -q || exit 1
  git -C "$WORK/git/bb" -c user.name=bb -c user.email=bb@example add -A || exit 1
  git -C "$WORK/git/bb" -c user.name=bb -c user.email=bb@example commit -qm "BetterBash $RELEASE_REF" || exit 1
  git -C "$WORK/git/bb" tag "$RELEASE_REF" || exit 1
  git clone -q --bare "$WORK/git/bb" "$WORK/git/repo.git" || exit 1
  REPO_URL=file://$WORK/git/repo.git

  # TLS for the openssl method, with a certificate valid for one day and for
  # localhost only.
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

  if ! command -v node >/dev/null 2>&1; then
    log_error "node is needed to serve the staged files locally (or use --live URL)"
    exit 1
  fi
  _https_port=$BB_HTTPS_PORT
  [ "$HTTPS_ENABLED" = "1" ] || _https_port=-
  node "$REPO_ROOT/tests/static-server.mjs" "$STAGED" "$BB_HTTP_PORT" \
    "$_https_port" "$CERT" "$KEY" >"$WORK/server.log" 2>&1 &
  SERVER_PID=$!

  _waited=0
  while [ $_waited -lt 50 ]; do
    grep -q 'listening https ' "$WORK/server.log" 2>/dev/null && break
    if [ "$HTTPS_ENABLED" != "1" ] && grep -q 'listening http ' "$WORK/server.log" 2>/dev/null; then
      break
    fi
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
  PLAIN_BASE=http://127.0.0.1:$HTTP_PORT
  TLS_BASE=${HTTPS_PORT:+https://localhost:$HTTPS_PORT}

  # curl, wget and openssl each need to be told to trust the test certificate.
  CURL_CA_BUNDLE=$CERT
  export CURL_CA_BUNDLE
  # wget reads its config from $WGETRC; the value of ca-certificate is taken
  # literally, so it must not be quoted.
  printf 'ca-certificate = %s\n' "$CERT" >"$WORK/wgetrc"
  WGETRC=$WORK/wgetrc
  export WGETRC

  log_info "serving $PLAIN_BASE${TLS_BASE:+ and $TLS_BASE}"
fi

# One extracted tree for the sections that want the installer of a release.
mkdir -p "$WORK/tree" && tar -C "$WORK/tree" -xzf "$PKG" || exit 1
TREE=$WORK/tree/bb

# The commands name a directory the fetched tree lands in; a test may not use the
# /tmp of its machine for it, so the page is asked to render its own.
FETCH_PARENT=$WORK/fetch
STAGE_DIR=$FETCH_PARENT/bb
mkdir -p "$FETCH_PARENT"

# fresh_stage: the fetch of the next run has to land somewhere empty, like on a
# machine that has not fetched anything yet.
fresh_stage() {
  rm -rf "$STAGE_DIR"
}

# render FIELD KIND OUT [CODE]
# The commands are rendered by the code of the page, with the theme code of this
# run in them (an empty CODE stands for the uninstaller, which ignores colours).
render() {
  _field=$1
  _kind=$2
  _out=$3
  _code=${4:-}
  if ! node "$REPO_ROOT/tests/install-commands.mjs" \
    --origin "$PLAIN_BASE" \
    --tls-base-url "${TLS_BASE:-$PLAIN_BASE}" \
    --repo-url "${REPO_URL:-$GITHUB_REPO_URL}" \
    --stage-dir "$STAGE_DIR" \
    --kind "$_kind" --field "$_field" --code "$_code" >"$_out" 2>"$_out.err"; then
    return 1
  fi
  return 0
}

# run_command CMDFILE HOME ANSWER LOG
# A command of the page is written for the shell it gets pasted into: bash, which
# has [[ ]] and reads ~/.bashrc. ANSWER is what the terminal types at it; an empty
# answer stands for a terminal that is not there at all.
run_command() {
  _cmdfile=$1
  _home=$2
  _answer=${3:-}
  _log=$4
  mkdir -p "$(dirname "$STAGE_DIR")"
  if [ -n "$_answer" ]; then
    printf '%s' "$_answer" | HOME="$_home" bash -c "$(cat "$_cmdfile")" >"$_log" 2>&1
  else
    HOME="$_home" bash -c "$(cat "$_cmdfile")" </dev/null >"$_log" 2>&1
  fi
}

# --- the checks -------------------------------------------------------------

check_installed_files() {
  _home=$1
  expect_file "$_home/.bb/bb.sh" "prompt/bb.sh installed"
  expect_file "$_home/.bb/git-prompt.sh" "prompt/git-prompt.sh installed"
  expect_file "$_home/.bb/bb-theme.sh" "prompt/bb-theme.sh installed (the decoder travels with the prompt)"
  expect_file "$_home/.bb/removebb.sh" "removebb.sh installed, so uninstalling needs no download"
  expect_file "$_home/.bb/version" "version installed"
  expect_file "$_home/.bb/theme.sh" "theme.sh written"
  expect_file "$_home/.bb/theme-code" "theme-code written (the code that produced it)"
  expect_grep '__prompt_command' "$_home/.bb/bb.sh" "installed prompt/bb.sh is the BetterBash prompt"
  expect_grep 'BetterBash' "$_home/.bashrc" "hook added to ~/.bashrc"
  expect_grep 'history-search-backward' "$_home/.inputrc" "readline block added to ~/.inputrc"

  # Nothing half written may be left in the directory the prompt is sourced from.
  _leftovers=$(find "$_home/.bb" -mindepth 1 -maxdepth 1 \
    ! -name bb.sh ! -name bb-theme.sh ! -name git-prompt.sh ! -name removebb.sh \
    ! -name version ! -name theme.sh ! -name theme-code 2>/dev/null | sed "s|^$_home/.bb/||")
  if [ -z "$_leftovers" ]; then
    log_success ".bb holds only the files of the installation"
  else
    log_error ".bb holds only the files of the installation (found: $_leftovers)"
  fi
}

check_theme() {
  _home=$1
  _code=$2

  if [ ! -f "$_home/.bb/theme.sh" ]; then
    log_error "theme.sh written for $_code"
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

  # The prompt is the whole point: source bb.sh and build PS1.
  _ps1=$(HOME=$_home BB_DIR=$_home/.bb bash -c \
    '. "$HOME/.bb/bb.sh" >/dev/null 2>&1; __prompt_command; printf "%s" "$PS1"' 2>/dev/null)
  if [ -z "$_ps1" ]; then
    log_error "prompt/bb.sh builds a PS1"
    return
  fi
  log_success "prompt/bb.sh builds a PS1"
  _theme_color=$(sed -n 's/^PRIMARY_COLOR=.*033\[\([0-9;]*\)m.*/\1/p' "$_home/.bb/theme.sh")
  case $_ps1 in
    *"033[${_theme_color}m"*) log_success "PS1 uses the colour $_theme_color of the theme" ;;
    *)
      log_error "PS1 uses the colour $_theme_color of the theme"
      printf '       PS1: %s\n' "$(printf '%s' "$_ps1" | cat -v | head -c 200)"
      ;;
  esac
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

# --- the commands of the page, run as they are printed -----------------------

if ! command -v node >/dev/null 2>&1; then
  log_error 'node is needed to render the commands of the page'
  echo
  echo "Tests passed: $PASS"
  echo "Tests failed: $(( FAIL + 1 ))"
  exit 1
fi

for _method in $BB_TEST_METHODS; do
  case $_method in
    # The openssl method speaks TLS, so it needs the https server (or a deployment).
    openssl) [ -n "$TLS_BASE" ] || continue ;;
    # A deployment is cloned from github.com, which this test does not depend on.
    git) [ -n "$REPO_URL" ] && command -v git >/dev/null 2>&1 || continue ;;
  esac

  log_info "$_method: the command of the page, installed and uninstalled"
  _home=$(new_home)
  HOMES="$HOMES $_home"
  fresh_stage

  if ! render "$_method" install "$WORK/$_method.install.cmd" "$BB_TEST_CODE"; then
    log_error "the page renders no $_method install command"
    sed 's/^/       /' "$WORK/$_method.install.cmd.err"
    continue
  fi
  sed 's/^/         /' "$WORK/$_method.install.cmd"

  expect_grep 'read -p' "$WORK/$_method.install.cmd" "$_method asks before installing anything"
  expect_grep "installbb.sh $BB_TEST_CODE" "$WORK/$_method.install.cmd" \
    "$_method hands the theme code to the installer"
  expect_grep '. ~/.bashrc' "$WORK/$_method.install.cmd" "$_method reloads the shell"
  expect_not_grep 'bash -s' "$WORK/$_method.install.cmd" "$_method does not pipe a script into a shell"

  if run_command "$WORK/$_method.install.cmd" "$_home" y "$WORK/$_method.install.log"; then
    log_success "$_method installs with the command of the page"
  else
    log_error "$_method failed to install with the command of the page"
    sed 's/^/       /' "$WORK/$_method.install.log"
    continue
  fi

  check_installed_files "$_home"
  check_theme "$_home" "$BB_TEST_CODE"

  if [ -f "$_home/.bb/version" ] && [ "$(sed -n '1p' "$_home/.bb/version")" = "$RELEASE_REF" ]; then
    log_success "the installed tree reports $RELEASE_REF"
  else
    log_error "the installed tree reports $(sed -n '1p' "$_home/.bb/version" 2>/dev/null), expected $RELEASE_REF"
  fi

  if ! render "$_method" uninstall "$WORK/$_method.remove.cmd"; then
    log_error "the page renders no $_method uninstall command"
    continue
  fi
  expect_not_grep "$BB_TEST_CODE" "$WORK/$_method.remove.cmd" \
    "the $_method uninstall command does not mention the theme code"
  expect_grep 'remove BetterBash' "$WORK/$_method.remove.cmd" \
    "the $_method uninstall command asks about removing"

  fresh_stage
  if run_command "$WORK/$_method.remove.cmd" "$_home" y "$WORK/$_method.remove.log"; then
    log_success "$_method uninstalls with the command of the page"
  else
    log_error "$_method failed to uninstall with the command of the page"
    sed 's/^/       /' "$WORK/$_method.remove.log"
  fi
  check_uninstalled "$_home"
done

# --- answering the question --------------------------------------------------

log_info 'the question is what stands between fetching and installing'
_home=$(new_home)
HOMES="$HOMES $_home"
render curl install "$WORK/answer.cmd" "$BB_TEST_CODE"

for _answer in 'n' 'x' ''; do
  case $_answer in
    '') _what='having no terminal to answer in' ;;
    *) _what="answering $_answer" ;;
  esac
  fresh_stage
  if run_command "$WORK/answer.cmd" "$_home" "$_answer" "$WORK/answer.log"; then
    : # The chain may end with the reload of ~/.bashrc; what matters is below.
  fi
  if [ -e "$_home/.bb/bb.sh" ] || grep -q BetterBash "$_home/.bashrc"; then
    log_error "$_what installs nothing"
  else
    log_success "$_what installs nothing"
  fi
  # A second attempt of the same command in the same home has to stay possible,
  # so a refused question must not have half written anything.
  if [ -d "$_home/.bb" ]; then
    log_error "$_what leaves an empty home of a prompt behind"
  else
    log_success "$_what leaves nothing behind to be installed over"
  fi
done

# The fetched tree is what the answer is about, so the answer cannot be needed
# before the fetch: the files have to be there even after a refusal.
if [ -f "$STAGE_DIR/installbb.sh" ]; then
  log_success 'a refused question still fetched the tree it can be read in'
else
  log_error 'a refused question still fetched the tree it can be read in'
fi

# --- the package -------------------------------------------------------------

log_info 'the package the fetch commands answer with'
_size=$(wc -c <"$PKG" | tr -d ' ')
# The tree of the prompt, not the repository: a package that grows past a few
# hundred kilobytes means something unrelated got into it.
if [ "$_size" -gt 4000 ] && [ "$_size" -lt 200000 ]; then
  log_success "bb.tgz is $_size bytes (the tree, not the repository)"
else
  log_error "bb.tgz is $_size bytes, which is not the size of the tree"
fi

if [ -f "$PKG_SHA_FILE" ]; then
  _declared=$(sed -E 's/^([0-9a-f]+).*/\1/' "$PKG_SHA_FILE" 2>/dev/null)
  _computed=$(sha256sum "$PKG" 2>/dev/null | cut -d' ' -f1)
  if [ -n "$_computed" ] && [ "$_declared" = "$_computed" ]; then
    log_success 'bb.tgz.sha256 describes bb.tgz'
  else
    log_error 'bb.tgz.sha256 describes bb.tgz'
  fi
else
  log_error 'bb.tgz.sha256 was not published'
fi

# The openssl method of the legacy path stripped carriage returns out of the body,
# which is harmless for a shell script and fatal for an archive: it ate four bytes
# of exactly this package and left a corrupt gzip behind. So the bytes fetched by
# the openssl command of the page are compared with what curl would hand over.
case " $BB_TEST_METHODS " in
  *openssl*)
    if [ -n "$TLS_BASE" ]; then
      render openssl install "$WORK/openssl.fetch.cmd" "$BB_TEST_CODE"
      # Everything before the extraction is the request and the header strip.
      _pipeline=$(sed 's/ | tar -C .*//' "$WORK/openssl.fetch.cmd")
      HOME=$WORK sh -c "$_pipeline >'$WORK/openssl-package.tgz'" 2>"$WORK/openssl-fetch.log"
      if [ ! -s "$WORK/openssl-package.tgz" ]; then
        log_error 'the openssl request of the page produced no package at all'
        sed 's/^/       /' "$WORK/openssl-fetch.log"
      else
        _a=$(sha256sum "$WORK/openssl-package.tgz" | cut -d' ' -f1)
        _b=$(sha256sum "$PKG" | cut -d' ' -f1)
        if [ "$_a" = "$_b" ]; then
          log_success 'openssl delivers bb.tgz byte for byte, like curl does'
        else
          log_error 'openssl delivers bb.tgz byte for byte, like curl does'
          printf '       openssl %s\n       package   %s\n' "$_a" "$_b"
        fi
        if gzip -t "$WORK/openssl-package.tgz" 2>"$WORK/gzip.log"; then
          log_success 'the package openssl fetched is a readable gzip'
        else
          log_error 'the package openssl fetched is a readable gzip'
          sed 's/^/       /' "$WORK/gzip.log"
        fi
      fi
    fi
    ;;
esac

# An answer that is not a package must not install anything: the fetch of an
# origin serving an error page instead of bb.tgz.
log_info 'an origin that does not answer with the package'
_home=$(new_home)
HOMES="$HOMES $_home"
fresh_stage
if printf 'y' | HOME=$_home bash -c \
  "curl -sL $PLAIN_BASE/nope.tgz | tar -C '$FETCH_PARENT' -xz && sh '$STAGE_DIR/installbb.sh' --yes $BB_TEST_CODE" \
  >"$WORK/nopackage.log" 2>&1; then
  log_error 'an origin serving no package installs nothing'
else
  log_success 'an origin serving no package installs nothing'
fi
if [ -e "$_home/.bb/bb.sh" ] || grep -q BetterBash "$_home/.bashrc"; then
  log_error 'an origin serving no package leaves nothing installed'
else
  log_success 'an origin serving no package leaves nothing installed'
fi

# --- what installbb.sh refuses ----------------------------------------------

log_info 'installbb.sh refuses a tree it should not copy from'

# A tree of the right shape but of the wrong permissions: /tmp is offered by the
# world, so files anybody could have edited are not installed.
_planted=$WORK/planted
mkdir -p "$_planted" && tar -C "$_planted" -xzf "$PKG" || exit 1
chmod -R a+w "$_planted/bb"
_home=$(new_home)
HOMES="$HOMES $_home"
if HOME=$_home sh "$_planted/bb/installbb.sh" --yes "$BB_TEST_CODE" >"$WORK/planted.log" 2>&1; then
  log_error 'a tree other users can write to is refused'
else
  log_success 'a tree other users can write to is refused'
fi
expect_grep 'writable by other users' "$WORK/planted.log" 'and says why'

# An incomplete tree: a directory that holds some of a release.
_incomplete=$WORK/incomplete/bb
mkdir -p "$_incomplete/prompt" || exit 1
cp "$REPO_ROOT/prompt/bb.sh" "$_incomplete/prompt/" || exit 1
cp "$REPO_ROOT/installbb.sh" "$_incomplete/" || exit 1
_home=$(new_home)
HOMES="$HOMES $_home"
if HOME=$_home sh "$_incomplete/installbb.sh" --yes "$BB_TEST_CODE" >"$WORK/incomplete.log" 2>&1; then
  log_error 'an incomplete tree is refused'
else
  log_success 'an incomplete tree is refused'
fi
if [ -e "$_home/.bb/bb.sh" ]; then
  log_error 'an incomplete tree is refused before anything is written'
else
  log_success 'an incomplete tree is refused before anything is written'
fi

# A file of the right name that is not the file it claims to be.
_fake=$WORK/fake/bb
mkdir -p "$_fake/prompt" || exit 1
cp "$TREE/installbb.sh" "$TREE/removebb.sh" "$_fake/" || exit 1
cp "$TREE/VERSION_APP.txt" "$_fake/" || exit 1
cp "$TREE/prompt/bb-theme.sh" "$TREE/prompt/git-prompt.sh" "$_fake/prompt/" || exit 1
printf 'echo not a prompt\n' >"$_fake/prompt/bb.sh"
_home=$(new_home)
HOMES="$HOMES $_home"
if HOME=$_home sh "$_fake/installbb.sh" --yes "$BB_TEST_CODE" >"$WORK/fake.log" 2>&1; then
  log_error 'a file that is not the BetterBash file it claims to be is refused'
else
  log_success 'a file that is not the BetterBash file it claims to be is refused'
fi
expect_grep 'not the BetterBash file' "$WORK/fake.log" 'and says which one'

# Bad theme codes are refused before anything is written.
for _bad in 'nope' 'vN-y_5uA/' '../../etc/passwd' ''; do
  _home=$(new_home)
  HOMES="$HOMES $_home"
  if HOME=$_home sh "$TREE/installbb.sh" --repo "$TREE" --yes "$_bad" >"$WORK/bad.log" 2>&1; then
    log_error "'$_bad' is refused"
  else
    log_success "'$_bad' is refused"
  fi
  if [ -e "$_home/.bb/bb.sh" ]; then
    log_error "'$_bad' is refused before anything is written"
  else
    log_success "'$_bad' is refused before anything is written"
  fi
done

# A tree without the readline block: ~/.inputrc is a convenience, so its absence
# must cost the binding and nothing else.
_noinputrc=$WORK/noinputrc
mkdir -p "$_noinputrc" && tar -C "$_noinputrc" -xzf "$PKG" || exit 1
rm "$_noinputrc/bb/.inputrc"
_home=$(new_home)
HOMES="$HOMES $_home"
if HOME=$_home sh "$_noinputrc/bb/installbb.sh" --yes "$BB_TEST_CODE" >"$WORK/noinputrc.log" 2>&1; then
  log_success 'a tree without .inputrc installs the prompt'
else
  log_error 'a tree without .inputrc installs the prompt'
  sed 's/^/       /' "$WORK/noinputrc.log"
fi
expect_grep 'NOT installed' "$WORK/noinputrc.log" 'and says the readline binding is missing'
if grep -q BetterBash "$_home/.inputrc"; then
  log_error 'a tree without .inputrc writes nothing into ~/.inputrc'
else
  log_success 'a tree without .inputrc writes nothing into ~/.inputrc'
fi
# The prompt itself is unaffected - only the binding is missing.
expect_file "$_home/.bb/bb.sh" 'a tree without .inputrc still installs the prompt'
expect_file "$_home/.bb/theme.sh" 'a tree without .inputrc still installs the colours'

# --- installbb.sh from a script, under every shell ---------------------------

log_info 'the installer of the fetched tree, under sh, bash and dash'
for _shell in $BB_TEST_SHELLS; do
  command -v "$_shell" >/dev/null 2>&1 || continue
  _tree=$WORK/tree-of-$_shell
  rm -rf "$_tree"
  mkdir -p "$_tree" || exit 1
  tar -C "$_tree" -xzf "$PKG" --strip-components=1 || exit 1
  _home=$(new_home)
  HOMES="$HOMES $_home"
  if HOME=$_home "$_shell" "$_tree/installbb.sh" --yes "$BB_TEST_CODE" >"$WORK/$_shell.log" 2>&1; then
    log_success "$_shell runs installbb.sh"
  else
    log_error "$_shell failed to run installbb.sh"
    sed 's/^/       /' "$WORK/$_shell.log"
    continue
  fi
  check_installed_files "$_home"
  check_theme "$_home" "$BB_TEST_CODE"

  # The uninstaller travelled with the prompt, so cleaning up needs no fetch.
  if HOME=$_home "$_shell" "$_home/.bb/removebb.sh" >"$WORK/$_shell-remove.log" 2>&1; then
    log_success "$_shell uninstalls from ~/.bb, without fetching anything"
  else
    log_error "$_shell failed to uninstall from ~/.bb"
    sed 's/^/       /' "$WORK/$_shell-remove.log"
  fi
  check_uninstalled "$_home"
done

# --- the theme rules ---------------------------------------------------------

log_info 'the theme of a machine survives a reinstall, and a reroll replaces it'
_home=$(new_home)
HOMES="$HOMES $_home"
theme_line() {
  sed -n 's/^ *theme *\([A-Za-z0-9_-]\{8\}\).*/\1/p' "$1"
}
HOME=$_home sh "$TREE/installbb.sh" --repo "$TREE" --yes rand >"$WORK/rand1.log" 2>&1
HOME=$_home sh "$TREE/installbb.sh" --repo "$TREE" --yes rand >"$WORK/rand2.log" 2>&1
_first=$(theme_line "$WORK/rand1.log")
_second=$(theme_line "$WORK/rand2.log")
HOME=$_home BB_THEME_REROLL=1 sh "$TREE/installbb.sh" --repo "$TREE" --yes rand >"$WORK/rand3.log" 2>&1
_third=$(theme_line "$WORK/rand3.log")

if [ -n "$_first" ] && [ "$_first" = "$_second" ]; then
  log_success "two random installs keep the theme $_first of the first one"
else
  log_error "two random installs keep one theme (got '$_first' then '$_second')"
fi
if [ -n "$_third" ] && [ "$_third" != "$_first" ]; then
  log_success "a reroll draws a new theme ($_third)"
else
  log_error "a reroll draws a new theme (got '$_third')"
fi
check_theme "$_home" rand

log_info 'a reinstall with another code replaces the theme, one without keeps it'
_home=$(new_home)
HOMES="$HOMES $_home"
HOME=$_home sh "$TREE/installbb.sh" --repo "$TREE" --yes "$BB_TEST_CODE" >"$WORK/re1.log" 2>&1
_first_theme=$(cat "$_home/.bb/theme-code" 2>/dev/null)
HOME=$_home sh "$TREE/installbb.sh" --repo "$TREE" --yes >"$WORK/re2.log" 2>&1
if [ -n "$_first_theme" ] && [ "$_first_theme" = "$(cat "$_home/.bb/theme-code" 2>/dev/null)" ]; then
  log_success "a reinstall without a code keeps theme $_first_theme"
else
  log_error "a reinstall without a code keeps one theme (theme-code: $(cat "$_home/.bb/theme-code" 2>/dev/null))"
fi
if [ "$BB_TEST_CODE" != rand ] && [ "$_first_theme" != "$BB_TEST_CODE" ]; then
  log_error "the theme of $BB_TEST_CODE is the one written (got $_first_theme)"
else
  log_success "the theme of $BB_TEST_CODE is the one written"
fi
HOME=$_home sh "$TREE/installbb.sh" --repo "$TREE" --yes q-_8Ttne >"$WORK/re3.log" 2>&1
if grep -q 'q-_8Ttne' "$_home/.bb/theme-code" 2>/dev/null; then
  log_success 'a reinstall with another code replaces the theme'
else
  log_error 'a reinstall with another code replaces the theme'
fi
check_theme "$_home" q-_8Ttne

log_info 'an upgrade removes files this release no longer writes'
_home=$(new_home)
HOMES="$HOMES $_home"
HOME=$_home sh "$TREE/installbb.sh" --repo "$TREE" --yes "$BB_TEST_CODE" >"$WORK/upgrade.log" 2>&1
# A name ~/.bb used to hold and this release does not write, put there by hand;
# the next install has to take it away.
: >"$_home/.bb/inputrc"
HOME=$_home sh "$TREE/installbb.sh" --repo "$TREE" --yes "$BB_TEST_CODE" >"$WORK/upgrade2.log" 2>&1
if [ -e "$_home/.bb/inputrc" ]; then
  log_error 'a retired file is removed by the next install'
else
  log_success 'a retired file is removed by the next install'
fi

# --- summary -----------------------------------------------------------------

echo
echo "Tests passed: $PASS"
echo "Tests failed: $FAIL"
exit "$FAIL"
