#!/usr/bin/env node
//
// The copy buttons of the page, and what they fall back to.
//
//   node tests/test-copy.mjs
//
// navigator.clipboard is exposed only to a secure context, so the page has two ways
// to copy: the clipboard API where it exists, and a selection copied by
// document.execCommand everywhere else (which is what a page served over plain http
// by ./dev.sh has). src/clipboard.js picks between them and turns whatever is left
// into a reason the page can show. Since nothing but the browser can tell the two
// contexts apart on its own, the two are faked here: the same module is run with a
// clipboard, without one, and with both refusing.
//
// The page itself is only read, not run: it must not reach past the helper into
// navigator.clipboard, must not fall back to alert() any more, and must leave every
// box selectable, because selecting the text is the way out that stays open when
// both ways of copying failed.
//
// Exit code is the number of failures.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = dirname(here);
const srcDir = join(repoRoot, 'webpage', 'frontend', 'src');
const appFile = join(srcDir, 'App.vue');
const templateFile = join(srcDir, 'template.html');

let failures = 0;
const ok = (what) => console.log(`  \x1b[32mok\x1b[0m   ${what}`);
const fail = (what) => {
  console.log(`  \x1b[31mFAIL\x1b[0m ${what}`);
  failures += 1;
};

const { copyText, CopyFailed } = await import(
  new URL(`../webpage/frontend/src/clipboard.js`, import.meta.url).href
);

// --- the browser that is faked here ---------------------------------------

// document enough for a copy: it hands out one textarea, answers execCommand, and
// records what the copy did with it, so the fallback can be held to what it promises
// (the text in a field, the field selected, and nothing of it left behind).
function fakeDocument({ copies }) {
  const made = [];
  const did = { selected: 0, ranged: 0, focused: 0, appended: [], removed: [] };
  const doc = {
    activeElement: { focus: () => (did.focused += 1) },
    createElement: () => {
      const area = {
        value: '',
        style: {},
        setAttribute() {},
        select: () => (did.selected += 1),
        setSelectionRange: () => (did.ranged += 1),
        remove: () => did.removed.push(area),
      };
      made.push(area);
      return area;
    },
    body: {
      appendChild: (node) => (did.appended.push(node), node),
      removeChild: () => {},
    },
  };
  if (copies !== null) doc.execCommand = () => copies;
  return { doc, made, did };
}

// navigator.clipboard, either the one a secure context has or nothing at all.
function setNavigator({ writes }) {
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'navigator');
  const navigatorValue = writes === null
    ? {} // an insecure context: the property is not there to be read at all
    : { clipboard: { writeText: () => (writes === 'reject' ? Promise.reject(new Error('denied by the browser')) : Promise.resolve()) } };
  Object.defineProperty(globalThis, 'navigator', { value: navigatorValue, configurable: true, writable: true });
  return () => {
    if (previous) Object.defineProperty(globalThis, 'navigator', previous);
    delete globalThis.navigator;
  };
}

function setDocument(document) {
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'document');
  globalThis.document = document;
  return () => {
    if (previous) Object.defineProperty(globalThis, 'document', previous);
    else delete globalThis.document;
  };
}

/** Run one copy in a world of the two given kinds: `writes` the clipboard API,
 *  `copies` what execCommand answers (null when the document has none). */
async function tryCopy({ writes, copies }) {
  const undoNavigator = setNavigator({ writes });
  const fake = fakeDocument({ copies });
  const undoDocument = setDocument(fake.doc);
  try {
    return { way: await copyText('the text'), fake };
  } catch (error) {
    if (!(error instanceof CopyFailed)) throw error;
    return { reason: error.reason, message: error.message, fake };
  } finally {
    undoNavigator();
    undoDocument();
  }
}

// --- the two ways of copying ----------------------------------------------

const expected = new Map([
  // A secure page: the API takes it and nothing of the older way is touched.
  ['api', { writes: 'ok', copies: true, way: 'clipboard' }],
  // Plain http: no API to ask, so the selection copies it - which is the whole
  // point, and the case that used to answer with an alert.
  ['http', { writes: null, copies: true, way: 'selection' }],
  // The API refused (focus lost, permission off) and the selection takes over.
  ['refused', { writes: 'reject', copies: true, way: 'selection' }],
  // Both refused: the reason the page shows, and the two differ.
  ['no-clipboard', { writes: null, copies: false, reason: 'insecure' }],
  ['denied', { writes: 'reject', copies: false, reason: 'denied' }],
]);

for (const [name, want] of expected) {
  const got = await tryCopy({ writes: want.writes, copies: want.copies });
  const outcome = want.way ?? want.reason;
  const have = got.way ?? got.reason;
  if (have !== outcome) {
    fail(`${name}: copied as ${want.way ?? `refused with ${want.reason}`}, got ${have ?? 'a success'}`);
    continue;
  }
  ok(`${name}: ${want.way ? `copied by the ${want.way}` : `refused, and says why (${want.reason})`}`);
}

// --- that the fallback really selects something ---------------------------

const fellBack = await tryCopy({ writes: null, copies: true });
const [field] = fellBack.fake.made;
if (!field || field.value !== 'the text') {
  fail('the fallback puts the text into a field of the document');
} else {
  ok('the fallback puts the text into a field of the document');
}
if (fellBack.fake.did.selected !== 1) {
  fail('that field is selected, since the selection is what gets copied');
} else {
  ok('that field is selected, since the selection is what gets copied');
}
if (fellBack.fake.did.appended.length !== 1 || fellBack.fake.did.removed.length !== 1) {
  fail('the field is taken out of the page again, however the copy went');
} else {
  ok('the field is taken out of the page again, however the copy went');
}
if (fellBack.fake.did.focused !== 1) {
  fail('the focus the copy took from the button is given back');
} else {
  ok('the focus the copy took from the button is given back');
}

// Every way of copying says something when it failed, and says it to be read: a
// reason without a sentence is how the old alert ("copy it manually") came back.
for (const [name, want] of expected) {
  if (!want.reason) continue;
  const got = await tryCopy({ writes: want.writes, copies: want.copies });
  if (!/Ctrl\+C/.test(got.message ?? '')) {
    fail(`${name}: the message of a failed copy keeps the user to Ctrl+C`);
  } else {
    ok(`${name}: the message of a failed copy keeps the user to Ctrl+C`);
  }
}

// --- the page over them ---------------------------------------------------

const app = readFileSync(appFile, 'utf8');
const template = readFileSync(templateFile, 'utf8');

// The page may not go around the helper: navigator.clipboard is the property that
// does not exist on an http page, so reading it in App.vue is the original bug.
// Comments are not code and may name the property to explain it - only the
// statements of the script are looked at.
const code = app
  .split('\n')
  .filter((line) => !/^\s*(\/\/|\*|\/\*)/.test(line))
  .join('\n');
if (/navigator\.clipboard/.test(code)) {
  fail('App.vue copies through ./clipboard.js, never through navigator.clipboard itself');
} else {
  ok('App.vue copies through ./clipboard.js, never through navigator.clipboard itself');
}

// No alert: a failed copy is shown in the page it failed in, next to the box.
if (/alert\(/.test(code)) {
  fail('App.vue has no alert left to interrupt the page with');
} else {
  ok('App.vue has no alert left to interrupt the page with');
}

// Every copy button of the page goes through a handler of the script, and every
// box selects itself on a click - whichever way the copy went, a click and Ctrl+C
// has to copy the text that is being looked at.
const buttons = [
  ...new Set(
    [...template.matchAll(/<button @click="(copy[A-Za-z]*)"/g)].map((m) => m[1]),
  ),
];
const copyHandlers = [...app.matchAll(/^async function (copy[A-Za-z]*)\(/gm)].map((m) => m[1]);
const unbound = buttons.filter((name) => !copyHandlers.includes(name));
if (!buttons.length || unbound.length) {
  fail(`every copy button names an async handler of App.vue (missing: ${unbound.join(', ') || 'none'})`);
} else {
  ok(`the copy buttons (${buttons.join(', ')}) are handlers of App.vue`);
}

const clicks = [...template.matchAll(/@click="(select[A-Za-z]*)"/g)].map((m) => m[1]);
if (!clicks.length || new Set(clicks).size !== 1 || !app.includes(`function ${clicks[0]}(`)) {
  fail('every box of the page selects itself on a click, through one handler');
} else {
  ok(`every box selects itself on a click (${clicks[0]})`);
}

const shown = [...template.matchAll(/v-if="(copy[A-Za-z]*Error)"/g)].map((m) => m[1]);
const undeclared = shown.filter((name) => !app.includes(`const ${name} = ref(`));
if (!shown.length || undeclared.length) {
  fail(`the failure of each box is shown under it (missing: ${undeclared.join(', ') || 'none'})`);
} else {
  ok(`the failure of each box is shown under it (${shown.join(', ')})`);
}

process.exit(failures === 0 ? 0 : 1);
