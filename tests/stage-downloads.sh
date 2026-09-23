#!/bin/sh
#
# Stage what a BetterBash release is made of, for the static host.
#
#   ./tests/stage-downloads.sh DEST
#
# Two things are produced in DEST, and both from the same list of files:
#
#   bb.tgz          the tree installbb.sh copies from, with a bb/ prefix, so
#                   `curl -sL .../bb.tgz | tar -C /tmp -xz` leaves /tmp/bb; the
#                   commands of the WebUI fetch exactly this, from the origin that
#                   served the page. bb.tgz.sha256 carries its checksum.
#   loose files     getbb.sh and the prompt files of the legacy path, which still
#                   downloads one file at a time from the origin root.
#
# Everything a user downloads is listed here and nowhere else: the Pages workflow
# stages into the WebUI's dist directory with this script, and
# ./test-install.sh serves the staged copy to the git, curl, wget and openssl
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
# shellcheck disable=SC1007
# cd without CPATH: an empty assignment in front of a command, not an assignment
# to a variable called CPATH.
DEST=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")

# The tree installbb.sh copies from. The package is this list under a bb/ prefix,
# and it is complete on purpose: the uninstaller travels with the prompt, so a
# machine can be cleaned up without downloading anything.
BB_TREE_FILES='installbb.sh
removebb.sh
.inputrc
VERSION_APP.txt
prompt/bb-theme.sh
prompt/bb.sh
prompt/git-prompt.sh'

# The legacy path: files a released getbb.sh downloads from the origin root, one
# request each. Kept while those install commands are still in the wild.
BB_LOOSE_FILES='getbb.sh
removebb.sh
.inputrc
prompt/bb-theme.sh
prompt/bb.sh
prompt/git-prompt.sh'

if [ ! -d "$REPO_ROOT" ]; then
  printf 'stage-downloads: no repository at %s\n' "$REPO_ROOT" >&2
  exit 1
fi

# One check for both lists, so a missing file is reported before anything is
# written, rather than as a package that fails verify_tree on a user machine.
for file in $BB_TREE_FILES $BB_LOOSE_FILES; do
  if [ ! -f "$REPO_ROOT/$file" ]; then
    printf 'stage-downloads: %s is missing from the repository\n' "$file" >&2
    exit 1
  fi
done

mkdir -p "$DEST" || exit 1

stage_file() {
  # Remove the previous copy first: cp onto a running file keeps the inode and
  # confuses caches, and a leftover file would look like a successful staging.
  rm -f "$DEST/$1"
  mkdir -p "$DEST/$(dirname "$1")" || return 1
  cp "$REPO_ROOT/$1" "$DEST/$1" || return 1
}

for file in $BB_LOOSE_FILES; do
  stage_file "$file" || exit 1
done

# --- the package -------------------------------------------------------------

# Built in its own directory so that the archive holds a bb/ prefix: extracting
# it gives /tmp/bb, the directory every install command of the WebUI names.
PACK=$DEST/.bb-package
rm -rf "$PACK"
mkdir -p "$PACK/bb" || exit 1
for file in $BB_TREE_FILES; do
  mkdir -p "$PACK/bb/$(dirname "$file")" || exit 1
  cp "$REPO_ROOT/$file" "$PACK/bb/$file" || exit 1
done
# The tree of a package carries no VCS or test leftovers, whatever the working
# copy it was built from holds.
find "$PACK" -name '*.part' -delete 2>/dev/null

# Reproducible where tar supports it, because a checksum of a release should not
# depend on the minute it was built in. GNU tar flags only; anything else that
# can produce a gzip is accepted without them.
rm -f "$DEST/bb.tgz"
if ! (cd "$PACK" && tar --sort=name --owner=0 --group=0 --numeric-owner \
  --mtime="@${SOURCE_DATE_EPOCH:-0}" -czf "$DEST/bb.tgz" bb 2>/dev/null); then
  (cd "$PACK" && tar -czf "$DEST/bb.tgz" bb) || exit 1
fi
rm -rf "$PACK"

if command -v sha256sum >/dev/null 2>&1; then
  _sha=sha256sum
elif command -v shasum >/dev/null 2>&1; then
  _sha='shasum -a 256'
else
  _sha=''
fi
if [ -n "$_sha" ]; then
  (cd "$DEST" && $_sha bb.tgz >bb.tgz.sha256) || exit 1
fi

# The staged tree has to answer the requests the installers make, so check the
# URLs here rather than in every consumer of the staging.
missing=0
for file in $BB_LOOSE_FILES; do
  if [ ! -s "$DEST/$file" ]; then
    printf 'stage-downloads: %s staged empty\n' "$file" >&2
    missing=$(( missing + 1 ))
  fi
done
if [ ! -s "$DEST/bb.tgz" ]; then
  printf 'stage-downloads: bb.tgz staged empty\n' >&2
  missing=$(( missing + 1 ))
fi
if [ -n "$_sha" ] && [ ! -s "$DEST/bb.tgz.sha256" ]; then
  printf 'stage-downloads: bb.tgz.sha256 was not written\n' >&2
  missing=$(( missing + 1 ))
fi

# The package is checked by listing it rather than by trusting the build: every
# file of the tree has to be inside, under the bb/ prefix the install commands
# extract to.
for file in $BB_TREE_FILES; do
  if ! tar -tzf "$DEST/bb.tgz" "bb/$file" >/dev/null 2>&1; then
    printf 'stage-downloads: bb/%s is not in bb.tgz\n' "$file" >&2
    missing=$(( missing + 1 ))
  fi
done
[ "$missing" = "0" ] || exit 1

printf 'Staged %s loose files and bb.tgz (%s bytes, %s files inside) into %s\n' \
  "$(printf '%s\n' "$BB_LOOSE_FILES" | grep -c .)" \
  "$(wc -c <"$DEST/bb.tgz" | tr -d ' ')" \
  "$(tar -tzf "$DEST/bb.tgz" | grep -cv '/$')" "$DEST"
