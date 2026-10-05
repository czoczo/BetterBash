#!/bin/sh
#
# Stage what a BetterBash release is made of, for the static host.
#
#   ./tests/stage-downloads.sh DEST
#
# What is produced in DEST is bb.tgz, and one list of files decides it:
#
#   bb.tgz          the tree the install commands of the WebUI fetch, holding that
#                   tree at the root of the archive, so
#                   `curl -sL .../bb.tgz | tar -C ~/.bb -xz` is the tree in ~/.bb -
#                   one level, the directory the command names. The destination is
#                   written on the command line rather than carried inside the
#                   package, which is what lets the package be unpacked anywhere.
#                   The commands fetch exactly this, from the origin that served
#                   the page, and bb.tgz.sha256 carries its checksum.
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

# The tree the install commands fetch. The package is this list at its root, and it
# is complete on purpose: the uninstaller travels with the prompt, so a machine can
# be cleaned up without downloading anything.
#
# install-pending is the flag that tells a tree it has not been installed yet and q
# is the question its install command asks, read out of the fetched tree. Both belong
# to a tree alone: they are not published as files of their own, but the git method
# needs them, so they live in the repository.
BB_TREE_FILES='install-pending
q
installbb.sh
removebb.sh
.inputrc
VERSION_APP.txt
prompt/bb-theme.sh
prompt/bb.sh
prompt/git-prompt.sh'

if [ ! -d "$REPO_ROOT" ]; then
  printf 'stage-downloads: no repository at %s\n' "$REPO_ROOT" >&2
  exit 1
fi

# A missing file is reported before anything is written, rather than as a package that
# fails verify_tree on a user machine.
for file in $BB_TREE_FILES; do
  if [ ! -f "$REPO_ROOT/$file" ]; then
    printf 'stage-downloads: %s is missing from the repository\n' "$file" >&2
    exit 1
  fi
done

mkdir -p "$DEST" || exit 1

# --- the package -------------------------------------------------------------

# Built in its own directory so that the archive holds the tree at its own root: the
# install commands name the directory they extract into (`tar -C ~/.bb -xz`), so the
# package carries no directory of its own and the fetched tree lands in ~/.bb itself.
PACK=$DEST/.bb-package
rm -rf "$PACK"
mkdir -p "$PACK" || exit 1
for file in $BB_TREE_FILES; do
  mkdir -p "$PACK/$(dirname "$file")" || exit 1
  cp "$REPO_ROOT/$file" "$PACK/$file" || exit 1
done
# The tree of a package carries no VCS or test leftovers, whatever the working
# copy it was built from holds.
find "$PACK" -name '*.part' -delete 2>/dev/null

# Reproducible where tar supports it, because a checksum of a release should not
# depend on the minute it was built in. GNU tar flags only; anything else that
# can produce a gzip is accepted without them.
rm -f "$DEST/bb.tgz"
if ! (cd "$PACK" && tar --sort=name --owner=0 --group=0 --numeric-owner \
  --mtime="@${SOURCE_DATE_EPOCH:-0}" -czf "$DEST/bb.tgz" . 2>/dev/null); then
  (cd "$PACK" && tar -czf "$DEST/bb.tgz" .) || exit 1
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
if [ ! -s "$DEST/bb.tgz" ]; then
  printf 'stage-downloads: bb.tgz staged empty\n' >&2
  missing=$(( missing + 1 ))
fi
if [ -n "$_sha" ] && [ ! -s "$DEST/bb.tgz.sha256" ]; then
  printf 'stage-downloads: bb.tgz.sha256 was not written\n' >&2
  missing=$(( missing + 1 ))
fi

# The package is checked by listing it rather than by trusting the build: every file
# of the tree has to be inside, right at the root the install commands extract to,
# because that root is unpacked on top of a real ~/.bb of a real machine. Names are
# listed with the leading ./ tar writes them, so the count of files inside has to be
# the count of the tree as well - nothing extra may travel with a release.
_listing=$(tar -tzf "$DEST/bb.tgz")
for file in $BB_TREE_FILES; do
  if ! printf '%s\n' "$_listing" | grep -qx "./$file"; then
    printf 'stage-downloads: %s is not in bb.tgz\n' "$file" >&2
    missing=$(( missing + 1 ))
  fi
done
_inside=$(printf '%s\n' "$_listing" | grep -cv '/$')
_wanted=$(printf '%s\n' "$BB_TREE_FILES" | grep -c .)
if [ "$_inside" != "$_wanted" ]; then
  printf 'stage-downloads: bb.tgz holds %s files, the tree is %s\n' "$_inside" "$_wanted" >&2
  printf '%s\n' "$_listing" | sed 's/^/stage-downloads:   /' >&2
  missing=$(( missing + 1 ))
fi
[ "$missing" = "0" ] || exit 1

printf 'Staged bb.tgz (%s bytes, %s files inside) into %s\n' \
  "$(wc -c <"$DEST/bb.tgz" | tr -d ' ')" \
  "$(tar -tzf "$DEST/bb.tgz" | grep -cv '/$')" "$DEST"
