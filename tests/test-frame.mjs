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
// The compact shape of the prompt - Alt+t, which takes the top line away - is held to
// the frame it comes from too: the line it keeps is that line, glyph for glyph, with
// only its opening corner exchanged for half a dash, in the prompt and on the page.
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
// run. A spec is columns:exitcode:seconds. Each record printed is one line of the
// frame - the top one, or the one the cursor stands on - its escapes expanded and
// then dropped, and records are separated by a record separator.
const lineOf = {
  // The line of the frame the frame is measured on.
  top: `line=\${line#*$'\\n'}
  line=\${line%%$'\\n'*}`,
  // The line the cursor stands on, which is the last one of a prompt and, of the
  // compact shape, the only one.
  bottom: `line=\${line##*$'\\n'}`,
};

const driverFor = (wanted) => `
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
  ${lineOf[wanted]}
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

// drawShell(avatar, specs, { compact, line }) - the lines of the prompt an
// interactive shell with the avatar of this machine on or off drew for each spec.
// compact is the shape Alt+t switches to, and line which of its lines to look at.
function drawShell(avatar, specs, { compact = false, line = 'top' } = {}) {
  if (!(line in lineOf)) throw new Error(`no line of a prompt named ${line}`);
  const env = {
    ...process.env,
    BB_DIR: join(repoRoot, 'prompt'),
    AVATAR: String(avatar),
    ...(compact ? { BB_COMPACT: '1' } : {}),
  };
  const out = execFileSync('bash', ['-c', driverFor(line), 'test-frame', ...specs], {
    env,
    cwd: repoRoot,
  }).toString('utf8');
  return out.split('\x1e');
}

// paintedLines - how many lines of the terminal the prompt paints, bash counting
// them itself. Every shape opens with the newline that moves it off the output
// before it, and that one is not a line of the prompt.
function paintedLines(compact) {
  const script = `
. "$BB_DIR/bb.sh" 2>/dev/null
export COLUMNS=120
BB_TIMER=$(( SECONDS - 42 ))
true
__prompt_command
printf '%s' "\${PS1@P}" | awk 'END { print NR - 1 }'
`;
  const env = {
    ...process.env,
    BB_DIR: join(repoRoot, 'prompt'),
    ...(compact ? { BB_COMPACT: '1' } : {}),
  };
  return Number(execFileSync('bash', ['-c', script, 'test-frame'], { env, cwd: repoRoot })
    .toString('utf8')
    .trim());
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

// --- the compact prompt, Alt+t -------------------------------------------

// Alt+t takes the top line away, and with it the frame. What is kept is the line the
// cursor stands on, drawn as it is drawn in the frame; only the corner that opens it
// differs, because a corner needs the line that hung from it.
{
  const specs = ['120:0:42', '120:1:42', '60:0:9'];
  // The two shapes of the same prompt, in the same state of the same shell, so that
  // they can be read against each other.
  const kept = drawShell(true, specs, { line: 'bottom' });
  const compact = drawShell(true, specs, { compact: true, line: 'bottom' });
  const wrong = [];
  specs.forEach((spec, i) => {
    const want = kept[i].replace('└', '┈');
    if (compact[i].includes('┌') || compact[i].includes('└'))
      wrong.push(`${spec}: the compact line holds a corner of the frame (${compact[i]})`);
    else if (!compact[i].startsWith('┈─'))
      wrong.push(`${spec}: the compact line does not open with a half dash (${compact[i]})`);
    else if (compact[i] !== want)
      wrong.push(
        `${spec}: the compact line is not the line the cursor stands on with its corner exchanged (\n         compact ${compact[i]}\n         kept     ${want})`
      );
  });
  // A prompt of one line paints one line, and the frame still paints two.
  const framePainted = paintedLines(false);
  const compactPainted = paintedLines(true);
  if (framePainted !== 2) wrong.push(`the frame paints ${framePainted} lines, want 2`);
  if (compactPainted !== 1) wrong.push(`the compact prompt paints ${compactPainted} lines, want 1`);
  if (wrong.length) wrong.slice(0, 8).forEach((what) => fail(what));
  else
    ok(
      `the compact prompt is one line over ${specs.length} terminals, and it is the line kept from the frame`
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
      });
  return { forAvatar, host };
}

{
  const { forAvatar, host } = previewPromptLines();
  const wrong = [];
  const widths = [];
  let failingLines = 0;
  for (const showAvatar of [true, false]) {
    for (const line of forAvatar(showAvatar).filter((l) => l.startsWith('┌'))) {
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

// And the preview shows what Alt+t leaves of it: one line, the last of the two it
// previews, with the same half dash the prompt puts in place of the corner.
{
  const { forAvatar } = previewPromptLines();
  const promptCompact = drawShell(true, ['120:0:42'], { compact: true, line: 'bottom' })[0];
  const wrong = [];
  for (const showAvatar of [true, false]) {
    const lines = forAvatar(showAvatar);
    const kept = lines.filter((l) => l.startsWith('└'));
    const compact = lines.filter((l) => l.startsWith('┈'));
    if (compact.length !== 1) {
      wrong.push(`the preview holds one compact line of its own (found ${compact.length})`);
      continue;
    }
    const want = kept.length ? kept[kept.length - 1].replace('└', '┈') : null;
    if (!want) {
      wrong.push('the preview holds a line for the compact line to be');
      continue;
    }
    if (compact[0] !== want)
      wrong.push(
        `the preview's compact line is not its own last line with the corner exchanged (\n         preview ${compact[0]}\n         want     ${want})`
      );
    // Segments come and go with the shape on the page but not between the two of
    // them, so what is previewed and what is prompted hold the same brackets.
    const bracketed = (line) => (line.match(/[()]/g) || []).length;
    if (bracketed(compact[0]) !== bracketed(promptCompact))
      wrong.push(
        `the preview's compact line holds ${bracketed(compact[0])} brackets, the prompt's holds ${bracketed(promptCompact)}`
      );
  }
  if (wrong.length) wrong.slice(0, 8).forEach((what) => fail(what));
  else ok(`the preview shows the compact line as the prompt draws it: ${promptCompact.replace(/\)─.*$/, ')─…')}`);
}

console.log(failures ? `\n${failures} failure(s)` : `\nthe frame of the prompt and the frame of the page agree`);
process.exit(failures ? 1 : 0);
