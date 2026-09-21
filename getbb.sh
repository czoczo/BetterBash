#!/bin/bash

printHelp() {
    printf '%s' "$(cat <<EOF
Usage: $0 [download method]

Available methods:
  curl
  wget
  openssl
 
EOF
)"
    exit 0
}


case $1 in
    curl|wget|openssl) true ;;
    *) printHelp ;;
esac

# Where the rest of the files are downloaded from.
#
# The backend that serves this script fills the variables in (see
# webpage/backend), so a download started against any listener - a local
# development instance included - keeps talking to that same listener.
#
# The defaults are the production values and are written in the shape an older
# backend, which only rewrites "git.cz0.cz" and
# "/czoczo/BetterBash/raw/branch/master", would leave behind.
BB_BASE_URL="${BB_BASE_URL:-https://git.cz0.cz/czoczo/BetterBash/raw/branch/master}"
BB_PATH="${BB_PATH:-/czoczo/BetterBash/raw/branch/master}"
BB_TLS_HOST="${BB_TLS_HOST:-git.cz0.cz}"
BB_TLS_PORT="${BB_TLS_PORT:-443}"

get_file_openssl() {
  # Only a non standard port belongs into the Host header, which keeps the
  # production request identical to the one that has always been sent.
  local host_header="$BB_TLS_HOST"
  [ "$BB_TLS_PORT" = "443" ] || host_header="$BB_TLS_HOST:$BB_TLS_PORT"

  echo -e "GET $BB_PATH/$1 HTTP/1.1\r\nHost: $host_header\r\nConnection: close\r\n\r\n" \
  | openssl s_client -quiet -connect "$BB_TLS_HOST:$BB_TLS_PORT" 2>/dev/null \
  | sed '1,/^\r$/d' \
  | sed -E ':a;N;$!ba;s/(\r\n)?[a-f0-9]+\r\n//g' \
  | sed 's/\r$//'
}

get_file_curl() {
  curl -sL "${BB_BASE_URL}/$1"
}

get_file_wget() {
  wget -q -O - "${BB_BASE_URL}/$1"
}

get_file() {
  case $1 in
  "curl")
    get_file_curl "$2"
    ;;
  "wget")
    get_file_wget "$2"
    ;;
  "openssl")
    get_file_openssl "$2"
    ;;
  esac
}

# Prints the content of $2, refusing to succeed when the endpoint did not
# answer with anything usable.
fetch_file() {
  local content
  content="$(get_file "$1" "$2")"
  if [ -z "$content" ]; then
    echo "BetterBash: failed to download $2 from $BB_BASE_URL" >&2
    return 1
  fi
  printf '%s\n' "$content"
}

handle_inputrc() {
  grep -q "BetterBash" ~/.inputrc 2>/dev/null && return 0
  fetch_file "$1" .inputrc >> ~/.inputrc
}

DIR=~/.bb
CMD=$(cat <<-END
# BetterBash
[ -f $DIR/bb.sh ] && . $DIR/bb.sh
bind -f ~/.inputrc
END
)

mkdir -p $DIR && \
fetch_file "$1" prompt/bb.sh > $DIR/bb.sh && \
fetch_file "$1" prompt/git-prompt.sh > $DIR/git-prompt.sh && \
handle_inputrc "$1" && \
grep -q "BetterBash" ~/.bashrc 2>/dev/null || echo "$CMD" >> ~/.bashrc
