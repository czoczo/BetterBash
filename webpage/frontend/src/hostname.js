// A host name for the machine the preview of the page stands for.
//
// The preview is a prompt of a machine this page has never seen: it cannot read
// `/etc/hostname`, so the name - and the avatar hashed out of it, see avatar.js -
// has to come from somewhere else. It used to come from one constant: every
// visitor previewed the same machine, refreshed the page, and previewed it again.
// Here it comes from a draw, so a fresh load of the page is a fresh machine, and
// the avatar below it is that machine's rather than one shared by everyone who
// ever opened the page.
//
// The words of the name are the words of `hostnamegen`: an adjective and a noun,
// drawn out of the two lists below and joined with a dash. The lists are that
// script's own, kept as it keeps them - including the two words it holds twice
// (`water`, `sun`), which is why those two come up a little more often than the
// rest. What is left out is the number the script puts behind them: it numbered one
// machine among many with the same words, and the preview is a single machine that
// nobody has to tell apart from another. A name made here is what a name from that
// script is before its number.
//
// What a name is good for is the field of the page it is typed into: nothing here
// enters a theme code, and no install command carries it. The field keeps being
// typeable - a name drawn is not a name the visitor is stuck with, and the avatar
// follows whichever of the two is standing.
//
// tests/test-avatar.mjs holds this to two things: that the page draws its default
// name here rather than spelling one out, and that no name this can make is too
// long for the field the page puts it in.

// The adjectives and the nouns, in the order the script lists them.
export const ADJECTIVES = [
  'autumn', 'hidden', 'bitter', 'misty', 'silent', 'empty', 'dry', 'dark',
  'summer', 'icy', 'delicate', 'quiet', 'white', 'cool', 'spring', 'winter',
  'patient', 'twilight', 'dawn', 'crimson', 'wispy', 'weathered', 'blue',
  'billowing', 'broken', 'cold', 'damp', 'falling', 'frosty', 'green', 'long',
  'late', 'lingering', 'bold', 'little', 'morning', 'muddy', 'old', 'red',
  'rough', 'still', 'small', 'sparkling', 'throbbing', 'shy', 'wandering',
  'withered', 'wild', 'black', 'young', 'holy', 'solitary', 'fragrant', 'aged',
  'snowy', 'proud', 'floral', 'restless', 'divine', 'polished', 'ancient',
  'purple', 'lively', 'nameless',
];

export const NOUNS = [
  'waterfall', 'river', 'breeze', 'moon', 'rain', 'wind', 'sea', 'morning',
  'snow', 'lake', 'sunset', 'pine', 'shadow', 'leaf', 'dawn', 'glitter',
  'forest', 'hill', 'cloud', 'meadow', 'sun', 'glade', 'bird', 'brook',
  'butterfly', 'bush', 'dew', 'dust', 'field', 'fire', 'flower', 'firefly',
  'feather', 'grass', 'haze', 'mountain', 'night', 'pond', 'darkness',
  'snowflake', 'silence', 'sound', 'sky', 'shape', 'surf', 'thunder', 'violet',
  'water', 'wildflower', 'wave', 'water', 'resonance', 'sun', 'wood', 'dream',
  'cherry', 'tree', 'fog', 'frost', 'voice', 'paper', 'frog', 'smoke', 'star',
];

// The longest name this file can make: its longest adjective and its longest noun,
// with the dash between them. It is stated here because it is a property of the
// lists above and of nothing else, and the field of the page that a name is typed
// into has a maxlength of its own to keep.
export const MAX_HOSTNAME_LENGTH =
  Math.max(...ADJECTIVES.map((word) => word.length)) +
  1 +
  Math.max(...NOUNS.map((word) => word.length));

// The dice of the browser, if it has them. `crypto.getRandomValues` is what a page
// reaches for when it wants a number nobody outside the page can predict, which is
// more than a preview asks for but is also the dice that costs nothing to use.
const dice = typeof globalThis.crypto?.getRandomValues === 'function' ? globalThis.crypto : null;

/**
 * A whole number from 0 up to but not including `limit`, every one of them as
 * likely as any other.
 *
 * Taking the remainder of a 32 bit draw is not even unless the limit divides
 * 2^32, so the values past the last whole multiple of the limit are thrown away and
 * the draw is taken again - the same trick the page could play with `od` and `%` of
 * the shell script it borrows this shape from, without the shell.
 *
 * Where a browser has no crypto (and in a test run by node, which has it), the
 * older dice of the page are rolled instead: `Math.random`, the same one the theme
 * of the page is drawn with.
 */
export function randomBelow(limit) {
  if (!Number.isInteger(limit) || limit < 1) {
    throw new RangeError(`randomBelow wants a whole limit of at least 1, got ${limit}`);
  }
  if (!dice) return Math.floor(Math.random() * limit);

  const highest = 0xffffffff;
  const whole = highest - (highest % limit); // past it, a value would be preferred over others
  let drawn;
  do {
    drawn = dice.getRandomValues(new Uint32Array(1))[0];
  } while (drawn >= whole);
  return drawn % limit;
}

/**
 * A host name: an adjective and a noun, as `hostnamegen` spells them.
 *
 * `below` is the dice - the draw of one number under a limit - and is handed over
 * only so that a test can roll a name it knows in advance; a page lets it be the
 * browser's own.
 */
export function randomHostname({ below = randomBelow } = {}) {
  return `${ADJECTIVES[below(ADJECTIVES.length)]}-${NOUNS[below(NOUNS.length)]}`;
}
