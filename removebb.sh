#!/usr/bin/env bash
#
# BetterBash uninstaller.
#
# Removes the ~/.bb directory (prompt, theme library, decoded theme and the
# random theme code) and the two blocks BetterBash added to ~/.bashrc and
# ~/.inputrc. Like getbb.sh this is POSIX shell.
#
#   curl -sL https://betterbash.cz0.cz/removebb.sh | bash -s curl
#
# Options:
#
#   --dir DIR    remove the prompt files of DIR instead of ~/.bb
#   --no-inputrc leave the readline block of ~/.inputrc alone
#
# The shell has to be restarted (or ~/.bashrc re-read) for the change to show.

set -u

BB_DIR="${BB_DIR:-$HOME/.bb}"
BB_INPUTRC=1

while [ $# -gt 0 ]; do
  case $1 in
    --dir) BB_DIR=${2:-}; shift ;;
    --no-inputrc) BB_INPUTRC=0 ;;
    -h | --help)
      awk 'NR <= 2 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
      exit 0
      ;;
    # The download method of the install commands is accepted and ignored, so
    # `bash -s curl` works here exactly as it does for getbb.sh.
    curl | wget | openssl) ;;
    *)
      printf 'removebb: unexpected argument: %s (see --help)\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

BB_FAILURE=0

# The block in ~/.bashrc is the three lines starting at its "# BetterBash"
# comment; the readline block in ~/.inputrc is the five lines of this repository.
if [ -f "$HOME/.bashrc" ] && grep -q "BetterBash" "$HOME/.bashrc" 2>/dev/null; then
  sed -i '/BetterBash/,+2d' "$HOME/.bashrc" || BB_FAILURE=1
fi

if [ "$BB_INPUTRC" = "1" ] && [ -f "$HOME/.inputrc" ] && grep -q "BetterBash" "$HOME/.inputrc" 2>/dev/null; then
  sed -i '/BetterBash/,+4d' "$HOME/.inputrc" || BB_FAILURE=1
fi

if [ -d "$BB_DIR" ]; then
  rm -r "$BB_DIR" || BB_FAILURE=1
fi

if [ "$BB_FAILURE" = "1" ]; then
  printf 'BetterBash: uninstallation did not finish, see the messages above\n' >&2
  exit 1
fi

echo "BetterBash uninstallation completed. Restart your bash session to see the effect."
