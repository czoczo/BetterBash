// The top line of the prompt, as the page draws it in its preview.
//
// prompt/bb.sh builds the frame from optional elements and sizes the dashes between its
// halves from what shows. The page previews a prompt of a fixed width and has to be
// built the same way - a preview where hiding the clock left a hole would preview a
// prompt the shell does not draw - so this holds the nine elements and the border fill,
// and counts the same widths, separators, fill and handed back dashes.
// tests/test-frame.mjs draws the frame with bash and compares it glyph for glyph.

import { ELEMENT_KEYS } from './theme-code.js';

// The elements of the top line, in the order of their bits and of the frame. `label` is
// what the checkbox says, `hint` what it says on hover.
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
  // The tenth flag and not an element: the border fill, between the two halves.
  {
    key: 'PROMPT_FILL',
    label: 'Border fill',
    hint: 'the dashes that stretch the line to the width of the terminal',
  },
];

// The width of the preview box in glyphs, and the terminal that would draw the same
// line (prompt/bb.sh keeps four columns short of its right edge). Growing it grows the
// fill and keeps both preview lines one width; a theme without the fill is padded to the
// same width (see topLine), because a line that shrank with every unticked box would
// slide its elements sideways. .ps1-line in style.css scales the font to it.
export const PREVIEW_WIDTH = 120;
export const columnsFor = (width) => width + 4;

// The state of the checkboxes, which is also a theme of a machine. `jobs` 0 means a
// machine with no background commands: absent rather than hidden.
export const SAMPLE = {
  user: 'user',
  tty: 'pts/5',
  jobs: 1,
  code: 0,
  duration: '42',
  date: 'Wed May 14',
  clock: '00:40:03',
};

// The second prompt the page previews: root, a command that ended in error, no jobs -
// hence the two samples cannot share their numbers.
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
// The width a line without the fill falls short of, padded in as nothing to see. The
// preview centres a box around its longest line; a terminal does not.
const spaceRun = (count) => ({ text: ' '.repeat(count), colorKey: null });

// What an element takes when it shows: its glyphs plus the two dashes of the separator
// before it, except the first of a half, which hangs from the corner or the fill.
const widthOf = {
  // The brackets of (user@host:tty), its @ and its : over the names themselves.
  identity: ({ user, host, tty }) => 4 + user.length + host.length + tty.length,
  avatar: () => 12,
  // Separator, brackets, space, arrow and digits - prompt/bb.sh's PROC_NATURAL. No jobs
  // means no counter at all: absent, not hidden.
  jobs: (jobs) => (jobs > 0 ? String(jobs).length + 6 : 0),
  // The code, its arrow and a bracket each, or the five dashes of a command that ended
  // well. First of its half, so behind no separator.
  exit: (code) => (code ? String(code).length + 4 : 5),
  duration: (duration) => String(duration).length + 5,
  date: () => 14,
  clock: () => 12,
  // The three dashes and half a dash the line closes with.
  tail: () => 4,
};

// What the whole line would take: ROOM is worked out of this and never of what the theme
// hides, so a frame with three elements and one with seven break at the same width.
const naturalWidths = ({ user, host, tty, jobs, code, duration }) => {
  const left = 2 + widthOf.identity({ user, host, tty }) + widthOf.avatar() + widthOf.jobs(jobs);
  const right = widthOf.exit(code) + widthOf.duration(duration) + widthOf.date() + widthOf.clock() + widthOf.tail();
  return { left, right };
};

/**
 * The top line as segments of { text, colorKey } for a theme of the page. `avatar` is
 * the eight glyph segments the page draws and hands over as coloured pieces.
 */
export function topLine({ flags, host, avatar = [], sample = SAMPLE, columns = columnsFor(PREVIEW_WIDTH) }) {
  const { user, root = false, tty, jobs, code, duration, date, clock } = { ...SAMPLE, ...sample };
  const on = (key) => flags[key] !== false;
  const natural = naturalWidths({ user, host, tty, jobs, code, duration });
  // ROOM, of prompt/bb.sh: what the terminal leaves for the fill were the whole row
  // shown.
  const room = columns - 4 - natural.left - natural.right;
  // The two states of the line: stretched to the edge of the terminal, or holding only
  // what shows. A line without the fill is never too narrow for one.
  const fills = on('PROMPT_FILL');
  const narrow = fills && room <= 0;

  // (user@host:tty), one element with parts of its own: @ stands between a name and a
  // machine when both show, : belongs to the terminal and is dropped when it comes first.
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
    // The tty in the colour of the host, as prompt/bb.sh draws it.
    add(tty, 'PRIMARY_COLOR');
  }
  const identityNatural = widthOf.identity({ user, host, tty });
  const identityShown = identity.length ? identityWidth + 2 : 0;

  // What the hidden elements give up: to the fill where there is one, to their own place
  // as frame dashes where the terminal is too narrow. (user@host:tty) is the exception -
  // a bracket of dashes where a name stood reads as a name of dashes.
  const given =
    identityNatural - identityShown +
    (on('AVATAR') ? 0 : widthOf.avatar()) +
    (on('PROMPT_JOBS') ? 0 : widthOf.jobs(jobs)) +
    (on('PROMPT_EXIT') ? 0 : widthOf.exit(code)) +
    (on('PROMPT_DURATION') ? 0 : widthOf.duration(duration)) +
    (on('PROMPT_DATE') ? 0 : widthOf.date()) +
    (on('PROMPT_CLOCK') ? 0 : widthOf.clock());

  // An element that does not show: nothing while the fill takes its width back, frame
  // dashes of that width otherwise.
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

  // The job counter, absent rather than hidden when there are no jobs.
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

  // The fill: what the terminal leaves over, plus what the hidden elements gave up. It
  // is dropped rather than pushing the frame onto the next line, and absent altogether
  // when the theme asks for no fill.
  const fill = !fills || narrow ? 0 : room + given;
  if (fill > 0) out.push(segment(dashRun(fill), 'BORDCOL'));

  // The right half, hanging from the right edge: exit code, duration, date, clock. The
  // code stands behind no separator, being first of its half.
  if (on('PROMPT_EXIT')) {
    out.push(
      // Without the fill, the two dashes the other elements carry join it to what
      // stands before.
      ...(fills ? [] : [segment('──', 'BORDCOL')]),
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
  // The clock takes the colour of an error when the last command left one, whether or
  // not the code shows.
  out.push(
    ...(on('PROMPT_CLOCK')
      ? behind(clock, code ? 'ERR_COLOR' : 'PRIMARY_COLOR')
      : hiding('PROMPT_CLOCK', widthOf.clock()))
  );

  out.push(segment('───┈', 'BORDCOL'));

  // A line without the fill ends behind its last element, and the box is drawn around
  // the longest line it holds: untick a box and everything slides right. So the width
  // the fill would have stretched is padded in at the end, spaces and no colour.
  if (!fills) {
    const drawn = out.flat().reduce((glyphs, piece) => glyphs + [...piece.text].length, 0);
    const pad = columns - 12 - drawn;
    if (pad > 0) out.push(spaceRun(pad));
  }

  return out.flat();
}

export const lineText = (segments) => segments.map((s) => s.text).join('');

// The flags of the checkboxes, out of the bit string of the code and back into it.
export const flagsOf = (bits) =>
  Object.fromEntries(ELEMENT_KEYS.map((key, i) => [key, String(bits)[i] === '1']));

export const bitsOfFlags = (flags) => ELEMENT_KEYS.map((key) => (flags[key] === false ? '0' : '1')).join('');
