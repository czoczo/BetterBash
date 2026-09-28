#!/bin/sh
# BetterBash theme codes, POSIX shell.
#
# A theme code is a string of url safe Base64 characters carrying a whole theme:
# the eight colours of the prompt and, since the v1 format, which elements of the
# top line of that prompt it shows. The WebUI encodes the code, this library turns
# it back into the assignments prompt/bb.sh works with.
#
# Two formats, told apart by their length and never by their bits:
#
#   8 characters   what the retired Go backend produced, unchanged bit for bit:
#                  eight five bit colour components (base colour 30-37, bright
#                  bit, bold bit) and one bit for the host avatar. Its output is
#                  byte for byte what that backend injected into prompt/bb.sh, and
#                  tests/golden/ pins it (tests/test-theme.sh). It says nothing
#                  about the other elements of the top line, which therefore show.
#   13 characters  the v1 format: the digit "1" and twelve characters of payload,
#                  72 bits, laid out under BB_THEME_COLOR_BITS.
#
# A code of one format is never rewritten into the other: both are read for as
# long as BetterBash is, because codes are in the wild - in bookmarks, in notes,
# in the README. What a format does not say is left unsaid rather than defaulted:
# decoding a v0 code prints the eight colours and AVATAR, as it always did, and
# prompt/bb.sh holds the defaults for everything a code leaves open.
#
# Everything is plain POSIX shell: no bashisms, no external tools for decoding,
# /dev/urandom plus tr and head for random codes only. It is sourced by getbb.sh
# and by prompt/bb.sh, and can be run directly for experiments:
#
#   sh prompt/bb-theme.sh decode vN-y_5uA
#   sh prompt/bb-theme.sh flags 1AAAAAAAAAAAA
#   sh prompt/bb-theme.sh random
#   sh prompt/bb-theme.sh resolve rand ~/.bb/theme-code
#   sh prompt/bb-theme.sh write vN-y_5uA ~/.bb
#
# Every name starting with _bbt_ is internal and clobbered by these functions.

# The colour components in the order their bits appear in a code.
BB_THEME_KEYS='PRIMARY_COLOR SECONDARY_COLOR ROOT_COLOR TIME_COLOR ERR_COLOR SEPARATOR_COLOR BORDCOL PATH_COLOR'

# The elements of the top line of the prompt, in the order they stand on it: the
# five of its left half, then the four of its right half. They are the names of
# the variables prompt/bb.sh reads, and AVATAR is the one of them that predates
# the rest (see prompt/bb.sh).
BB_ELEMENTS='PROMPT_USER PROMPT_HOST PROMPT_TTY AVATAR PROMPT_JOBS PROMPT_EXIT PROMPT_DURATION PROMPT_DATE PROMPT_CLOCK'
BB_ELEMENTS_LEFT='PROMPT_USER PROMPT_HOST PROMPT_TTY AVATAR PROMPT_JOBS'
BB_ELEMENTS_RIGHT='PROMPT_EXIT PROMPT_DURATION PROMPT_DATE PROMPT_CLOCK'

# The flags of all of them, in the order of BB_ELEMENTS: one bit each, one
# meaning "show this element", and a theme that names none shows all.
BB_ELEMENT_COUNT=9
BB_ELEMENTS_ALL='111111111'

# The word the WebUI puts in an install command instead of a code, meaning
# "draw a theme here". Every run of it draws a new one, so the word is also how
# a reroll is asked for.
BB_THEME_RANDOM='rand'

# The word that means "the theme this machine already has", which is what an
# install command naming no code asks for: reinstalling must not change colours.
BB_THEME_KEEP='keep'

# Characters a theme code may consist of, in the order of their values: the url
# safe alphabet of Base64, where '-' is the 62nd character and '_' the 63rd. The
# order matters as much as the characters do, because _bbt_bits_to_code walks this
# string to turn a value into a character; the order _bbt_char_value spells out
# and the order written here are the same thing, and were not the first time this
# line was written.
BB_THEME_ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'

# v0: eight characters, 48 bits. The name BB_THEME_CODE_LENGTH is the one the
# older releases used for the only length they knew, and it stays.
BB_THEME_CODE_LENGTH=8

# v1: this version digit, then this many characters of payload.
BB_THEME_VERSION='1'
BB_THEME_V1_LENGTH=13
BB_THEME_V1_PAYLOAD=12

# The 72 bits of a v1 payload, counted from their most significant bit:
#
#   0  - 39   the eight colour components, in exactly the places they hold in a
#             v0 code, so that the same forty bits mean the same colours in
#             either format;
#   40 - 48   the nine element flags, in the order of BB_ELEMENTS;
#   49 - 55   the order of the five elements of the left half, as the rank of a
#             permutation in the factorial number system (5! = 120 needs 7 bits);
#   56 - 60   the order of the four elements of the right half, the same way
#             (4! = 24 needs 5 bits);
#   61 - 71   reserved, and zero in every code this release writes.
#
# The halves are ranked separately because the frame anchors them separately: the
# left half grows from the corner, the right half ends at the far end of the line
# and grows backwards, and the fill between them is what a hidden element hands
# its width to. An order that put the clock left of the user would not be a frame,
# so no order field is spent on it - and 12 bits are enough for that, where a
# permutation of all nine elements would need 19.
#
# The order fields are read and range checked and nothing else, because the
# prompt of this release draws one order: rank zero of each half, which is the
# order of BB_ELEMENTS_LEFT and BB_ELEMENTS_RIGHT. They are laid out here
# now so that the day the prompt learns to draw another, no new format is needed:
# a code with a non zero rank is already a legal v1 code.
#
# The reserved bits are held at zero rather than left free, so that a code this
# release calls valid is one no later release can mean something else by.
BB_THEME_COLOR_BITS=40
BB_THEME_FLAG_BIT=40
BB_THEME_ORDER_LEFT_BIT=49
BB_THEME_ORDER_LEFT_WIDTH=7
BB_THEME_ORDER_RIGHT_BIT=56
BB_THEME_ORDER_RIGHT_WIDTH=5
BB_THEME_ORDER_LEFT_COUNT=5
BB_THEME_ORDER_RIGHT_COUNT=4
BB_THEME_RESERVED_BITS=11

# --- the bits of a code --------------------------------------------------
#
# A code is read into a string of '0' and '1' characters, most significant bit
# first, and the fields are cut out of that string. Bit arithmetic on a 72 bit
# value would need more than the 32 bit arithmetic some shells have; a bit string
# needs none, ${s#??????} is POSIX, and no number here grows past 64.
#
# Each helper leaves its answer in a variable of its own - _bbt_val_out,
# _bbt_bits_out, _bbt_cut_out, _bbt_num_out, _bbt_code_out - rather than in
# command substitution, because a decode that forked per character would be slow
# where it is only ever long.

# _bbt_char_value CHAR
# _bbt_val_out: the index of CHAR in the theme code alphabet. A table rather than
# substring arithmetic, because ${var:0:1} and base# notation are not POSIX.
_bbt_char_value() {
  case $1 in
    A) _bbt_val_out=0;;   B) _bbt_val_out=1;;   C) _bbt_val_out=2;;   D) _bbt_val_out=3;;
    E) _bbt_val_out=4;;   F) _bbt_val_out=5;;   G) _bbt_val_out=6;;   H) _bbt_val_out=7;;
    I) _bbt_val_out=8;;   J) _bbt_val_out=9;;   K) _bbt_val_out=10;;  L) _bbt_val_out=11;;
    M) _bbt_val_out=12;;  N) _bbt_val_out=13;;  O) _bbt_val_out=14;;  P) _bbt_val_out=15;;
    Q) _bbt_val_out=16;;  R) _bbt_val_out=17;;  S) _bbt_val_out=18;;  T) _bbt_val_out=19;;
    U) _bbt_val_out=20;;  V) _bbt_val_out=21;;  W) _bbt_val_out=22;;  X) _bbt_val_out=23;;
    Y) _bbt_val_out=24;;  Z) _bbt_val_out=25;;  a) _bbt_val_out=26;;  b) _bbt_val_out=27;;
    c) _bbt_val_out=28;;  d) _bbt_val_out=29;;  e) _bbt_val_out=30;;  f) _bbt_val_out=31;;
    g) _bbt_val_out=32;;  h) _bbt_val_out=33;;  i) _bbt_val_out=34;;  j) _bbt_val_out=35;;
    k) _bbt_val_out=36;;  l) _bbt_val_out=37;;  m) _bbt_val_out=38;;  n) _bbt_val_out=39;;
    o) _bbt_val_out=40;;  p) _bbt_val_out=41;;  q) _bbt_val_out=42;;  r) _bbt_val_out=43;;
    s) _bbt_val_out=44;;  t) _bbt_val_out=45;;  u) _bbt_val_out=46;;  v) _bbt_val_out=47;;
    w) _bbt_val_out=48;;  x) _bbt_val_out=49;;  y) _bbt_val_out=50;;  z) _bbt_val_out=51;;
    0) _bbt_val_out=52;;  1) _bbt_val_out=53;;  2) _bbt_val_out=54;;  3) _bbt_val_out=55;;
    4) _bbt_val_out=56;;  5) _bbt_val_out=57;;  6) _bbt_val_out=58;;  7) _bbt_val_out=59;;
    8) _bbt_val_out=60;;  9) _bbt_val_out=61;;  -) _bbt_val_out=62;;  _) _bbt_val_out=63;;
    *)
      printf 'bb-theme: %s is not a character of the theme code alphabet\n' "$1" >&2
      return 1
      ;;
  esac
}

# _bbt_bits_of CHARS - _bbt_bits_out: the bit string of CHARS.
_bbt_bits_of() {
  _bbt_bo_rest=$1
  _bbt_bits_out=''

  while [ -n "$_bbt_bo_rest" ]; do
    _bbt_bo_tail=${_bbt_bo_rest#?}
    _bbt_char_value "${_bbt_bo_rest%"$_bbt_bo_tail"}" || return 1
    _bbt_bo_i=5
    while [ "$_bbt_bo_i" -ge 0 ]; do
      if [ $(( (_bbt_val_out >> _bbt_bo_i) & 1 )) -eq 1 ]; then
        _bbt_bits_out="${_bbt_bits_out}1"
      else
        _bbt_bits_out="${_bbt_bits_out}0"
      fi
      _bbt_bo_i=$((_bbt_bo_i - 1))
    done
    _bbt_bo_rest=$_bbt_bo_tail
  done

  return 0
}

# _bbt_cut BITS OFFSET LENGTH - _bbt_cut_out: the LENGTH bits of BITS from the
# OFFSETth, counted from the most significant end.
_bbt_cut() {
  _bbt_ct_rest=$1
  _bbt_ct_i=0
  while [ "$_bbt_ct_i" -lt "$2" ] && [ -n "$_bbt_ct_rest" ]; do
    _bbt_ct_rest=${_bbt_ct_rest#?}
    _bbt_ct_i=$((_bbt_ct_i + 1))
  done

  _bbt_cut_out=''
  _bbt_ct_i=0
  while [ "$_bbt_ct_i" -lt "$3" ]; do
    if [ -z "$_bbt_ct_rest" ]; then
      printf 'bb-theme: too few bits to cut at %s\n' "$2" >&2
      return 1
    fi
    _bbt_ct_tail=${_bbt_ct_rest#?}
    _bbt_cut_out=$_bbt_cut_out${_bbt_ct_rest%"$_bbt_ct_tail"}
    _bbt_ct_rest=$_bbt_ct_tail
    _bbt_ct_i=$((_bbt_ct_i + 1))
  done

  return 0
}

# _bbt_num BITS - _bbt_num_out: the number the bit string names.
_bbt_num() {
  _bbt_num_out=0
  _bbt_nm_rest=$1
  while [ -n "$_bbt_nm_rest" ]; do
    _bbt_nm_tail=${_bbt_nm_rest#?}
    if [ "${_bbt_nm_rest%"$_bbt_nm_tail"}" = 1 ]; then
      _bbt_num_out=$((_bbt_num_out * 2 + 1))
    else
      _bbt_num_out=$((_bbt_num_out * 2))
    fi
    _bbt_nm_rest=$_bbt_nm_tail
  done
}

# _bbt_bits_of_num VALUE LENGTH - _bbt_bits_out: the bit string of LENGTH bits
# naming VALUE.
_bbt_bits_of_num() {
  _bbt_bn_out=''
  _bbt_bn_i=$(( $2 - 1 ))
  while [ "$_bbt_bn_i" -ge 0 ]; do
    if [ $(( ($1 >> _bbt_bn_i) & 1 )) -eq 1 ]; then
      _bbt_bn_out="${_bbt_bn_out}1"
    else
      _bbt_bn_out="${_bbt_bn_out}0"
    fi
    _bbt_bn_i=$((_bbt_bn_i - 1))
  done
  _bbt_bits_out=$_bbt_bn_out
}

# _bbt_zeros LENGTH - _bbt_bits_out: a run of LENGTH zero bits.
_bbt_zeros() {
  _bbt_z_out=''
  _bbt_z_i=0
  while [ "$_bbt_z_i" -lt "$1" ]; do
    _bbt_z_out="${_bbt_z_out}0"
    _bbt_z_i=$((_bbt_z_i + 1))
  done
  _bbt_bits_out=$_bbt_z_out
}

# _bbt_bits_to_code BITS - _bbt_code_out: the code characters of a bit string
# whose length is a multiple of six.
_bbt_bits_to_code() {
  _bbt_bc_rest=$1
  _bbt_code_out=''

  while [ -n "$_bbt_bc_rest" ]; do
    if [ "${#_bbt_bc_rest}" -lt 6 ]; then
      printf 'bb-theme: %d bits do not fill a code character\n' "${#_bbt_bc_rest}" >&2
      return 1
    fi
    # The six leading bits, cut from the front: ${s%??????} would take the six
    # bits off the other end and read the number backwards.
    _bbt_cut "$_bbt_bc_rest" 0 6 || return 1
    _bbt_num "$_bbt_cut_out" || return 1
    _bbt_bc_rest=${_bbt_bc_rest#??????}

    _bbt_bc_i=0
    _bbt_bc_walk=$BB_THEME_ALPHABET
    while [ "$_bbt_bc_i" -lt "$_bbt_num_out" ]; do
      _bbt_bc_walk=${_bbt_bc_walk#?}
      _bbt_bc_i=$((_bbt_bc_i + 1))
    done
    _bbt_code_out=$_bbt_code_out${_bbt_bc_walk%"${_bbt_bc_walk#?}"}
  done

  return 0
}

# _bbt_factorial N - _bbt_num_out: the number of permutations of N things, and
# with it the number of ranks an order field of N elements has to name.
_bbt_factorial() {
  _bbt_fa_out=1
  _bbt_fa_i=2
  while [ "$_bbt_fa_i" -le "$1" ]; do
    _bbt_fa_out=$((_bbt_fa_out * _bbt_fa_i))
    _bbt_fa_i=$((_bbt_fa_i + 1))
  done
  _bbt_num_out=$_bbt_fa_out
}

# --- validation -----------------------------------------------------------

# bb_theme_validate CODE
# Succeeds when CODE is a theme code of either format. Anything else is refused,
# because a code is the only part of the command line this library ever looks at.
# A v1 code is refused when it was not written as one: an ordering rank beyond the
# permutations it names, or a reserved bit that is not zero, says some other
# format is being held out as this one, and installing it would install a theme
# nobody meant.
bb_theme_validate() {
  _bbtv_code=$1

  case ${#_bbtv_code} in
    "$BB_THEME_CODE_LENGTH") _bbtv_format=v0 ;;
    "$BB_THEME_V1_LENGTH") _bbtv_format=v1 ;;
    *)
      printf 'bb-theme: theme code must be %d characters long (v0) or %d (v%s), got %d (%s)\n' \
        "$BB_THEME_CODE_LENGTH" "$BB_THEME_V1_LENGTH" "$BB_THEME_VERSION" \
        "${#_bbtv_code}" "$_bbtv_code" >&2
      return 1
      ;;
  esac

  # POSIX pattern negation: any character outside the alphabet fails the match.
  case $_bbtv_code in
    *[!A-Za-z0-9_-]*)
      printf 'bb-theme: theme code %s contains characters outside the theme code alphabet\n' "$_bbtv_code" >&2
      return 1
      ;;
  esac

  [ "$_bbtv_format" = v1 ] || return 0

  # The version digit leads the code, so that a reader and a decoder both know
  # what they are holding before they start counting bits.
  if [ "${_bbtv_code%"${_bbtv_code#?}"}" != "$BB_THEME_VERSION" ]; then
    printf 'bb-theme: theme code %s is not of version %s\n' "$_bbtv_code" "$BB_THEME_VERSION" >&2
    return 1
  fi

  _bbt_bits_of "${_bbtv_code#?}" || return 1

  _bbt_cut "$_bbt_bits_out" "$BB_THEME_ORDER_LEFT_BIT" "$BB_THEME_ORDER_LEFT_WIDTH" || return 1
  _bbtv_left=$_bbt_cut_out
  _bbt_cut "$_bbt_bits_out" "$BB_THEME_ORDER_RIGHT_BIT" "$BB_THEME_ORDER_RIGHT_WIDTH" || return 1
  _bbtv_right=$_bbt_cut_out
  _bbt_cut "$_bbt_bits_out" 61 "$BB_THEME_RESERVED_BITS" || return 1
  _bbtv_reserved=$_bbt_cut_out

  _bbt_factorial "$BB_THEME_ORDER_LEFT_COUNT"
  _bbtv_ranks=$((_bbt_num_out - 1))
  _bbt_num "$_bbtv_left"
  if [ "$_bbt_num_out" -gt "$_bbtv_ranks" ]; then
    printf 'bb-theme: theme code %s ranks the %d elements of the left half above %d\n' \
      "$_bbtv_code" "$BB_THEME_ORDER_LEFT_COUNT" "$_bbtv_ranks" >&2
    return 1
  fi

  _bbt_factorial "$BB_THEME_ORDER_RIGHT_COUNT"
  _bbtv_ranks=$((_bbt_num_out - 1))
  _bbt_num "$_bbtv_right"
  if [ "$_bbt_num_out" -gt "$_bbtv_ranks" ]; then
    printf 'bb-theme: theme code %s ranks the %d elements of the right half above %d\n' \
      "$_bbtv_code" "$BB_THEME_ORDER_RIGHT_COUNT" "$_bbtv_ranks" >&2
    return 1
  fi

  _bbt_zeros "$BB_THEME_RESERVED_BITS"
  if [ "$_bbtv_reserved" != "$_bbt_bits_out" ]; then
    printf 'bb-theme: theme code %s holds bits that version %s leaves zero\n' \
      "$_bbtv_code" "$BB_THEME_VERSION" >&2
    return 1
  fi

  return 0
}

# --- flags ----------------------------------------------------------------

# bb_theme_flags CODE
# Prints the nine element flag bits of CODE, in the order of BB_ELEMENTS, and
# leaves them in _bbt_flags_out. A v0 code carries one of them - the avatar, at
# bit 40 - and says nothing about the rest: those show, which is what they did
# before there were flags at all.
bb_theme_flags() {
  _bbtf_code=$1

  case ${#_bbtf_code} in
    "$BB_THEME_CODE_LENGTH")
      _bbt_bits_of "$_bbtf_code" || return 1
      _bbt_cut "$_bbt_bits_out" 40 1 || return 1
      # The avatar bit of a v0 code goes to the place the avatar holds in
      # BB_ELEMENTS, which is the fourth; everything else shows.
      _bbtf_avatar=$_bbt_cut_out
      _bbt_cut "$BB_ELEMENTS_ALL" 0 3 || return 1
      _bbt_flags_out="${_bbt_cut_out}${_bbtf_avatar}11111"
      printf '%s\n' "$_bbt_flags_out"
      ;;
    "$BB_THEME_V1_LENGTH")
      _bbt_bits_of "${_bbtf_code#?}" || return 1
      _bbt_cut "$_bbt_bits_out" "$BB_THEME_FLAG_BIT" "$BB_ELEMENT_COUNT" || return 1
      _bbt_flags_out=$_bbt_cut_out
      printf '%s\n' "$_bbt_flags_out"
      ;;
    *)
      printf 'bb-theme: %s is not a theme code\n' "$_bbtf_code" >&2
      return 1
      ;;
  esac
}

# --- decoding -------------------------------------------------------------

# bb_theme_decode CODE
# Prints the assignments of the theme as
#   KEY='\033[...]'
# lines, ready to be sourced: the eight colours of both formats, and the element
# flags the format carries - AVATAR alone for a v0 code, exactly as it has always
# been printed, and all nine of BB_ELEMENTS for a v1 one.
bb_theme_decode() {
  _bbtd_code=$1

  bb_theme_validate "$_bbtd_code" || return 1

  case ${#_bbtd_code} in
    "$BB_THEME_CODE_LENGTH") bb_theme_decode_v0 "$_bbtd_code" ;;
    *) bb_theme_decode_v1 "$_bbtd_code" ;;
  esac
}

# bb_theme_decode_v0 CODE - the 48 bits of the format the Go backend produced.
bb_theme_decode_v0() {
  _bbt_halves "$1" 8 || return 1
  bb_theme_colors "$_bbt_hi" "$_bbt_lo"

  # The avatar flag is bit 40 of the code, the bit right behind the colours.
  if [ $(( (_bbt_lo >> 7) & 1 )) -eq 1 ]; then
    printf 'AVATAR=%s\n' "'true'"
  else
    printf 'AVATAR=%s\n' "'false'"
  fi
}

# bb_theme_decode_v1 CODE - the 72 bits behind the version digit. The colours are
# the first 40 bits of the payload, in the places they hold in a v0 code, so the
# two 24 bit halves of the colour fields are read the same way and mean the same:
# the payload characters one to four and five to eight.
bb_theme_decode_v1() {
  _bbt_halves "${1#?}" 8 || return 1
  bb_theme_colors "$_bbt_hi" "$_bbt_lo"

  bb_theme_flags "$1" > /dev/null || return 1
  _bbt_d1_n=0
  for _bbt_d1_key in $BB_ELEMENTS; do
    _bbt_cut "$_bbt_flags_out" "$_bbt_d1_n" 1 || return 1
    if [ "$_bbt_cut_out" = 1 ]; then
      printf '%s=%s\n' "$_bbt_d1_key" "'true'"
    else
      printf '%s=%s\n' "$_bbt_d1_key" "'false'"
    fi
    _bbt_d1_n=$((_bbt_d1_n + 1))
  done
}

# _bbt_halves CODE CHARS - _bbt_hi and _bbt_lo: the 24 most significant and the
# 24 bits after them of CHARS characters, so that no shell arithmetic ever needs
# more than 24 bits, which keeps this working on shells whose arithmetic is 32 bit.
_bbt_halves() {
  _bbt_hv_rest=$1
  _bbt_hi=0 _bbt_lo=0 _bbt_hv_pos=0 _bbt_hv_max=$(( $2 * 6 ))

  while [ -n "$_bbt_hv_rest" ]; do
    _bbt_hv_tail=${_bbt_hv_rest#?}
    _bbt_char_value "${_bbt_hv_rest%"$_bbt_hv_tail"}" || return 1
    _bbt_hv_rest=$_bbt_hv_tail

    if [ "$_bbt_hv_pos" -lt 24 ]; then
      _bbt_hi=$(( _bbt_hi * 64 + _bbt_val_out ))
    else
      _bbt_lo=$(( _bbt_lo * 64 + _bbt_val_out ))
    fi
    _bbt_hv_pos=$((_bbt_hv_pos + 6))

    # Only the first 48 bits of a v1 payload matter here: the flags and the
    # order fields are read out of the bit string, not out of these halves.
    if [ "$_bbt_hv_pos" -ge "$_bbt_hv_max" ]; then
      break
    fi
  done

  return 0
}

# bb_theme_colors HI LO
# Prints the eight colour assignments held in the two 24 bit halves of the 48
# most significant bits of a code, in which the colour fields sit at bits 0 to
# 39 - the same places in both formats. Field i of eight occupies bits (5*i) to
# (5*i + 4) counted from the most significant bit, so field four is the one that
# straddles the halves.
bb_theme_colors() {
  _bbtc_hi=$1
  _bbtc_lo=$2

  _bbtc_n=0
  for _bbtc_key in $BB_THEME_KEYS; do
    case $_bbtc_n in
      0) _bbtc_f=$(( (_bbtc_hi >> 19) & 31 )) ;;
      1) _bbtc_f=$(( (_bbtc_hi >> 14) & 31 )) ;;
      2) _bbtc_f=$(( (_bbtc_hi >> 9) & 31 )) ;;
      3) _bbtc_f=$(( (_bbtc_hi >> 4) & 31 )) ;;
      4) _bbtc_f=$(( (_bbtc_hi & 15) * 2 + ((_bbtc_lo >> 23) & 1) )) ;;
      5) _bbtc_f=$(( (_bbtc_lo >> 18) & 31 )) ;;
      6) _bbtc_f=$(( (_bbtc_lo >> 13) & 31 )) ;;
      7) _bbtc_f=$(( (_bbtc_lo >> 8) & 31 )) ;;
    esac

    # Component bits: base colour 0-7, bright, bold.
    _bbtc_number=$(( (_bbtc_f >> 2 & 7) + 30 ))
    [ $(( (_bbtc_f >> 1) & 1 )) -eq 1 ] && _bbtc_number=$(( _bbtc_number + 60 ))
    printf '%s=%s\n' "$_bbtc_key" "'\[\033[$(( _bbtc_f & 1 ));${_bbtc_number}m\]'"
    _bbtc_n=$(( _bbtc_n + 1 ))
  done
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

# --- drawing --------------------------------------------------------------

# bb_random_color_bits
# _bbt_color_bits_out: 40 random bits for the colour components, with no plain
# black among them, and nothing else. Which elements a prompt shows is never
# drawn: losing colours is what "rand" means.
#
# Codes are drawn straight from /dev/urandom filtered to the theme code alphabet,
# so every one of the 64 characters - and with it every one of the 2^40 colour
# combinations - is equally likely. $BB_THEME_RANDOM_FALLBACK (bash only) is used
# where /dev/urandom is unreadable.
# The RANDOM of the fallback below is not a POSIX variable; it is only ever read
# after having been tested for, which is how bash (and only bash) gets here.
# shellcheck disable=SC3028
bb_random_color_bits() {
  _bb_rcb_tries=0

  while :; do
    _bb_rcb_tries=$(( _bb_rcb_tries + 1 ))
    if [ "$_bb_rcb_tries" -gt 64 ]; then
      printf 'bb-theme: gave up drawing a readable theme code after 64 tries\n' >&2
      return 1
    fi

    # Seven characters, 42 bits, of which the first 40 become the colours: throwing
    # the last two away leaves the forty that are left as uniform as the stream
    # they came from.
    if [ -r /dev/urandom ]; then
      _bb_rcb_drawn=$(LC_ALL=C tr -dc 'A-Za-z0-9_-' < /dev/urandom | head -c 7)
    elif [ -n "${RANDOM:-}" ]; then
      _bb_rcb_drawn='' _bb_rcb_i=0
      while [ "$_bb_rcb_i" -lt 7 ]; do
        _bb_rcb_drawn=$_bb_rcb_drawn$(printf '%s' "$BB_THEME_ALPHABET" | cut -c $(( RANDOM % 64 + 1 )))
        _bb_rcb_i=$((_bb_rcb_i + 1))
      done
    else
      printf 'bb-theme: no source of randomness (cannot read /dev/urandom, and this shell has no RANDOM)\n' >&2
      return 1
    fi

    _bbt_bits_of "$_bb_rcb_drawn" || continue
    _bbt_cut "$_bbt_bits_out" 0 "$BB_THEME_COLOR_BITS" || continue
    _bb_rcb_colors=$_bbt_cut_out

    # Redraw while any component of the colours drawn is plain black. The colours
    # are looked at as the v0 code they would be on their own, eight zero bits
    # behind them standing for the fields this does not ask about.
    _bbt_zeros 8
    _bbt_bits_to_code "$_bb_rcb_colors$_bbt_bits_out" || continue
    if bb_theme_decode_v0 "$_bbt_code_out" 2>/dev/null | grep -q ';30m'; then
      continue
    fi

    _bbt_color_bits_out=$_bb_rcb_colors
    return 0
  done
}

# bb_random_theme_code [CODE]
# Prints a freshly drawn theme code of the current version. Its colours come up
# from /dev/urandom; its elements are taken from CODE when CODE is a theme code -
# which in practice is the theme this machine already wears - and are all shown
# when CODE is not there or says nothing.
bb_random_theme_code() {
  _bb_rt_flags=''
  if [ -n "${1:-}" ]; then
    _bb_rt_flags=$(bb_theme_flags "$1" 2>/dev/null) || _bb_rt_flags=''
  fi
  [ -n "$_bb_rt_flags" ] || _bb_rt_flags=$BB_ELEMENTS_ALL

  bb_random_color_bits || return 1

  # Both order fields at rank zero, which is the order of BB_ELEMENTS_LEFT and
  # BB_ELEMENTS_RIGHT, and the reserved bits at zero.
  _bbt_order_rank_bits 0 "$BB_THEME_ORDER_LEFT_COUNT" || return 1
  _bb_rt_left=$_bbt_bits_out
  _bbt_order_rank_bits 0 "$BB_THEME_ORDER_RIGHT_COUNT" || return 1
  _bb_rt_right=$_bbt_bits_out
  _bbt_zeros "$BB_THEME_RESERVED_BITS"

  _bbt_bits_to_code "$_bbt_color_bits_out$_bb_rt_flags$_bb_rt_left$_bb_rt_right$_bbt_bits_out" || return 1
  printf '%s%s\n' "$BB_THEME_VERSION" "$_bbt_code_out"
}

# _bbt_order_rank_bits RANK COUNT - _bbt_bits_out: the field that holds the order
# of COUNT elements, 7 bits for five and 5 bits for four, which is what the
# factorial of the count needs. A rank beyond the permutations of COUNT things is
# refused, because it names no order.
_bbt_order_rank_bits() {
  _bbt_or_width=$BB_THEME_ORDER_LEFT_WIDTH
  [ "$2" -le 4 ] && _bbt_or_width=$BB_THEME_ORDER_RIGHT_WIDTH

  _bbt_factorial "$2"
  if [ "$1" -lt 0 ] || [ "$1" -ge "$_bbt_num_out" ]; then
    printf 'bb-theme: %s ranks no order of %d elements\n' "$1" "$2" >&2
    return 1
  fi

  _bbt_bits_of_num "$1" "$_bbt_or_width"
}

# --- storing and resolving ------------------------------------------------

# bb_theme_stored CODE_FILE
# Prints the code CODE_FILE holds when it holds a usable one, and nothing when
# it does not exist, is empty or holds something unusable. Saying nothing is the
# answer of a machine that has no theme yet, so it is never a failure; only a
# file with a broken code in it is worth a word on stderr.
bb_theme_stored() {
  _bbts_file=$1

  [ -f "$_bbts_file" ] || return 0
  _bbts_code=$(tr -d '\n\r' <"$_bbts_file" 2>/dev/null)
  [ -n "$_bbts_code" ] || return 0

  if bb_theme_validate "$_bbts_code" 2>/dev/null; then
    printf '%s\n' "$_bbts_code"
  else
    printf 'bb-theme: stored theme code in %s is not usable\n' "$_bbts_file" >&2
  fi
  return 0
}

# bb_theme_resolve CODE CODE_FILE
# Prints the code to install:
#
#   a code of either format      that code;
#   BB_THEME_RANDOM ("rand")     a freshly drawn one, whose elements are the ones
#                                the theme CODE_FILE holds already had, so "rand"
#                                loses colours and not a machine's choices;
#   BB_THEME_KEEP ("keep"), or no CODE
#                                the code CODE_FILE holds, or a freshly drawn
#                                one on a machine that has no theme yet.
#
# The code printed here is what bb_theme_write stores in CODE_FILE, which is how
# the next plain reinstall knows which theme to keep. BB_THEME_REROLL=1 with no
# code means the same as "rand": it is how older releases asked for a new theme,
# and it still does.
bb_theme_resolve() {
  _bbtr_code=$1
  _bbtr_file=$2

  if [ -z "$_bbtr_code" ] && [ "${BB_THEME_REROLL:-0}" = "1" ]; then
    _bbtr_code=$BB_THEME_RANDOM
  fi
  _bbtr_stored=$(bb_theme_stored "$_bbtr_file")

  case $_bbtr_code in
    "$BB_THEME_RANDOM")
      _bbtr_drawn=$(bb_random_theme_code "$_bbtr_stored") || return 1
      # Redraw when the code that came up is the theme already worn here. One
      # chance in 2^40 says this never happens; "rand" promises a different
      # theme, so it is not left to chance.
      _bbtr_again=0
      while [ "$_bbtr_drawn" = "$_bbtr_stored" ] && [ "$_bbtr_again" -lt 3 ]; do
        _bbtr_again=$(( _bbtr_again + 1 ))
        _bbtr_drawn=$(bb_random_theme_code "$_bbtr_stored") || return 1
      done
      printf '%s\n' "$_bbtr_drawn"
      ;;
    "$BB_THEME_KEEP" | "")
      if [ -n "$_bbtr_stored" ]; then
        printf '%s\n' "$_bbtr_stored"
        return 0
      fi
      bb_random_theme_code
      ;;
    *)
      bb_theme_validate "$_bbtr_code" || return 1
      printf '%s\n' "$_bbtr_code"
      ;;
  esac
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
    flags) bb_theme_flags "${2:-}" ;;
    random) bb_random_theme_code "${2:-}" ;;
    stored) bb_theme_stored "${2:-}" ;;
    resolve) bb_theme_resolve "${2:-}" "${3:-}" ;;
    write) bb_theme_write "${2:-}" "${3:-}" ;;
    *) printf 'usage: %s {decode CODE | flags CODE | random [CODE] | stored CODE_FILE | resolve CODE CODE_FILE | write CODE DIR}\n' "$0" >&2; exit 2 ;;
  esac
fi
