// The host avatar of prompt/bb.sh, drawn in JavaScript: hashColor hashes the hostname
// with md5sum and getChar turns the number into a run of block glyphs. A faithful port,
// which keeps the quirks of the original rather than smoothing them out:
//
//   * `md5sum <<< "$host"` hashes the hostname *plus the newline* a here-string
//     appends, so an empty hostname still hashes to something;
//   * `$((0x<32 hex digits>))` reads a 128 bit digest through the signed 64 bit
//     arithmetic of bash, so the value is the low 64 bits, wrapped;
//   * `tr -d -` turns a negative value into its magnitude *as text*, which is
//     read back into arithmetic - and may overflow there too (only exactly at
//     -2^63, where the result goes negative again and the modulo below comes up
//     negative, which bash resolves to an array element counted back from the
//     end);
//   * the division and the modulo of bash truncate towards zero, like C;
//   * getChar works on a *global* n: each call divides it by 13 and again by 8,
//     so the glyphs come from a shrinking number rather than from four
//     independent draws;
//   * the second half of the run is the first half mirrored (only ◀/▶, ◢/◣ and
//     ◤/◥ swap), so an avatar is four decisions wearing eight glyphs.
//
// tests/test-avatar.mjs checks this file against the shell functions themselves, over
// tests/golden/avatars.txt and a generated sweep.

// The glyphs and the colours of getChar, in the order its arrays hold them.
const ARRCHAR = [
  '\u25B2', '\u25B6', '\u25BC', '\u25C0', '\u25C6', '\u25CF', '\u25E2', '\u25E3',
  '\u25E4', '\u25E5', '\u25AC', '\u25AE', '\u25A0',
];
const ARRFG = [31, 32, 33, 34, 35, 36, 90, 97];

// The glyphs that getChar swaps when it mirrors, by index in ARRCHAR.
const MIRROR = { 1: 3, 3: 1, 6: 7, 7: 6, 8: 9, 9: 8 };

const MASK64 = (1n << 64n) - 1n;

// $(( ... )) of bash is signed 64 bit and wraps around instead of failing.
function wrap64(value) {
  const wrapped = value & MASK64;
  return wrapped >= 1n << 63n ? wrapped - (1n << 64n) : wrapped;
}

// ${arr[$i]} of bash reads a negative subscript as an offset from just past the
// highest index, which is reachable through the -2^63 case above.
function at(arr, index) {
  return index < 0n ? arr[arr.length + Number(index)] : arr[Number(index)];
}

// --- md5 ------------------------------------------------------------------
// Web Crypto has no md5, so it lives here: the digest is the identity of a machine, not
// a security decision. UTF-8 bytes in, as md5sum takes them for a hostname.

const MD5_SHIFT = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
];

// floor(abs(sin(i + 1)) * 2^32) for i = 0..63, written down rather than computed:
// Math.sin need not agree between engines.
const MD5_SINE = new Uint32Array([
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
  0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
  0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
  0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
  0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
  0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
  0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
]);

export function md5Hex(text) {
  const message = new TextEncoder().encode(text);
  const blockCount = Math.floor((message.length + 8) / 64) + 1;
  const padded = new Uint8Array(blockCount * 64);
  padded.set(message);
  padded[message.length] = 0x80;

  // The length of the message in bits, in the last eight bytes, little endian;
  // written as two words so it does not need 64 bit numbers of its own.
  const view = new DataView(padded.buffer);
  const bitLength = message.length * 8;
  view.setUint32(padded.length - 8, bitLength >>> 0, true);
  view.setUint32(padded.length - 4, Math.floor(bitLength / 4294967296), true);

  let a0 = 0x67452301;
  let b0 = 0xefcdab89;
  let c0 = 0x98badcfe;
  let d0 = 0x10325476;
  const words = new Uint32Array(16);

  for (let offset = 0; offset < padded.length; offset += 64) {
    for (let i = 0; i < 16; i++) words[i] = view.getUint32(offset + i * 4, true);

    let a = a0;
    let b = b0;
    let c = c0;
    let d = d0;

    for (let i = 0; i < 64; i++) {
      let f;
      let g;
      if (i < 16) {
        f = (b & c) | (~b & d);
        g = i;
      } else if (i < 32) {
        f = (d & b) | (~d & c);
        g = (5 * i + 1) % 16;
      } else if (i < 48) {
        f = b ^ c ^ d;
        g = (3 * i + 5) % 16;
      } else {
        f = c ^ (b | ~d);
        g = (7 * i) % 16;
      }
      f = (f + a + MD5_SINE[i] + words[g]) >>> 0;
      a = d;
      d = c;
      c = b;
      const shift = MD5_SHIFT[i];
      const rotated = ((f << shift) | (f >>> (32 - shift))) >>> 0;
      b = (b + rotated) >>> 0;
    }

    a0 = (a0 + a) >>> 0;
    b0 = (b0 + b) >>> 0;
    c0 = (c0 + c) >>> 0;
    d0 = (d0 + d) >>> 0;
  }

  // md5sum prints the four words little endian, which is the byte order below.
  return [a0, b0, c0, d0]
    .map((word) =>
      [0, 8, 16, 24].map((shift) => ((word >>> shift) & 0xff).toString(16).padStart(2, '0')).join('')
    )
    .join('');
}

// --- the avatar -----------------------------------------------------------

/**
 * The avatar prompt/bb.sh draws for a hostname: `count` forward glyphs and the same
 * count mirrored. Each segment carries the glyph, the bash ANSI foreground code and
 * whether it belongs to the mirrored half.
 */
export function hostAvatar(host, count = 4) {
  // n=$(md5sum <<< "$1") - the here-string appends the newline.
  let n = wrap64(BigInt(`0x${md5Hex(`${host}\n`)}`));
  // n=$(echo "$n" | tr -d -), read back into arithmetic from text.
  n = wrap64(BigInt(String(n < 0n ? -n : n)));

  const forward = [];
  for (let i = 0; i < count; i++) {
    const char = n % 13n;
    n = n / 13n;
    const colour = n % 8n;
    n = n / 8n;
    forward.push({ char, colour });
  }

  const segments = [];
  const push = (char, colour, mirrored) => {
    // getChar swaps the char number before the lookup, and only for the glyphs it
    // names; a negative char matches none.
    const swap = mirrored ? MIRROR[Number(char)] : undefined;
    const fg = Number(at(ARRFG, colour));
    segments.push({
      glyph: at(ARRCHAR, swap === undefined ? char : BigInt(swap)),
      fg,
      code: `\\[\\033[1;${fg}m\\]`,
      mirrored,
    });
  };

  for (const { char, colour } of forward) push(char, colour, false);
  // The mirrored half repeats the decisions of the forward one, backwards.
  for (let i = forward.length - 1; i >= 0; i--) push(forward[i].char, forward[i].colour, true);

  return segments;
}
