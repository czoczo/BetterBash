#!/usr/bin/env node
//
// The theme code of the page and the theme code of the shell.
//
//   node tests/test-theme-code.mjs
//
// A theme is written by the page, read by the shell that installs it, and read
// again by the page when a link to it is opened, so the two of them have to
// spell out the same bits. prompt/bb-theme.sh decodes what the page encodes;
// this reads a code the other way round too, and holds both to the corpus of
// codes the retired Go backend issued, whose decodings tests/golden pins.
//
// What is checked here is the shape of the codes - which character carries which
// bit - and not the drawing of the prompt that follows from them: that is
// tests/test-frame.mjs and tests/test-theme.sh.
//
// Exit code is the number of failures.

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  ALL_ELEMENTS_ON,
  COLOR_KEYS,
  ELEMENT_KEYS,
  FILL_KEY,
  FLAG_BITS,
  RESERVED_BITS,
  bitsToCode,
  decode,
  elementFlag,
  encode,
  orderByRank,
  orderRank,
} from '../webpage/frontend/src/theme-code.js';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = dirname(here);
const library = join(repoRoot, 'prompt', 'bb-theme.sh');
const goldenCodes = join(repoRoot, 'tests', 'golden', 'theme-codes.txt');

let failures = 0;
const ok = (what) => console.log(`  \x1b[32mok\x1b[0m   ${what}`);
const fail = (what) => {
  console.log(`  \x1b[31mFAIL\x1b[0m ${what}`);
  failures += 1;
};

// --- reading codes with the shell -----------------------------------------

// One shell for every code asked about: prompt/bb-theme.sh is sourced once and
// asked about each code in turn, printing what it decoded as
//
//   code|flag bits|KEY=value;KEY=value;...
//
// A code the library refuses is printed with nothing between the separators, so
// that a refusal can be told from a decoding without a second run.
const shellDriver = `
. "$1" 2>/dev/null || exit 1
shift
for code in "$@"; do
  flags=$(bb_theme_flags "$code" 2>/dev/null)
  colors=$(bb_theme_decode "$code" 2>/dev/null | tr '\\n' '\\037')
  printf '%s|%s|%s\\n' "$code" "$flags" "$colors"
done
`;

function shellReads(codes) {
  const out = execFileSync('bash', ['-c', shellDriver, 'test-theme-code', library, ...codes], {
    cwd: repoRoot,
    encoding: 'utf8',
  });
  const read = new Map();
  for (const record of out.split('\n')) {
    if (!record) continue;
    const at = record.indexOf('|');
    const rest = record.slice(at + 1);
    const code = record.slice(0, at);
    const flags = rest.slice(0, rest.indexOf('|'));
    const colors = {};
    // The assignments that are not colours - the element flags prompt/bb.sh sources
    // - are kept as the library wrote them, quotes and all, because what is asked
    // of them is whether the file says PROMPT_FILL='true' or ='false'.
    const assignments = [];
    for (const pair of rest.slice(rest.indexOf('|') + 1).split('\u001f')) {
      if (!pair.includes('=')) continue;
      const key = pair.slice(0, pair.indexOf('='));
      // The library writes the value quoted for the shell it writes theme.sh
      // with; what is compared here is what that shell expands to.
      if (COLOR_KEYS.includes(key))
        colors[key] = pair.slice(pair.indexOf('=') + 1).replace(/^'(.*)'$/, '$1');
      else assignments.push(pair);
    }
    read.set(code, { flags, colors, assignments: assignments.join(';') });
  }
  return read;
}

// The colours of a theme as prompt/bb-theme.sh writes them into theme.sh.
const escapeOf = (attrs) =>
  `\\[\\033[${attrs.isBold ? 1 : 0};${attrs.isLight ? attrs.baseCode + 60 : attrs.baseCode}m\\]`;

// --- the corpus ------------------------------------------------------------

// Every code of the corpus, both decoded. The corpus is what the retired backend
// issued and still issues in shared links, and tests/golden/theme-golden.txt pins
// what the shell makes of it; what the page makes of it has to be the same
// theme, or a link opened from a note shows another one than the one it installed.
{
  const codes = readFileSync(goldenCodes, 'utf8').split('\n').filter(Boolean);
  const read = shellReads(codes);
  const wrong = [];
  for (const code of codes) {
    const decoded = decode(code);
    const fromShell = read.get(code);
    if (!decoded) {
      wrong.push(`${code}: the page cannot read a code of the corpus`);
      continue;
    }
    if (!fromShell || !fromShell.colors[COLOR_KEYS[0]]) {
      wrong.push(`${code}: the shell cannot read a code of the corpus`);
      continue;
    }
    if (decoded.version !== 0) wrong.push(`${code}: not read as the shape it is (v${decoded.version})`);
    for (const key of COLOR_KEYS) {
      if (escapeOf(decoded.colors[key]) !== fromShell.colors[key])
        wrong.push(`${code}: ${key} reads as ${escapeOf(decoded.colors[key])} here, ${fromShell.colors[key]} there`);
    }
    if (decoded.elements !== fromShell.flags)
      wrong.push(`${code}: elements ${decoded.elements} here, ${fromShell.flags} there`);
  }
  if (wrong.length) wrong.slice(0, 8).forEach((what) => fail(what));
  else ok(`the page and the shell read ${codes.length} codes of the corpus alike`);
}

// A code of the new shape out of its fields, every other bit of it zero: the
// element flags of the line (nine, the tenth flag of the fill following them), the
// two ordering ranks, the fill bit as a code holds it, and the bits a later
// release is asked to keep zero. A check names the field it means rather than a
// code, because which character carries a bit depends on every bit before it.
function withFields({ left = 0, right = 0, fill = 0, reserved = 0 } = {}) {
  const bits = (
    '0'.repeat(40) +
    ALL_ELEMENTS_ON.slice(0, FLAG_BITS) +
    left.toString(2).padStart(7, '0') +
    right.toString(2).padStart(5, '0') +
    fill.toString(2).padStart(1, '0') +
    reserved.toString(2).padStart(RESERVED_BITS, '0')
  )
    .split('')
    .map(Number);
  return '1' + bitsToCode(bits);
}

// --- codes the page writes --------------------------------------------------

// Codes of the new shape, over every combination the page can be asked for: the
// elements of the top line in each of the states the checkboxes hold it in, and
// colours drawn at random. Each is decoded by the shell, and each has to come
// back with the same colours and the same element flags.
{
  const pick = (n) => Math.floor(Math.random() * n);
  const randomColors = () => {
    const colors = {};
    for (const key of COLOR_KEYS) {
      let baseCode;
      do {
        baseCode = 30 + pick(8);
      } while (baseCode === 30 && pick(2) === 0);
      colors[key] = { baseCode, isLight: pick(2) === 1, isBold: pick(2) === 1 };
    }
    return colors;
  };

  const cases = [];
  // All on, all off, and one element off at a time - the states the checkboxes
  // of the page are actually put in.
  cases.push(ALL_ELEMENTS_ON);
  cases.push('0'.repeat(ELEMENT_KEYS.length));
  for (let i = 0; i < ELEMENT_KEYS.length; i++)
    cases.push(`${'1'.repeat(i)}0${'1'.repeat(ELEMENT_KEYS.length - i - 1)}`);
  for (let i = 0; i < 40; i++) {
    let bits = '';
    for (let k = 0; k < ELEMENT_KEYS.length; k++) bits += pick(2) ? '1' : '0';
    cases.push(bits);
  }

  const codes = cases.map((elements) => encode({ colors: randomColors(), elements }));
  const wrong = [];
  const read = shellReads(codes);
  codes.forEach((code, i) => {
    const fromShell = read.get(code);
    if (!fromShell || !fromShell.colors[COLOR_KEYS[0]]) {
      wrong.push(`${code}: the shell refused a code the page wrote (elements ${cases[i]})`);
      return;
    }
    const decoded = decode(code);
    if (!decoded) {
      wrong.push(`${code}: the page cannot read back what it wrote`);
      return;
    }
    if (decoded.version !== 1) wrong.push(`${code}: not the shape it was written as (v${decoded.version})`);
    if (decoded.elements !== cases[i])
      wrong.push(`${code}: elements ${decoded.elements} read back from ${cases[i]}`);
    if (fromShell.flags !== cases[i])
      wrong.push(`${code}: shell flags ${fromShell.flags}, page flags ${cases[i]}`);
    for (const key of COLOR_KEYS) {
      if (escapeOf(decoded.colors[key]) !== fromShell.colors[key])
        wrong.push(`${code}: ${key} ${escapeOf(decoded.colors[key])} here, ${fromShell.colors[key]} there`);
    }
  });
  if (wrong.length) wrong.slice(0, 8).forEach((what) => fail(what));
  else ok(`${codes.length} codes the page wrote are read by the shell as they were written`);
}

// --- codes the shell writes --------------------------------------------------

// The word "rand" of the install command draws a code on the machine, and the
// page has to read that code to show the theme it stands for.
{
  const out = execFileSync('bash', ['-c', '. "$1" && bb_random_theme_code', 'x', library], {
    cwd: repoRoot,
    encoding: 'utf8',
  }).trim();
  const decoded = decode(out);
  if (!decoded) fail(`the page cannot read the code the shell drew (${out})`);
  else if (decoded.elements !== ALL_ELEMENTS_ON)
    fail(`the code the shell drew hides elements of its own accord (${out}: ${decoded.elements})`);
  else ok(`the page reads the code the shell drew (${out})`);
}

// --- the border fill --------------------------------------------------------

// Nine flags of the elements, and the tenth of the fill that stands between them.
// The bit it takes was one of the reserved ones, so its meaning is held against
// its name: zero is the fill, which is what every code written before the flag -
// every code of eight characters, and every code of thirteen with its tail of zero
// bits - says, and one is a line holding nothing but the elements that show. What
// a code therefore means is checked of both readers, because a theme the page
// shortens has to be shortened by the shell too.
{
  const silent = withFields(); // every reserved bit zero, as an older code holds it
  const shortened = withFields({ fill: 1 });
  const wrong = [];
  const read = shellReads([silent, shortened]);

  for (const [code, fills, what] of [
    [silent, true, 'a code that never spoke of the fill'],
    [shortened, false, 'a code asking for no fill'],
  ]) {
    const decoded = decode(code);
    if (!decoded) {
      wrong.push(`${code}: the page refuses a code of this shape (${what})`);
      continue;
    }
    if (elementFlag(decoded.elements, FILL_KEY) !== fills)
      wrong.push(
        `${code}: ${what} reads as fill ${elementFlag(decoded.elements, FILL_KEY)} in the page, want ${fills}`
      );
    const fromShell = read.get(code);
    if (!fromShell || !fromShell.colors[COLOR_KEYS[0]]) {
      wrong.push(`${code}: the shell refuses a code of this shape (${what})`);
      continue;
    }
    // bb_theme_flags prints the flags as they are meant, the fill last and back to
    // its name, so a one there is the fill showing.
    if (fromShell.flags.charAt(ELEMENT_KEYS.indexOf(FILL_KEY)) !== (fills ? '1' : '0'))
      wrong.push(
        `${code}: ${what} reads as ${fromShell.flags} in the shell, want the fill ${fills ? 'on' : 'off'}`
      );
    // And the assignment prompt/bb.sh sources says the same.
    if (!fromShell.assignments.includes(`${FILL_KEY}=${fills ? "'true'" : "'false'"}`))
      wrong.push(`${code}: ${what} leaves no ${FILL_KEY}=${fills ? "'true'" : "'false'"} to source`);
  }

  // The fill is written back into the bit it was read out of, and the page agrees
  // with itself about a code it read: what it encodes from a decoded theme is that
  // theme's code again.
  for (const code of [silent, shortened]) {
    const decoded = decode(code);
    if (decoded && encode(decoded) !== code)
      wrong.push(`${code}: encoding what it decodes writes ${encode(decoded)}`);
  }

  if (wrong.length) wrong.slice(0, 6).forEach((what) => fail(what));
  else ok('the fill of a code is held against its name, and both readers say so');
}

// --- the shape of a code ---------------------------------------------------

// A code of the new shape is refused when it is not one: of another version, of
// an order that does not exist, or with something written into the bits kept for
// a later version. The page and the shell have to refuse the same things, or a
// link the page accepts installs a theme the installer will not have.
{
  const rejected = [
    '2AAAAAAAAAAAA', // of the next version, read as this one
    'AAAAAAAAAAAAB', // eight and a bit characters, of neither shape
    '1AAAAAAAAAAB?', // out of the alphabet
  ];
  const codes = [
    ...rejected,
    withFields({ left: 120 }),
    withFields({ left: 127 }),
    withFields({ right: 24 }),
    withFields({ right: 31 }),
    withFields({ reserved: 1 }),
    withFields({ reserved: (1 << RESERVED_BITS) - 1 }),
  ];
  // The last order that does exist, of each half, is read by both.
  const valid = [[119, 23], [0, 0], [1, 1]].map(([left, right]) => ({ code: withFields({ left, right }), left, right }));

  const wrong = [];
  const read = shellReads([...codes, ...valid.map((v) => v.code)]);
  for (const code of codes) {
    if (decode(code) !== null) wrong.push(`${code}: the page read a code it should refuse`);
    const fromShell = read.get(code);
    if (fromShell && fromShell.colors[COLOR_KEYS[0]])
      wrong.push(`${code}: the shell read a code it should refuse`);
  }
  for (const { code, left, right } of valid) {
    const decoded = decode(code);
    if (!decoded) wrong.push(`${code}: a code of the last order that exists was refused`);
    else if (decoded.leftOrder !== left || decoded.rightOrder !== right)
      wrong.push(`${code}: orders ${decoded.leftOrder}/${decoded.rightOrder}, want ${left}/${right}`);
    else if (!read.get(code)?.colors[COLOR_KEYS[0]]) wrong.push(`${code}: the shell refused a code of orders ${left}/${right}`);
  }
  if (wrong.length) wrong.slice(0, 8).forEach((what) => fail(what));
  else ok('both refuse what is not a code of this shape, and read the last orders that exist');
}

// --- the orders ------------------------------------------------------------

// The rank of an order and the order of a rank, in both halves: every order of
// four elements and every order of five has to come back to itself, and no rank
// may name the same order twice.
{
  const wrong = [];
  for (const count of [4, 5]) {
    const seen = new Set();
    for (let rank = 0; rank < factorial(count); rank++) {
      const order = orderByRank(rank, count);
      if (!order) {
        wrong.push(`rank ${rank} of ${count} elements has no order`);
        continue;
      }
      if (orderRank(order, count) !== rank) wrong.push(`rank ${rank} of ${count} comes back as ${orderRank(order, count)}`);
      const key = order.join('');
      if (seen.has(key)) wrong.push(`rank ${rank} of ${count} repeats ${key}`);
      seen.add(key);
    }
    if (seen.size !== factorial(count)) wrong.push(`${count} elements gave ${seen.size} orders, want ${factorial(count)}`);
    if (orderByRank(factorial(count), count) !== null) wrong.push(`${count} elements have an order at rank ${factorial(count)}`);
  }
  if (wrong.length) wrong.slice(0, 8).forEach((what) => fail(what));
  else ok('the orders of four and of five elements rank and unrank without repeating one');
}

function factorial(count) {
  return count <= 1 ? 1 : count * factorial(count - 1);
}

console.log('');
if (failures === 0) console.log('the page and the shell spell the same theme code');
else console.log(`${failures} check(s) failed`);
process.exit(failures);
