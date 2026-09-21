#!/usr/bin/env bash
#
# Check that every BetterBash installation method works against the development
# backend. Each method installs into, and uninstalls from, its own throwaway
# HOME, so the real shell configuration is never touched.
#
# Usage: ./test-install-methods.sh [options]
#
#   --base-host HOST   host the client side of the checks connects as (default
#                      localhost; pass the address of a machine running ./dev.sh
#                      with --site-host 0.0.0.0 to test it over the network)
#   --http-port PORT     plain HTTP backend port (default 18081, used by curl/wget)
#   --https-port PORT    HTTPS backend port    (default 18443, used by openssl)
#   --repo PATH          repository checkout to serve (default: this one)
#   --code CODE          theme code to install (default vN-y_5uA)
#   --keep               keep the temporary HOMEs for inspection
#
# If a backend already listens on the requested port it is reused, otherwise one
# is started for the duration of the test.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_HOST=localhost
HTTP_PORT=18081
HTTPS_PORT=18443
REPO_PATH="$REPO_ROOT"
CODE="vN-y_5uA"
KEEP=0

while [ $# -gt 0 ]; do
  case "$1" in
    --base-host) BASE_HOST="$2"; shift 2 ;;
    --http-port) HTTP_PORT="$2"; shift 2 ;;
    --https-port) HTTPS_PORT="$2"; shift 2 ;;
    --repo) REPO_PATH="$2"; shift 2 ;;
    --code) CODE="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

for command in go git curl wget openssl; do
  command -v "$command" >/dev/null || { echo "missing requirement: $command" >&2; exit 1; }
done

# Everything below talks to the backend through these two, so --base-host moves
# the whole suite to another machine.
BASE_URL="http://${BASE_HOST}:${HTTP_PORT}"
TLS_CONNECT="${BASE_HOST}:${HTTPS_PORT}"
WORK_DIR="$(mktemp -d)"
BACKEND_PID=""
FAILURES=0

stop_backend() {
  if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
  fi
}

finish() {
  stop_backend
  if [ "$KEEP" = "1" ]; then
    echo "temporary files kept in $WORK_DIR"
  elif [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
  fi
}
trap finish EXIT INT TERM

start_backend() {
  # Starting one is only possible on this machine; a remote base host has to be
  # started over there with ./dev.sh.
  if [ "$BASE_HOST" != localhost ]; then
    echo "cannot start a backend for --base-host $BASE_HOST here, start it over there with ./dev.sh --public-host $BASE_HOST" >&2
    return 1
  fi

  echo "==> Starting a development backend on ${BASE_URL} (TLS ${TLS_CONNECT})"
  (cd "$REPO_PATH/webpage/backend" && go build -o "$WORK_DIR/bbb" .) || return 1

  APP_ENV=development \
  BB_HTTP_PORT="$HTTP_PORT" \
  BB_HTTPS_PORT="$HTTPS_PORT" \
  BB_REPO_PATH="$REPO_PATH" \
  BB_REPO_LOCAL=true \
  BB_REDIRECT_URL="$BASE_URL" \
    "$WORK_DIR/bbb" >"$WORK_DIR/backend.log" 2>&1 &
  BACKEND_PID=$!

  for _ in $(seq 1 50); do
    curl -fsS -o /dev/null "$BASE_URL/stats" 2>/dev/null && return 0
    sleep 0.2
  done

  echo "the backend did not come up, its log:" >&2
  cat "$WORK_DIR/backend.log" >&2
  return 1
}

# --- checks -------------------------------------------------------------

pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILURES=$(( FAILURES + 1 )); }

check() {
  local description="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$description"; else fail "$description"; fi
}

install_with_curl() {
  local script="$1" home="$2"
  curl -sL "${BASE_URL}/${CODE}/${script}" | HOME="$home" bash -s curl
}

install_with_wget() {
  local script="$1" home="$2"
  wget -q -O - "${BASE_URL}/${CODE}/${script}" | HOME="$home" bash -s wget
}

install_with_openssl() {
  local script="$1" home="$2"
  echo -e "GET /${CODE}/${script} HTTP/1.1\r\nHost: ${TLS_CONNECT}\r\nConnection: close\r\n\r\n" \
    | openssl s_client -quiet -connect "$TLS_CONNECT" 2>/dev/null \
    | sed '1,/^\r$/d' | HOME="$home" bash -s openssl
}

verify_installation() {
  local method="$1" home="$2" label="$3"

  check "$label: bb.sh downloaded" test -s "$home/.bb/bb.sh"
  check "$label: theme injected into bb.sh" grep -q "^PRIMARY_COLOR=" "$home/.bb/bb.sh"
  check "$label: avatar flag injected into bb.sh" grep -q "^AVATAR=" "$home/.bb/bb.sh"
  check "$label: git-prompt.sh downloaded" test -s "$home/.bb/git-prompt.sh"
  check "$label: inputrc appended" grep -q "BetterBash" "$home/.inputrc"
  check "$label: bashrc updated" grep -q "BetterBash" "$home/.bashrc"
  check "$label: prompt function builds PS1" bash -c "
      HOME='$home'
      . '$home/.bb/bb.sh'
      __prompt_command
      [ -n \"\$PS1\" ]
    "
}

# The download script handed out by the development backend has to point back at
# it, otherwise the installation stops working after its first request.
verify_endpoint_injection() {
  local method="$1"
  local file="$WORK_DIR/getbb-$method.sh"
  local label="$method endpoints"

  local base_url="$BASE_URL/$CODE"

  case "$method" in
    curl) curl -fsS -o "$file" "${BASE_URL}/${CODE}/getbb.sh" ;;
    openssl)
      base_url="https://${TLS_CONNECT}/${CODE}"
      echo -e "GET /${CODE}/getbb.sh HTTP/1.1\r\nHost: ${TLS_CONNECT}\r\nConnection: close\r\n\r\n" \
        | openssl s_client -quiet -connect "$TLS_CONNECT" 2>/dev/null \
        | sed '1,/^\r$/d' >"$file"
      ;;
  esac

  check "$label: script downloaded" test -s "$file"
  check "$label: curl/wget base url rewritten" grep -q "^BB_BASE_URL='${base_url}'" "$file"
  # A script fetched over TLS must not be chunked, bash would choke on the
  # markers and on stray carriage returns.
  check "$label: no carriage returns left in the script" bash -c "! grep -q $'\\r' '$file'"
  check "$label: openssl target rewritten" grep -q "^BB_TLS_PORT='${HTTPS_PORT}'" "$file"
  check "$label: no production endpoint left behind" bash -c "! grep -q 'git.cz0.cz\|bb.cz0.cz' '$file'"
}

verify_uninstallation() {
  local method="$1" home="$2" label="$3"

  check "$label: ~/.bb removed" test ! -e "$home/.bb"
  check "$label: bashrc cleaned" bash -c "! grep -q 'BetterBash' '$home/.bashrc'"
  check "$label: inputrc cleaned" bash -c "! grep -q 'BetterBash' '$home/.inputrc'"
}

run_method() {
  local method="$1"
  local home="$WORK_DIR/$method"
  local label="$method install/uninstall via $BASE_URL"

  mkdir -p "$home"
  echo "==> $method"

  case "$method" in
    curl) install_with_curl getbb.sh "$home" ;;
    wget) install_with_wget getbb.sh "$home" ;;
    openssl) install_with_openssl getbb.sh "$home" ;;
    *) fail "unknown method $method"; return ;;
  esac

  verify_installation "$method" "$home" "$label"

  case "$method" in
    curl) install_with_curl removebb.sh "$home" ;;
    wget) install_with_wget removebb.sh "$home" ;;
    openssl) install_with_openssl removebb.sh "$home" ;;
  esac

  verify_uninstallation "$method" "$home" "$label"
}

# --- run ----------------------------------------------------------------

if curl -fsS -o /dev/null "$BASE_URL/stats" 2>/dev/null; then
  echo "==> Reusing the backend already listening on ${BASE_URL}"
else
  start_backend || exit 1
fi

verify_endpoint_injection curl
verify_endpoint_injection openssl

for method in curl wget openssl; do
  run_method "$method"
done

echo "==> Random theme endpoint through $BASE_URL"
random_script="$WORK_DIR/rand-getbb.sh"
curl -fsS -o "$random_script" "${BASE_URL}/rand/getbb.sh"
if [ -s "$random_script" ]; then
  pass "rand/getbb.sh served"
  rand_home="$WORK_DIR/rand"
  mkdir -p "$rand_home"
  curl -fsS "${BASE_URL}/rand/getbb.sh" | HOME="$rand_home" bash -s curl >/dev/null 2>&1
  check "rand install produced a themed bb.sh" grep -q "^PRIMARY_COLOR=" "$rand_home/.bb/bb.sh"
else
  fail "rand/getbb.sh served"
fi

echo
if [ "$FAILURES" = "0" ]; then
  echo "All installation methods work against $BASE_URL"
else
  echo "$FAILURES check(s) failed"
fi
exit "$FAILURES"
