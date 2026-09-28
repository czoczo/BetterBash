// The top line of the prompt, as the page draws it in its preview.
//
// prompt/bb.sh draws the frame of a prompt out of elements, every one of them
// optional, and sizes the dashes between its two halves from what the two halves
// show: the line is as long as the terminal leaves, whatever is hidden. The page
// shows a prompt of its own, of a fixed width, and it has to be built the same
// way - a preview in which hiding the clock left a hole where it stood would
// preview a prompt the shell does not draw.
//
// So this holds the elements the checkboxes of the page speak for, and builds the
// line: the same widths prompt/bb.sh counts, the same separators, the same fill
// and the same dashes an hidden element hands back when the fill is gone.
// tests/test-frame.mjs draws the frame with bash and compares it with what this
// builds, glyph for glyph.

import { ELEMENT_KEYS } from './theme-code.js';

// The elements of the top line, in the order their bits are written and in the
// order they stand in the frame. `label` is what the checkbox of the page says,
// and `hint` what it says when the pointer rests on it: which part of the line
// the checkbox takes away.
export const ELEMENTS = [
  { key: 'PROMPT_USER', label: 'Username', hint: 'the name in (user@host:tty)' },
  { key: 'PROMPT_HOST', label: 'Hostname', hint: 'the machine in (user@host:tty)' },
  { key: 'PROMPT_TTY', label: 'Terminal', hint: 'the pts/5 in (user@host:tty)' },
  { key: 'AVATAR', label: 'Avatar', hint: 'the hostname hashed into eight glyphs' },
  { key: 'PROMPT_JOBS', label: 'Background jobs', hint: 'commands running in the background' },
  { key: 'PROMPT_EXIT', label: 'Exit code', hint: 'what the last command returned' },
  { key: 'PROMPT_DURATION', label: 'Duration', hint: 'how long the last command ran' },
  { key: 'PROMPT_DATE', label: 'Date', hint: 'the day the prompt was drawn' },
  { key: 'PROMPT_CLOCK', label: 'Clock', hint: 'the time the prompt was drawn' },
];

export const LEFT_ELEMENTS = ELEMENTS.slice(0, 5);
export const RIGHT_ELEMENTS = ELEMENTS.slice(5);

// The width of the preview box, in glyphs, and the terminal that would draw the
// same line: prompt/bb.sh keeps the top line four columns short of the right
// edge of the terminal it is drawn in.
//
// Growing this grows the fill of both prompt lines by the same number of glyphs -
// the two halves take what they take, so every glyph added here is a glyph of the
// border between them - and the two lines of the preview stay one width, which is
// what the box is drawn for (see .ps1-line in src/style.css, which scales the font
// to it so the black box of the page stays as wide as it was).
export const PREVIEW_WIDTH = 120;
export const columnsFor = (width) => width + 4;

// The state of the checkboxes of the page, which is also a theme of a machine:
// what the prompt of a preview shows, apart from the colours and the name of the
// host. `jobs` is the number of background commands, and 0 stands for a machine
// with none, which has no counter to show rather than one hiding it.
export const SAMPLE = {
  user: 'user',
  tty: 'pts/5',
  jobs: 1,
  code: 0,
  duration: '42',
  date: 'Wed May 14',
  clock: '00:40:03',
};

// A prompt of a machine that is logged in as root, has a command that ended in
// error, and has nothing running in the background: the second prompt the page
// previews, and the reason the two of them cannot share their numbers.
export const SAMPLE_ROOT = {
  user: 'ROOT',
  root: true,
  tty: 'pts/5',
  jobs: 0,
  code: 127,
  duration: '12',
  date: 'Wed May 14',
  clock: '00:40:12',
};

const segment = (text, colorKey) => ({ text, colorKey });
const dashRun = (count) => '─'.repeat(count);

// What an element of the line takes when it shows: its own glyphs and the two
// dashes of the separator that stands before it, except for the first element of
// a half, which hangs from the corner or from the fill instead.
const widthOf = {
  // The brackets of (user@host:tty), its @ and its : over the names themselves.
  identity: ({ user, host, tty }) => 4 + user.length + host.length + tty.length,
  avatar: () => 12,
  // Two dashes of its separator, a bracket each, the space and the arrow, and the
  // digits of the count - what prompt/bb.sh calls PROC_NATURAL. A machine with no
  // background jobs has no counter, and takes nothing: it is absent, not hidden.
  jobs: (jobs) => (jobs > 0 ? String(jobs).length + 6 : 0),
  // The code, its arrow and a bracket each - or the five dashes that stand for a
  // command that ended well, which is the width of that segment when it shows.
  // It is the first element of its half, so it stands behind no separator.
  exit: (code) => (code ? String(code).length + 4 : 5),
  duration: (duration) => String(duration).length + 5,
  date: () => 14,
  clock: () => 12,
  // The three dashes and half a dash the line closes with.
  tail: () => 4,
};

// Everything the line would take were all of it shown - the measure prompt/bb.sh
// calls ROOM is worked out of this, and never of what the theme hides, so a frame
// with three elements and a frame with seven break at the same width.
const naturalWidths = ({ user, host, tty, jobs, code, duration }) => {
  const left = 2 + widthOf.identity({ user, host, tty }) + widthOf.avatar() + widthOf.jobs(jobs);
  const right = widthOf.exit(code) + widthOf.duration(duration) + widthOf.date() + widthOf.clock() + widthOf.tail();
  return { left, right };
};

// The top line of the prompt, as segments of { text, colorKey }, for a theme of
// the page: the flags of the elements, the colours, the host name of the preview,
// and the sample of what the prompt says. `avatar` is the eight glyph segments of
// the host, which the page draws itself and only hands over as coloured pieces.
export function topLine({ flags, host, avatar = [], sample = SAMPLE, columns = columnsFor(PREVIEW_WIDTH) }) {
  const { user, root = false, tty, jobs, code, duration, date, clock } = { ...SAMPLE, ...sample };
  const on = (key) => flags[key] !== false;
  const natural = naturalWidths({ user, host, tty, jobs, code, duration });
  // ROOM, of prompt/bb.sh: what the terminal leaves for the fill were the whole
  // row shown. It is measured over every element and never over the ones the
  // theme hides, so a frame with three elements and a frame with seven break at
  // the same width.
  const room = columns - 4 - natural.left - natural.right;
  const narrow = room <= 0;

  // (user@host:tty), measured and drawn as one element with parts of its own. The
  // @ belongs to a name and a machine together and stands between them when both
  // do; the : belongs to the terminal, and is dropped when the terminal comes
  // first in the brackets, which would else open with it.
  const identity = [];
  let identityWidth = 0;
  const add = (text, colorKey) => {
    identity.push(segment(text, colorKey));
    identityWidth += text.length;
  };
  if (on('PROMPT_USER')) add(user, root ? 'ROOT_COLOR' : 'SECONDARY_COLOR');
  if (on('PROMPT_HOST')) {
    if (identity.length) add('@', 'SEPARATOR_COLOR');
    add(host, 'PRIMARY_COLOR');
  }
  if (on('PROMPT_TTY')) {
    if (identity.length) add(':', 'SEPARATOR_COLOR');
    // The terminal of the line in the colour of the host, as prompt/bb.sh draws it:
    // both say which machine this is, and one of them is not a note about the other.
    add(tty, 'PRIMARY_COLOR');
  }
  const identityNatural = widthOf.identity({ user, host, tty });
  const identityShown = identity.length ? identityWidth + 2 : 0;

  // What the elements that hide give up: to the fill, where there is a fill; to
  // their own place, as dashes of the frame, where the terminal is too narrow for
  // the whole row. The parts of (user@host:tty) are the exception - a bracket full
  // of dashes where a name stood reads as a name of dashes - so a half shown
  // identity is absorbed by the fill, or given up below the break.
  const given =
    identityNatural - identityShown +
    (on('AVATAR') ? 0 : widthOf.avatar()) +
    (on('PROMPT_JOBS') ? 0 : widthOf.jobs(jobs)) +
    (on('PROMPT_EXIT') ? 0 : widthOf.exit(code)) +
    (on('PROMPT_DURATION') ? 0 : widthOf.duration(duration)) +
    (on('PROMPT_DATE') ? 0 : widthOf.date()) +
    (on('PROMPT_CLOCK') ? 0 : widthOf.clock());

  // An element that does not show: nothing where the fill is there to take its
  // width back, and dashes of the frame of that same width where it is not.
  const hiding = (key, naturalWidth) =>
    on(key) ? [] : narrow ? [segment(dashRun(naturalWidth), 'BORDCOL')] : [];

  const out = [segment('┌─', 'BORDCOL')];

  if (identity.length) out.push(segment('(', 'SEPARATOR_COLOR'), ...identity, segment(')', 'SEPARATOR_COLOR'));
  else if (narrow) out.push(segment(dashRun(identityNatural), 'BORDCOL'));

  // The avatar, behind two dashes of its own.
  if (on('AVATAR')) {
    out.push(segment('──', 'BORDCOL'), segment('(', 'SEPARATOR_COLOR'), ...avatar, segment(')', 'SEPARATOR_COLOR'));
  } else {
    out.push(...hiding('AVATAR', widthOf.avatar()));
  }

  // The counter of background commands, which a machine without any does not
  // have: it is absent rather than hidden, and hands nothing back.
  if (jobs > 0) {
    if (on('PROMPT_JOBS')) {
      out.push(
        segment('──', 'BORDCOL'),
        segment('(', 'SEPARATOR_COLOR'),
        segment(`${jobs} ↻`, 'SECONDARY_COLOR'),
        segment(')', 'SEPARATOR_COLOR')
      );
    } else {
      out.push(...hiding('PROMPT_JOBS', widthOf.jobs(jobs)));
    }
  }

  // The fill: whatever width the terminal leaves over, and whatever the elements
  // that hide gave up. When the terminal is too narrow for the row, the fill is
  // dropped rather than keeping the dash it would otherwise carry, because that
  // dash would push the frame onto the next line.
  const fill = narrow ? 0 : room + given;
  if (fill > 0) out.push(segment(dashRun(fill), 'BORDCOL'));

  // The right half, hanging from the right edge of the line: the code the last
  // command left, how long it ran, the day, and the time of it. The code stands
  // behind no separator - it is the first of its half, and the fill is behind it -
  // and the five dashes of a command that ended well are that segment rather than
  // something next to it.
  if (on('PROMPT_EXIT')) {
    out.push(
      code
        ? [segment('(', 'SEPARATOR_COLOR'), segment(`${code} ↵`, 'ERR_COLOR'), segment(')', 'SEPARATOR_COLOR')]
        : [segment(dashRun(5), 'BORDCOL')]
    );
  } else {
    out.push(...hiding('PROMPT_EXIT', widthOf.exit(code)));
  }

  const behind = (text, colorKey) => [
    segment('──', 'BORDCOL'),
    segment('(', 'SEPARATOR_COLOR'),
    segment(text, colorKey),
    segment(')', 'SEPARATOR_COLOR'),
  ];

  out.push(...(on('PROMPT_DURATION') ? behind(`${duration}s`, 'PRIMARY_COLOR') : hiding('PROMPT_DURATION', widthOf.duration(duration))));
  out.push(...(on('PROMPT_DATE') ? behind(date, 'TIME_COLOR') : hiding('PROMPT_DATE', widthOf.date())));
  // The clock is drawn in the colour of an error when the command that drew the
  // prompt left one, whether or not the code of it shows too.
  out.push(
    ...(on('PROMPT_CLOCK')
      ? behind(clock, code ? 'ERR_COLOR' : 'PRIMARY_COLOR')
      : hiding('PROMPT_CLOCK', widthOf.clock()))
  );

  out.push(segment('───┈', 'BORDCOL'));

  return out.flat();
}

export const lineText = (segments) => segments.map((s) => s.text).join('');

// The flags of a theme as the checkboxes hold them: a thing of booleans out of
// the bit string of the theme code, and back into it.
export const flagsOf = (bits) =>
  Object.fromEntries(ELEMENT_KEYS.map((key, i) => [key, String(bits)[i] === '1']));

export const bitsOfFlags = (flags) => ELEMENT_KEYS.map((key) => (flags[key] === false ? '0' : '1')).join('');
