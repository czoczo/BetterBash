#!/bin/sh
#
# BetterBash installer, run from a tree you fetched yourself.
#
# Nothing is downloaded here. The prompt files are copied out of a BetterBash
# tree that an ordinary command of your own fetched (git clone, or the tarball of
# a release through curl, wget or openssl), so every file that reaches ~/.bb can
# be read next to this script before it is run.
#
# Usage, exactly as the WebUI shows it:
#
#   curl -sL https://betterbash.cz0.cz/bb.tgz | tar -C /tmp -xz \
#     && read -p"install BetterBash from /tmp/bb? [y/N] " -n1 && [[ $REPLY == [Yy] ]] \
#     && sh /tmp/bb/installbb.sh vN-y_5uA && . ~/.bashrc
#
#   git clone -q --depth 1 --branch 0.1.3 https://github.com/czoczo/BetterBash /tmp/bb \
#     && read -p"install BetterBash from /tmp/bb? [y/N] " -n1 && [[ $REPLY == [Yy] ]] \
#     && sh /tmp/bb/installbb.sh vN-y_5uA && . ~/.bashrc
#
# Options, in any order:
#
#   <code>            theme code from the WebUI, or the word "rand" for a theme
#                     drawn on this machine and remembered in ~/.bb/theme-code
#   --repo DIR        the fetched tree to copy from (default: the directory this
#                     script is in, which is what the commands above give)
#   --dir DIR         install the prompt files into DIR (default ~/.bb)
#   --reroll          draw a new random theme instead of keeping the stored one
#   --yes             accepted and ignored: the question of the command line is
#                     asked there, so automation keeps one shape for both
#   --no-inputrc      leave ~/.inputrc alone
#   -h, --help        this text
#
# Nothing here needs bash: the script is POSIX shell, and is tested under dash
# too, so `sh /tmp/bb/installbb.sh <code>` works. The question asked before it is
# run is a bash line, because that is the shell it gets pasted into.

set -u

BB_DIR="${BB_DIR:-$HOME/.bb}"
BB_REPO="${BB_REPO:-}"
BB_CODE="${BB_THEME:-}"
BB_INPUTRC=1

# The payload of a release: source path in the fetched tree, a colon, and the
# name it gets in ~/.bb. The layout in ~/.bb stays as flat as it has ever been,
# so the hook of every released BetterBash keeps working.
BB_PAYLOAD='prompt/bb-theme.sh:bb-theme.sh
prompt/bb.sh:bb.sh
prompt/git-prompt.sh:git-prompt.sh
removebb.sh:removebb.sh
VERSION_APP.txt:version'

# Names ~/.bb used to hold and this release no longer writes. They are removed on
# install, so an upgrade cannot leave a stale file that nothing reads.
BB_RETIRED='inputrc'

# What proves a tree is what it claims to be. A directory under /tmp is offered
# by the world, so the copy step waits for the files to be the BetterBash files
# of a release before a single byte is written into the home directory.
require_marker() {
  if ! grep -q "$2" "$BB_REPO/$1"; then
    printf 'installbb: %s is not the BetterBash file it should be (no %s in it)\n' \
      "$BB_REPO/$1" "$2" >&2
    return 1
  fi
}

printHelp() {
  # The usage block is the comment above, so help stays in one place.
  awk 'NR <= 2 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
  exit 0
}

# A theme code is eight characters of the theme code alphabet, or the word that
# stands for "draw one here". Anything else in the argument list is a mistake and
# has to be refused before anything is written.
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
    --repo) BB_REPO=${2:-}; shift ;;
    --dir) BB_DIR=${2:-}; shift ;;
    --code) BB_CODE=${2:-}; shift ;;
    --reroll) BB_THEME_REROLL=1 ;;
    --yes | -y) ;;
    --no-inputrc) BB_INPUTRC=0 ;;
    -h | --help) printHelp ;;
    *)
      if [ -n "$BB_CODE" ]; then
        printf 'installbb: unexpected argument: %s (see --help)\n' "$1" >&2
        exit 2
      fi
      if ! is_theme_code "$1"; then
        printf 'installbb: %s is not a theme code (eight characters of A-Za-z0-9_-, or "rand"; see --help)\n' "$1" >&2
        exit 2
      fi
      BB_CODE=$1
      ;;
  esac
  shift
done

if [ ! -d "$HOME" ]; then
  printf 'installbb: no home directory to install into\n' >&2
  exit 2
fi

# --- the tree to copy from ---------------------------------------------------

# The directory this script was run from is the fetched tree: `sh /tmp/bb/installbb.sh`
# from any working directory points at /tmp/bb, which is what the commands of the
# WebUI extract to. --repo overrides it (the tests use that).
if [ -z "$BB_REPO" ]; then
  case $0 in
    */*) BB_REPO=$(cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) ;;
    *) BB_REPO=$(pwd -P) ;;
  esac
fi

# uid_of PATH and mode_of PATH: GNU and BSD stat, and "" when neither answers. An
# empty answer means "this system cannot tell", which is reported and never
# treated as a refusal.
uid_of() { stat -c %u "$1" 2>/dev/null || stat -f %u "$1" 2>/dev/null || printf ''; }
mode_of() { stat -c %A "$1" 2>/dev/null || stat -f %Sp "$1" 2>/dev/null || printf ''; }

# The world can write into /tmp, so a tree found there has to belong to the user
# running the installation and must not be writable by anybody else. Both the
# directory and every file that is about to be copied.
is_own_tree() {
  _want=$(id -u)
  _uncheckable=0

  # The directory of the tree first, then every file that is about to be copied.
  _got=$(uid_of "$BB_REPO")
  if [ -z "$_got" ]; then
    _uncheckable=1
  elif [ "$_got" != "$_want" ]; then
    printf 'installbb: %s belongs to uid %s, not to you (%s)\n' "$BB_REPO" "$_got" "$_want" >&2
    printf 'installbb: refusing to install files you did not fetch (mktemp -d avoids a shared /tmp name)\n' >&2
    return 1
  fi

  for _pair in $BB_PAYLOAD; do
    _path=$BB_REPO/${_pair%%:*}
    _got=$(uid_of "$_path")
    if [ -z "$_got" ]; then
      _uncheckable=1
      continue
    fi
    if [ "$_got" != "$_want" ]; then
      printf 'installbb: %s belongs to uid %s, not to you (%s)\n' "$_path" "$_got" "$_want" >&2
      return 1
    fi
  done

  _mode=$(mode_of "$BB_REPO")
  if [ -n "$_mode" ]; then
    # The last three characters of -rw-r--r-- are the bits of everyone else.
    case $(printf '%s' "$_mode" | cut -c 8-10) in
      *w*)
        printf 'installbb: %s is writable by other users (%s)\n' "$BB_REPO" "$_mode" >&2
        printf 'installbb: refusing to install files anyone could have changed (mktemp -d avoids a shared /tmp name)\n' >&2
        return 1
        ;;
    esac
  fi

  for _pair in $BB_PAYLOAD; do
    _path=$BB_REPO/${_pair%%:*}
    _mode=$(mode_of "$_path")
    [ -n "$_mode" ] || continue
    case $(printf '%s' "$_mode" | cut -c 8-10) in
      *w*)
        printf 'installbb: %s is writable by other users (%s)\n' "$_path" "$_mode" >&2
        return 1
        ;;
    esac
  done

  [ "$_uncheckable" = 1 ] &&
    printf 'installbb: warning: stat did not say who owns the tree, ownership was not checked\n' >&2
  return 0
}

# verify_tree: every payload file has to be there, non empty, and carry the
# marker only the real file carries. A tarball that came back as an error page,
# or a half extracted tree, fails here rather than half installing a prompt.
verify_tree() {
  if [ ! -d "$BB_REPO" ]; then
    printf 'installbb: no BetterBash tree at %s (see --help)\n' "$BB_REPO" >&2
    return 1
  fi

  for _pair in $BB_PAYLOAD; do
    _src=${_pair%%:*}
    if [ ! -f "$BB_REPO/$_src" ]; then
      printf 'installbb: %s is missing from %s, so this is not a complete BetterBash tree\n' "$_src" "$BB_REPO" >&2
      return 1
    fi
    if [ ! -s "$BB_REPO/$_src" ]; then
      printf 'installbb: %s of %s is empty\n' "$_src" "$BB_REPO" >&2
      return 1
    fi
  done

  require_marker "prompt/bb-theme.sh" "^bb_theme_decode" || return 1
  require_marker "prompt/bb.sh" "__prompt_command" || return 1
  require_marker "prompt/git-prompt.sh" "__git_ps1" || return 1
  require_marker "removebb.sh" "BetterBash uninstallation completed" || return 1

  is_own_tree
}

if ! verify_tree; then
  exit 1
fi

# --- copy --------------------------------------------------------------------

# The decoder travels with the prompt, and it is sourced from the fetched tree
# rather than from ~/.bb, so the theme of this run does not depend on the copy
# having happened yet.
# shellcheck source=/dev/null
. "$BB_REPO/prompt/bb-theme.sh"

mkdir -p "$BB_DIR" || {
  printf 'installbb: cannot create %s\n' "$BB_DIR" >&2
  exit 1
}

BB_VERSION=$(sed -n '1p' "$BB_REPO/VERSION_APP.txt" 2>/dev/null)
[ -n "$BB_VERSION" ] || BB_VERSION=unknown

for _pair in $BB_PAYLOAD; do
  _src=${_pair%%:*}
  _dst=${_pair#*:}
  # Copied aside and moved, so a file that cannot be read leaves the previous
  # installation untouched instead of an empty one.
  if ! cp "$BB_REPO/$_src" "$BB_DIR/$_dst.part" 2>/dev/null; then
    printf 'installbb: could not read %s\n' "$BB_REPO/$_src" >&2
    rm -f "$BB_DIR/$_dst.part"
    exit 1
  fi
  if ! mv -f "$BB_DIR/$_dst.part" "$BB_DIR/$_dst"; then
    printf 'installbb: could not write %s\n' "$BB_DIR/$_dst" >&2
    rm -f "$BB_DIR/$_dst.part"
    exit 1
  fi
done

for _retired in $BB_RETIRED; do
  rm -f "$BB_DIR/$_retired"
done

# --- the theme ---------------------------------------------------------------

# The code from the command line, or the one this machine already has, or a
# freshly drawn random one. A random theme is kept across reinstalls, --reroll
# (BB_THEME_REROLL=1) asks for a new one.
BB_THEME_REROLL=${BB_THEME_REROLL:-0}
export BB_THEME_REROLL
[ -n "$BB_CODE" ] || BB_CODE=$BB_THEME_RANDOM

if ! BB_RESOLVED=$(bb_theme_resolve "$BB_CODE" "$BB_DIR/theme-code"); then
  printf 'installbb: could not resolve the theme %s\n' "$BB_CODE" >&2
  exit 1
fi

if ! bb_theme_write "$BB_RESOLVED" "$BB_DIR"; then
  printf 'installbb: could not write the theme to %s\n' "$BB_DIR" >&2
  exit 1
fi

# Readline bindings are a convenience; the prompt works without them. The block
# comes from .inputrc of the fetched tree and is appended once. Failing here is
# not fatal, but it is reported, because the arrow keys are what people notice.
BB_INPUTRC_ACTION=skipped
if [ "$BB_INPUTRC" = "1" ]; then
  if grep -q "BetterBash" "$HOME/.inputrc" 2>/dev/null; then
    BB_INPUTRC_ACTION=kept
  elif [ ! -f "$BB_REPO/.inputrc" ]; then
    BB_INPUTRC_ACTION=missing
  elif cat "$BB_REPO/.inputrc" >>"$HOME/.inputrc"; then
    BB_INPUTRC_ACTION=added
  else
    BB_INPUTRC_ACTION=failed
  fi
fi
case $BB_INPUTRC_ACTION in
  added) BB_INPUTRC_NOTE="history search added to ~/.inputrc" ;;
  kept) BB_INPUTRC_NOTE="history search already in ~/.inputrc" ;;
  missing) BB_INPUTRC_NOTE="NOT installed, no .inputrc in $BB_REPO" ;;
  failed) BB_INPUTRC_NOTE="NOT installed, ~/.inputrc could not be written" ;;
  skipped) BB_INPUTRC_NOTE="not requested (--no-inputrc)" ;;
esac

# The hook in ~/.bashrc is the block every release of BetterBash writes, so the
# removebb.sh of any release finds it again - and so does the one that ships in
# ~/.bb of this one.
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
    printf 'installbb: could not write to %s/.bashrc\n' "$HOME" >&2
  fi
fi

if [ "$BB_CODE" = "$BB_THEME_RANDOM" ]; then
  BB_THEME_NOTE="drawn here, remembered in $BB_DIR/theme-code"
else
  BB_THEME_NOTE="from the WebUI"
fi

cat <<EOF

BetterBash $BB_VERSION ${BB_BASHRC_ACTION} in ~/.bashrc
  from     $BB_REPO
  theme    $BB_RESOLVED ($BB_THEME_NOTE)
  colors   $BB_DIR/theme.sh
  prompt   $BB_DIR/bb.sh
  readline $BB_INPUTRC_NOTE
  remove   sh $BB_DIR/removebb.sh

Reload the shell, or run: . ~/.bashrc
EOF
