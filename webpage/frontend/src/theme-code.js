// The theme code of the install commands and of a shared link, in the two shapes
// it has.
//
// A code is characters of the base64url alphabet, and every one of them carries
// six bits of the theme. prompt/bb-theme.sh decodes the same characters on the
// machine that installs, and tests/test-theme-code.mjs holds the two of them to
// each other bit for bit.
//
//   v0  eight characters, 48 bits: eight colours of five bits each, and the bit
//       of the avatar behind them. Codes of this shape are in shared links and
//       in ~/.bb/theme-code of every machine that installed one, so they are
//       read as they always were and never written again.
//   v1  thirteen characters: the digit 1, then twelve characters of payload, of
//       which the first 40 bits are the colours of v0 in the same order, the
//       next nine are the elements of the top line of the prompt, the next
//       seven and five are the order of the two halves of that line, and the
//       last eleven are kept at zero so that a later version cannot be mistaken
//       for this one.
//
// The colours of both shapes, in the order their bits are written.
//
// The order of the nine element bits is the order the elements stand in on the
// top line of the prompt: five of the left half, then four of the right one.

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

export const ELEMENT_KEYS = [
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

// The elements of the two halves of the top line, in the order of ELEMENT_KEYS.
// The halves are ordered apart from one another because the frame anchors them
// apart: the left half hangs from the opening corner, the right one from the
// closing. Five elements have 120 orders and need seven bits, four have 24 and
// need five.
export const LEFT_ELEMENTS = ELEMENT_KEYS.slice(0, 5);
export const RIGHT_ELEMENTS = ELEMENT_KEYS.slice(5);

export const VERSION = '1';
export const V0_LENGTH = 8;
export const V1_LENGTH = 13;
export const COLOR_BITS = 40;
export const FLAG_BITS = 9;
export const LEFT_ORDER_BITS = 7;
export const RIGHT_ORDER_BITS = 5;
export const RESERVED_BITS = 11;
export const V1_PAYLOAD_BITS = COLOR_BITS + FLAG_BITS + LEFT_ORDER_BITS + RIGHT_ORDER_BITS + RESERVED_BITS;

export const ALL_ELEMENTS_ON = '1'.repeat(ELEMENT_KEYS.length);

// --- bits and characters ---------------------------------------------------

// The value of a character of the alphabet, or -1 for anything else. - is 62 and
// _ is 63: the same way round base64url, prompt/bb-theme.sh and the Go backend
// whose corpus tests/golden pins all agree on.
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

// The rank of an order among all orders of n things, the way a factorial number
// system counts them: 0 is the order the elements stand in by default, and the
// last rank is n! - 1.
export function orderRank(order, count) {
  if (order.length !== count) return null;
  const pool = [...Array(count).keys()];
  let rank = 0;
  for (let i = 0; i < count; i++) {
    const at = pool.indexOf(order[i]);
    if (at < 0) return null;
    pool.splice(at, 1);
    // The weight of this place is the number of orders of what is left after it.
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

// The five bits of one colour slot: three for which of the eight colours, one
// for the bright half of the palette and one for bold.
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

// A theme: the eight colours, the nine elements of the top line, and the two
// orders. `elements` is the bit string of the nine element flags in the order of
// ELEMENT_KEYS, '1' showing one; the orders are ranks, and both are 0 - the
// order of ELEMENT_KEYS - until the page can be asked to reorder them.
export function encode({ colors, elements = ALL_ELEMENTS_ON, leftOrder = 0, rightOrder = 0 }) {
  const bits = colorBitsString(colors) + elements + leftOrder.toString(2).padStart(7, '0') +
    rightOrder.toString(2).padStart(5, '0') + '0'.repeat(RESERVED_BITS);
  return VERSION + bitsToCode(bits.split('').map(Number));
}

// Both shapes are read: eight characters are a code of the first shape, whose
// only element is the avatar, and thirteen are a code of this one.
export function decode(code) {
  if (typeof code !== 'string') return null;
  if (code.length === V0_LENGTH) {
    const bits = bitsOf(code);
    if (!bits) return null;
    // The avatar bit is the first of the 48 that the shape has room for, and it
    // is the only element a code of this shape says anything about: the rest of
    // them were never asked for, and show.
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
  // What is kept is kept at zero, so that a code with something in it is never
  // read as a theme of this shape by a release that means it as another.
  if (bits.slice(V1_PAYLOAD_BITS - RESERVED_BITS).some((bit) => bit !== 0)) return null;
  return {
    version: 1,
    colors: colorsFromBits(bits.slice(0, COLOR_BITS)),
    elements: bits.slice(COLOR_BITS, COLOR_BITS + FLAG_BITS).join(''),
    leftOrder: left,
    rightOrder: right,
  };
}

export function isThemeCode(code) {
  return decode(code) !== null;
}

// The flag of one element out of a bit string of nine.
export const elementFlag = (elements, key) => elements.charAt(ELEMENT_KEYS.indexOf(key)) === '1';
