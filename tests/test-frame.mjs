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
//     closes with three dashes of its own and half a dash where it ends,
//   * the top line keeps one length - across the avatar showing or hidden, the
//     exit code, the digits of a duration, the background jobs and the width of
//     the terminal,
//   * the preview on the page wears the same frame: the same separators, and its
//     two prompt lines of one length in both avatar states.
//
// The compact shape of the prompt - Alt+t, which takes the top line away - is held to
// the frame it comes from too: the line it keeps is that line, glyph for glyph, with
// only its opening corner exchanged for half a dash, in the prompt and on the page.
// On the page the compact line is labelled besides: a comment of the shell stands
// directly over it, and stays shorter than the prompt lines so that it does not
// decide how wide the preview is.
//
// The prompt is drawn by bash itself, with the same ${PS1@P} an interactive shell
// expands; the preview of it on the page is drawn by the model the page draws from
// (src/preview.js) and compared with that prompt, glyph for glyph, so a change to
// one of them that the other does not follow fails here.
//
// Exit code is the number of failures.

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// The theme code and the top line of the prompt, as the page reads and draws them:
// theme-code.js is what both the page and the shell library spell a code by, and
// preview.js is what the preview of the page is built from.
import { ALL_ELEMENTS_ON, ELEMENT_KEYS } from '../webpage/frontend/src/theme-code.js';
import {
  ELEMENTS,
  PREVIEW_WIDTH,
  SAMPLE,
  SAMPLE_ROOT,
  flagsOf,
  lineText,
  topLine,
} from '../webpage/frontend/src/preview.js';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = dirname(here);
const templateFile = join(repoRoot, 'webpage', 'frontend', 'src', 'template.html');

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

// How many dashes the top line closes with, where its last glyph is half a dash. A
// line that does not end in half a dash closes with -1 of them, so that the frame
// the prompt draws and the frame the page previews are held to one shape here
// rather than to a run of dashes either of them could end with.
function closingRun(line) {
  const tail = line.match(/(─*)┈$/);
  return tail ? tail[1].length : -1;
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
  const tail = closingRun(succeeding);
  if (tail !== 3)
    wrong.push(`the top line closes with ${tail} dash(es) and a half dash, want 3 and a half dash`);
  if (wrong.length) wrong.forEach((what) => fail(what));
  else
    ok(
      'every segment of the frame stands behind two dashes and the line closes with three and half a dash'
    );
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

// The lines of the preview that the markup still holds by hand - the two lines the
// cursor stands on and the compact line - read out of the markup the way a browser
// draws it: the <template> that does not apply is left out, the avatar loop draws
// its eight glyphs, and Vue condenses away the whitespace between the elements. The
// top lines of the two prompts are not here any more: they are drawn by
// src/preview.js, and compared with the shell below instead of with the markup.
function previewPromptLines() {
  const tpl = readFileSync(templateFile, 'utf8');
  const start = tpl.indexOf('<div class="terminal">');
  const end = tpl.indexOf('<div class="share-section">', start);
  const chunks = [...tpl.slice(start, end).matchAll(/<div class="ps1-line">([\s\S]*?)<\/div>\n/g)].map(
    (m) => m[1]
  );

  // The name the field of the page holds is drawn afresh on every load of it
  // (src/hostname.js), so this cannot ask the page which name it drew and none of
  // what is measured below may depend on the answer: the markup is filled with a name
  // of this test's own, the same one into the line the cursor stands on and into the
  // compact line drawn from it, which is all either of them is compared over.
  const host = 'previewhost';

  const forAvatar = (showAvatar) =>
    chunks
      .map((chunk) => {
        let out = chunk.replace(
          /<template v-if="(!?)showAvatar">([\s\S]*?)<\/template>/g,
          (_m, not, body) => ((not === '!') !== showAvatar ? body : '')
        );
        out = out.replace(/\{\{\s*previewHostname\s*\}\}/g, host);
        out = out.replace(/<span[^>]*in avatarSegments[\s\S]*?<\/span\s*>/g, '▮▲▲■■▲▲▮');
        out = out.replace(/<!--[\s\S]*?-->/g, '');
        out = out.replace(/<\/span\s*>/g, '</span>');
        out = out.replace(/<[^>]*>/g, '');
        out = out.replace(/&gt;/g, '>').replace(/&nbsp;/g, ' ');
        return out.replace(/\s*\n\s*/g, '');
      });
  return { forAvatar, host };
}

// --- the preview draws what the shell draws -------------------------------

// What the preview of the page shows of a top line is no longer held in its markup:
// src/preview.js builds that line out of the same elements, the same separators and
// the same widths prompt/bb.sh draws with, and the template of the page paints what
// it returns. So the preview is compared with the prompt itself - the same machine,
// the same terminal, the same theme of elements - drawn twice, once by bash and once
// by the model the page draws from, and the two have to come out as one string of
// glyphs.
//
// Whatever a theme hides, the shell measures out of the line, so this holds what the
// boxes of the page do to the frame as well: an element that hides and leaves a hole
// where it stood, or that moves the end of the line by a glyph, fails here - and
// fails twice, above the width where the fill takes what the elements give up and
// below the width where the fill is gone and an element hands its width back as
// dashes of the frame, in its own place.

// One prompt of a shell on this machine, drawn with the elements of a theme: columns
// is the terminal, bits says which of the nine elements stand and which the border
// fill among them, code is what the last command left behind it, duration how long
// it ran, and jobs how many commands run beside it. Along with the line it returns
// what that shell drew itself out of - the
// name, the host, the terminal, the avatar the host hashes into, the count of jobs -
// because the preview draws the same machine and has to say the same things about it.
function drawPrompt({ columns, bits, code = 0, duration = 42, jobs = 0 }) {
  const env = {
    ...process.env,
    BB_DIR: join(repoRoot, 'prompt'),
    AVATAR: 'true',
    COLUMNS: String(columns),
    USER: process.env.USER || 'tester',
  };
  ELEMENT_KEYS.forEach((key, i) => {
    env[key] = bits[i] === '1' ? 'true' : 'false';
  });
  // The command the prompt is drawn for, leaving the code it is to leave. A
  // subshell, because $? of the shell drawing the prompt is what the code of it is
  // read from, and `exit` there would end the drawing before it began.
  const lastCommand = code === 0 ? 'true' : `( exit ${code} )`;
  const script = `
. "$BB_DIR/bb.sh" 2>/dev/null
export COLUMNS
${jobs > 0 ? 'sleep 30 &' : ':'}
BB_TIMER=$(( SECONDS - ${duration} ))
${lastCommand}
__prompt_command
line=\${PS1@P}
line=\${line#*$'\\n'}
line=\${line%%$'\\n'*}
line=\${line//$'\\001'/}
line=\${line//$'\\002'/}
line=\${line//$'\\016'/}
line=\${line//$'\\017'/}
strip='s/\\x1b\\[[0-9;]*[a-zA-Z]//g'
line=$(printf '%s' "$line" | sed -e "$strip")
# CH is the avatar as PS1 holds it - the eight glyphs between the colour codes and
# their \[ \] wrappers - so it is expanded the way a prompt is, and then stripped.
avatar=$(printf '%s' "\${CH@P}" | sed -e "$strip")
printf '%s\\x1f%s\\x1f%s\\x1f%s\\x1f%s\\x1f%s\\x1f%s' "$line" "$USER" "$HOSTNAM" "$cur_tty" "$avatar" "$PROCCNT" "$BB_TIMER_SHOW"
`;
  const record = execFileSync('bash', ['-c', script, 'test-frame'], { env, cwd: repoRoot }).toString(
    'utf8'
  );
  const [line, user, host, tty, avatar, proccnt, timer] = record.split('\u001f');
  // BB_TIMER_SHOW is what the shell formatted the duration into - however many
  // digits and units it chose - and the width of the segment is that string, so it
  // is taken from the shell rather than computed here.
  return { line, user, host, tty, avatar, jobs: Number(proccnt), timer };
}

// The day of \d and the time of \t, as the shell that drew the line put them between
// their brackets. They are read off that line rather than asked of the clock here,
// because a prompt and a test run a second apart would disagree over nothing else.
const PREVIEW_DATE = /\((\w{3} \w{3} [\d ]{2})\)/;

const PREVIEW_CASES = [
  // The two prompts of the preview, as the page draws them: a command that ended
  // well with something running behind it, and a failed one with nothing.
  { columns: 102, bits: ALL_ELEMENTS_ON, code: 0, jobs: 1 },
  { columns: 102, bits: ALL_ELEMENTS_ON, code: 127, jobs: 0 },
  // Neither half of the identity and no avatar: the brackets go with them, and the
  // fill takes what they gave up.
  { columns: 102, bits: '0000111111', code: 0, jobs: 1 },
  // The counter of jobs and the whole right half gone, an exit code to show.
  { columns: 102, bits: '1111000011', code: 42, jobs: 1 },
  // Nothing but the day: every other element handed its width to the fill.
  { columns: 102, bits: '0000000101', code: 0, jobs: 0 },
  // A line of nothing but frame.
  { columns: 102, bits: '0000000001', code: 0, jobs: 0 },
  // Below the width where the fill is gone, so every element that hides draws its
  // own width in dashes of the frame instead of handing it over.
  { columns: 76, bits: ALL_ELEMENTS_ON, code: 0, jobs: 1 },
  { columns: 70, bits: '1010101011', code: 7, jobs: 1 },
  { columns: 60, bits: '0000000001', code: 128, jobs: 1 },
  // A wide terminal, a duration of four digits and a count of jobs of one.
  { columns: 200, bits: '0110101111', code: 0, duration: 4242, jobs: 1 },
  // With no border fill: the line ends where its last element ends. The counter of
  // jobs and an exit code to show, and everything else hidden; the identity and the
  // clock of it, which is the shortest line anyone asks for; and nothing to stand
  // between the corners at all.
  { columns: 102, bits: '0000111110', code: 127, jobs: 1 },
  { columns: 102, bits: '1100100010', code: 0, jobs: 1 },
  { columns: 102, bits: '0000000000', code: 0, jobs: 0 },
  // Too narrow for the whole row and no fill either: there is no fill to drop, so
  // the line is as long as its elements and nothing is padded in their places.
  { columns: 60, bits: '1111111110', code: 7, jobs: 1 },
];

{
  const wrong = [];
  for (const spec of PREVIEW_CASES) {
    const drawn = drawPrompt(spec);
    const sample = {
      user: drawn.user,
      tty: drawn.tty,
      jobs: drawn.jobs,
      code: spec.code,
      duration: drawn.timer,
      date: (drawn.line.match(PREVIEW_DATE) || [, 'Wed May 14'])[1],
      clock: (drawn.line.match(CLOCK) || [, '00:40:03'])[1],
    };
    const padded = lineText(
      topLine({
        flags: flagsOf(spec.bits),
        host: drawn.host,
        avatar: [...drawn.avatar].map((glyph) => ({ text: glyph })),
        sample,
        columns: spec.columns,
      })
    );
    // A theme without the border fill gets its line padded out at the end with
    // spaces, which is a thing of the preview only (see src/preview.js): what the
    // shell drew ends behind its last element. So the line is compared with the
    // padding taken back off, and the padding is held to being nothing but spaces,
    // exactly as many as the fill would have stretched.
    const previewed = padded.replace(/ +$/, '');
    const padding = width(padded) - width(previewed);
    const where = `${spec.columns} columns, elements ${spec.bits}, code ${spec.code}, ${drawn.jobs} job(s)`;
    const fills = spec.bits[ELEMENT_KEYS.length - 1] !== '0';
    const owed = Math.max(0, spec.columns - 4 - width(previewed));
    if (!fills && padding !== owed)
      wrong.push(`the line of elements ${spec.bits} is padded ${padding} glyphs, want the ${owed} the fill would have stretched (${where})`);
    if (fills && padding)
      wrong.push(`the line of elements ${spec.bits} is padded ${padding} glyphs where the fill stretches of its own (${where})`);
    if (previewed !== drawn.line) {
      wrong.push(`the preview does not draw what the shell drew (${where})\n         shell   ${drawn.line}\n         preview ${previewed}`);
    }
  }
  if (wrong.length) wrong.slice(0, 4).forEach((what) => fail(what));
  else
    ok(
      `the preview draws the frame of the shell, glyph for glyph, over ${PREVIEW_CASES.length} settings of the elements`
    );
}

// The parts of (user@host:tty) in their colours, read out of the escapes bash put in
// front of them. What is held to one here is which colour a part wears: the terminal
// of the line in the colour of the host - both say which machine this is - and the
// bracket and the @ and : of the brackets in the colour of the separator. The text of
// a line is one thing and the colour of it another, and a preview that drew the same
// words in another colour than the prompt would be noticed by anyone who looks at
// both. (The colour of a name belongs to SECONDARY_COLOR, or to ROOT_COLOR for root;
// prompt/bb.sh decides that, and this does not second-guess it.)
{
  const env = {
    ...process.env,
    BB_DIR: join(repoRoot, 'prompt'),
    COLUMNS: '120',
    USER: process.env.USER || 'tester',
  };
  const script = `
. "$BB_DIR/bb.sh" 2>/dev/null
export COLUMNS
true
__prompt_command
printf '%s\\x1f%s\\x1f%s\\x1f%s\\x1f%s' "\${PS1@P}" "$HOSTNAM" "$cur_tty" "\${PRIMARY_COLOR@P}" "\${SEPARATOR_COLOR@P}"
`;
  // The \[ \] wrappers of the colour variables are turned into \001 and \002 by the
  // same prompt expansion that turns \033 into an escape, and both are dropped here:
  // what is left around the text is the escape of a colour and nothing else.
  const [top, host, tty, primary, separator] = execFileSync(
    'bash',
    ['-c', script, 'test-frame'],
    { env, cwd: repoRoot }
  )
    .toString('utf8')
    .split('\u001f')
    .map((field) => field.replace(/[\001\002\016\017]/g, ''));
  // The line of the identity, which is the first of the two the prompt is made of -
  // and the one a host name is spelled on, so that is how it is picked out.
  const line = top.split('\n').find((one) => one.includes(host)) || top.split('\n')[0];
  // The colour in force in the middle of a word, because a separator standing right
  // in front of a name is not the colour of that name.
  const colourOf = (word) => {
    const at = line.indexOf(word);
    if (at < 0) return null;
    const codes = line.slice(0, at + Math.floor(word.length / 2)).match(/\x1b\[[0-9;]*m/g) || [];
    return codes.length ? codes[codes.length - 1] : '';
  };
  const wrong = [];
  if (host && tty) {
    if (colourOf(host) !== primary)
      wrong.push('the host of the top line is not drawn in PRIMARY_COLOR');
    if (colourOf(tty) !== colourOf(host))
      wrong.push(
        `the terminal of the top line stands in ${colourOf(tty)}, its host in ${colourOf(host)} - the same colour was asked for`
      );
    if (colourOf('(') !== separator)
      wrong.push('the bracket of the identity is not drawn in SEPARATOR_COLOR');
  } else {
    wrong.push(`the prompt names no host and terminal to compare (${JSON.stringify(host)}, ${JSON.stringify(tty)})`);
  }
  // And the preview says the same in the keys it hands the template.
  const segments = topLine({
    flags: flagsOf(ALL_ELEMENTS_ON),
    host: 'myhost',
    avatar: [],
    sample: { ...SAMPLE, tty: 'pts/7' },
  });
  const keyOf = (word) => (segments.find((part) => part.text === word) || {}).colorKey;
  if (keyOf('myhost') !== 'PRIMARY_COLOR' || keyOf('pts/7') !== 'PRIMARY_COLOR')
    wrong.push(
      `the preview colours its host ${keyOf('myhost')} and its terminal ${keyOf('pts/7')}, want both PRIMARY_COLOR`
    );
  if (wrong.length) wrong.slice(0, 4).forEach((what) => fail(what));
  else ok('the terminal of the line wears the colour of the host, in the prompt and in the preview');
}

// A line without the border fill, of its own: the elements that show, two dashes
// between neighbours, and the width it does not use left to the terminal. Nothing is
// stretched and nothing padded in the place of what hides, so the same elements make
// the same visible line whatever the terminal is wide - and a preview that held that
// to be false would be a preview of another line than the one the shell draws. What
// the fill would have stretched is put behind the line as spaces, which the shell
// does not draw and the preview needs: the box is drawn around the longest line it
// holds, and without them every element of it would slide right as a box got ticked.
{
  const wrong = [];
  // A code left behind, so that the five dashes standing for a command that ended
  // well - which are an element of the line, not a stretch of it - never turn up in
  // the middle of what is measured here.
  const sample = { ...SAMPLE, code: 7 };
  // The last of the ten bits is the fill, and it is off in every one of these: both
  // halves whole, only the identity and the clock, nothing at all, and one element
  // of each half with a hidden one between them.
  // A theme of every element and a theme of three are both asked of a terminal of
  // 60 columns: only the second of them can stop short of its edge.
  for (const [bits, sparse] of [
    ['1111111110', false],
    ['1100100010', true],
    ['0000000000', true],
    ['1001000100', false],
  ]) {
    const lines = [60, 102, 200].map((columns) =>
      lineText(
        topLine({
          flags: flagsOf(bits),
          host: 'myhost',
          avatar: [...'▮▲▲■■▲▲▮'].map((glyph) => ({ text: glyph })),
          sample,
          columns,
        })
      )
    );
    // What the line is - its elements, its tail, and nothing else. Behind them the
    // preview puts the width the fill would have stretched; that padding is held to
    // here and nowhere else, because it is nothing to see and has to stay nothing
    // but that.
    const shown = lines.map((padded) => padded.replace(/ +$/, ''));
    if (new Set(shown).size !== 1)
      wrong.push(`elements ${bits} draw ${lines.length} different lines as the terminal grows: ${shown.join(' | ')}`);
    const line = shown[0];
    // Padding to the width of the box, and never past the last element of a line
    // too long for it: at every terminal the model is asked about, the preview line
    // measures what a stretched line measures.
    [60, 102, 200].forEach((columns, i) => {
      const want = Math.max(width(shown[i]), columns - 4);
      if (width(lines[i]) !== want)
        wrong.push(
          `elements ${bits} of ${columns} columns measure ${width(lines[i])} glyphs with their padding, want ${want}`
        );
    });
    // Every run of dashes between two elements of such a line is the two that
    // separate them. The first run of the line carries the single dash of the open
    // corner, and the last is the three and a half it closes with, so neither of
    // those two is held to it.
    const runs = (line.match(/─+/g) || []).map((run) => run.length);
    const between = runs.slice(1, -1);
    if (between.some((run) => run !== 2))
      wrong.push(`elements ${bits} stand ${between.join(', ')} dashes apart, want two between neighbours`);
    // What the fill would have stretched to the edge is gone from it: the same
    // theme with the fill on is longer by exactly that much.
    const stretched = lineText(
      topLine({
        flags: flagsOf(`${bits.slice(0, 9)}1`),
        host: 'myhost',
        avatar: [...'▮▲▲■■▲▲▮'].map((glyph) => ({ text: glyph })),
        sample,
        columns: 102,
      })
    );
    if (width(line) >= width(stretched))
      wrong.push(
        `elements ${bits} are ${width(line)} glyphs with the fill off and ${width(stretched)} with it on - the fill was asked to stay away`
      );
    // And a theme of few elements stops well short of the edge of a narrow terminal
    // rather than reaching for it.
    if (sparse && width(line) >= 60 - 4)
      wrong.push(`elements ${bits} still reach the edge of a terminal of 60 columns (${width(line)} glyphs)`);
    if (runs.some((run) => run > 4))
      wrong.push(`elements ${bits} stretch ${Math.max(...runs)} dashes in a row where none is stretched`);
  }
  if (wrong.length) wrong.slice(0, 4).forEach((what) => fail(what));
  else
    ok(
      'a line without the border fill is its elements, two dashes apart, padded to one width at any terminal'
    );
}

// The two prompt lines the page shows are of the width the box is padded to, whatever
// the theme shows - the invariant the frame has always held, now held of the model
// rather than of the markup. It holds of a theme asking for no fill as well: such a
// line is short of that width by the stretch it never drew, and is padded to it with
// spaces, so that nothing on the line moves as the boxes of the page are ticked.
{
  const wrong = [];
  const widths = [];
  for (const sample of [SAMPLE, SAMPLE_ROOT]) {
    for (const bits of [ALL_ELEMENTS_ON, '0001000011', '1010101011', '0000000001', '1111111110', '1100100010']) {
      const line = lineText(
        topLine({
          flags: flagsOf(bits),
          host: 'myhost',
          avatar: [...'▮▲▲■■▲▲▮'].map((glyph) => ({ text: glyph })),
          sample,
        })
      );
      widths.push(width(line));
      if (width(line) !== PREVIEW_WIDTH)
        wrong.push(`the preview line of elements ${bits} is ${width(line)} glyphs, want ${PREVIEW_WIDTH}`);
      // The three dashes and the half dash the line closes with are only to be
      // told from the fill while something stands in front of them to end.
      if (bits[8] === '1' && closingRun(line.replace(/ +$/, '')) !== 3)
        wrong.push(`the preview line of elements ${bits} closes with ${closingRun(line)} dashes and a half, want 3 and a half`);
    }
  }
  if (new Set(widths).size !== 1) wrong.push(`the preview lines are ${[...new Set(widths)].join(', ')} wide - they have to be one width`);
  if (wrong.length) wrong.slice(0, 4).forEach((what) => fail(what));
  else ok(`the preview lines are one width over every setting of the elements: ${widths[0]} glyphs`);
}

// The markup paints the model, and holds no line of a prompt of its own: a top line
// written by hand in the template would be a frame that no box of the page can
// change, and no test of the shell can reach.
{
  const tpl = readFileSync(templateFile, 'utf8');
  const start = tpl.indexOf('<div class="terminal">');
  const end = tpl.indexOf('<div class="share-section">', start);
  const painted = [...tpl.slice(start, end).matchAll(/┌─/g)].length;
  const wrong = [];
  for (const i of [0, 1])
    if (!tpl.includes(`previewTopLines[${i}]`))
      wrong.push(`the template does not render the model's top line ${i}`);
  if (painted !== 0)
    wrong.push(`the template holds ${painted} hand-drawn top line(s) of a prompt, want the model to draw them`);
  // The boxes are one loop over the elements of the line, each bound to the flag of
  // the element its label names - so the loop, the binding and the order of the
  // elements are what is checked, rather than nine boxes spelled out.
  if (!tpl.includes('in promptElements'))
    wrong.push('the template holds no loop over the elements of the top line');
  if (!tpl.includes('elementFlags[element.key]'))
    wrong.push('the boxes of the elements are not bound to what the theme shows');
  if (ELEMENTS.map((element) => element.key).join(',') !== ELEMENT_KEYS.join(','))
    wrong.push('the elements the boxes speak for are not the elements the theme code carries, in its order');
  if (wrong.length) wrong.slice(0, 4).forEach((what) => fail(what));
  else ok(`the template paints the model's lines and holds a box for each of the ${ELEMENTS.length} elements`);
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

// --- the label the preview puts over its compact line --------------------

// The compact line of the preview is not the shape a reader of the page has seen
// before, so a line of comment stands over it: said the way a shell says it (after a
// hash), naming the shortcut that draws it. It is a caption and not a prompt, and it
// stays shorter than the prompt lines, so that it does not decide how wide the
// preview is (see .ps1-comment in src/style.css).
{
  const tpl = readFileSync(templateFile, 'utf8');
  const start = tpl.indexOf('<div class="terminal">');
  const end = tpl.indexOf('<div class="share-section">', start);
  const painted = [...tpl.slice(start, end).matchAll(/<div class="ps1-line( ps1-comment)?">([\s\S]*?)<\/div>\n/g)].map(
    (m) => ({ comment: m[1] === ' ps1-comment', text: m[2].replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ') })
  );

  const wrong = [];
  const at = painted.findIndex((l) => l.comment);
  if (at < 0) {
    wrong.push("the preview holds no comment line of its own ('# ...')");
  } else {
    const comment = painted[at].text.trim();
    const under = painted[at + 1];
    if (!comment.startsWith('#')) wrong.push(`a comment line does not open with a hash (${comment})`);
    else if (!/Alt\+t/.test(comment))
      wrong.push(`the comment does not name the shortcut that draws the shape under it (${comment})`);
    else if ([...comment].length > PREVIEW_WIDTH)
      wrong.push(`the comment is ${[...comment].length} glyphs and would decide the width of the preview`);
    if (!under || !under.text.trim().startsWith('┈─'))
      wrong.push('the comment does not stand directly over the compact line it labels');
    if (painted.filter((l) => l.comment).length !== 1)
      wrong.push('the preview labels one line, the compact one, and no other');
  }
  if (wrong.length) wrong.forEach((what) => fail(what));
  else ok(`the preview says what its compact line is: ${painted[at].text.trim()}`);
}

console.log(failures ? `\n${failures} failure(s)` : `\nthe frame of the prompt and the frame of the page agree`);
process.exit(failures ? 1 : 0);
