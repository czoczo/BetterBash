#!/usr/bin/env bash
#
# BetterBash installer of the LEGACY path: it downloads one file at a time.
#
# Deprecated by installbb.sh, which copies the prompt out of a tree the user
# fetched (git clone, or the bb.tgz package) and therefore never pipes a script
# into a shell. The WebUI prints those commands now. This script is kept for the
# install commands of older releases that are in other people's notes and
# scripts - they still work - and it is the only path that needs neither git nor
# tar. ./tests/test-legacy-pipe.sh keeps it working while it lives here.
#
# Downloads the prompt files of this repository and writes the theme chosen in
# the WebUI to ~/.bb/theme.sh. There is no server side of the theme any more:
# the theme code travels as an argument of this script, and prompt/bb-theme.sh
# decodes it on this machine into a file prompt/bb.sh reads.
#
# Usage, as released before the package path:
#
#   curl -sL https://betterbash.cz0.cz/getbb.sh | bash -s -- curl vN-y_5uA
#   curl -sL https://betterbash.cz0.cz/getbb.sh | bash -s -- curl rand
#   wget -q -O - https://betterbash.cz0.cz/getbb.sh | bash -s wget vN-y_5uA
#
# Options, in any order after the download method:
#
#   <code>            theme code from the WebUI, or the word "rand" for a theme
#                     drawn on this machine and remembered in ~/.bb/theme-code
#   --reroll          draw a new random theme instead of keeping the stored one
#   --base-url URL    download from another origin (a development checkout, the
#                     repository mirror, the other domain of the WebUI)
#   --dir DIR         install the prompt files into DIR (default ~/.bb)
#   --no-inputrc      leave ~/.inputrc alone
#   -h, --help        this text
#
# Nothing here needs bash: the script is POSIX shell, and is tested under dash
# too, so `sh getbb.sh curl <code>` works.

set -u

BB_BASE_URL="${BB_BASE_URL:-https://betterbash.cz0.cz}"
BB_DIR="${BB_DIR:-$HOME/.bb}"
BB_METHOD=""
BB_CODE="${BB_THEME:-}"
BB_INPUTRC=1

printHelp() {
  # The usage block is the comment above, so help stays in one place.
  awk 'NR <= 2 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
  exit 0
}

# A theme code is eight characters of the theme code alphabet, or the word that
# stands for "draw one here". Anything else in the argument list is a mistake and
# has to be refused before a single request goes out.
is_theme_code() {
  case $1 in
    rand) return 0 ;;
    ????????)
      case $1 in
        *[!A-Za-z0-9_-]*) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

while [ $# -gt 0 ]; do
  case $1 in
    curl | wget | openssl) BB_METHOD=$1 ;;
    --reroll) BB_THEME_REROLL=1 ;;
    --base-url) BB_BASE_URL=${2:-}; shift ;;
    --dir) BB_DIR=${2:-}; shift ;;
    --code) BB_CODE=${2:-}; shift ;;
    --no-inputrc) BB_INPUTRC=0 ;;
    -h | --help) printHelp ;;
    *)
      if [ -n "$BB_CODE" ]; then
        printf 'getbb: unexpected argument: %s (see --help)\n' "$1" >&2
        exit 2
      fi
      if ! is_theme_code "$1"; then
        printf 'getbb: %s is not a theme code (eight characters of A-Za-z0-9_-, or "rand"; see --help)\n' "$1" >&2
        exit 2
      fi
      BB_CODE=$1
      ;;
  esac
  shift
done

case $BB_METHOD in
  curl | wget | openssl) ;;
  *)
    printf 'getbb: choose a download method: curl, wget or openssl (see --help)\n' >&2
    exit 2
    ;;
esac

if [ -z "$BB_BASE_URL" ]; then
  printf 'getbb: nothing to download from (--base-url)\n' >&2
  exit 2
fi
if [ ! -d "$HOME" ]; then
  printf 'getbb: no home directory to install into\n' >&2
  exit 2
fi

# --- downloads -------------------------------------------------------------

# All three methods print the body of one file of BB_BASE_URL on stdout. The
# paths are constants of this script and the theme code is never part of a URL,
# so nothing that comes off the command line ever reaches a request.
get_file_curl() {
  curl -fsSL "${BB_BASE_URL}/$1"
}

get_file_wget() {
  wget -q -O - "${BB_BASE_URL}/$1"
}

get_file_openssl() {
  # The dependency free method: a raw HTTP request over TLS. GitHub answers such
  # requests with a Content-Length, but chunk markers are removed defensively
  # together with the carriage returns of the headers. -servername is needed
  # because a shared front proxy serves many hosts from one address.
  _host=$BB_TLS_HOST
  [ "$BB_TLS_PORT" = "443" ] || _host=$BB_TLS_HOST:$BB_TLS_PORT

  printf 'GET /%s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n' "$1" "$_host" \
    | openssl s_client -quiet -connect "$BB_TLS_HOST:$BB_TLS_PORT" -servername "$BB_TLS_HOST" 2>/dev/null \
    | sed '1,/^\r$/d' \
    | sed -E ':a;N;$!ba;s/(\r\n)?[a-f0-9]+\r\n//g' \
    | sed 's/\r$//'
}

# The openssl variant needs host and port separately, taken from BB_BASE_URL.
split_tls_endpoint() {
  _rest=${BB_BASE_URL#*://}
  BB_TLS_HOST=${_rest%%/*}
  BB_TLS_PORT=443
  case $BB_TLS_HOST in
    *:*)
      BB_TLS_PORT=${BB_TLS_HOST##*:}
      BB_TLS_HOST=${BB_TLS_HOST%%:*}
      ;;
  esac
}

get_file() {
  case $BB_METHOD in
    curl) get_file_curl "$1" ;;
    wget) get_file_wget "$1" ;;
    openssl) get_file_openssl "$1" ;;
  esac
}

# fetch_file SERVER_PATH LOCAL_PATH MARKER
# Downloads a file and keeps it only if it is what it claims to be: a proxy or a
# CDN answering with an error page must never end up as a shell script in the
# home directory, and a rejected download leaves no LOCAL_PATH at all.
fetch_file() {
  _server=$1
  _local=$2
  _marker=$3

  # Downloaded aside and moved only when accepted, so a rejected file can never
  # be read by the shell as if it were part of the installation.
  _part="$_local.part"
  : >"$_part" || return 1
  if ! get_file "$_server" >"$_part" 2>/dev/null; then
    rm -f "$_part"
    printf 'getbb: failed to download %s/%s\n' "$BB_BASE_URL" "$_server" >&2
    return 1
  fi

  if [ ! -s "$_part" ]; then
    rm -f "$_part"
    printf 'getbb: %s/%s came back empty\n' "$BB_BASE_URL" "$_server" >&2
    return 1
  fi

  if [ -n "$_marker" ] && ! grep -q "$_marker" "$_part"; then
    rm -f "$_part"
    printf 'getbb: %s/%s is not the BetterBash file it should be (no %s in it)\n' \
      "$BB_BASE_URL" "$_server" "$_marker" >&2
    return 1
  fi

  mv -f "$_part" "$_local"
  return 0
}

# --- install ---------------------------------------------------------------

# Everything is downloaded before anything is decoded, because the decoder is
# itself one of the files.
mkdir -p "$BB_DIR" || {
  printf 'getbb: cannot create %s\n' "$BB_DIR" >&2
  exit 1
}
split_tls_endpoint

if ! fetch_file "prompt/bb-theme.sh" "$BB_DIR/bb-theme.sh" "^bb_theme_decode"; then
  printf 'getbb: without the theme library there is nothing to install\n' >&2
  exit 1
fi

# The library is POSIX shell, so sourcing it keeps this script POSIX shell too.
# shellcheck source=/dev/null
. "$BB_DIR/bb-theme.sh"

if ! fetch_file "prompt/bb.sh" "$BB_DIR/bb.sh" "__prompt_command"; then exit 1; fi
if ! fetch_file "prompt/git-prompt.sh" "$BB_DIR/git-prompt.sh" "__git_ps1"; then exit 1; fi

# The theme: the code from the command line, or the one this machine already
# has, or a freshly drawn random one. A random theme is kept across reinstalls,
# --reroll (BB_THEME_REROLL=1) asks for a new one.
BB_THEME_REROLL=${BB_THEME_REROLL:-0}
export BB_THEME_REROLL
[ -n "$BB_CODE" ] || BB_CODE=$BB_THEME_RANDOM

if ! BB_RESOLVED=$(bb_theme_resolve "$BB_CODE" "$BB_DIR/theme-code"); then
  printf 'getbb: could not resolve the theme %s\n' "$BB_CODE" >&2
  exit 1
fi

if ! bb_theme_write "$BB_RESOLVED" "$BB_DIR"; then
  printf 'getbb: could not write the theme to %s\n' "$BB_DIR" >&2
  exit 1
fi

# Readline bindings are a convenience; the prompt works without them.
if [ "$BB_INPUTRC" = "1" ] && ! grep -q "BetterBash" "$HOME/.inputrc" 2>/dev/null; then
  if fetch_file ".inputrc" "$BB_DIR/inputrc" ""; then
    if cat "$BB_DIR/inputrc" >>"$HOME/.inputrc"; then
      # ~/.inputrc is the copy that counts; ~/.bb stays free of loose files.
      rm -f "$BB_DIR/inputrc"
    fi
  else
    printf 'getbb: could not download .inputrc, history search on the arrow keys is not installed\n' >&2
  fi
fi

# The hook in ~/.bashrc is the block every release of BetterBash writes, so the
# removebb.sh of any release finds it again.
BB_BASHRC_BLOCK=$(cat <<-'END'
	# BetterBash
	[ -f "$HOME/.bb/bb.sh" ] && . "$HOME/.bb/bb.sh"
	bind -f ~/.inputrc
END
)

BB_BASHRC_ACTION=kept
if ! grep -q "BetterBash" "$HOME/.bashrc" 2>/dev/null; then
  if printf '%s\n' "$BB_BASHRC_BLOCK" >>"$HOME/.bashrc"; then
    BB_BASHRC_ACTION=added
  else
    printf 'getbb: could not write to %s/.bashrc\n' "$HOME" >&2
  fi
fi

if [ "$BB_CODE" = "$BB_THEME_RANDOM" ]; then
  BB_THEME_NOTE="remembered in $BB_DIR/theme-code"
else
  BB_THEME_NOTE="from the WebUI"
fi

cat <<EOF

BetterBash ${BB_BASHRC_ACTION} ~/.bashrc
  theme   $BB_RESOLVED ($BB_THEME_NOTE)
  colors  $BB_DIR/theme.sh
  prompt  $BB_DIR/bb.sh
  files   $BB_BASE_URL

Reload the shell, or run: . ~/.bashrc
EOF
