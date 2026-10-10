#!/usr/bin/env node
//
// Which colour of the theme skins the WebUI.
//
//   node tests/test-accent.mjs
//
// A theme carries eight colours (prompt/bb-theme.sh), and the page has to pick
// one of them as the accent that re-skins its chrome - headings, links, buttons,
// active tabs, and the banner of the header. It is the BORDER COLOR (BORDCOL),
// the colour a prompt draws its frame in and the colour the preview on the page
// shows most of; PRIMARY_COLOR, which colours the inside of a prompt, is not it.
//
// The choice is one line of src/App.vue, so this checks three things around it:
//
//   * the accent really is read from that slot of the theme, and the slot is the
//     one the page shows its user as "Border Color",
//   * the fallback ramp of assets/main.css is the ramp src/theme.js builds of its
//     own base, so the page does not start in a colour the theme would never
//     produce (the values before the first paint),
//   * that fallback base is the border colour of the defaults of src/App.vue,
//     read out of the same tables of colours the preview paints with.
//
// Exit code is the number of failures.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { buildAccentPalette } from '../webpage/frontend/src/theme.js';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = dirname(here);
const srcDir = join(repoRoot, 'webpage', 'frontend', 'src');
const appFile = join(srcDir, 'App.vue');
const mainCssFile = join(srcDir, 'assets', 'main.css');

const appSrc = readFileSync(appFile, 'utf8');
const mainCss = readFileSync(mainCssFile, 'utf8');

let failures = 0;
const ok = (what) => console.log(`  \x1b[32mok\x1b[0m   ${what}`);
const fail = (what) => {
  console.log(`  \x1b[31mFAIL\x1b[0m ${what}`);
  failures += 1;
};

// --- the slot of the theme the accent comes from --------------------------

const accentKey = appSrc.match(/const ACCENT_COLOR_KEY = '([A-Z_]+)'/)?.[1];
if (!accentKey) {
  fail('App.vue names the slot of its accent colour in ACCENT_COLOR_KEY');
} else if (accentKey !== 'BORDCOL') {
  fail(`the accent comes from BORDCOL, not from ${accentKey}`);
} else {
  ok('the accent of the page comes from the BORDCOL slot of the theme');
}

// The one call that builds the ramp, and the slot it reads. Reading it through
// ACCENT_COLOR_KEY rather than a literal keeps this and the check above the same
// statement.
const accentCall =
  /buildAccentPalette\(getPreviewColorFromBash\(generatedColors\.value\.?(\[ACCENT_COLOR_KEY\]|[A-Z_]+)\)\)/.exec(
    appSrc,
  );
if (!accentCall) {
  fail('App.vue builds its accent ramp out of generatedColors.value[ACCENT_COLOR_KEY]');
} else if (accentCall[1] !== '[ACCENT_COLOR_KEY]') {
  fail(`the accent ramp reads generatedColors.value.${accentCall[1]} instead of [ACCENT_COLOR_KEY]`);
} else {
  ok('that ramp is built from generatedColors.value[ACCENT_COLOR_KEY]');
}

// The slot has a name in the UI; the accent may only be called the colour of the
// border if the page shows that slot under that name too.
const labels = appSrc.slice(
  appSrc.indexOf('const colorLabels = {'),
  appSrc.indexOf('const colorLabels = {') + 1024,
);
if (accentKey && /BORDCOL: 'Border Color'/.test(labels)) {
  ok('the page shows that slot to its user as "Border Color"');
} else {
  fail("App.vue labels BORDCOL as 'Border Color' in colorLabels");
}

// --- the fallback ramp of assets/main.css ---------------------------------

// The six variables of the ramp, as the stylesheet declares them on :root.
const rootBlock = mainCss.slice(mainCss.indexOf(':root {'), mainCss.indexOf('}', mainCss.indexOf(':root {')));
const declared = Object.fromEntries(
  [...rootBlock.matchAll(/--primary-([a-z-]+):\s*([^;]+);/g)].map((m) => [m[1], m[2].trim()]),
);

const expectedVars = ['color', 'base', 'hover', 'bright', 'soft', 'contrast'];
const missing = expectedVars.filter((name) => !declared[name]);
if (missing.length) {
  fail(`assets/main.css declares the whole accent ramp (missing: ${missing.join(', ')})`);
} else {
  ok('assets/main.css declares the whole accent ramp');

  // What the ramp of that base has to look like. The stylesheet carries its own
  // base, so the two can be compared without knowing the theme of the page.
  const ramp = buildAccentPalette(declared.base);
  const compared = {
    '--primary-color': [declared.color, ramp.accent],
    '--primary-hover': [declared.hover, ramp.hover],
    '--primary-bright': [declared.bright, ramp.bright],
    '--primary-soft': [declared.soft, ramp.soft],
    '--primary-contrast': [declared.contrast, ramp.onAccent],
  };
  const drifted = Object.entries(compared).filter(([, [a, b]]) => a !== b);
  if (drifted.length) {
    fail(
      `the fallback ramp is buildAccentPalette('${declared.base}') (drifted: ` +
        drifted.map(([name, [a, b]]) => `${name} ${a} != ${b}`).join(', ') +
        ')',
    );
  } else {
    ok(`the fallback ramp is the ramp of its own base ${declared.base}`);
  }

  if (declared.base.toLowerCase() === '#4e9a06') {
    fail('the fallback base is the border colour of the defaults, not the classic primary green');
  }
}

// --- that base against the defaults of App.vue ----------------------------

// One colour of the defaults, read the way the preview reads it: the number of
// the colour out of the Bash code, and the hex the tables of colours give it,
// bold variant included (a bold colour of its own hex).
function defaultColorHex(appText, key) {
  const decl = appText.match(new RegExp(`^ *${key}: '[^']*?(\\d{2})(;1)?m[^']*'`, 'm'));
  if (!decl) return null;
  const [, num, bold] = decl;
  const isLight = Number(num) >= 90;

  // The table a colour is read out of: the bold ones first, then the bright and
  // the base ones.
  const hexIn = (table) => {
    const start = appText.indexOf(`const ${table} = {`);
    if (start === -1) return null;
    const block = appText.slice(start, appText.indexOf('\n};', start));
    return block.match(new RegExp(`^ *${num}: \\{[^}]*?hex: ["'](#[0-9a-fA-F]{6})["']`, 'm'))?.[1] ?? null;
  };

  return (bold && hexIn('boldColorSpecifics')) || hexIn(isLight ? 'lightColorDefinitions' : 'baseColorDefinitions');
}

const defaultBorder = defaultColorHex(appSrc, 'BORDCOL');
if (!defaultBorder) {
  fail("the border colour of the defaults in App.vue can be read out of its tables");
} else if (declared.base && declared.base.toLowerCase() !== defaultBorder.toLowerCase()) {
  fail(
    `the fallback base ${declared.base} is the border colour of the defaults (${defaultBorder})`,
  );
} else {
  ok(`the fallback base ${declared.base} is the border colour of the defaults`);
}

if (failures) {
  console.log(`\n${failures} failure(s): the accent of the page is not the border colour`);
} else {
  console.log('\nthe page is skinned by the border colour of the theme');
}

process.exit(failures);
