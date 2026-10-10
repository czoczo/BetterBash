#!/usr/bin/env node
//
// The host avatar of prompt/bb.sh, drawn by prompt/bb.sh and by the WebUI.
//
//   node tests/test-avatar.mjs            # check the page against the shell
//   node tests/test-avatar.mjs --write    # rewrite tests/golden/avatars.txt
//
// prompt/bb.sh draws the host avatar with hashColor/getChar; webpage/frontend/
// src/avatar.js draws it for the preview on the page. The two are separate
// implementations of one look, so this runs the shell functions (extracted from
// prompt/bb.sh without running the prompt) and the JavaScript port over the same
// hostnames and compares them, both against tests/golden/avatars.txt.
//
// The shell is the truth: --write regenerates the fixture from it, and a change
// to hashColor or getChar shows up here as a failing fixture rather than as the
// page quietly disagreeing with every prompt. md5Hex of avatar.js is checked
// against node:crypto in passing, since everything the avatar is comes from it.
//
// The page draws the name it previews an avatar of - src/hostname.js does, on every
// load of the page - so the last section holds that draw too: that the page really
// asks for a name rather than spelling one out, and that whatever name it gets fits
// the field the name is typed into.
//
// Exit code is the number of failures.

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { hostAvatar, md5Hex } from '../webpage/frontend/src/avatar.js';
import { ADJECTIVES, MAX_HOSTNAME_LENGTH, NOUNS, randomHostname } from '../webpage/frontend/src/hostname.js';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = dirname(here);
const bbSh = join(repoRoot, 'prompt', 'bb.sh');
const goldenFile = join(repoRoot, 'tests', 'golden', 'avatars.txt');
const write = process.argv.includes('--write');

let failures = 0;
const ok = (what) => console.log(`  \x1b[32mok\x1b[0m   ${what}`);
const fail = (what) => {
  console.log(`  \x1b[31mFAIL\x1b[0m ${what}`);
  failures += 1;
};

// --- the hostnames -------------------------------------------------------

// The hostnames every run checks. The odd ones are the ones a port trips over:
// the empty hostname (md5sum of a lone newline), a name with a space, a name in
// a script that is not ASCII, a name of many characters, a name that keeps its
// trailing newline. --write draws the fixture from exactly this list.
const builtinHosts = [
  // The name the preview showed by default for as long as the page had one, and the
  // name every fixture below has been drawn over since - the page draws its own now.
  'myhost',
  '',
  'localhost',
  'HOST',
  'my host',
  'host.local',
  'host-name',
  'podman-build-a3f3c1',
  'x86-64-workstation',
  '0',
  '1234567890123456789012345678901234567890123456789012345678901234',
  'żółw',
  '☃',
  'host with  trailing and leading  space ',
  'trailing-newline-host\n',
];
// A sweep over names of both signs of the wrapped digest and of every corner of
// the glyph table, so a port cannot pass by checking only the shapes it thought of.
for (let i = 0; i < 120; i++) builtinHosts.push(`sweep-${i}-${(i * 7919).toString(36)}`);

// --- the shell side ------------------------------------------------------

// getChar and hashColor, plus the arrays in front of them, cut out of
// prompt/bb.sh: from the glyph table to the end of hashColor. Everything the
// avatar is lives between those two markers, and nothing of the prompt runs -
// sourcing prompt/bb.sh itself would install a tree and build a PS1.
// Hostnames come in as arguments, so they need no quoting of their own, and one
// bash draws them all. Its records are separated by a record separator.
function shellAvatars(hosts) {
  const script = `
set -u
drawing=$(mktemp) || exit 1
trap 'rm -f "$drawing"' EXIT INT TERM
awk '
  /^arrchar=/ && state == 0 { state = 1 }
  state >= 1 { print }
  /^function hashColor / && state == 1 { state = 2 }
  state == 2 && /^}$/ { exit }
' "$BB_SH" > "$drawing" || exit 1
. "$drawing" || exit 1
if ! command -v hashColor > /dev/null; then
  printf 'test-avatar: no hashColor in %s - did the avatar move away from getChar?\n' "$BB_SH" >&2
  exit 1
fi
first=1
for host in "$@"; do
  if [ "$first" = 0 ]; then printf '\\x1e'; fi
  first=0
  hashColor "$host" 4
done
`;
  const out = execFileSync('bash', ['-c', script, 'test-avatar', ...hosts], {
    env: { ...process.env, BB_SH: bbSh },
    maxBuffer: 16 * 1024 * 1024,
  }).toString('utf8');
  return out.split('\x1e').map(parseHashColor);
}

// hashColor prints \[\033[1;<fg>m<glyph>\] per segment, wrapped in a preamble
// and a reset; only the segments are of interest.
function parseHashColor(raw) {
  const segments = [];
  for (const part of raw.split('\x1b[1;').slice(1)) {
    const head = part.match(/^(\d+)m/);
    if (!head) continue;
    let rest = part.slice(head[0].length).replace(/^\\/, '');
    const end = rest.indexOf('\\]');
    segments.push({ glyph: end < 0 ? rest : rest.slice(0, end), fg: Number(head[1]) });
  }
  // The preamble and the trailing reset are one extra segment each way.
  return segments.slice(1, -1);
}

// --- the fixture ---------------------------------------------------------

function render(host, segments) {
  return [`### ${JSON.stringify(host)}`, ...segments.map((s) => `${s.glyph}\t${s.fg}`)].join('\n');
}

// The fixture line by line: a `### "<host>"` line opens a record, every
// "<glyph><tab><fg>" line after it belongs to that record. Comments in front of
// the first record are neither.
function parseGolden(text) {
  const records = [];
  let record = null;
  for (const line of text.split('\n')) {
    if (line.startsWith('### ')) {
      record = { host: JSON.parse(line.slice(4)), segments: [] };
      records.push(record);
    } else if (record && line.includes('\t')) {
      const tab = line.indexOf('\t');
      record.segments.push({ glyph: line.slice(0, tab), fg: Number(line.slice(tab + 1)) });
    }
  }
  return records;
}

const same = (a, b) =>
  a.length === b.length && a.every((s, i) => s.glyph === b[i].glyph && s.fg === b[i].fg);

// --- the checks ----------------------------------------------------------

// The fixture, when there is one, is both the list of hostnames to check and
// the expected drawing of them; --write starts from the list above instead.
let fixture = [];
try {
  fixture = parseGolden(readFileSync(goldenFile, 'utf8'));
} catch {
  if (!write) fail(`no fixture at ${goldenFile}; run tests/test-avatar.mjs --write`);
}
const hosts = [...builtinHosts, ...fixture.map((r) => r.host).filter((h) => !builtinHosts.includes(h))];

const shellAll = shellAvatars(hosts);

// What the shell drew, keyed by hostname: both comparisons below look a drawing
// up by the hostname it belongs to, so a fixture and a generated list may differ
// in order and in length. Only disagreements get a line each; an ok line says
// what the run covered.
const drawn = new Map(hosts.map((host, i) => [host, shellAll[i]]));

function report(label, checked, wrong) {
  if (!wrong.length) {
    ok(`${label} (${checked} hostnames)`);
    return;
  }
  wrong
    .map(
      ([host, expected, actual]) =>
        `${JSON.stringify(host)}\n         expected: ${JSON.stringify(expected)}\n` +
        `         drew:     ${JSON.stringify(actual)}`
    )
    .slice(0, 10)
    .forEach((what) => fail(`${label}: ${what}`));
  if (wrong.length > 10) fail(`${label}: ... and ${wrong.length - 10} more`);
}

if (!write && fixture.length) {
  const malformed = fixture.filter((r) => r.segments.length !== 8);
  if (malformed.length) {
    fail(`fixture: ${malformed.length} record(s) do not hold eight segments`);
  }
  report(
    'prompt/bb.sh still draws tests/golden/avatars.txt',
    fixture.length,
    fixture
      .filter((r) => !same(r.segments, drawn.get(r.host)))
      .map((r) => [r.host, r.segments, drawn.get(r.host)])
  );
}

report(
  'src/avatar.js draws what prompt/bb.sh draws',
  hosts.length,
  hosts
    .filter((host) => !same(drawn.get(host), hostAvatar(host, 4)))
    .map((host) => [host, drawn.get(host), hostAvatar(host, 4)])
);

// The digest is the whole of the avatar, so it is checked on its own too.
const md5Strings = ['', 'myhost', 'żółw', 'x'.repeat(200), 'a\nb', '\u00e5\u0306'];
const wrongDigests = md5Strings.filter(
  (s) => md5Hex(s) !== createHash('md5').update(Buffer.from(s, 'utf8')).digest('hex')
);
if (wrongDigests.length) {
  wrongDigests.forEach((s) => fail(`md5Hex(${JSON.stringify(s)}) is not what md5sum computes`));
} else {
  ok(`md5Hex of src/avatar.js matches md5sum (${md5Strings.length} strings)`);
}

// --- the page ------------------------------------------------------------

// The page draws its avatar, it does not paint one. The preview used to carry
// eight spans of glyphs and colours - the avatar of "myhost", baked into the
// markup. Drawing it from the hostname field is what is checked here: that no
// avatar glyph is left in the markup, and that every place an avatar shows is fed by
// the field.
const srcDir = join(repoRoot, 'webpage', 'frontend', 'src');
const template = readFileSync(join(srcDir, 'template.html'), 'utf8');
const app = readFileSync(join(srcDir, 'App.vue'), 'utf8');

const painted = template.match(/[\u25B2\u25BC\u25C0\u25B6\u25C6\u25CF\u25E2\u25E3\u25E4\u25E5\u25AC\u25AE\u25A0]/g) || [];
if (painted.length) {
  fail(`page: ${painted.length} avatar glyph(s) painted into template.html instead of drawn`);
}

// The compact line of the preview is still drawn in the markup, and loops over
// avatarSegments; the two top lines come from src/preview.js, and it is App.vue that
// hands that model the same drawing. Three places an avatar shows, as it were - what
// may not happen is one of them painting an avatar of its own instead.
const loops = (template.match(/v-for="\(segment, index\) in avatarSegments"/g) || []).length;
const fedToModel = /avatar:\s*avatarSegments\.value\./.test(app);
const hostsNamed = template.match(/myhost/g) || [];
if (loops < 1 || !fedToModel || hostsNamed.length) {
  fail(
    `page: ${loops} avatar loop(s) in the markup (want the compact line at least), the model is ${fedToModel ? '' : 'not '}fed the avatar, ${hostsNamed.length} hostname(s) spelled out in the template (want 0)`
  );
} else {
  ok('page: the avatar and the host of the preview all follow the hostname field');
}

// --- the name the page draws ---------------------------------------------

// The name the field starts at is drawn rather than written down: a page cannot know
// the machine it was opened on, so it names one for itself and draws another on
// every load. Two things are worth holding of a name chosen by dice - that the page
// really asks for one (a name written into App.vue would be the same machine for
// everyone, which is what the draw replaced), and that however the dice fall the
// name is short enough for the field it lands in.
//
// The field is the awkward half of that second one: maxlength stops a *typed* name
// at its number of characters, but stops a name set by the page not at all, and a
// host longer than the field would be a host whose avatar is not the avatar of what
// the field shows. So the longest name src/hostname.js can make is measured against
// the maxlength of the input, and not against a guess of a reasonable length.
const drawnFromDice = /const previewHostname = ref\(randomHostname\(\)\)/.test(app);
const pinnedHost = app.match(/const previewHostname = ref\('([^']*)'\)/);
if (drawnFromDice && pinnedHost) {
  fail(`page: App.vue both draws its host and pins one (${JSON.stringify(pinnedHost[1])})`);
} else if (!drawnFromDice) {
  fail('page: App.vue does not start the hostname field from randomHostname() of src/hostname.js');
} else {
  ok('page: the host of the preview is drawn on every load, not written down');
}

// The maxlength the input of the field gives itself, and the shape of a name: two
// words of the two lists and the dash between them, and nothing else - in particular
// no digits, for the number `hostnamegen` puts behind its two words is left out of
// the names of the page on purpose.
const maxlength = Number((template.match(/id="avatar-host"[\s\S]*?maxlength="(\d+)"/) || [])[1]);
const NAME = /^([a-z]+)-([a-z]+)$/;

const wrong = [];
if (!maxlength) wrong.push('the hostname field of the page has no maxlength to be kept to');

// The longest name the file can make, measured again over the lists it makes names
// out of, so that the constant the file states is not one it quietly forgot to
// widen when it widened a word.
const longest =
  Math.max(...ADJECTIVES.map((w) => w.length)) + 1 + Math.max(...NOUNS.map((w) => w.length));
if (MAX_HOSTNAME_LENGTH !== longest) {
  wrong.push(`src/hostname.js states ${MAX_HOSTNAME_LENGTH} as its longest name, the lists allow ${longest}`);
}
if (maxlength && longest > maxlength) {
  wrong.push(`the longest name src/hostname.js can make is ${longest} characters and the field takes ${maxlength}`);
}

// Every word of both lists has to be able to stand in a name: one with a dash, an
// upper case letter or a space in it would be a name the shape below does not find.
for (const [list, what] of [[ADJECTIVES, 'adjective'], [NOUNS, 'noun']]) {
  const odd = list.filter((word) => !/^[a-z]+$/.test(word));
  if (odd.length) wrong.push(`${what} list of src/hostname.js holds ${odd.map((w) => JSON.stringify(w)).join(', ')}`);
}

// The two draws a name is spelled out of, in the order they are spelled with, and
// the limits they are drawn under - the contract the page does not use but this
// holds, because it is what makes `below` below.
const limits = [];
const first = randomHostname({
  below: (limit) => (limits.push(limit), 0),
});
if (limits.join(',') !== [ADJECTIVES.length, NOUNS.length].join(',')) {
  wrong.push(`a name draws its two words under limits ${limits.join(', ')}, want ${[ADJECTIVES.length, NOUNS.length].join(', ')}`);
}
if (first !== `${ADJECTIVES[0]}-${NOUNS[0]}`) {
  wrong.push(`a name of two zeroes is ${JSON.stringify(first)}, want ${JSON.stringify(`${ADJECTIVES[0]}-${NOUNS[0]}`)}`);
}

// A sweep of the real dice: every name of the shape, none of it longer than the
// field, every word of it a word of the lists, and the names differing - a draw that
// drew the same name every load would be a name written down.
const sweep = Array.from({ length: 2000 }, () => randomHostname());
const malformed = sweep.filter((name) => !NAME.test(name));
const overlong = sweep.filter((name) => [...name].length > maxlength);
const offList = sweep.filter((name) => {
  const parts = NAME.exec(name);
  return parts && (!ADJECTIVES.includes(parts[1]) || !NOUNS.includes(parts[2]));
});
const distinct = new Set(sweep).size;
if (malformed.length) wrong.push(`${malformed.length} of ${sweep.length} names are not of the shape adjective-noun (${malformed.slice(0, 3).join(', ')})`);
if (overlong.length) wrong.push(`${overlong.length} of ${sweep.length} names are too long for the field (${overlong.slice(0, 3).join(', ')})`);
if (offList.length) wrong.push(`${offList.length} of ${sweep.length} names are made of words of no list (${offList.slice(0, 3).join(', ')})`);
if (distinct < 1000) wrong.push(`${sweep.length} draws came up ${distinct} distinct name(s)`);

if (wrong.length) wrong.forEach((what) => fail(what));
else {
  ok(
    `src/hostname.js draws names of adjective-noun over ${sweep.length} draws, at most ${longest} characters into a ${maxlength} character field (${distinct} of them distinct)`
  );
}

if (write) {
  const lines = hosts.map((host, i) => render(host, shellAll[i])).join('\n');
  const banner = [
    '# Host avatars the prompt of prompt/bb.sh draws, generated by tests/test-avatar.mjs --write.',
    '#',
    '# One record per hostname: a `### "<hostname>"` line (JSON quoted, so an empty',
    '# hostname and one holding spaces are unambiguous) followed by the eight segments',
    '# getChar printed for it, as "<glyph><tab><ANSI foreground code>". The JavaScript',
    '# port in webpage/frontend/src/avatar.js and the shell functions have to draw',
    '# exactly this. Do not edit it by hand: it is what the shell drew.',
    '',
  ].join('\n');
  mkdirSync(dirname(goldenFile), { recursive: true });
  writeFileSync(goldenFile, `${banner}${lines}\n`);
  ok(`wrote ${hosts.length} hostnames to ${goldenFile}`);
}

console.log(failures ? `\n${failures} failure(s)` : `\nall ${hosts.length} hostnames agree`);
process.exit(failures ? 1 : 0);
