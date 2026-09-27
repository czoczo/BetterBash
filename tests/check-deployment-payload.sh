#!/bin/sh
#
# Check what a staged deployment serves, so an install command cannot 404.
#
#   ./tests/check-deployment-payload.sh DIST
#
# DIST is a built WebUI into which tests/stage-downloads.sh has put the installer
# files (webpage/frontend/dist in both deploy workflows). Everything the page tells
# a user to fetch has to be there, and bb.tgz has to hold exactly the tree of a
# release, so the package cannot carry anything the deployment does not already
# show.
#
# Both workflows run this on the artifact they are about to hand to their host:
# the GitHub Pages one and the Cloudflare Pages one, which stage the same files.

set -u

DIST=${1:-}
if [ -z "$DIST" ] || [ ! -d "$DIST" ]; then
  printf 'check-deployment-payload: DIST directory required\n' >&2
  exit 2
fi

# What is served loose is what the legacy getbb.sh path downloads; the current
# path fetches bb.tgz and nothing else.
for path in bb.tgz bb.tgz.sha256 getbb.sh removebb.sh .inputrc \
            prompt/bb-theme.sh prompt/bb.sh prompt/git-prompt.sh; do
  if [ ! -s "$DIST/$path" ]; then
    printf '%s/%s is missing, so an installation command would 404\n' "$DIST" "$path" >&2
    exit 1
  fi
done

# Names that belong to a fetched tree alone and therefore travel inside bb.tgz
# without being published as files of their own: install-pending, the flag that
# tells a tree it is not installed yet, q, the question an install command reads
# out of the tree it fetched, and the two files only the sourcing of a tree needs
# (installbb.sh and the version it reports). Everything else inside the package has
# to be staged loose as well, so the package cannot hold anything the deployment
# does not already show. tests/stage-downloads.sh owns the tree; ./test-install.sh
# runs its checks against the same staging.
missing=
for path in $(tar -tzf "$DIST/bb.tgz" | sed 's|^\./||' | grep -v '/$'); do
  case "$path" in
    install-pending | q | installbb.sh | VERSION_APP.txt) continue ;;
  esac
  [ -f "$DIST/$path" ] || missing="$missing $path"
done
if [ -n "$missing" ]; then
  printf 'inside bb.tgz but not staged as a file of its own:%s\n' "$missing" >&2
  exit 1
fi

ls -l "$DIST"
