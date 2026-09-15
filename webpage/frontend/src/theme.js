// UI (chrome) theming helpers.
//
// The page chrome (headings, links, buttons, active tabs, ...) used to be
// hardcoded to a green (#4e9a06) with a few derived shades. From now on the
// accent is derived from the theme's PRIMARY_COLOR, so that a random theme
// re-skins the whole page.

export const PAGE_BACKGROUND = '#1e1e1e';

const clamp = (v, min, max) => Math.min(max, Math.max(min, v));

export function hexToRgb(hex) {
  let clean = String(hex).trim().replace('#', '');
  if (clean.length === 3) {
    clean = clean.split('').map((c) => c + c).join('');
  }
  const num = parseInt(clean, 16);
  if (Number.isNaN(num)) return { r: 0, g: 0, b: 0 };
  return { r: (num >> 16) & 0xff, g: (num >> 8) & 0xff, b: num & 0xff };
}

export function rgbToHex({ r, g, b }) {
  const to2 = (v) => Math.round(clamp(v, 0, 255)).toString(16).padStart(2, '0');
  return `#${to2(r)}${to2(g)}${to2(b)}`;
}

/** h: 0-360, s: 0-1, l: 0-1 */
export function rgbToHsl({ r, g, b }) {
  const rd = r / 255;
  const gd = g / 255;
  const bd = b / 255;
  const max = Math.max(rd, gd, bd);
  const min = Math.min(rd, gd, bd);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === rd) h = (gd - bd) / d + (gd < bd ? 6 : 0);
    else if (max === gd) h = (bd - rd) / d + 2;
    else h = (rd - gd) / d + 4;
    h /= 6;
  }
  return { h: h * 360, s, l };
}

/** h: 0-360, s: 0-1, l: 0-1 */
export function hslToRgb({ h, s, l }) {
  const hh = ((h % 360) + 360) % 360 / 360;
  if (s === 0) {
    const v = l * 255;
    return { r: v, g: v, b: v };
  }
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  const conv = (t) => {
    let tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p + (q - p) * 6 * tt;
    if (tt < 1 / 2) return q;
    if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
    return p;
  };
  return { r: conv(hh + 1 / 3) * 255, g: conv(hh) * 255, b: conv(hh - 1 / 3) * 255 };
}

export function hslToHex(hsl) {
  return rgbToHex(hslToRgb(hsl));
}

function linearize(channel) {
  const v = channel / 255;
  return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

export function relativeLuminance({ r, g, b }) {
  return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b);
}

export function contrastRatio(colorA, colorB) {
  const lumA = relativeLuminance(hexToRgb(colorA));
  const lumB = relativeLuminance(hexToRgb(colorB));
  const lighter = Math.max(lumA, lumB);
  const darker = Math.min(lumA, lumB);
  return (lighter + 0.05) / (darker + 0.05);
}

/**
 * Nudge a colour's lightness (hue/saturation are kept) until it is readable
 * against `bgHex`. Without this a random PRIMARY_COLOR such as "Black" or
 * "Light Gray" would make headings, links and buttons unreadable.
 */
export function ensureContrast(hex, bgHex, minRatio) {
  if (contrastRatio(hex, bgHex) >= minRatio) return hex;

  const bgIsDark = relativeLuminance(hexToRgb(bgHex)) < 0.5;
  const { h, s, l } = rgbToHsl(hexToRgb(hex));

  for (let i = 1; i <= 100; i++) {
    const nextL = clamp(l + (bgIsDark ? i : -i) * 0.01, 0, 1);
    const candidate = hslToHex({ h, s, l: nextL });
    if (contrastRatio(candidate, bgHex) >= minRatio) return candidate;
    if (nextL === (bgIsDark ? 1 : 0)) break;
  }

  return bgIsDark ? '#ffffff' : '#000000';
}

export function shiftLightness(hex, delta) {
  const { h, s, l } = rgbToHsl(hexToRgb(hex));
  return hslToHex({ h, s, l: clamp(l + delta, 0, 1) });
}

const REFERENCE_PRIMARY = '#4e9a06';
const referenceHsl = rgbToHsl(hexToRgb(REFERENCE_PRIMARY));

/**
 * The header banner is a raster image drawn in the classic primary green, so it
 * is rotated towards the accent hue instead of being recoloured pixel by pixel.
 */
export function bannerFilterFor(accentHex) {
  const { h, s } = rgbToHsl(hexToRgb(accentHex));
  // A near-grey accent carries no hue: mute the banner instead of rotating it.
  if (s < 0.15) {
    return { hueRotate: 0, saturate: 0.15 };
  }
  return {
    hueRotate: ((h - referenceHsl.h + 540) % 360) - 180,
    saturate: clamp(s / referenceHsl.s, 0.4, 1.6),
  };
}

/**
 * Build the full accent ramp from the raw PRIMARY_COLOR hex value.
 * `base` is untouched, `accent` is guaranteed readable on the page background.
 */
export function buildAccentPalette(baseHex) {
  const accent = ensureContrast(baseHex, PAGE_BACKGROUND, 4.5);

  const accentL = rgbToHsl(hexToRgb(accent)).l;
  // Buttons read as "pressed" when they move away from the page background.
  const hover = ensureContrast(
    shiftLightness(accent, accentL > 0.3 ? -0.08 : 0.12),
    PAGE_BACKGROUND,
    2.5,
  );

  const bright = ensureContrast(shiftLightness(accent, 0.24), PAGE_BACKGROUND, 4.5);

  const { r, g, b } = hexToRgb(accent);
  const soft = `rgba(${Math.round(r)}, ${Math.round(g)}, ${Math.round(b)}, 0.2)`;

  const onAccent =
    contrastRatio(accent, '#ffffff') >= 3 ? '#ffffff' : PAGE_BACKGROUND;

  const { hueRotate, saturate } = bannerFilterFor(accent);

  return { base: baseHex, accent, hover, bright, soft, onAccent, hueRotate, saturate };
}

export function applyAccentPalette(palette, target = document.documentElement) {
  if (!target || !target.style) return;
  target.style.setProperty('--primary-color', palette.accent);
  target.style.setProperty('--primary-base', palette.base);
  target.style.setProperty('--primary-hover', palette.hover);
  target.style.setProperty('--primary-bright', palette.bright);
  target.style.setProperty('--primary-soft', palette.soft);
  target.style.setProperty('--primary-contrast', palette.onAccent);
  target.style.setProperty('--banner-hue-rotate', `${palette.hueRotate.toFixed(1)}deg`);
  target.style.setProperty('--banner-saturate', palette.saturate.toFixed(2));
}
