#!/usr/bin/env bash
#
# Run the BetterBash backend and WebUI locally (development environment).
#
# Usage: ./dev.sh [options]
#
#   --http-port PORT     port of the plain HTTP backend listener (default 8081)
#   --https-port PORT    port of the HTTPS backend listener, used by the openssl
#                        installation method (default 8443)
#   --site-host HOST     interface the WebUI dev server listens on
#                        (default 0.0.0.0, i.e. reachable from other machines)
#   --site-port PORT     port of the WebUI dev server (default 5173)
#   --public-host HOST   host advertised in the install commands and used for the
#                        backend -> WebUI redirect (default localhost; use the
#                        address the other machine types, e.g. this host's IP)
#   --repo PATH          repository checkout to serve (default: this one)
#   --no-frontend        start the backend only
#
# Both listeners of the backend are bound to all interfaces already, so with
# --public-host the whole setup - WebUI, download endpoints and the prompt
# scripts installed with curl, wget or openssl - works from another machine.
#
# The backend serves the files of the repository working copy, so changes to
# prompt/bb.sh, .inputrc or getbb.sh are picked up on the next request. Every
# installation method can be tried against it: see ./test-install-methods.sh.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HTTP_PORT="${BB_HTTP_PORT:-8081}"
HTTPS_PORT="${BB_HTTPS_PORT:-8443}"
SITE_HOST="${VITE_BB_SITE_HOST:-0.0.0.0}"
SITE_PORT="${VITE_BB_SITE_PORT:-5173}"
# The address a browser on another machine would type. Empty means localhost, so
# a plain ./dev.sh keeps generating the commands of a machine that serves itself.
PUBLIC_HOST="${VITE_BB_PUBLIC_HOST:-}"
REPO_PATH="$REPO_ROOT"
FRONTEND=1

usage() {
  awk 'NR <= 2 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --http-port) HTTP_PORT="$2"; shift 2 ;;
    --https-port) HTTPS_PORT="$2"; shift 2 ;;
    --site-host) SITE_HOST="$2"; shift 2 ;;
    --site-port) SITE_PORT="$2"; shift 2 ;;
    --public-host) PUBLIC_HOST="$2"; shift 2 ;;
    --repo) REPO_PATH="$2"; shift 2 ;;
    --no-frontend) FRONTEND=0; shift ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
done

for command in go git curl; do
  command -v "$command" >/dev/null || { echo "missing requirement: $command" >&2; exit 1; }
done
if [ "$FRONTEND" = "1" ]; then
  command -v pnpm >/dev/null || { echo "missing requirement: pnpm (see https://pnpm.io)" >&2; exit 1; }
fi

# Without --public-host everything stays on localhost. With it, the address is
# the one remote clients announce, and a named host is additionally allowed
# through the dev server's host check (IPv4 addresses always are).
if [ -z "$PUBLIC_HOST" ]; then
  PUBLIC_HOST=localhost
fi

# The endpoints the WebUI has to offer in its install commands. They override
# webpage/frontend/.env.development, which carries the same defaults.
export APP_ENV=development
export BB_HTTP_PORT="$HTTP_PORT"
export BB_HTTPS_PORT="$HTTPS_PORT"
export BB_REPO_PATH="$REPO_PATH"
export BB_REPO_LOCAL=true
export BB_REDIRECT_URL="http://${PUBLIC_HOST}:${SITE_PORT}"
export VITE_BB_ENV=development
export VITE_BB_INSTALL_BASE_URL="http://${PUBLIC_HOST}:${HTTP_PORT}"
export VITE_BB_TLS_HOST="$PUBLIC_HOST"
export VITE_BB_TLS_PORT="$HTTPS_PORT"
export VITE_BB_SITE_PORT="$SITE_PORT"
export VITE_BB_SITE_URL="http://${PUBLIC_HOST}:${SITE_PORT}"
export VITE_BB_SITE_ALLOWED_HOSTS="$PUBLIC_HOST"

BACKEND_BIN="$(mktemp -d)/bbb"
BACKEND_PID=""

cleanup() {
  if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
  fi
  rm -rf "$(dirname "$BACKEND_BIN")"
}
trap cleanup EXIT INT TERM

echo "==> Building the backend"
(cd "$REPO_ROOT/webpage/backend" && go build -o "$BACKEND_BIN" .)

echo "==> Starting the backend (APP_ENV=development)"
"$BACKEND_BIN" &
BACKEND_PID=$!

for _ in $(seq 1 50); do
  curl -fsS -o /dev/null "http://localhost:${HTTP_PORT}/stats" 2>/dev/null && break
  sleep 0.2
done

cat <<EOF

  Backend    http://${PUBLIC_HOST}:${HTTP_PORT}   (openssl method: https://${PUBLIC_HOST}:${HTTPS_PORT})
  WebUI      http://${PUBLIC_HOST}:${SITE_PORT} on ${SITE_HOST}   (Ctrl-C stops both)
  Repository ${REPO_PATH} (working copy, never pulled or reset)
  Reload     curl -s http://localhost:${HTTP_PORT}/reload

  Try every installation method against it:
    ./test-install-methods.sh --http-port ${HTTP_PORT} --https-port ${HTTPS_PORT}
  From another machine, add the address it reaches you on:
    ./test-install-methods.sh --base-host ${PUBLIC_HOST} --http-port ${HTTP_PORT}

EOF

if [ "$FRONTEND" != "1" ]; then
  echo "==> Frontend skipped, backend pid ${BACKEND_PID}. Press Ctrl-C to stop."
  wait "$BACKEND_PID"
  exit 0
fi

echo "==> Installing WebUI dependencies"
(cd "$REPO_ROOT/webpage/frontend" && pnpm install --silent)

echo "==> Starting the WebUI on http://${SITE_HOST}:${SITE_PORT} (Ctrl-C stops both)"
(cd "$REPO_ROOT/webpage/frontend" && pnpm exec vite --mode development --host "$SITE_HOST" --port "$SITE_PORT")
