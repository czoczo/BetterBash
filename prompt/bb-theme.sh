#!/bin/sh
# BetterBash theme codes, POSIX shell.
#
# A theme code is eight characters of the url safe Base64 alphabet carrying 48
# bits: eight five bit colour components (base colour 30-37, bright bit, bold
# bit) and one bit for the host avatar. The WebUI encodes the code, this library
# turns it back into the assignments prompt/bb.sh works with.
#
# The output of bb_theme_decode is byte for byte what the retired Go backend
# injected into prompt/bb.sh, and tests/golden/ pins it (tests/test-theme.sh).
#
# Everything is plain POSIX shell: no bashisms, no external tools for decoding,
# /dev/urandom plus tr and head for random codes only. It is sourced by getbb.sh
# and by prompt/bb.sh, and can be run directly for experiments:
#
#   sh prompt/bb-theme.sh decode vN-y_5uA
#   sh prompt/bb-theme.sh random
#   sh prompt/bb-theme.sh write vN-y_5uA ~/.bb
#
# Every name starting with _bbt_ is internal and clobbered by these functions.

# The theme components in the order their bits appear in a code.
BB_THEME_KEYS='PRIMARY_COLOR SECONDARY_COLOR ROOT_COLOR TIME_COLOR ERR_COLOR SEPARATOR_COLOR BORDCOL PATH_COLOR'

# The word the WebUI puts in an install command instead of a code, meaning
# "pick a theme on this machine and keep it".
BB_THEME_RANDOM='rand'

# Characters a theme code may consist of, and its length.
BB_THEME_ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'
BB_THEME_CODE_LENGTH=8

# bb_theme_validate CODE
# Succeeds when CODE is exactly BB_THEME_CODE_LENGTH characters of the theme
# code alphabet. Anything else is refused, because a code is the only part of
# the command line this library ever looks at.
bb_theme_validate() {
  _bbtv_code=$1

  if [ "${#_bbtv_code}" -ne "$BB_THEME_CODE_LENGTH" ]; then
    printf 'bb-theme: theme code must be %d characters long, got %d (%s)\n' \
      "$BB_THEME_CODE_LENGTH" "${#_bbtv_code}" "$_bbtv_code" >&2
    return 1
  fi

  # POSIX pattern negation: any character outside the alphabet fails the match.
  case $_bbtv_code in
    *[!A-Za-z0-9_-]*)
      printf 'bb-theme: theme code %s contains characters outside the theme code alphabet\n' "$_bbtv_code" >&2
      return 1
      ;;
  esac

  return 0
}

# bb_theme_decode CODE
# Prints the nine assignments of the theme (eight colours and AVATAR) as
#   KEY='\033[...]'
# lines, ready to be sourced. The 48 bits of the code are held in two 24 bit
# halves so that no shell arithmetic ever needs more than 24 bits, which keeps
# this working on shells whose arithmetic is 32 bit.
bb_theme_decode() {
  _bbtd_code=$1

  bb_theme_validate "$_bbtd_code" || return 1

  _bbtd_hi=0 _bbtd_lo=0 _bbtd_pos=0 _bbtd_rest=$_bbtd_code
  while [ -n "$_bbtd_rest" ]; do
    # Leading character of the remainder, mapped to its index in the alphabet.
    # A table rather than substring arithmetic, because ${var:0:1} and base#
    # notation are not POSIX.
    case $_bbtd_rest in
      A*) _bbtd_v=0;;  B*) _bbtd_v=1;;  C*) _bbtd_v=2;;  D*) _bbtd_v=3;;
      E*) _bbtd_v=4;;  F*) _bbtd_v=5;;  G*) _bbtd_v=6;;  H*) _bbtd_v=7;;
      I*) _bbtd_v=8;;  J*) _bbtd_v=9;;  K*) _bbtd_v=10;; L*) _bbtd_v=11;;
      M*) _bbtd_v=12;; N*) _bbtd_v=13;; O*) _bbtd_v=14;; P*) _bbtd_v=15;;
      Q*) _bbtd_v=16;; R*) _bbtd_v=17;; S*) _bbtd_v=18;; T*) _bbtd_v=19;;
      U*) _bbtd_v=20;; V*) _bbtd_v=21;; W*) _bbtd_v=22;; X*) _bbtd_v=23;;
      Y*) _bbtd_v=24;; Z*) _bbtd_v=25;; a*) _bbtd_v=26;; b*) _bbtd_v=27;;
      c*) _bbtd_v=28;; d*) _bbtd_v=29;; e*) _bbtd_v=30;; f*) _bbtd_v=31;;
      g*) _bbtd_v=32;; h*) _bbtd_v=33;; i*) _bbtd_v=34;; j*) _bbtd_v=35;;
      k*) _bbtd_v=36;; l*) _bbtd_v=37;; m*) _bbtd_v=38;; n*) _bbtd_v=39;;
      o*) _bbtd_v=40;; p*) _bbtd_v=41;; q*) _bbtd_v=42;; r*) _bbtd_v=43;;
      s*) _bbtd_v=44;; t*) _bbtd_v=45;; u*) _bbtd_v=46;; v*) _bbtd_v=47;;
      w*) _bbtd_v=48;; x*) _bbtd_v=49;; y*) _bbtd_v=50;; z*) _bbtd_v=51;;
      0*) _bbtd_v=52;; 1*) _bbtd_v=53;; 2*) _bbtd_v=54;; 3*) _bbtd_v=55;;
      4*) _bbtd_v=56;; 5*) _bbtd_v=57;; 6*) _bbtd_v=58;; 7*) _bbtd_v=59;;
      8*) _bbtd_v=60;; 9*) _bbtd_v=61;; -*) _bbtd_v=62;; _*) _bbtd_v=63;;
      *)
        printf 'bb-theme: cannot decode theme code %s\n' "$_bbtd_code" >&2
        return 1
        ;;
    esac
    _bbtd_rest=${_bbtd_rest#?}
    if [ "$_bbtd_pos" -lt 4 ]; then
      _bbtd_hi=$(( _bbtd_hi * 64 + _bbtd_v ))
    else
      _bbtd_lo=$(( _bbtd_lo * 64 + _bbtd_v ))
    fi
    _bbtd_pos=$(( _bbtd_pos + 1 ))
  done

  # Field i of nine occupies bits (43 - 5*i) down to (48 - 5*i - 1) of the
  # 48 bit value, so field five is the one that straddles the two halves.
  _bbtd_n=0
  for _bbtd_key in $BB_THEME_KEYS; do
    case $_bbtd_n in
      0) _bbtd_f=$(( (_bbtd_hi >> 19) & 31 )) ;;
      1) _bbtd_f=$(( (_bbtd_hi >> 14) & 31 )) ;;
      2) _bbtd_f=$(( (_bbtd_hi >> 9) & 31 )) ;;
      3) _bbtd_f=$(( (_bbtd_hi >> 4) & 31 )) ;;
      4) _bbtd_f=$(( (_bbtd_hi & 15) * 2 + ((_bbtd_lo >> 23) & 1) )) ;;
      5) _bbtd_f=$(( (_bbtd_lo >> 18) & 31 )) ;;
      6) _bbtd_f=$(( (_bbtd_lo >> 13) & 31 )) ;;
      7) _bbtd_f=$(( (_bbtd_lo >> 8) & 31 )) ;;
    esac

    # Component bits: base colour 0-7, bright, bold.
    _bbtd_number=$(( (_bbtd_f >> 2 & 7) + 30 ))
    [ $(( (_bbtd_f >> 1) & 1 )) -eq 1 ] && _bbtd_number=$(( _bbtd_number + 60 ))
    printf '%s=%s\n' "$_bbtd_key" "'\[\033[$(( _bbtd_f & 1 ));${_bbtd_number}m\]'"
    _bbtd_n=$(( _bbtd_n + 1 ))
  done

  # The avatar flag is the top bit of the last byte, which is bit seven.
  if [ $(( (_bbtd_lo >> 7) & 1 )) -eq 1 ]; then
    printf 'AVATAR=%s\n' "'true'"
  else
    printf 'AVATAR=%s\n' "'false'"
  fi
}

# bb_theme_is_black LINE
# Reports whether one decoded assignment is plain black, which would be
# invisible on a dark terminal. Random codes are redrawn until none is black.
bb_theme_is_black() {
  case $1 in
    *';30m'*) return 0 ;;
    *) return 1 ;;
  esac
}

# bb_random_theme_code
# Prints a uniformly random theme code with no plain black component. Codes are
# drawn straight from /dev/urandom filtered to the theme code alphabet, so every
# one of the 64^8 codes is equally likely. $BB_THEME_RANDOM_FALLBACK (bash only)
# is used where /dev/urandom is unreadable.
bb_random_theme_code() {
  _bbrc_tries=0

  while :; do
    _bbrc_tries=$(( _bbrc_tries + 1 ))
    if [ "$_bbrc_tries" -gt 64 ]; then
      printf 'bb-theme: gave up drawing a readable theme code after 64 tries\n' >&2
      return 1
    fi

    if [ -r /dev/urandom ]; then
      _bbrc_code=$(LC_ALL=C tr -dc 'A-Za-z0-9_-' < /dev/urandom | head -c "$BB_THEME_CODE_LENGTH")
    elif [ -n "${RANDOM:-}" ]; then
      _bbrc_code='' _bbrc_i=0
      while [ "$_bbrc_i" -lt "$BB_THEME_CODE_LENGTH" ]; do
        _bbrc_code=$_bbrc_code$(printf '%s' "$BB_THEME_ALPHABET" | cut -c $(( RANDOM % 64 + 1 )))
        _bbrc_i=$(( _bbrc_i + 1 ))
      done
    else
      printf 'bb-theme: no source of randomness (/dev/urandom unreadable, no $RANDOM)\n' >&2
      return 1
    fi

    bb_theme_validate "$_bbrc_code" 2>/dev/null || continue
    # Redraw while any component of the drawn theme is plain black.
    if bb_theme_decode "$_bbrc_code" 2>/dev/null | grep -q ';30m'; then
      continue
    fi

    printf '%s\n' "$_bbrc_code"
    return 0
  done
}

# bb_theme_resolve CODE CODE_FILE
# Prints the code to install: CODE as it is, except for BB_THEME_RANDOM, which
# becomes the code stored in CODE_FILE (kept across reinstalls) or a fresh
# random one. BB_THEME_REROLL=1 forces a new random code.
bb_theme_resolve() {
  _bbtr_code=$1
  _bbtr_file=$2

  if [ "$_bbtr_code" != "$BB_THEME_RANDOM" ]; then
    bb_theme_validate "$_bbtr_code" || return 1
    printf '%s\n' "$_bbtr_code"
    return 0
  fi

  if [ -f "$_bbtr_file" ] && [ "${BB_THEME_REROLL:-0}" != "1" ]; then
    _bbtr_stored=$(cat "$_bbtr_file" 2>/dev/null | tr -d '\n\r')
    if bb_theme_validate "$_bbtr_stored" 2>/dev/null; then
      printf '%s\n' "$_bbtr_stored"
      return 0
    fi
    printf 'bb-theme: stored theme code in %s is not usable, drawing a new one\n' "$_bbtr_file" >&2
  fi

  bb_random_theme_code
}

# bb_theme_write CODE DIR
# Writes the decoded theme to DIR/theme.sh and the code it came from to
# DIR/theme-code, both atomically. This is the only place that writes theme
# files; prompt/bb.sh only ever reads them.
bb_theme_write() {
  _bbtw_code=$1
  _bbtw_dir=$2

  bb_theme_validate "$_bbtw_code" || return 1

  if [ ! -d "$_bbtw_dir" ]; then
    printf 'bb-theme: no such directory: %s\n' "$_bbtw_dir" >&2
    return 1
  fi

  _bbtw_tmp="$2/theme.sh.new"
  {
    printf '%s\n' '# Generated by prompt/bb-theme.sh from the theme code below.'
    printf '%s %s\n' '# bb-theme-code:' "$_bbtw_code"
    printf '%s\n' '# Sourced by prompt/bb.sh before its own defaults. Edit in the'
    printf '%s\n' '# WebUI and reinstall, or run: getbb.sh <method> <code>'
    bb_theme_decode "$_bbtw_code" || exit 1
  } >"$_bbtw_tmp" || { rm -f "$_bbtw_tmp"; return 1; }
  mv -f "$_bbtw_tmp" "$2/theme.sh" || { rm -f "$_bbtw_tmp"; return 1; }

  printf '%s\n' "$_bbtw_code" >"$2/theme-code.new" || { rm -f "$2/theme-code.new"; return 1; }
  mv -f "$2/theme-code.new" "$2/theme-code" || { rm -f "$2/theme-code.new"; return 1; }

  return 0
}

# Run directly rather than sourced: a small command line front end, mostly for
# trying codes out by hand and for the tests.
if [ "${0##*/}" = "bb-theme.sh" ]; then
  case ${1:-} in
    decode) bb_theme_decode "${2:-}" ;;
    random) bb_random_theme_code ;;
    resolve) bb_theme_resolve "${2:-}" "${3:-}" ;;
    write) bb_theme_write "${2:-}" "${3:-}" ;;
    *) printf 'usage: %s {decode CODE | random | resolve CODE CODE_FILE | write CODE DIR}\n' "$0" >&2; exit 2 ;;
  esac
fi
