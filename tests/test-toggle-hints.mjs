#!/usr/bin/env node
//
// The bubbles that explain the two toggles of the install commands.
//
//   node tests/test-toggle-hints.mjs
//
// The Random and Auto checkboxes of the page change the command shown under them in
// ways that are not to be seen in it: one puts the word "rand" where a theme code
// stands, the other takes the question out of the command. The page says so in a
// bubble painted in the accent colour, hung over the pair it belongs to, and this
// checks three things around it:
//
//   * every tab panel has one bubble per toggle, wrapped around the checkbox and its
//     label, which is the pair the pointer of a user finds,
//   * the sentence the bubble paints is the sentence the checkbox hands to an assistive
//     technology (aria-describedby names the bubble and nothing else), and no toggle
//     keeps a title next to it, because a title is a second bubble, grey and late,
//   * the stylesheet paints the bubble with the accent of the theme, hides it until
//     the pointer is on the pair, and shows it to the pointer alone: neither a click
//     on the checkbox nor the keyboard may keep a bubble standing once the pointer
//     that asked for it has gone away.
//
// The words of a bubble are only worth painting if the command does what they say, so
// the claim of each is tried against src/config.js, the one place the commands come
// from.
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
const styleFile = join(srcDir, 'style.css');

const app = readFileSync(appFile, 'utf8');
const template = readFileSync(templateFile, 'utf8');
const style = readFileSync(styleFile, 'utf8');

let failures = 0;
const ok = (what) => console.log(`  \x1b[32mok\x1b[0m   ${what}`);
const fail = (what) => {
  console.log(`  \x1b[31mFAIL\x1b[0m ${what}`);
  failures += 1;
};

const TABS = ['curl', 'git', 'wget', 'openssl'];
const TOGGLES = ['random', 'auto'];

// --- one bubble per toggle, wrapped around the pair it belongs to ----------

// A pair is the checkbox, its label and the bubble of both, inside one .toggle-hint.
// The bubble is bound to a hint of App.vue rather than holding text of its own, so
// what is painted and what is read out cannot drift apart.
const pairPattern =
  /<span class="toggle-hint">\s*<input id="(random|auto)-toggle-(\w+)"([^>]*?)\/>\s*<label for="\1-toggle-\2"[^>]*>([^<]*)<\/label>\s*<span class="toggle-hint-bubble" id="\1-hint-\2" role="tooltip">\{\{\s*\1ToggleHint\s*\}\}<\/span>\s*<\/span>/g;

const pairs = [...template.matchAll(pairPattern)];
const wrapped = new Set(pairs.map(([, toggle, tab]) => `${toggle}-${tab}`));

// Every tab panel holds all four toggles, and only the panel of the active tab is
// shown, so the four panels are four copies of the pair - each with an id of its own,
// because v-show keeps them all in the document.
for (const tab of TABS) {
  for (const toggle of TOGGLES) {
    const bubble = `${toggle}-hint-${tab}`;
    if (!wrapped.has(`${toggle}-${tab}`)) {
      fail(`${tab}: ${toggle} checkbox carries no bubble wrapped around itself and its label`);
      continue;
    }
    const input = template.match(new RegExp(`<input id="${toggle}-toggle-${tab}"[^>]*\\/>`))?.[0];
    if (!input?.includes(`aria-describedby="${bubble}"`)) {
      fail(`${tab}: the ${toggle} checkbox does not name its bubble (${bubble}) to assistive technology`);
      continue;
    }
    ok(`${tab}: ${toggle} checkbox, label and bubble (${bubble}) are one hoverable pair`);
  }
}

// A pair that half matches the pattern above would go unnoticed: count the wrappers
// and the bubbles, so a stray or mislabelled one is a failure and not an omission.
const wrapperCount = (template.match(/class="toggle-hint"/g) ?? []).length;
const bubbleCount = (template.match(/class="toggle-hint-bubble"/g) ?? []).length;
if (wrapperCount !== 8 || bubbleCount !== 8 || pairs.length !== 8) {
  fail(`the eight toggles of the four tabs are eight pairs (found ${pairs.length} of ${wrapperCount} wrappers and ${bubbleCount} bubbles)`);
} else {
  ok('the eight toggles of the four tabs are eight pairs, and nothing else is one');
}

const ids = [...template.matchAll(/id="([a-z0-9-]*hint-[a-z0-9-]+)"/g)].map((m) => m[1]);
if (new Set(ids).size !== ids.length) {
  fail('every bubble of every panel has an id of its own (v-show keeps all panels in the document)');
} else {
  ok('every bubble of every panel has an id of its own');
}

// A title attribute is the grey box of the browser: it cannot be painted in the
// accent colour, appears after a delay, and would answer a user who is already
// reading the bubble above their cursor with a second bubble.
const titledToggles = [...template.matchAll(/<(label|input)[^>]*(random|auto)-toggle-\w+[^>]*\stitle=/g)];
if (titledToggles.length) {
  fail(`a toggle keeps a title next to its bubble (${titledToggles.map((m) => m[2]).join(', ')})`);
} else {
  ok('no toggle keeps a title next to its bubble');
}

// --- what the bubbles say, and whether the command does it -----------------

// The two hints of App.vue, each with a sentence for an install and one for a removal,
// because the two commands differ and only one of them is on the screen.
function hintTexts(name) {
  const block = app.match(
    new RegExp(`const ${name} = computed\\(\\(\\) =>\\s*uninstallFlag\\.value\\s*\\?\\s*'([^']+)'\\s*:\\s*'([^']+)',?`),
  );
  return block ? { uninstall: block[1], install: block[2] } : null;
}

const randomHint = hintTexts('randomToggleHint');
const autoHint = hintTexts('autoToggleHint');

for (const [name, hints] of [['randomToggleHint', randomHint], ['autoToggleHint', autoHint]]) {
  if (!hints || !hints.install.length || !hints.uninstall.length) {
    fail(`App.vue has ${name} with a sentence for an install and one for a removal`);
    continue;
  }
  ok(`${name}: a sentence of its own for an install and for a removal`);
}

// src/config.js, the one place the commands of the page are built.
const { installCommands } = await import(new URL('../webpage/frontend/src/config.js', import.meta.url).href);
if (!randomHint || !autoHint) {
  console.log('\nthe hints of the bubbles are missing, so their claims cannot be tried');
  process.exit(failures);
}

// "the command carries the word rand in place of a theme code" - and the colors of
// the page are out of it, so a code of the page is nowhere in it.
const pageCode = 'vN-y_5uA';
const randomCommand = installCommands({ kind: 'install', code: 'rand' }).curl;
const themedCommand = installCommands({ kind: 'install', code: pageCode }).curl;
const claimsRandom = randomCommand === themedCommand.replace(pageCode, 'rand');
if (!claimsRandom) {
  fail('the bubble of Random says the command carries "rand" in place of a theme code, and it does not');
} else {
  ok('the bubble of Random says what the command does with the theme code');
}

// "the command drops the question it asks" - with Auto, and asks without it; for an
// install out of the tree it fetched and for a removal written into the command.
const asked = {
  install: installCommands({ kind: 'install', code: pageCode, auto: false }).curl,
  uninstall: installCommands({ kind: 'uninstall', auto: false }).curl,
};
const autoAsked = {
  install: installCommands({ kind: 'install', code: pageCode, auto: true }).curl,
  uninstall: installCommands({ kind: 'uninstall', auto: true }).curl,
};
for (const kind of ['install', 'uninstall']) {
  const dropsQuestion = asked[kind].includes('read -p') && !autoAsked[kind].includes('read -p');
  if (!dropsQuestion) {
    fail(`the bubble of Auto says the command drops its question, and the ${kind} command does not`);
  } else {
    ok(`the bubble of Auto says what the ${kind} command does with its question`);
  }
}

// Random does nothing to a removal, and the bubble says so rather than explaining a
// word the command never carries.
if (!/[Nn]othing to do/.test(randomHint.uninstall)) {
  fail('the bubble of Random says it has nothing to do with a removal command');
} else if (installCommands({ kind: 'uninstall' }).curl.includes('rand')) {
  fail('the bubble of Random says it has nothing to do with a removal command, and the removal command carries "rand"');
} else {
  ok('the bubble of Random has nothing to do with a removal command, and says so');
}

// --- the bubble as it is painted -------------------------------------------

// The accent of the theme (the border colour of the prompt it previews) is the
// background of the bubble, and the ink is the colour chosen against that accent.
const bubbleRule = style.match(/\.toggle-hint-bubble\s*\{([^}]*)\}/)?.[1] ?? '';
const expectRule = [
  ['background-color: var(--primary-color)', 'the bubble is painted in the accent colour of the theme'],
  ['color: var(--primary-contrast)', 'and in the ink that is readable on the accent'],
  ['position: absolute', 'and hung over the pair it belongs to'],
  ['visibility: hidden', 'hidden until the pointer is on the pair'],
  ['pointer-events: none', 'and never catching the pointer it hides behind'],
];
for (const [declaration, what] of expectRule) {
  if (!bubbleRule.includes(declaration)) {
    fail(`style.css: ${what} (no "${declaration}" in .toggle-hint-bubble)`);
  } else {
    ok(`style.css: ${what}`);
  }
}

// A wrapper without a bubble of its own is a bubble that never appears, so the pair
// needs the rule that shows it - and the pointer over the pair has to be the only
// thing that shows it. A rule keyed to the focus of a checkbox (the old :focus-within)
// answers a click as much as a Tab, so a bubble shown by it stayed on the page after
// the click that checked the box and after the pointer had gone elsewhere. A keyboard
// user is not left without the sentence: aria-describedby hands it over at the
// checkbox, read out instead of painted.

// The stylesheet with its comments taken out: they name the selectors they explain,
// so a rule matched in the raw file might be a sentence about a rule instead of one.
const css = style.replace(/\/\*[\s\S]*?\*\//g, '');
const shownByPointer = /\.toggle-hint:hover \.toggle-hint-bubble\s*\{[^}]*opacity:\s*1/s.test(css);
const shownByFocus = /:focus[^{}]*\{[^}]*opacity:\s*1/s.test(css);
if (!shownByPointer) {
  fail('style.css shows a bubble while the pointer is on the pair');
} else if (shownByFocus) {
  fail('no rule shows a bubble on focus: a click on the checkbox must not leave one standing');
} else {
  ok('a bubble comes with the pointer over its pair and goes when the pointer goes');
}

// The tail, so the bubble points at the checkbox instead of floating over the row.
if (!/\.toggle-hint-bubble::after[^{]*\{[^}]*background-color: var\(--primary-color\)/s.test(style)) {
  fail('style.css gives the tail of the bubble the accent colour too');
} else {
  ok('style.css gives the tail of the bubble the accent colour too');
}

console.log(`\nthe toggles of the install commands explain themselves in the accent colour`);
process.exit(failures);
