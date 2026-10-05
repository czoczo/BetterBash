// The theme code of the install commands and of a shared link, in its two shapes. A
// code is characters of the base64url alphabet, six bits of the theme each.
// prompt/bb-theme.sh decodes the same characters on the machine that installs, and
// tests/test-theme-code.mjs holds the two to each other bit for bit.
//
//   v0  eight characters, 48 bits: eight colours of five bits and the avatar bit. They
//       are in shared links and in ~/.bb/theme-code, so they are read as they always
//       were and never written again.
//   v1  thirteen characters: the digit 1, then twelve of payload - 40 colour bits (the
//       colours of v0, same places), 9 element bits, 7 + 5 for the order of the two
//       halves of the top line, 1 for the border fill, 10 kept at zero so a later
//       version cannot be mistaken for this one.
//
// The fill is held against its name (zero fills, one does not) because its bit was one
// of the kept ones, so every older code means the line it always drew.
//
// Element bits are in the order the elements stand on the line: five of the left half,
// then four of the right. The fill follows them, though it stands between the halves.

export const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

export const COLOR_KEYS = [
  'PRIMARY_COLOR',
  'SECONDARY_COLOR',
  'ROOT_COLOR',
  'TIME_COLOR',
  'ERR_COLOR',
  'SEPARATOR_COLOR',
  'BORDCOL',
  'PATH_COLOR',
];

// The nine elements of the top line, in the order they stand on it.
export const LINE_ELEMENTS = [
  'PROMPT_USER',
  'PROMPT_HOST',
  'PROMPT_TTY',
  'AVATAR',
  'PROMPT_JOBS',
  'PROMPT_EXIT',
  'PROMPT_DURATION',
  'PROMPT_DATE',
  'PROMPT_CLOCK',
];

// The border fill: a flag with a checkbox like the elements, but not one - it stands
// between the halves, so it is ranked nowhere and takes the bit behind the nine.
export const FILL_KEY = 'PROMPT_FILL';

// The flags in the order they are read, written and shown as checkboxes: the
// elements of the line, then the fill.
export const ELEMENT_KEYS = [...LINE_ELEMENTS, FILL_KEY];

// The two halves of the top line are the first five elements of LINE_ELEMENTS and the
// next four. They are ordered apart because the frame anchors them apart: five have 120
// orders (7 bits), four have 24 (5 bits).

export const VERSION = '1';
export const V0_LENGTH = 8;
export const V1_LENGTH = 13;
export const COLOR_BITS = 40;
export const FLAG_BITS = 9;
export const LEFT_ORDER_BITS = 7;
export const RIGHT_ORDER_BITS = 5;
export const FILL_BITS = 1;
export const RESERVED_BITS = 10;
export const V1_PAYLOAD_BITS = COLOR_BITS + FLAG_BITS + LEFT_ORDER_BITS + RIGHT_ORDER_BITS +
  FILL_BITS + RESERVED_BITS;

// Where the fill is held in the payload, and the string that says every flag shows.
const FILL_BIT = COLOR_BITS + FLAG_BITS + LEFT_ORDER_BITS + RIGHT_ORDER_BITS;

export const ALL_ELEMENTS_ON = '1'.repeat(ELEMENT_KEYS.length);

// --- bits and characters ---------------------------------------------------

// The value of a character, or -1 for anything else. - is 62 and _ is 63, as base64url
// and prompt/bb-theme.sh read them.
export function charValue(char) {
  return ALPHABET.indexOf(char);
}

export function bitsOf(code) {
  const bits = [];
  for (const char of code) {
    const value = charValue(char);
    if (value < 0) return null;
    for (let shift = 5; shift >= 0; shift--) bits.push((value >> shift) & 1);
  }
  return bits;
}

export function bitsToCode(bits) {
  let out = '';
  for (let i = 0; i < bits.length; i += 6) {
    let value = 0;
    for (let j = 0; j < 6; j++) value = (value << 1) | (bits[i + j] || 0);
    out += ALPHABET[value];
  }
  return out;
}

// --- the orders ------------------------------------------------------------

// The rank of an order in the factorial number system: 0 is the default order, the last
// rank is n! - 1.
export function orderRank(order, count) {
  if (order.length !== count) return null;
  const pool = [...Array(count).keys()];
  let rank = 0;
  for (let i = 0; i < count; i++) {
    const at = pool.indexOf(order[i]);
    if (at < 0) return null;
    pool.splice(at, 1);
    // The weight of this place: the number of orders of what is left after it.
    let place = 1;
    for (let k = count - 1 - i; k > 1; k--) place *= k;
    rank += at * place;
  }
  return rank;
}

export function orderByRank(rank, count) {
  if (!Number.isInteger(rank) || rank < 0 || rank >= factorial(count)) return null;
  const pool = [...Array(count).keys()];
  const order = [];
  for (let i = 0; i < count; i++) {
    let place = 1;
    for (let k = count - 1 - i; k > 1; k--) place *= k;
    const at = Math.floor(rank / place);
    rank -= at * place;
    order.push(pool[at]);
    pool.splice(at, 1);
  }
  return rank === 0 ? order : null;
}

const factorial = (count) => (count <= 1 ? 1 : count * factorial(count - 1));

export const MAX_LEFT_ORDER = 120;
export const MAX_RIGHT_ORDER = 24;

// --- colours ---------------------------------------------------------------

// The five bits of a colour slot: three for the colour, one for bright, one for bold.
export function colorBits(attrs) {
  const short = attrs.baseCode - 30;
  const light = attrs.isLight ? 1 : 0;
  const bold = attrs.isBold ? 1 : 0;
  return ((short << 2) | (light << 1) | bold) & 0x1f;
}

export function colorAttrs(bits) {
  return {
    baseCode: (bits >> 2) + 30,
    isLight: ((bits >> 1) & 1) === 1,
    isBold: (bits & 1) === 1,
  };
}

const colorBitsString = (colors) =>
  COLOR_KEYS.map((key) => colorBits(colors[key] ?? { baseCode: 37, isLight: false, isBold: false }))
    .map((value) => value.toString(2).padStart(5, '0'))
    .join('');

const colorsFromBits = (bits) => {
  const colors = {};
  COLOR_KEYS.forEach((key, i) => {
    colors[key] = colorAttrs(bitsToNumber(bits.slice(i * 5, i * 5 + 5)));
  });
  return colors;
};

const bitsToNumber = (bits) => bits.reduce((value, bit) => (value << 1) | bit, 0);

// --- the code in full ------------------------------------------------------

/**
 * A theme into a code. `elements` is the bit string of the flags in the order of
 * ELEMENT_KEYS (the nine of the line, the fill last), '1' showing one; the orders are
 * ranks, both 0 - the order of LINE_ELEMENTS - until the page can reorder them. The
 * fill goes in against its name, so every older code still means a line stretched to
 * the edge.
 */
export function encode({ colors, elements = ALL_ELEMENTS_ON, leftOrder = 0, rightOrder = 0 }) {
  const fill = elements.charAt(FLAG_BITS) === '1' ? '0' : '1';
  const bits = colorBitsString(colors) + elements.slice(0, FLAG_BITS) +
    leftOrder.toString(2).padStart(LEFT_ORDER_BITS, '0') +
    rightOrder.toString(2).padStart(RIGHT_ORDER_BITS, '0') +
    fill + '0'.repeat(RESERVED_BITS);
  return VERSION + bitsToCode(bits.split('').map(Number));
}

/** Reads both shapes: eight characters, whose only element is the avatar, or thirteen. */
export function decode(code) {
  if (typeof code !== 'string') return null;
  if (code.length === V0_LENGTH) {
    const bits = bitsOf(code);
    if (!bits) return null;
    // The only element a v0 code speaks of; the rest were never asked for, and show.
    const avatar = bits[COLOR_BITS] === 1 ? '1' : '0';
    return {
      version: 0,
      colors: colorsFromBits(bits.slice(0, COLOR_BITS)),
      elements: `${ALL_ELEMENTS_ON.slice(0, 3)}${avatar}${ALL_ELEMENTS_ON.slice(4)}`,
      leftOrder: 0,
      rightOrder: 0,
    };
  }
  if (code.length !== V1_LENGTH || code[0] !== VERSION) return null;
  const bits = bitsOf(code.slice(1));
  if (!bits || bits.length !== V1_PAYLOAD_BITS) return null;
  const left = bitsToNumber(bits.slice(COLOR_BITS + FLAG_BITS, COLOR_BITS + FLAG_BITS + LEFT_ORDER_BITS));
  const right = bitsToNumber(bits.slice(COLOR_BITS + FLAG_BITS + LEFT_ORDER_BITS, COLOR_BITS + FLAG_BITS + LEFT_ORDER_BITS + RIGHT_ORDER_BITS));
  if (left >= MAX_LEFT_ORDER || right >= MAX_RIGHT_ORDER) return null;
  // Kept bits are zero, so a code holding something is never read as this shape.
  if (bits.slice(V1_PAYLOAD_BITS - RESERVED_BITS).some((bit) => bit !== 0)) return null;
  return {
    version: 1,
    colors: colorsFromBits(bits.slice(0, COLOR_BITS)),
    // The flags of the line, then the fill back from its bit: a one there says it does
    // not fill.
    elements: bits.slice(COLOR_BITS, COLOR_BITS + FLAG_BITS).join('') +
      (bits[FILL_BIT] === 1 ? '0' : '1'),
    leftOrder: left,
    rightOrder: right,
  };
}

export function isThemeCode(code) {
  return decode(code) !== null;
}

// --- asking for a draw ---------------------------------------------------

// The word an install command carries instead of a code, when the machine running it
// should draw the colours, and the separator before a code the draw should wear.
export const RANDOM_WORD = 'rand';
export const RANDOM_SEPARATOR = ':';

// The word, and the code whose elements the draw wears. A code is always carried: the
// boxes of the top line are the one thing a draw never picks for itself. The colours of
// that code are ignored - the machine draws its own.
export function randomRequest(code = '') {
  return code ? `${RANDOM_WORD}${RANDOM_SEPARATOR}${code}` : RANDOM_WORD;
}

// The code a request carries: '' when it carries none, null when it is no draw or
// carries something that is not a code.
export function randomRequestCode(request) {
  if (typeof request !== 'string') return null;
  if (request === RANDOM_WORD) return '';
  if (!request.startsWith(`${RANDOM_WORD}${RANDOM_SEPARATOR}`)) return null;
  const code = request.slice(RANDOM_WORD.length + RANDOM_SEPARATOR.length);
  return isThemeCode(code) ? code : null;
}

// The flag of one element, or of the fill, out of the bit string of them all.
export const elementFlag = (elements, key) => elements.charAt(ELEMENT_KEYS.indexOf(key)) === '1';
