// Auto-fitting of the bash prompt preview.
//
// Goal: the longest prompt line should fill (almost) the whole width of the
// black preview box at any window size, using one monospace font size for the
// whole preview so terminal columns keep lining up.
//
// Scaling the font size alone is not enough: browsers (on Linux especially,
// where font hinting rounds glyph advances to whole pixels) grow the rendered
// line width as a staircase, so one font-size step can jump past the available
// width. The size is therefore found by *measuring* - a binary search for the
// largest font size that still fits - and the leftover pixels are closed with a
// small, uniform letter-spacing bonus (spread over the characters of the line,
// which keeps the monospace look and the column alignment).
//
// Note: clientWidth/scrollWidth of the lines are useless here - they are block
// boxes sharing the width of their container. The text extent is measured with
// a Range instead.

const MIN_FONT_SIZE = 6;
const MAX_FONT_SIZE = 30;
const MEASUREMENT_FONT_SIZE = 20; // seed used to sanity check the box
const FILL_RATIO = 0.995; // "almost" the full width
const SEARCH_PASSES = 9;
const MAX_EXTRA_TRACKING = 2; // px per character

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const toPx = (value) => (value === 'normal' ? 0 : parseFloat(value) || 0);

/** Horizontal extent of the rendered text inside `el` (not its block box). */
function measureTextWidth(el) {
  const range = document.createRange();
  range.selectNodeContents(el);

  let left = Infinity;
  let right = -Infinity;
  for (const rect of range.getClientRects()) {
    if (rect.width <= 0) continue;
    left = Math.min(left, rect.left);
    right = Math.max(right, rect.right);
  }
  range.detach?.();

  return Number.isFinite(left) && Number.isFinite(right) ? right - left : 0;
}

/**
 * Longest rendered line: its width and character count.
 * `width` includes the trailing letter-spacing that CSS adds after the last
 * character, so `inkWidth` (the visible extent) is `width - letterSpacing`.
 */
function measureLongestLine(lines, letterSpacing) {
  let width = 0;
  let chars = 0;
  for (const line of lines) {
    const lineWidth = measureTextWidth(line);
    if (lineWidth > width) {
      width = lineWidth;
      chars = Math.max(1, Array.from(line.textContent).length);
    }
  }
  return { width, inkWidth: width - letterSpacing * (chars > 1 ? 1 : 0), chars };
}

export function fitTerminalFont(
  el,
  {
    lineSelector = '.ps1-line',
    minFontSize = MIN_FONT_SIZE,
    maxFontSize = MAX_FONT_SIZE,
    measurementFontSize = MEASUREMENT_FONT_SIZE,
    fillRatio = FILL_RATIO,
    searchPasses = SEARCH_PASSES,
    maxExtraTracking = MAX_EXTRA_TRACKING,
  } = {},
) {
  if (!el) return null;

  const lines = [...el.querySelectorAll(lineSelector)];
  if (!lines.length) return null;

  // A scrollbar popping in would narrow the box mid-measurement.
  const prevOverflowX = el.style.overflowX;
  el.style.overflowX = 'hidden';

  // Start from the stylesheet values so every run is independent.
  el.style.fontSize = '';
  el.style.letterSpacing = '';
  const computed = getComputedStyle(el);
  const baseTracking = toPx(computed.letterSpacing);
  const paddingX = toPx(computed.paddingLeft) + toPx(computed.paddingRight);
  const available = el.clientWidth - paddingX;
  if (available <= 0) {
    el.style.overflowX = prevOverflowX;
    return null;
  }
  const targetWidth = available * fillRatio;

  const setFontSize = (size) => {
    el.style.fontSize = `${size}px`;
  };
  const setTracking = (value) => {
    el.style.letterSpacing = `${value}px`;
  };
  const currentTracking = () =>
    el.style.letterSpacing === '' ? baseTracking : toPx(el.style.letterSpacing);
  const longest = () => measureLongestLine(lines, currentTracking());

  // Bail out when nothing measurable is rendered.
  setFontSize(measurementFontSize);
  if (longest().width <= 0) {
    el.style.overflowX = prevOverflowX;
    return null;
  }

  // 1) largest font size whose lines still fit (binary search on measured width)
  let low = minFontSize;
  let high = maxFontSize;
  setFontSize(low);
  let bestSize = low;
  let best = longest();

  if (best.inkWidth <= targetWidth) {
    for (let i = 0; i < searchPasses; i++) {
      const mid = (low + high) / 2;
      setFontSize(mid);
      if (longest().inkWidth <= targetWidth) {
        low = mid;
      } else {
        high = mid;
      }
    }
    bestSize = low;
    setFontSize(bestSize);
    best = longest();

    // 2) close the staircase gap with uniform extra tracking. For a monospace
    // run: inkWidth = chars * advance + (chars - 1) * tracking.
    if (best.inkWidth < targetWidth) {
      const advanceTotal = best.width - best.chars * currentTracking();
      const idealTracking = (targetWidth - advanceTotal) / Math.max(1, best.chars - 1);
      const extra = clamp(idealTracking - baseTracking, 0, maxExtraTracking);
      if (extra > 0) {
        setTracking(baseTracking + extra);
        const corrected = longest();
        if (corrected.inkWidth > targetWidth) {
          const scale = targetWidth / corrected.inkWidth;
          setTracking(baseTracking + extra * scale);
        }
      }
    }
  }

  setFontSize(bestSize);
  if (currentTracking() === baseTracking) el.style.letterSpacing = '';
  el.style.overflowX = prevOverflowX;

  return bestSize;
}
