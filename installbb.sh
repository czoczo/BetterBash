#!/bin/sh
#
# BetterBash installer, run from a tree you fetched yourself.
#
# Nothing is downloaded here. The prompt files are copied out of a tree an ordinary
# command of your own fetched (git clone, or the tarball of a release through curl,
# wget or openssl) into ~/.bb, so every file can be read before it is run.
#
# Usage, exactly as the WebUI shows it:
#
#   mkdir -p ~/.bb && curl -sL https://betterbash.cz0.cz/bb.tgz | tar -C ~/.bb -xz \
#     && read -p"$(<~/.bb/q)" -n1 && [[ $REPLY == [Yy] ]] \
#     && . ~/.bb/prompt/bb.sh vN-y_5uA
#
#   git clone -q --depth 1 --branch 0.1.3 https://github.com/czoczo/BetterBash ~/.bb \
#     && read -p"$(<~/.bb/q)" -n1 && [[ $REPLY == [Yy] ]] \
#     && . ~/.bb/prompt/bb.sh vN-y_5uA
#
# The question is not written into the command: it is read from q of the fetched tree,
# so its words - and nothing else - decide what answering y agrees to.
#
# The tree is fetched into ~/.bb and installed into that same directory: the files of
# the tree and the files copied out of it live next to each other, and only the names
# of the latter are what a shell sources.
#
# The command ends by sourcing prompt/bb.sh of the tree, which runs this script: a
# fetched tree carries install-pending, and its first sourcing installs and takes the
# flag away (see prompt/bb.sh). Run directly, this script installs without sourcing:
# prompt/bb.sh is bash, and a script, a container or a non-bash shell has no prompt to
# source:
#
#   sh ~/.bb/installbb.sh vN-y_5uA
#
# Options, in any order:
#
#   <code>            theme code from the WebUI: eight characters of colour, or
#                     thirteen of a theme that also spells out which elements of
#                     the first line of the prompt stand
#   "rand"            a theme drawn on this machine - a new one on every run,
#                     never the one ~/.bb/theme-code already holds; only colours
#                     are drawn, which elements stand is never drawn
#   "rand:<code>"     the same draw, wearing the elements <code> spells out
#                     instead of the ones this machine already wore - which is
#                     what the WebUI writes while its Random box is ticked, so
#                     the boxes ticked on the page are never lost to the draw
#   "keep"            the theme this machine has, which is also what a command
#                     without a code means
#   --repo DIR        the fetched tree to copy from (default: the directory this
#                     script is in, which is what the commands above give)
#   --dir DIR         install the prompt files into DIR (default ~/.bb)
#   --reroll          accepted for compatibility: it means the same as the word
#                     "rand", which draws a new theme all by itself now
#   --no-inputrc      leave ~/.inputrc alone
#   -h, --help        this text
#
# POSIX shell, tested under dash. The question asked before it is run is a bash line,
# because that is the shell it gets pasted into.

BB_DIR="${BB_DIR:-$HOME/.bb}"
BB_REPO="${BB_REPO:-}"
BB_INPUTRC=1

# The payload of a release: source path in the tree, a colon, the name it gets in
# ~/.bb. The layout stays as flat as it has ever been, so the hook of every released
# BetterBash keeps working.
BB_PAYLOAD='prompt/bb-theme.sh:bb-theme.sh
prompt/bb.sh:bb.sh
prompt/git-prompt.sh:git-prompt.sh
removebb.sh:removebb.sh
VERSION_APP.txt:version'

# Names ~/.bb used to hold and this release no longer writes, removed on install so an
# upgrade leaves no stale file nothing reads.
BB_RETIRED='inputrc'

# The flag that a tree has not been installed yet; removed here.
BB_PENDING='install-pending'

# bb_require_marker PATH MARKER
bb_require_marker() {
  if ! grep -q "$2" "$1"; then
    printf 'installbb: %s is not the BetterBash file it should be (no %s in it)\n' \
      "$1" "$2" >&2
    return 1
  fi
}

bb_print_help() {
  # The usage block is the comment above, so help stays in one place. Asking for help
  # is remembered rather than exited from: sourced, this file must never end the shell.
  awk 'NR <= 2 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
  BB_HELP=1
  return 0
}

# A theme code: eight characters of the theme code alphabet (v0), thirteen (the same
# code with the elements of the top line), "rand", "keep", or "rand:<code>". Anything
# else in the arguments is refused before anything is written.
bb_is_theme_code() {
  # The words are spelled out: this runs before bb-theme.sh is sourced.
  case $1 in
    rand | keep) return 0 ;;
    # Behind the word, the code whose elements the draw wears; only its shape is
    # checked here.
    rand:*)
      bb_is_theme_code "${1#rand:}"
      return $?
      ;;
    ????????)
      case $1 in
        *[!A-Za-z0-9_-]*) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    1????????????)
      case $1 in
        *[!A-Za-z0-9_-]*) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

# bb_parse_options, after bb_install has taken the tree out of the arguments.
bb_parse_options() {
  BB_HELP=0
  BB_CODE=${BB_THEME:-}
  BB_INPUTRC=1

  while [ $# -gt 0 ]; do
    case $1 in
      --repo) BB_REPO=${2:-}; shift ;;
      --dir) BB_DIR=${2:-}; shift ;;
      --code) BB_CODE=${2:-}; shift ;;
      --reroll) BB_THEME_REROLL=1 ;;
      --no-inputrc) BB_INPUTRC=0 ;;
      -h | --help) bb_print_help ;;
      *)
        if [ -n "$BB_CODE" ]; then
          printf 'installbb: unexpected argument: %s (see --help)\n' "$1" >&2
          return 2
        fi
        if ! bb_is_theme_code "$1"; then
          printf 'installbb: %s is not a theme code (eight characters of A-Za-z0-9_-, thirteen of them for a theme with its elements spelled out, "rand", "rand:<code>" or "keep"; see --help)\n' "$1" >&2
          return 2
        fi
        BB_CODE=$1
        ;;
    esac
    shift
  done
  return 0
}

# uid_of PATH and mode_of PATH: GNU and BSD stat, "" when neither answers - which is
# reported and never treated as a refusal.
bb_uid_of() { stat -c %u "$1" 2>/dev/null || stat -f %u "$1" 2>/dev/null || printf ''; }
bb_mode_of() { stat -c %A "$1" 2>/dev/null || stat -f %Sp "$1" 2>/dev/null || printf ''; }

# bb_is_own_tree: the tree - its directory and every file to be copied - must belong to
# the user installing and must not be writable by anybody else. A tree is not installed
# just because it has the right name.
bb_is_own_tree() {
  _want=$(id -u)
  _uncheckable=0

  # The directory of the tree first, then every file that is about to be copied.
  _got=$(bb_uid_of "$BB_REPO")
  if [ -z "$_got" ]; then
    _uncheckable=1
  elif [ "$_got" != "$_want" ]; then
    printf 'installbb: %s belongs to uid %s, not to you (%s)\n' "$BB_REPO" "$_got" "$_want" >&2
    printf 'installbb: refusing to install files you did not fetch\n' >&2
    return 1
  fi

  for _pair in $BB_PAYLOAD; do
    _path=$BB_REPO/${_pair%%:*}
    _got=$(bb_uid_of "$_path")
    if [ -z "$_got" ]; then
      _uncheckable=1
      continue
    fi
    if [ "$_got" != "$_want" ]; then
      printf 'installbb: %s belongs to uid %s, not to you (%s)\n' "$_path" "$_got" "$_want" >&2
      return 1
    fi
  done

  _mode=$(bb_mode_of "$BB_REPO")
  if [ -n "$_mode" ]; then
    # The last three characters of -rw-r--r-- are the bits of everyone else.
    case $(printf '%s' "$_mode" | cut -c 8-10) in
      *w*)
        printf 'installbb: %s is writable by other users (%s)\n' "$BB_REPO" "$_mode" >&2
        printf 'installbb: refusing to install files anyone could have changed\n' >&2
        return 1
        ;;
    esac
  fi

  for _pair in $BB_PAYLOAD; do
    _path=$BB_REPO/${_pair%%:*}
    _mode=$(bb_mode_of "$_path")
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

# bb_verify_tree: every payload file must be there, non empty and carrying the marker
# only the real file has. A tarball that came back as an error page, or a half
# extracted tree, fails here rather than half installing a prompt.
bb_verify_tree() {
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

  bb_require_marker "$BB_REPO/prompt/bb-theme.sh" "^bb_theme_decode" || return 1
  bb_require_marker "$BB_REPO/prompt/bb.sh" "__prompt_command" || return 1
  bb_require_marker "$BB_REPO/prompt/git-prompt.sh" "__git_ps1" || return 1
  bb_require_marker "$BB_REPO/removebb.sh" "BetterBash uninstallation completed" || return 1

  bb_is_own_tree
}

# bb_copy_payload: the tree into ~/.bb, one file at a time, each copied aside and moved
# into place, so a source that cannot be read leaves the previous installation intact
# instead of an empty file.
bb_copy_payload() {
  mkdir -p "$BB_DIR" || {
    printf 'installbb: cannot create %s\n' "$BB_DIR" >&2
    return 1
  }

  for _pair in $BB_PAYLOAD; do
    _src=${_pair%%:*}
    _dst=${_pair#*:}

    if ! cp "$BB_REPO/$_src" "$BB_DIR/$_dst.part" 2>/dev/null; then
      printf 'installbb: could not read %s\n' "$BB_REPO/$_src" >&2
      rm -f "$BB_DIR/$_dst.part"
      return 1
    fi
    if ! mv -f "$BB_DIR/$_dst.part" "$BB_DIR/$_dst"; then
      printf 'installbb: could not write %s\n' "$BB_DIR/$_dst" >&2
      rm -f "$BB_DIR/$_dst.part"
      return 1
    fi
  done

  for _retired in $BB_RETIRED; do
    rm -f "$BB_DIR/$_retired"
  done
  return 0
}

# bb_install_theme: the decoder is sourced from the fetched tree rather than from
# ~/.bb, so this run does not depend on the copy having happened.
bb_install_theme() {
  # shellcheck source=/dev/null
  . "$BB_REPO/prompt/bb-theme.sh" || {
    printf 'installbb: could not read the theme library of %s\n' "$BB_REPO" >&2
    return 1
  }

  # What the machine already wears, so the summary can say whether this run kept it or
  # replaced it. Read quietly - bb_theme_resolve reads the same file and is the one
  # that reports an unusable code - and only once the file exists, because a shell
  # reports a failed redirection on its own stderr.
  BB_PREV_CODE=''
  if [ -f "$BB_DIR/theme-code" ]; then
    BB_PREV_CODE=$(tr -d '\n\r' <"$BB_DIR/theme-code" 2>/dev/null)
  fi

  # No code keeps the theme of this machine; "rand" asks for a new draw, and so does
  # the --reroll (BB_THEME_REROLL=1) of older releases.
  BB_THEME_REROLL=${BB_THEME_REROLL:-0}
  export BB_THEME_REROLL
  [ -n "$BB_CODE" ] || BB_CODE=$BB_THEME_KEEP
  if [ "$BB_CODE" = "$BB_THEME_KEEP" ] && [ "$BB_THEME_REROLL" = 1 ]; then
    BB_CODE=$BB_THEME_RANDOM
  fi

  if ! BB_RESOLVED=$(bb_theme_resolve "$BB_CODE" "$BB_DIR/theme-code"); then
    printf 'installbb: could not resolve the theme %s\n' "$BB_CODE" >&2
    return 1
  fi

  bb_theme_write "$BB_RESOLVED" "$BB_DIR" || {
    printf 'installbb: could not write the theme to %s\n' "$BB_DIR" >&2
    return 1
  }
  return 0
}

# bb_install_inputrc: readline bindings are a convenience; the prompt works without
# them. The block comes from .inputrc of the tree and is appended once. Failure is not
# fatal, but it is reported.
bb_install_inputrc() {
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
}

# bb_install_bashrc: the hook is the block every release writes, so the removebb.sh of
# any release finds it again.
bb_install_bashrc() {
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
}

bb_theme_note() {
  case $BB_CODE in
    "$BB_THEME_RANDOM")
      printf 'drawn here, as a new theme on every run'
      ;;
    "$BB_THEME_RANDOM$BB_THEME_RANDOM_SEP"*)
      printf 'drawn here, as a new theme on every run, over the elements of %s' "${BB_CODE#*"$BB_THEME_RANDOM_SEP"}"
      ;;
    "$BB_THEME_KEEP")
      if [ -n "$BB_PREV_CODE" ] && [ "$BB_RESOLVED" = "$BB_PREV_CODE" ]; then
        printf 'kept from %s/theme-code' "$BB_DIR"
      else
        printf 'drawn here, the first theme of this machine'
      fi
      ;;
    *) printf 'from the WebUI' ;;
  esac
}

# bb_reload_note: installed by its own prompt/bb.sh - how every command of the page
# ends - the shell is building the prompt as this prints, so nothing is left to reload.
# Run directly, the shell the script runs in does have to.
bb_reload_note() {
  if [ "${BB_SOURCED_BY_PROMPT:-0}" = 1 ]; then
    printf 'this shell wears it now; other sessions pick it up as they start'
  else
    printf 'reload the shell, or run: . ~/.bashrc'
  fi
}

# bb_install TREE [option ...]
# Installs the tree TREE into ~/.bb, returning non zero without writing anything when
# the tree is not what a BetterBash tree should be. Sourcing this file only defines
# these functions; run directly, bb_install is called below.
bb_install() {
  BB_REPO=${1:-}
  shift 2>/dev/null || true

  if ! bb_parse_options "$@"; then
    return 2
  fi
  if [ "$BB_HELP" = 1 ]; then
    return 0
  fi

  if [ ! -d "$HOME" ]; then
    printf 'installbb: no home directory to install into\n' >&2
    return 2
  fi

  if ! bb_verify_tree; then
    return 1
  fi

  bb_copy_payload || return 1
  bb_install_theme || return 1
  bb_install_inputrc
  bb_install_bashrc

  BB_VERSION=$(sed -n '1p' "$BB_REPO/VERSION_APP.txt" 2>/dev/null)
  [ -n "$BB_VERSION" ] || BB_VERSION=unknown

  # Installed, so no longer pending: the flag goes, and with it the promise that
  # sourcing prompt/bb.sh in that tree installs anything. The tree itself stays.
  rm -f "$BB_REPO/$BB_PENDING"

  cat <<EOF

BetterBash $BB_VERSION ${BB_BASHRC_ACTION} in ~/.bashrc
  from     $BB_REPO
  theme    $BB_RESOLVED ($(bb_theme_note))
  colors   $BB_DIR/theme.sh
  prompt   $BB_DIR/bb.sh
  readline $BB_INPUTRC_NOTE
  remove   sh $BB_DIR/removebb.sh

$(bb_reload_note)
EOF
  return 0
}

# Run directly rather than sourced - the same test bb-theme.sh uses - so that
# `. installbb.sh` defines functions and changes nothing else.
if [ "${0##*/}" = "installbb.sh" ]; then
  set -u
  # The directory this script was run from is the fetched tree, so `sh ~/.bb/installbb.sh`
  # works from any working directory. --repo overrides it (the tests use that).
  if [ -z "$BB_REPO" ]; then
    case $0 in
      */*) BB_REPO=$(cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) ;;
      *) BB_REPO=$(pwd -P) ;;
    esac
  fi
  bb_install "$BB_REPO" "$@"
  exit $?
fi
