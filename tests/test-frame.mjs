#!/usr/bin/env node
//
// The frame prompt/bb.sh draws around a prompt, and the copy of it the WebUI
// shows as a preview.
//
//   node tests/test-frame.mjs
//
// The frame of a prompt is one line of the terminal, and the dashes between its
// two halves are whatever width the terminal leaves between them, so every piece
// of it has to be counted as it is drawn. Three things are held to that:
//
//   * every segment stands behind a separator of two dashes, and the top line
//     closes with four dashes of its own,
//   * the top line keeps one length - across the avatar showing or hidden, the
//     exit code, the digits of a duration, the background jobs and the width of
//     the terminal,
//   * the preview on the page wears the same frame: the same separators, and its
//     two prompt lines of one length in both avatar states.
//
// The prompt is drawn by bash itself, with the same ${PS1@P} an interactive shell
// expands, and the preview is read out of the markup of the page, so a change to
// one of them that the other does not follow fails here.
//
// Exit code is the number of failures.

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = dirname(here);
const templateFile = join(repoRoot, 'webpage', 'frontend', 'src', 'template.html');
const appFile = join(repoRoot, 'webpage', 'frontend', 'src', 'App.vue');

let failures = 0;
const ok = (what) => console.log(`  \x1b[32mok\x1b[0m   ${what}`);
const fail = (what) => {
  console.log(`  \x1b[31mFAIL\x1b[0m ${what}`);
  failures += 1;
};

// ${PS1@P} of an older bash cannot expand a prompt, and without it there is no
// frame to look at - the same guard tests/test-timer.sh makes.
if (
  execFileSync('bash', ['-c', 'ps1=x; printf %s "${ps1@P}"'], { cwd: repoRoot }).toString() !== 'x'
) {
  fail('bash here cannot expand a prompt with ${PS1@P}');
  process.exit(1);
}

// --- drawing the prompt ---------------------------------------------------

// One bash per avatar state, because prompt/bb.sh reads AVATAR when it is sourced;
// all the terminal widths, exit codes and durations asked for are drawn in that one
// run. A spec is columns:exitcode:seconds. Each record printed is the visible top
// line of the frame, its escapes expanded and then dropped, and records are
// separated by a record separator.
const driver = `
. "$BB_DIR/bb.sh" 2>/dev/null
# tput cols, which is what sizes the frame, reads the environment of the shell.
export COLUMNS
i=0
for spec in "$@"; do
  COLUMNS=\${spec%%:*}
  rest=\${spec#*:}
  rc=\${rest%%:*}
  dur=\${rest#*:}
  BB_TIMER=$(( SECONDS - dur ))
  if [ "$rc" = 0 ]; then true; else false; fi
  __prompt_command
  line=\${PS1@P}
  line=\${line#*$'\\n'}
  line=\${line%%$'\\n'*}
  line=\${line//$'\\001'/}
  line=\${line//$'\\002'/}
  line=\${line//$'\\016'/}
  line=\${line//$'\\017'/}
  line=$(printf '%s' "$line" | sed -e "s/\\x1b\\[[0-9;]*[a-zA-Z]//g")
  if [ "$i" -gt 0 ]; then printf '\\x1e'; fi
  i=$(( i + 1 ))
  printf '%s' "$line"
done
`;

function drawShell(avatar, specs) {
  const out = execFileSync('bash', ['-c', driver, 'test-frame', ...specs], {
    env: { ...process.env, BB_DIR: join(repoRoot, 'prompt'), AVATAR: String(avatar) },
    cwd: repoRoot,
  }).toString('utf8');
  return out.split('\x1e');
}

const DATE = /\((\w{3} \w{3} \d{2})\)/;
const CLOCK = /\((\d{2}:\d{2}:\d{2})\)/;
const DURATION = /\((\d+)s\)/;

// The length of the dash run immediately before the segment the expression names,
// or -1 when the line holds no such segment.
function runBefore(line, re) {
  const at = line.search(re);
  if (at < 0) return -1;
  let n = 0;
  while (at - 1 - n >= 0 && line[at - 1 - n] === '─') n++;
  return n;
}

// The length of the dash run between the first two bracketed groups of the line,
// which is what stands between (user@host:tty) and what follows it.
function runBetweenGroups(line) {
  const gap = line.match(/\)(─*)\(/);
  return gap ? gap[1].length : -1;
}

const width = (line) => [...line].length;

// --- the separators of the frame -----------------------------------------

// A 120 column terminal, 42 seconds, a failing command: the one frame where all
// three of the right hand segments stand between brackets of their own, and so
// where the separator of each is measurable rather than merged with the fill.
const failing = drawShell(true, ['120:1:42'])[0];
const succeeding = drawShell(true, ['120:0:42'])[0];

{
  const wrong = [];
  for (const [name, re] of [
    ['the date', DATE],
    ['the clock', CLOCK],
    ['the duration', DURATION],
  ]) {
    const run = runBefore(failing, re);
    if (run !== 2) wrong.push(`${name} stands behind ${run} dash(es), want 2`);
  }
  const left = runBetweenGroups(failing);
  if (left !== 2) wrong.push(`the avatar stands behind ${left} dash(es), want 2`);
  const tail = (succeeding.match(/(─*)$/) || [''])[0];
  if (tail.length !== 4) wrong.push(`the top line closes with ${tail.length} dash(es), want 4`);
  if (wrong.length) wrong.forEach((what) => fail(what));
  else ok('every segment of the frame stands behind two dashes and the line closes with four');
}

// A frame too narrow for its terminal gives up its fill. What then precedes the
// duration is the five dashes that stand for a command that ended well and the two
// of its separator - and nothing else, which is how they can be counted here.
{
  const narrow = drawShell(true, ['60:0:42'])[0];
  const run = runBefore(narrow, DURATION);
  if (run === 7) ok('a command that ended well stands in with five dashes behind two of separator');
  else fail(`a command that ended well stands in with five dashes (run before its duration: ${run})`);
}

// --- one length of the line ----------------------------------------------

{
  const specs = [];
  for (const columns of [60, 80, 90, 100, 120, 200]) {
    for (const rc of [0, 1]) {
      for (const dur of [9, 42, 1234]) specs.push(`${columns}:${rc}:${dur}`);
    }
  }
  const on = drawShell(true, specs);
  const off = drawShell(false, specs);
  const wrong = [];
  const perColumn = new Map();
  specs.forEach((spec, i) => {
    const columns = Number(spec.split(':')[0]);
    const a = width(on[i]);
    const b = width(off[i]);
    if (a !== b) wrong.push(`${spec}: ${a} wide with the avatar on, ${b} with it off`);
    // A terminal wide enough to hold the frame sees it end four columns short of
    // its right edge, whatever the exit code, the duration or the avatar.
    else if (columns >= 100 && a !== columns - 4)
      wrong.push(`${spec}: ${a} wide in a ${columns} column terminal, want ${columns - 4}`);
    else perColumn.set(columns, `${a}`);
  });
  if (wrong.length) wrong.slice(0, 8).forEach((what) => fail(what));
  else
    ok(
      `the line keeps its length over ${specs.length} frames: ${[...perColumn]
        .map(([c, w]) => `${c}->${w}`)
        .join(' ')}`
    );
}

// --- the preview on the page ---------------------------------------------

// The prompt lines of the preview, read out of the markup the way a browser draws
// it: the <template> that does not apply is left out, the interpolation of the fill
// is replaced by the run App.vue sizes it to, the avatar loop draws its eight
// glyphs, and Vue condenses away the whitespace between the elements.
function previewPromptLines() {
  const tpl = readFileSync(templateFile, 'utf8');
  const start = tpl.indexOf('<div class="terminal">');
  const end = tpl.indexOf('<div class="share-section">', start);
  const chunks = [...tpl.slice(start, end).matchAll(/<div class="ps1-line">([\s\S]*?)<\/div>\n/g)].map(
    (m) => m[1]
  );

  const app = readFileSync(appFile, 'utf8');
  const bases = [...app.matchAll(/previewFill\((\d+)\)/g)].map((m) => Number(m[1]));
  const host = (app.match(/const previewHostname = ref\('([^']*)'\)/) || [])[1];
  if (bases.length !== 2) throw new Error('App.vue holds no two previewFill() bases');
  if (!host) throw new Error('App.vue holds no hostname for the preview');

  const forAvatar = (showAvatar) =>
    chunks
      .map((chunk) => {
        let out = chunk.replace(
          /<template v-if="(!?)showAvatar">([\s\S]*?)<\/template>/g,
          (_m, not, body) => ((not === '!') !== showAvatar ? body : '')
        );
        out = out.replace(/\{\{\s*previewHostname\s*\}\}/g, host);
        out = out.replace(/\{\{\s*previewFillOne\s*\}\}/g, '─'.repeat(bases[0]));
        out = out.replace(/\{\{\s*previewFillTwo\s*\}\}/g, '─'.repeat(bases[1]));
        out = out.replace(/<span[^>]*in avatarSegments[\s\S]*?<\/span\s*>/g, '▮▲▲■■▲▲▮');
        out = out.replace(/<!--[\s\S]*?-->/g, '');
        out = out.replace(/<\/span\s*>/g, '</span>');
        out = out.replace(/<[^>]*>/g, '');
        out = out.replace(/&gt;/g, '>').replace(/&nbsp;/g, ' ');
        return out.replace(/\s*\n\s*/g, '');
      })
      .filter((line) => line.startsWith('┌'));
  return { forAvatar, host };
}

{
  const { forAvatar, host } = previewPromptLines();
  const wrong = [];
  const widths = [];
  let failingLines = 0;
  for (const showAvatar of [true, false]) {
    for (const line of forAvatar(showAvatar)) {
      widths.push(width(line));
      if (!line.includes(`${host}:`)) wrong.push(`the preview line does not name its host ${host}`);
      for (const [name, re] of [
        ['the date', DATE],
        ['the clock', CLOCK],
      ]) {
        const run = runBefore(line, re);
        if (run !== 2) wrong.push(`the preview's ${name} stands behind ${run} dash(es), want 2`);
      }
      const tail = (line.match(/(─*)$/) || [''])[0];
      if (tail.length !== 4)
        wrong.push(`the preview's top line closes with ${tail.length} dash(es), want 4`);
      // The line of a failed command is the one whose duration stands between
      // brackets of its own, as in the frame above.
      if (line.includes('↵')) {
        failingLines += 1;
        const run = runBefore(line, DURATION);
        if (run !== 2)
          wrong.push(`the preview's duration stands behind ${run} dash(es), want 2`);
      }
    }
  }
  if (failingLines !== 2) wrong.push(`the preview holds ${failingLines} failing lines, want 2`);
  if (!(widths.length === 4 && widths.every((w) => w === widths[0])))
    wrong.push(`the preview lines are ${widths.join(', ')} wide - they have to be one width`);
  if (wrong.length) wrong.slice(0, 8).forEach((what) => fail(what));
  else
    ok(
      `the preview wears the same frame as the prompt: ${widths[0]} glyphs, two dashes between its segments`
    );
}

console.log(failures ? `\n${failures} failure(s)` : `\nthe frame of the prompt and the frame of the page agree`);
process.exit(failures ? 1 : 0);
