#!/bin/sh
# BetterBash theme codes, POSIX shell.
#
# A theme code is a string of url safe Base64 characters carrying a whole theme: the
# eight colours of the prompt and, since v1, which elements of its top line show. The
# WebUI encodes it; this library turns it back into the assignments prompt/bb.sh uses.
#
# Two formats, told apart by length and never by bits, and both read for as long as
# BetterBash lives - codes are in bookmarks, notes and the README:
#
#   8 characters   v0, what the retired Go backend produced, bit for bit, pinned by
#                  tests/golden/: eight five bit colour components (base 30-37, bright,
#                  bold) and the avatar bit. Everything it does not say shows.
#   13 characters  v1: the digit "1" and twelve characters of payload, 72 bits, laid
#                  out under BB_THEME_COLOR_BITS.
#
# Plain POSIX shell: no bashisms, no external tools for decoding, /dev/urandom plus tr
# and head for random codes only. Sourced by prompt/bb.sh, runnable directly:
#
#   sh prompt/bb-theme.sh decode vN-y_5uA
#   sh prompt/bb-theme.sh flags 1AAAAAAAAAAAA
#   sh prompt/bb-theme.sh random
#   sh prompt/bb-theme.sh resolve rand ~/.bb/theme-code
#   sh prompt/bb-theme.sh resolve rand:1AAAAAAAAAAAA ~/.bb/theme-code
#   sh prompt/bb-theme.sh write vN-y_5uA ~/.bb
#
# Every name starting with _bbt_ is internal and clobbered by these functions.

# The colour components in the order their bits appear in a code.
BB_THEME_KEYS='PRIMARY_COLOR SECONDARY_COLOR ROOT_COLOR TIME_COLOR ERR_COLOR SEPARATOR_COLOR BORDCOL PATH_COLOR'

# The elements of the top line, in the order they stand on it: the five of the left
# half then the four of the right. These are the variable names prompt/bb.sh reads;
# AVATAR predates the rest.
BB_ELEMENTS='PROMPT_USER PROMPT_HOST PROMPT_TTY AVATAR PROMPT_JOBS PROMPT_EXIT PROMPT_DURATION PROMPT_DATE PROMPT_CLOCK'
BB_ELEMENT_COUNT=9

# The border fill: the dashes between the elements and the run that reaches the line
# to the width of the terminal. A flag with a checkbox like the elements, but not one:
# it stands between the halves, so it is ranked nowhere and takes the next bit.
BB_FILL='PROMPT_FILL'

# All ten flags, in the order they are read, written and printed: the elements, then
# the fill. One bit each means "show this", and a theme naming none shows all.
BB_FLAGS="$BB_ELEMENTS $BB_FILL"
BB_FLAG_COUNT=10
BB_FLAGS_ALL='1111111111'
# The field of flags a code holds is the elements of the line and no more.
BB_THEME_FLAG_COUNT=$BB_ELEMENT_COUNT

# The word the WebUI puts in an install command instead of a code: draw a theme here.
# Every run draws a new one, so it is also how a reroll is asked for.
BB_THEME_RANDOM='rand'

# The word that means "the theme this machine already has", which is what an
# install command naming no code asks for: reinstalling must not change colours.
BB_THEME_KEEP='keep'

# The word above may carry a theme code with it, and this is what separates the
# word from the code: `rand:1ABCDEFGHIJKLMNOP`. See "asking for a draw" below.
BB_THEME_RANDOM_SEP=':'

# The characters a code may consist of, in the order of their values: the url safe
# alphabet of Base64, where '-' is 62 and '_' is 63. The order matters as much as the
# characters: _bbt_bits_to_code walks this string, and it must agree with the table
# _bbt_char_value spells out.
BB_THEME_ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'

# v0: eight characters, 48 bits. BB_THEME_CODE_LENGTH is the name older releases used
# for the only length they knew.
BB_THEME_CODE_LENGTH=8

# v1: this version digit, then this many characters of payload.
BB_THEME_VERSION='1'
BB_THEME_V1_LENGTH=13
BB_THEME_V1_PAYLOAD=12

# The 72 bits of a v1 payload, from the most significant bit:
#
#   0  - 39   the eight colour components, in exactly the places they hold in a v0
#             code, so the same forty bits mean the same colours in either format;
#   40 - 48   the nine element flags, in the order of BB_ELEMENTS;
#   49 - 55   order of the five left half elements: the rank of a permutation in the
#             factorial number system (5! = 120 needs 7 bits);
#   56 - 60   order of the four right half elements, the same way (4! = 24, 5 bits);
#   61        the border fill, held against its name: zero fills to the edge of the
#             terminal, one keeps only the elements that show;
#   62 - 71   reserved, zero in every code this release writes.
#
# The fill is inverted because its bit was once reserved: every older code holds zero
# there, and zero is the line stretched to the edge, as it always was.
#
# The halves are ranked separately because the frame anchors them separately: the left
# grows from the corner, the right grows back from the far end, and the fill between
# them takes what a hidden element hands back. An order putting the clock left of the
# user would not be a frame, so it is not offered - 12 bits for the two halves where a
# permutation of all nine would need 19.
#
# The order fields are only read and range checked: this prompt draws rank zero of
# each half, the order of BB_ELEMENTS. They are laid out now so that a prompt learning
# another order needs no new format.
#
# Reserved bits are held at zero rather than left free, so a code this release calls
# valid is one no later release can mean something else by.
BB_THEME_COLOR_BITS=40
BB_THEME_FLAG_BIT=40
BB_THEME_ORDER_LEFT_BIT=49
BB_THEME_ORDER_LEFT_WIDTH=7
BB_THEME_ORDER_RIGHT_BIT=56
BB_THEME_ORDER_RIGHT_WIDTH=5
BB_THEME_ORDER_LEFT_COUNT=5
BB_THEME_ORDER_RIGHT_COUNT=4
# The bit the border fill is held in, and from the bit behind it the bits this
# release keeps zero.
BB_THEME_FILL_BIT=61
BB_THEME_RESERVED_BIT=62
BB_THEME_RESERVED_BITS=10

# --- the bits of a code --------------------------------------------------
#
# A code is read into a string of '0' and '1', most significant bit first, and the
# fields are cut out of it: bit arithmetic on a 72 bit value would need more than the
# 32 bit arithmetic some shells have, a bit string needs none.
#
# Each helper leaves its answer in its own variable (_bbt_val_out, _bbt_bits_out,
# _bbt_cut_out, _bbt_num_out, _bbt_code_out) instead of command substitution, which
# would fork per character.

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
# Succeeds when CODE is a theme code of either format; anything else is refused, since
# a code is the only part of the command line this library looks at. A v1 code is
# refused when it was not written as one - a rank beyond the permutations it names, or
# a reserved bit that is not zero.
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

  # POSIX pattern negation: anything outside the alphabet fails the match.
  case $_bbtv_code in
    *[!A-Za-z0-9_-]*)
      printf 'bb-theme: theme code %s contains characters outside the theme code alphabet\n' "$_bbtv_code" >&2
      return 1
      ;;
  esac

  [ "$_bbtv_format" = v1 ] || return 0

  # The version digit leads the code, so what is held is known before counting bits.
  if [ "${_bbtv_code%"${_bbtv_code#?}"}" != "$BB_THEME_VERSION" ]; then
    printf 'bb-theme: theme code %s is not of version %s\n' "$_bbtv_code" "$BB_THEME_VERSION" >&2
    return 1
  fi

  _bbt_bits_of "${_bbtv_code#?}" || return 1

  _bbt_cut "$_bbt_bits_out" "$BB_THEME_ORDER_LEFT_BIT" "$BB_THEME_ORDER_LEFT_WIDTH" || return 1
  _bbtv_left=$_bbt_cut_out
  _bbt_cut "$_bbt_bits_out" "$BB_THEME_ORDER_RIGHT_BIT" "$BB_THEME_ORDER_RIGHT_WIDTH" || return 1
  _bbtv_right=$_bbt_cut_out
  _bbt_cut "$_bbt_bits_out" "$BB_THEME_RESERVED_BIT" "$BB_THEME_RESERVED_BITS" || return 1
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
# Prints the flags of CODE in the order of BB_ELEMENTS then BB_FILL, and leaves them
# in _bbt_flags_out. A v0 code carries only the avatar, at bit 40; the rest show.
bb_theme_flags() {
  _bbtf_code=$1

  case ${#_bbtf_code} in
    "$BB_THEME_CODE_LENGTH")
      _bbt_bits_of "$_bbtf_code" || return 1
      _bbt_cut "$_bbt_bits_out" 40 1 || return 1
      # The avatar bit goes to the avatar's place in BB_ELEMENTS, the fourth;
      # everything else shows.
      _bbtf_avatar=$_bbt_cut_out
      _bbt_cut "$BB_FLAGS_ALL" 0 3 || return 1
      _bbtf_head=$_bbt_cut_out
      _bbt_cut "$BB_FLAGS_ALL" 4 "$(( BB_FLAG_COUNT - 4 ))" || return 1
      _bbt_flags_out="${_bbtf_head}${_bbtf_avatar}${_bbt_cut_out}"
      printf '%s\n' "$_bbt_flags_out"
      ;;
    "$BB_THEME_V1_LENGTH")
      _bbt_bits_of "${_bbtf_code#?}" || return 1
      _bbt_cut "$_bbt_bits_out" "$BB_THEME_FLAG_BIT" "$BB_THEME_FLAG_COUNT" || return 1
      _bbtf_line=$_bbt_cut_out
      # Held against its name: only a one says it does not fill.
      _bbt_cut "$_bbt_bits_out" "$BB_THEME_FILL_BIT" 1 || return 1
      if [ "$_bbt_cut_out" = 1 ]; then _bbtf_fill=0; else _bbtf_fill=1; fi
      _bbt_flags_out="${_bbtf_line}${_bbtf_fill}"
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
# Prints the theme as sourceable KEY='\033[...]' lines: the eight colours of both
# formats, plus the flags the format carries - AVATAR alone for v0, all ten for v1.
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

# bb_theme_decode_v1 CODE - the 72 bits behind the version digit. The colours are the
# first 40 bits of the payload, read as the two 24 bit halves of a v0 code.
bb_theme_decode_v1() {
  _bbt_halves "${1#?}" 8 || return 1
  bb_theme_colors "$_bbt_hi" "$_bbt_lo"

  bb_theme_flags "$1" > /dev/null || return 1
  _bbt_d1_n=0
  for _bbt_d1_key in $BB_FLAGS; do
    _bbt_cut "$_bbt_flags_out" "$_bbt_d1_n" 1 || return 1
    if [ "$_bbt_cut_out" = 1 ]; then
      printf '%s=%s\n' "$_bbt_d1_key" "'true'"
    else
      printf '%s=%s\n' "$_bbt_d1_key" "'false'"
    fi
    _bbt_d1_n=$((_bbt_d1_n + 1))
  done
}

# _bbt_halves CODE CHARS - _bbt_hi and _bbt_lo: the first 24 bits and the 24 after
# them. No shell arithmetic here needs more than 24 bits, so 32 bit shells cope.
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

    # Only the first 48 bits matter here; flags and order fields come from the bit
    # string, not from these halves.
    if [ "$_bbt_hv_pos" -ge "$_bbt_hv_max" ]; then
      break
    fi
  done

  return 0
}

# bb_theme_colors HI LO
# The eight colour assignments of the two 24 bit halves of a code. Field i of eight
# occupies bits (5*i) to (5*i + 4) from the most significant bit, so field four
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

# --- drawing --------------------------------------------------------------

# bb_random_color_bits
# _bbt_color_bits_out: 40 random colour bits with no plain black among them. Which
# elements a prompt shows is never drawn - losing colours is what "rand" means.
#
# Drawn from /dev/urandom filtered to the alphabet, so all 64 characters and all 2^40
# colour combinations are equally likely. Where urandom is unreadable, the bash-only
# RANDOM is used - read only after having been tested for.
# shellcheck disable=SC3028
bb_random_color_bits() {
  _bb_rcb_tries=0

  while :; do
    _bb_rcb_tries=$(( _bb_rcb_tries + 1 ))
    if [ "$_bb_rcb_tries" -gt 64 ]; then
      printf 'bb-theme: gave up drawing a readable theme code after 64 tries\n' >&2
      return 1
    fi

    # Seven characters, 42 bits, the first 40 becoming the colours: dropping the last
    # two leaves them as uniform as the stream they came from.
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

    # Redraw while any component is plain black: the colours are looked at as the v0
    # code they would be alone, eight zero bits behind them.
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
# A freshly drawn code of the current version: colours from /dev/urandom, elements
# from CODE when CODE is a theme code (the theme worn here, or the one a `rand:CODE`
# asked to wear), all shown when CODE is missing or says nothing.
bb_random_theme_code() {
  _bb_rt_flags=''
  if [ -n "${1:-}" ]; then
    _bb_rt_flags=$(bb_theme_flags "$1" 2>/dev/null) || _bb_rt_flags=''
  fi
  [ -n "$_bb_rt_flags" ] || _bb_rt_flags=$BB_FLAGS_ALL

  bb_random_color_bits || return 1

  # Both order fields at rank zero, the fill in its bit and against its name, the
  # reserved bits at zero.
  _bbt_order_rank_bits 0 "$BB_THEME_ORDER_LEFT_COUNT" || return 1
  _bb_rt_left=$_bbt_bits_out
  _bbt_order_rank_bits 0 "$BB_THEME_ORDER_RIGHT_COUNT" || return 1
  _bb_rt_right=$_bbt_bits_out
  _bbt_cut "$_bb_rt_flags" 0 "$BB_THEME_FLAG_COUNT" || return 1
  _bb_rt_line=$_bbt_cut_out
  _bbt_cut "$_bb_rt_flags" "$BB_THEME_FLAG_COUNT" 1 || return 1
  if [ "$_bbt_cut_out" = 1 ]; then _bb_rt_fillbit=0; else _bb_rt_fillbit=1; fi
  _bbt_zeros "$BB_THEME_RESERVED_BITS"

  _bbt_bits_to_code "$_bbt_color_bits_out$_bb_rt_line$_bb_rt_left$_bb_rt_right$_bb_rt_fillbit$_bbt_bits_out" || return 1
  printf '%s%s\n' "$BB_THEME_VERSION" "$_bbt_code_out"
}

# _bbt_order_rank_bits RANK COUNT - _bbt_bits_out: the order field of COUNT elements,
# 7 bits for five and 5 for four. A rank beyond the permutations of COUNT is refused;
# it names no order.
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

# --- asking for a draw ----------------------------------------------------
#
# "rand" asks for a theme drawn on this machine and may carry a code with it:
# `rand:1ABCDEFGHIJKLMNOP`. What that code says about colours is ignored - they come
# from urandom - and what it says about the top line is used, so the boxes of the page
# reach the machine that runs the command. The word standing alone keeps the line of
# the theme already worn here.

# bb_theme_is_random ARG - whether ARG asks for a theme drawn here: the bare word, or
# the word and a code behind it.
bb_theme_is_random() {
  case ${1:-} in
    "$BB_THEME_RANDOM") return 0 ;;
    "$BB_THEME_RANDOM$BB_THEME_RANDOM_SEP"*) return 0 ;;
    *) return 1 ;;
  esac
}

# bb_theme_random_tail ARG
# The code ARG carries behind the word, also in _bbt_random_tail_out; nothing when ARG
# is the word alone. Anything else behind the separator is refused rather than ignored.
bb_theme_random_tail() {
  _bbtrt_arg=${1:-}
  _bbt_random_tail_out=''

  case $_bbtrt_arg in
    "$BB_THEME_RANDOM") return 0 ;;
    "$BB_THEME_RANDOM$BB_THEME_RANDOM_SEP"*) ;;
    *)
      printf 'bb-theme: %s does not ask for a drawn theme\n' "$_bbtrt_arg" >&2
      return 1
      ;;
  esac

  _bbtrt_tail=${_bbtrt_arg#"$BB_THEME_RANDOM$BB_THEME_RANDOM_SEP"}
  if [ -z "$_bbtrt_tail" ]; then
    printf 'bb-theme: %s asks for a theme behind the word and carries none\n' "$_bbtrt_arg" >&2
    return 1
  fi
  if ! bb_theme_validate "$_bbtrt_tail"; then
    printf 'bb-theme: %s is no theme to draw over\n' "$_bbtrt_tail" >&2
    return 1
  fi

  _bbt_random_tail_out=$_bbtrt_tail
  printf '%s\n' "$_bbt_random_tail_out"
  return 0
}

# --- storing and resolving ------------------------------------------------

# bb_theme_stored CODE_FILE
# The code CODE_FILE holds, or nothing when it is missing, empty or unusable. Saying
# nothing is the answer of a machine with no theme yet, so it is never a failure.
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
#   a code of either format   that code;
#   "rand"                    a freshly drawn one wearing the elements of the theme
#                             CODE_FILE holds - colours lost, choices kept;
#   "rand:CODE"               a freshly drawn one wearing the elements CODE spells out,
#                             whatever was worn before;
#   "keep" or no CODE         the code CODE_FILE holds, or a fresh draw when it holds
#                             nothing.
#
# What is printed here is what bb_theme_write stores, so the next plain reinstall knows
# which theme to keep. BB_THEME_REROLL=1 with no code means "rand".
bb_theme_resolve() {
  _bbtr_code=$1
  _bbtr_file=$2

  if [ -z "$_bbtr_code" ] && [ "${BB_THEME_REROLL:-0}" = "1" ]; then
    _bbtr_code=$BB_THEME_RANDOM
  fi
  _bbtr_stored=$(bb_theme_stored "$_bbtr_file")

  if bb_theme_is_random "$_bbtr_code"; then
    # The elements to wear: those of the code behind the word, or those of the theme
    # worn here when the word stands alone.
    bb_theme_random_tail "$_bbtr_code" > /dev/null || return 1
    _bbtr_wear=$_bbt_random_tail_out
    [ -n "$_bbtr_wear" ] || _bbtr_wear=$_bbtr_stored

    _bbtr_drawn=$(bb_random_theme_code "$_bbtr_wear") || return 1
    # Redraw when the code drawn equals the one worn here: one chance in 2^40, but
    # "rand" promises a different theme.
    _bbtr_again=0
    while [ "$_bbtr_drawn" = "$_bbtr_stored" ] && [ "$_bbtr_again" -lt 3 ]; do
      _bbtr_again=$(( _bbtr_again + 1 ))
      _bbtr_drawn=$(bb_random_theme_code "$_bbtr_wear") || return 1
    done
    printf '%s\n' "$_bbtr_drawn"
    return 0
  fi

  case $_bbtr_code in
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
# Writes the decoded theme to DIR/theme.sh and its code to DIR/theme-code, both
# atomically. The only place that writes theme files; prompt/bb.sh only reads them.
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
    printf '%s\n' '# Sourced by prompt/bb.sh before its own defaults. Choose the theme in'
    printf '%s\n' '# the WebUI and reinstall, or: . ~/.bb/prompt/bb.sh <code>'
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
