#!/usr/bin/env bash
#
# Run the BetterBash WebUI and the files it installs, locally.
#
# Usage: ./dev.sh [options]
#
#   --tls-port PORT      port of the HTTPS file server used by the openssl
#                        install method (default 8443)
#   --site-host HOST     interface the WebUI dev server listens on
#                        (default 0.0.0.0, i.e. reachable from other machines)
#   --site-port PORT     port of the WebUI dev server (default 5173)
#   --public-host HOST   host clients announce, and the certificate of the file
#                        server is issued for (default localhost)
#   --repo PATH          repository whose files to serve (default: this one)
#   --no-frontend        serve the installer files only, without the WebUI
#
# There is nothing else to run: BetterBash is the WebUI plus a few shell scripts.
# The files a user downloads are staged into public/ of the WebUI, so the dev
# server serves them and the curl and wget install commands point at the dev
# server itself, exactly as they point at the Pages deployment in production.
# Only the openssl method, which insists on TLS, gets a second listener: a small
# HTTPS file server with a self signed certificate in .dev/.
#
# Changes to prompt/bb.sh, .inputrc or getbb.sh are picked up by restaging: the
# staging happens once at start, so restart after editing them (or run
# ./tests/stage-downloads.sh webpage/frontend/public).
#
# Every installation method can be tried against the working copy:
#   ./test-install-methods.sh
# against this running dev setup:
#   ./test-install-methods.sh --live http://localhost:${SITE_PORT}

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TLS_PORT="${BB_TLS_PORT:-8443}"
SITE_HOST="${VITE_BB_SITE_HOST:-0.0.0.0}"
SITE_PORT="${VITE_BB_SITE_PORT:-5173}"
# The address a browser on another machine would type. Empty means localhost, so
# a plain ./dev.sh keeps generating the commands of a machine serving itself.
PUBLIC_HOST="${VITE_BB_PUBLIC_HOST:-}"
REPO_PATH="$REPO_ROOT"
FRONTEND=1

usage() {
  awk 'NR <= 2 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tls-port) TLS_PORT="$2"; shift 2 ;;
    --site-host) SITE_HOST="$2"; shift 2 ;;
    --site-port) SITE_PORT="$2"; shift 2 ;;
    --public-host) PUBLIC_HOST="$2"; shift 2 ;;
    --repo) REPO_PATH="$2"; shift 2 ;;
    --no-frontend) FRONTEND=0; shift ;;
    -h | --help) usage ;;
    *)
      echo "unknown option: $1 (see --help)" >&2
      exit 2
      ;;
  esac
done

[ -d "$REPO_PATH" ] || { echo "no repository at $REPO_PATH" >&2; exit 1; }
for command in node openssl curl; do
  command -v "$command" >/dev/null || { echo "missing requirement: $command" >&2; exit 1; }
done
if [ "$FRONTEND" = "1" ]; then
  command -v pnpm >/dev/null || { echo "missing requirement: pnpm (see https://pnpm.io)" >&2; exit 1; }
fi

[ -n "$PUBLIC_HOST" ] || PUBLIC_HOST=localhost

# The files a user downloads, next to the WebUI. public/ is generated and is not
# in version control; see tests/stage-downloads.sh for what belongs in it.
SERVE_DIR="$REPO_PATH/webpage/frontend/public"

echo "==> Staging the installer files of $REPO_PATH into ${SERVE_DIR#$REPO_ROOT/}"
"$REPO_PATH/tests/stage-downloads.sh" "$SERVE_DIR"

# A certificate is generated once and reused; SANs cover localhost, the loopback
# address and whatever --public-host named.
DEV_DIR="$REPO_ROOT/.dev"
CERT="$DEV_DIR/localhost.pem"
KEY="$DEV_DIR/localhost.key"
mkdir -p "$DEV_DIR"
if [ ! -f "$CERT" ] || ! openssl x509 -checkend 86400 -noout -infile "$CERT" >/dev/null 2>&1; then
  echo "==> Writing a self signed certificate for localhost, 127.0.0.1 and $PUBLIC_HOST to $DEV_DIR"
  sans="DNS:localhost,DNS:$PUBLIC_HOST,IP:127.0.0.1"
  [ "$PUBLIC_HOST" = "localhost" ] && sans="DNS:localhost,IP:127.0.0.1"
  openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
    -keyout "$KEY" -out "$CERT" -subj /CN=localhost -addext "subjectAltName=$sans" >/dev/null
fi

# The install commands of the page follow the origin the page is loaded from, so
# they are cleared here and .env.development does not have to know the port.
export VITE_BB_ENV=development
export VITE_BB_INSTALL_BASE_URL=
export VITE_BB_TLS_BASE_URL="https://${PUBLIC_HOST}:${TLS_PORT}"
export VITE_BB_SITE_PORT="$SITE_PORT"
export VITE_BB_SITE_HOST="$SITE_HOST"
export VITE_BB_SITE_ALLOWED_HOSTS="$PUBLIC_HOST"

FILES_PID=""

cleanup() {
  if [ -n "$FILES_PID" ] && kill -0 "$FILES_PID" 2>/dev/null; then
    kill "$FILES_PID" 2>/dev/null || true
    wait "$FILES_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

echo "==> Serving $SERVE_DIR over https://localhost:${TLS_PORT} (openssl install method)"
node "$REPO_ROOT/tests/static-server.mjs" "$SERVE_DIR" "-" "$TLS_PORT" "$CERT" "$KEY" &
FILES_PID=$!

for _ in $(seq 1 50); do
  curl -fsS -o /dev/null "https://localhost:${TLS_PORT}/getbb.sh" \
    --cacert "$CERT" 2>/dev/null && break
  sleep 0.2
done

cat <<EOF

  WebUI        http://${PUBLIC_HOST}:${SITE_PORT} on ${SITE_HOST}   (Ctrl-C stops both)
  curl / wget  http://${PUBLIC_HOST}:${SITE_PORT}/getbb.sh   (served by the dev server)
  openssl      https://${PUBLIC_HOST}:${TLS_PORT}/getbb.sh   (self signed certificate)
  files        $SERVE_DIR (staged, generated)

  Try every installation method against the working copy:
    ./test-install-methods.sh
  or against this running setup:
    ./test-install-methods.sh --live http://localhost:${SITE_PORT}

EOF

if [ "$FRONTEND" != "1" ]; then
  echo "==> WebUI skipped, installer files on pid ${FILES_PID}. Press Ctrl-C to stop."
  wait "$FILES_PID"
  exit 0
fi

echo "==> Installing WebUI dependencies"
(cd "$REPO_ROOT/webpage/frontend" && pnpm install --silent)

echo "==> Starting the WebUI on http://${SITE_HOST}:${SITE_PORT} (Ctrl-C stops both)"
(cd "$REPO_ROOT/webpage/frontend" && pnpm exec vite --mode development --host "$SITE_HOST" --port "$SITE_PORT")
