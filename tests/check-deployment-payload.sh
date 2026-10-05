#!/bin/sh
#
# Check what a staged deployment serves, so an install command cannot 404.
#
#   ./tests/check-deployment-payload.sh DIST
#
# DIST is a built WebUI into which tests/stage-downloads.sh has put the package
# (webpage/frontend/dist in both deploy workflows). bb.tgz and its checksum are all
# a user is asked to fetch: every method unpacks the same archive into ~/.bb.
#
# Both workflows run this on the artifact they are about to hand to their host: the
# GitHub Pages one and the Cloudflare Pages one, which stage the same files.

set -u

DIST=${1:-}
if [ -z "$DIST" ] || [ ! -d "$DIST" ]; then
  printf 'check-deployment-payload: DIST directory required\n' >&2
  exit 2
fi

for path in bb.tgz bb.tgz.sha256; do
  if [ ! -s "$DIST/$path" ]; then
    printf '%s/%s is missing, so an installation command would 404\n' "$DIST" "$path" >&2
    exit 1
  fi
done

# The checksum is published so it can be checked against the bytes it describes.
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$DIST" && sha256sum -c bb.tgz.sha256) || exit 1
fi

# The names an install touches inside the archive: the prompt and its theme library,
# the flag that marks a fetched tree as not installed yet, the question its install
# command reads out of the tree, and the uninstaller, which has to travel with the
# prompt so a machine can be cleaned up without downloading anything. A package
# missing one of them installs a prompt that breaks later.
missing=
for path in prompt/bb.sh prompt/bb-theme.sh install-pending q removebb.sh; do
  tar -tzf "$DIST/bb.tgz" | grep -qx "./$path" || missing="$missing $path"
done
if [ -n "$missing" ]; then
  printf 'bb.tgz does not hold:%s\n' "$missing" >&2
  exit 1
fi

ls -l "$DIST"
