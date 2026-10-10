// A host name for the machine the preview stands for. The page cannot read
// `/etc/hostname`, so the name - and the avatar hashed out of it, see avatar.js - is
// drawn instead of being one constant every visitor shared.
//
// The words are those of `hostnamegen`: an adjective and a noun joined with a dash, from
// the two lists below kept as that script holds them - including its two duplicated
// words (`water`, `sun`), which is why they come up a little more often. The number the
// script appends is left out: it told one machine from another of the same name, and the
// preview is a single machine.
//
// Nothing here enters a theme code or an install command, and the field stays typeable -
// the avatar follows whichever name stands in it. tests/test-avatar.mjs holds that the
// page draws its default name here and that no name is too long for its field.

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

// The longest name these lists can make: longest adjective + dash + longest noun. The
// field of the page keeps a maxlength of its own to it.
export const MAX_HOSTNAME_LENGTH =
  Math.max(...ADJECTIVES.map((word) => word.length)) +
  1 +
  Math.max(...NOUNS.map((word) => word.length));

// The dice of the browser, if it has them - more than a preview asks for, but free to
// use.
const dice = typeof globalThis.crypto?.getRandomValues === 'function' ? globalThis.crypto : null;

/**
 * A whole number from 0 up to (not including) `limit`, all equally likely. The remainder
 * of a 32 bit draw is not even unless the limit divides 2^32, so values past the last
 * whole multiple are thrown away and redrawn. Without crypto, `Math.random` is used.
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
 * A host name: an adjective and a noun, as `hostnamegen` spells them. `below` is the
 * dice, handed over only so a test can roll a name it knows in advance.
 */
export function randomHostname({ below = randomBelow } = {}) {
  return `${ADJECTIVES[below(ADJECTIVES.length)]}-${NOUNS[below(NOUNS.length)]}`;
}
