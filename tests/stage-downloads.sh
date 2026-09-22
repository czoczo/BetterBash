#!/bin/sh
#
# Stage the files BetterBash installs from its static host.
#
#   ./tests/stage-downloads.sh DEST
#
# Everything a user downloads is listed here and nowhere else: the Pages
# workflow stages into the WebUI's dist directory with this script, and
# ./test-install-methods.sh serves a staged copy to the curl, wget and openssl
# methods. So the layout the tests exercise is the layout that gets deployed.
#
# DEST is emptied of a previous staging first (it never deletes the WebUI build,
# because it only removes the names it is about to copy).

set -u

usage() {
  awk 'NR <= 2 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi
if [ $# -ne 1 ]; then
  usage >&2
  printf '\n' >&2
  printf 'stage-downloads: one argument required\n' >&2
  exit 2
fi

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")

# Paths relative to the repository root, in the layout the installer expects.
BB_FILES='
getbb.sh
removebb.sh
.inputrc
prompt/bb-theme.sh
prompt/bb.sh
prompt/git-prompt.sh
'

if [ ! -d "$REPO_ROOT" ]; then
  printf 'stage-downloads: no repository at %s\n' "$REPO_ROOT" >&2
  exit 1
fi

mkdir -p "$DEST" || exit 1

for file in $BB_FILES; do
  if [ ! -f "$REPO_ROOT/$file" ]; then
    printf 'stage-downloads: %s is missing from the repository\n' "$file" >&2
    exit 1
  fi
  mkdir -p "$DEST/$(dirname "$file")" || exit 1
  # Remove the previous copy first: cp onto a running file keeps the inode and
  # confuses caches, and a leftover file would look like a successful staging.
  rm -f "$DEST/$file"
  cp "$REPO_ROOT/$file" "$DEST/$file" || exit 1
done

# The staged tree has to answer the requests the installer makes, so check the
# URLs here rather than in every consumer of the staging.
missing=0
for file in $BB_FILES; do
  if [ ! -s "$DEST/$file" ]; then
    printf 'stage-downloads: %s staged empty\n' "$file" >&2
    missing=$(( missing + 1 ))
  fi
done
[ "$missing" = "0" ] || exit 1

printf 'Staged %s files into %s\n' "$(printf '%s\n' "$BB_FILES" | grep -c .)" "$DEST"
