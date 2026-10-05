<template src="./template.html"></template>

<script setup>
import { ref, computed, watchEffect, onMounted, onBeforeUnmount } from 'vue';
import { buildAccentPalette, applyAccentPalette } from './theme';
import { hostAvatar } from './avatar';
import { randomHostname } from './hostname';
import { APP_ENV, installCommands } from './config';
import { copyText } from './clipboard';
// theme-code.js holds the layout of a theme code and preview.js builds the top line the
// boxes change; the tests read the same files, so page, tests and shell agree.
import {
  ALL_ELEMENTS_ON,
  COLOR_KEYS as ENCODING_ORDERED_COLOR_KEYS,
  decode as readThemeCode,
  encode as writeThemeCode,
  randomRequest,
} from './theme-code';
import { ELEMENTS as PROMPT_ELEMENTS, SAMPLE, SAMPLE_ROOT, bitsOfFlags, flagsOf, topLine } from './preview';
// default theme vN-y_5uA

// Surfaced so a development build cannot be mistaken for the published one.
const appEnv = APP_ENV;

// Color labels for UI
const colorLabels = {
  PRIMARY_COLOR: 'Primary Color',
  SECONDARY_COLOR: 'Secondary Color',
  ROOT_COLOR: 'Root User Color',
  TIME_COLOR: 'Time Color',
  ERR_COLOR: 'Error Code Color',
  SEPARATOR_COLOR: 'Separator Color',
  BORDCOL: 'Border Color',
  PATH_COLOR: 'Path Color',
};

// The boxes of the page, one per element of the top line plus the border fill.
const promptElements = PROMPT_ELEMENTS;

// Which elements show and whether the border fills the line. An eight character code
// says nothing about them and shows them all.
const elementFlags = ref(flagsOf(ALL_ELEMENTS_ON));

// The avatar box stood by itself for longer than the rest; it keeps its old name here
// and in the tour that points at it.
const showAvatar = computed({
  get: () => elementFlags.value.AVATAR !== false,
  set: (on) => {
    elementFlags.value.AVATAR = !!on;
  },
});

// The prompt draws its avatar from the machine's own name and this page cannot read
// /etc/hostname, so the name is asked for - the same string the preview prints as the
// host. The starting name is drawn from the word lists of src/hostname.js, so every load
// stands for another machine; the field stays typeable.
const previewHostname = ref(randomHostname());
const avatarSegments = computed(() => hostAvatar(previewHostname.value, 4));

// The two preview lines as prompt/bb.sh would draw them: one for a command that ended
// well, one for root whose last command failed. tests/test-frame.mjs compares them with
// bash glyph for glyph. A line longer than the box would break under the font size it
// scales to, hence the 32 character hostname field.
const previewLineOf = (sample) =>
  topLine({
    flags: elementFlags.value,
    host: previewHostname.value,
    avatar: avatarSegments.value.map((s) => ({ text: s.glyph, code: s.code })),
    sample,
  });
const previewTopLines = computed(() => [previewLineOf(SAMPLE), previewLineOf(SAMPLE_ROOT)]);
const uninstallFlag = ref(false);
// Random mode: the word "rand" in front of the code asks the machine running the command
// to draw its own colours. The code travels behind it because a draw is a draw of colours
// only - the boxes still say the top line.
const randomFlag = ref(false);
// Automatic mode: the command drops the question it asks before installing, for scripts
// and containers where nobody can answer.
const autoFlag = ref(false);

const activeTab = ref('curl');

// --- Base Color Definitions (30-37 range) ---
const baseColorDefinitions = {
    30: { name: "Black", hex: "#000000", css: "text-black" },
    31: { name: "Red", hex: "#cc0000", css: "text-red" },
    32: { name: "Green", hex: "#4e9a06", css: "text-green" },
    33: { name: "Yellow", hex: "#c4a000", css: "text-yellow" },
    34: { name: "Blue", hex: "#3465a4", css: "text-blue" },
    35: { name: "Magenta", hex: "#75507b", css: "text-magenta" },
    36: { name: "Cyan", hex: "#06989a", css: "text-cyan" },
    37: { name: "Light Gray", hex: "#d3d7cf", css: "text-white" },
};

// --- Light/Bright Color Definitions (90-97 range) ---
const lightColorDefinitions = {
    90: { name: "Bright Black", hex: "#555753", css: "text-bright-black" },
    91: { name: "Bright Red", hex: "#ef2929", css: "text-bright-red" },
    92: { name: "Bright Green", hex: "#8ae234", css: "text-bright-green" },
    93: { name: "Bright Yellow", hex: "#fce94f", css: "text-bright-yellow" },
    94: { name: "Bright Blue", hex: "#729fcf", css: "text-bright-blue" },
    95: { name: "Bright Magenta", hex: "#ad7fa8", css: "text-bright-magenta" },
    96: { name: "Bright Cyan", hex: "#34e2e2", css: "text-bright-cyan" },
    97: { name: "White", hex: "#eeeeec", css: "text-bright-white" },
};

// --- Specific Hex/CSS for BOLD versions ---
const boldColorSpecifics = {
    31: { hex: "#ff4d4d", css: "text-bold-red" },
    32: { hex: "#73d216", css: "text-bold-green" },
    33: { hex: "#edd400", css: "text-bold-yellow" },
    34: { hex: "#3584e4", css: "text-bold-blue" },
    35: { hex: "#ad7fa8", css: "text-bold-magenta" },
    36: { hex: "#34e2e2", css: "text-bold-cyan" },
    37: { hex: "#ffffff", css: "text-bold-white" },
    90: { hex: "#7c7c7c", css: "text-bold-bright-black" },
    95: { hex: "#d070d0", css: "text-bold-bright-magenta" },
    97: { hex: "#ffffff", css: "text-bold-bright-white" },
};

const finalColorMappings = {};
for (const code in baseColorDefinitions) {
    finalColorMappings[`${code}-false`] = { hex: baseColorDefinitions[code].hex, cssClass: baseColorDefinitions[code].css };
}
for (const code in lightColorDefinitions) {
    finalColorMappings[`${code}-false`] = { hex: lightColorDefinitions[code].hex, cssClass: lightColorDefinitions[code].css };
}
for (const code in baseColorDefinitions) {
    const numCode = parseInt(code);
    if (boldColorSpecifics[numCode] && !(numCode >= 90)) {
        finalColorMappings[`${numCode}-true`] = { hex: boldColorSpecifics[numCode].hex, cssClass: boldColorSpecifics[numCode].css };
    } else {
        finalColorMappings[`${numCode}-true`] = { hex: baseColorDefinitions[numCode].hex, cssClass: `${baseColorDefinitions[numCode].css} font-bold-style` };
    }
}
for (const code in lightColorDefinitions) {
    const numCode = parseInt(code);
    if (boldColorSpecifics[numCode]) {
        finalColorMappings[`${numCode}-true`] = { hex: boldColorSpecifics[numCode].hex, cssClass: boldColorSpecifics[numCode].css };
    } else {
        finalColorMappings[`${numCode}-true`] = { hex: lightColorDefinitions[numCode].hex, cssClass: `${lightColorDefinitions[numCode].css} font-bold-style` };
    }
}

const baseColorOptions = Object.entries(baseColorDefinitions).map(([value, { name }]) => ({
  name,
  value: parseInt(value),
}));

const initialBashColorCodes = {
  PRIMARY_COLOR: '\\[\\033[00;92m\\]',       // Bright Green
  SECONDARY_COLOR: '\\[\\033[00;95;1m\\]', // Bold Bright Magenta
  ROOT_COLOR: '\\[\\033[00;31;1m\\]',        // Bold Red
  TIME_COLOR: '\\[\\033[00;33;1m\\]',        // Bold Yellow
  ERR_COLOR: '\\[\\033[00;31;1m\\]',         // Bold Red
  SEPARATOR_COLOR: '\\[\\033[00;97;1m\\]', // Bold White (Bright)
  BORDCOL: '\\[\\033[00;90;1m\\]',         // Bold Bright Black (Gray)
  PATH_COLOR: '\\[\\033[00;97;1m\\]',        // Bold White (Bright)
  RST: '\\[\\033[00;37m\\]',                // Light Gray (Normal)
};

function parseInitialBashCodeToAttributes(bashCode) {
  const match = bashCode.match(/\[(?:(\d{1,2}|[a-zA-Z]);)?(\d{2})(;1)?m/);
  let baseCode = 37; 
  let isLight = false;
  let isBold = false;

  if (match) {
    const stylePart = match[1]; 
    let colorNum = parseInt(match[2]);
    const boldSuffix = match[3]; 

    isLight = colorNum >= 90 && colorNum <= 97;
    baseCode = isLight ? colorNum - 60 : colorNum;
    isBold = !!boldSuffix || stylePart === '1' || stylePart === '01';
  } else {
    const simpleMatch = bashCode.match(/\[(\d{2})m/);
    if (simpleMatch) {
        let colorNum = parseInt(simpleMatch[1]);
        isLight = colorNum >= 90 && colorNum <= 97;
        baseCode = isLight ? colorNum - 60 : colorNum;
        isBold = false; 
    }
  }
  return { baseCode, isLight, isBold };
}

const selectedColorAttributes = ref({});
ENCODING_ORDERED_COLOR_KEYS.forEach(key => {
  if (initialBashColorCodes[key]) {
    selectedColorAttributes.value[key] = parseInitialBashCodeToAttributes(initialBashColorCodes[key]);
  } else {
    selectedColorAttributes.value[key] = { baseCode: 37, isLight: false, isBold: false };
  }
});

const generatedColors = computed(() => {
  const finalCodes = {};
  for (const key in selectedColorAttributes.value) {
    const attrs = selectedColorAttributes.value[key];
    let actualCode = attrs.isLight ? attrs.baseCode + 60 : attrs.baseCode;
    
    if (attrs.isBold) {
      finalCodes[key] = `\\[\\033[1;${actualCode}m\\]`;
    } else {
      finalCodes[key] = `\\[\\033[0;${actualCode}m\\]`; 
    }
  }
  return finalCodes;
});

function parseGeneratedBashCode(bashCode) {
  const match = bashCode.match(/\[(?:(1);)?(\d{2})m/);
  if (match) {
    const isBold = !!match[1];
    const colorNum = parseInt(match[2]);
    return { colorNum, isBold };
  }
  const nonBoldMatch = bashCode.match(/\[0;(\d{2})m/);
  if (nonBoldMatch) {
    return { colorNum: parseInt(nonBoldMatch[1]), isBold: false };
  }
  const simplestMatch = bashCode.match(/\[(\d{2})m/);
  if (simplestMatch) {
    return { colorNum: parseInt(simplestMatch[1]), isBold: false };
  }
  console.warn("Could not parse bash code for preview:", bashCode);
  return { colorNum: 37, isBold: false }; 
}

const getPreviewColorFromBash = (bashCode) => {
  if (!bashCode) return baseColorDefinitions[37].hex;
  const { colorNum, isBold } = parseGeneratedBashCode(bashCode);
  const mappingKey = `${colorNum}-${isBold}`;
  const fallbackKeyNormal = `${colorNum}-false`;
  const colorData = finalColorMappings[mappingKey] || finalColorMappings[fallbackKeyNormal];

  if (colorData) return colorData.hex;
  return baseColorDefinitions[37].hex;
};

const getColorClassFromBash = (bashCode) => {
  if (!bashCode) return 'text-white';
  const { colorNum, isBold } = parseGeneratedBashCode(bashCode);
  const mappingKey = `${colorNum}-${isBold}`;
  const fallbackKeyNormal = `${colorNum}-false`;
  const colorData = finalColorMappings[mappingKey];

  if (colorData) return colorData.cssClass;
  
  const normalData = finalColorMappings[fallbackKeyNormal];
  if (normalData) {
    return isBold ? `${normalData.cssClass} font-bold-style` : normalData.cssClass;
  }
  return 'text-white font-bold-style';
};

// Referenced by the @change handlers of every picker and box in the template; the page
// reacts to its state through the computeds below, so there is nothing to do here.
const updatePromptDetails = () => {};

// --- The theme code -----------------------------------------------------
// A theme leaves the page as a code and comes back as one. Nothing here writes the eight
// character shape any more and everything still reads it: those codes are out in the
// wild. theme-code.js holds the layout once, for the page, the tests and the shell.
function themeCodeFor(attrs, flags) {
  return writeThemeCode({ colors: attrs, elements: bitsOfFlags(flags) });
}

/** The same read the other way, into what the pickers and the boxes hold. Null for a
 *  fragment that is not a code of either shape. */
function parseShareCode(code) {
  const read = readThemeCode(code);
  if (!read) return null;
  return { selectedAttrs: read.colors, elements: read.elements };
}

// The code of the install commands, or in random mode the request "rand:<code>". The
// colours of that code are irrelevant to the machine running it; what it travels for is
// the top line, which is never drawn.
const installThemeCode = computed(() => {
  const code = themeCodeFor(selectedColorAttributes.value, elementFlags.value);
  return randomFlag.value ? randomRequest(code) : code;
});

// What the fetched tree is asked to do, and with which theme code.
const installKind = computed(() => (uninstallFlag.value ? 'uninstall' : 'install'));

/**
 * The bubbles over the Random and Auto checkboxes: each toggle changes the command line
 * in ways not visible in it, so the consequence is spelled out - for the command actually
 * shown, since a removal takes no theme and Random has nothing to do with it.
 */
const randomToggleHint = computed(() =>
  uninstallFlag.value
    ? 'Random theme mode: nothing to do with a removal - turn Uninstall off and the command asks for a draw.'
    : 'Random theme mode: the command carries "rand:" in front of the theme code, so the machine draws its own colors on every run - of a line wearing the boxes ticked above.',
);

const autoToggleHint = computed(() =>
  uninstallFlag.value
    ? 'Automatic mode: the command asks nothing before it removes BetterBash - the variant for scripts and containers.'
    : 'Automatic mode: the command asks nothing before it installs - the variant for scripts and containers.',
);

// Every install command fetches from the origin serving this page into ~/.bb and sources
// the prompt of that tree (see src/config.js). A removal needs no fetch, so all four tabs
// show one uninstall command, without a theme code.
const currentInstallCommands = computed(() =>
  installCommands({
    kind: installKind.value,
    code: uninstallFlag.value ? null : installThemeCode.value,
    auto: autoFlag.value,
  })
);

const gitInstallUrl = computed(() => currentInstallCommands.value.git);
const curlInstallUrl = computed(() => currentInstallCommands.value.curl);
const wgetInstallUrl = computed(() => currentInstallCommands.value.wget);
const opensslInstallUrl = computed(() => currentInstallCommands.value.openssl);

const shareableUrl = computed(() => {
  const code = themeCodeFor(selectedColorAttributes.value, elementFlags.value);
  return `${window.location.origin}${window.location.pathname}#${code}`;
});

// --- Copying out of the page ---------------------------------------------
// Both boxes copy through ./clipboard.js, which falls back to a copied selection where
// navigator.clipboard does not exist. When even that fails, the field of the pressed
// button is selected and the reason shown, so Ctrl+C stays a way out.

/**
 * Copy `text`; on failure select the field of the button and leave the reason in
 * `showError`. Says whether the clipboard took it. The field is looked up before
 * anything is awaited, because the event is gone by the time the copy fails.
 */
async function copyOut(text, button, showError) {
  showError('');
  const field = button?.closest?.('.share-url-container')?.querySelector('textarea, input');
  try {
    await copyText(text);
    return true;
  } catch (error) {
    console.error('Failed to copy: ', error);
    field?.select();
    showError(error.message);
    return false;
  }
}

/** Each box keeps its own pair of feedback; a failure fades with the next "Copied!". */
function flashCopied(shown) {
  shown.value = true;
  setTimeout(() => {
    shown.value = false;
  }, 2000);
}

const copySuccess = ref(false);
const copyUrlError = ref('');

async function copyUrlToClipboard(event) {
  const copied = await copyOut(shareableUrl.value, event?.currentTarget, (why) => {
    copyUrlError.value = why;
  });
  if (copied) flashCopied(copySuccess);
}

const copyCmdSuccess = ref(false);
const copyCmdError = ref('');

// Only the panel of the active tab is shown, so the command to copy is always the one of
// activeTab.
async function copyInstallCmd(event) {
  const command = currentInstallCommands.value[activeTab.value] ?? '';
  if (!command) return; // nothing shown, so nothing to copy
  const copied = await copyOut(command, event?.currentTarget, (why) => {
    copyCmdError.value = why;
  });
  if (copied) flashCopied(copyCmdSuccess);
}

// A box selects its own text on click; the field comes from the event so the boxes never
// select one another.
function selectField(event) {
  event?.target?.select?.();
}

// Load theme functionality
const loadUrlInput = ref('');
const loadError = ref('');
const loadSuccess = ref(false);

function loadThemeFromUrl() {
  loadError.value = '';
  loadSuccess.value = false;
  
  if (!loadUrlInput.value.trim()) {
    loadError.value = 'Please enter a URL';
    return;
  }

  try {
    // A shared link keeps the theme code in its fragment, and a bare code is accepted
    // as it is. Install URLs of the backend this page replaced ("/CODE/getbb.sh") are
    // still understood, because people keep them in bookmarks and notes.
    let code = '';
    const url = loadUrlInput.value.trim();

    if (url.includes('#')) {
      code = url.split('#')[1];
    } else {
      // A theme code of either shape, and the longer one first: eight characters
      // taken from the front of a thirteen character code would match nothing.
      const kept = url.match(/\/([A-Za-z0-9_-]{8}|1[A-Za-z0-9_-]{12})\/(?:getbb|removebb)\.sh/);
      code = kept ? kept[1] : url;
    }

    if (!code) {
      loadError.value = 'Could not extract theme code from URL';
      return;
    }

    const parsed = parseShareCode(code);
    if (!parsed) {
      loadError.value = 'Invalid theme code';
      return;
    }

    // Apply the loaded theme, colours and the elements of its top line alike
    applyTheme(parsed);
    
    loadSuccess.value = true;
    loadUrlInput.value = '';
    
    setTimeout(() => {
      loadSuccess.value = false;
    }, 3000);
    
  } catch (error) {
    console.error('Error loading theme:', error);
    loadError.value = 'Error loading theme';
  }
}

// Apply a parsed theme ({ selectedAttrs, elements }) to the UI. A theme that came
// from a code of eight characters says nothing about the elements of its top line
// beyond the avatar, and readThemeCode has already filled the rest in as showing.
function applyTheme(theme) {
  if (!theme) return;
  selectedColorAttributes.value = theme.selectedAttrs;
  elementFlags.value = flagsOf(theme.elements);
}

// Random attributes for every color slot, in the same shape as a parsed share code.
function buildRandomAttrs() {
  const randomAttrs = {};

  for (const key of ENCODING_ORDERED_COLOR_KEYS) {
    let baseCode, isLight, isBold;

    do {
      baseCode = Math.floor(Math.random() * 8) + 30; // Random base code 30-37
      isLight = Math.random() < 0.5; // Random boolean for light
      isBold = Math.random() < 0.5;  // Random boolean for bold

      // Continue loop if we have black (30) with light unchecked (false)
    } while (baseCode === 30 && !isLight);

    randomAttrs[key] = {
      baseCode,
      isLight,
      isBold
    };
  }

  return randomAttrs;
}

function generateRandomTheme({ silent = false } = {}) {
  try {
    // Random colours, and only colours: the boxes next to the preview answer the top
    // line, and dice that answered it too would untick a box the page opened with.
    const randomAttrs = buildRandomAttrs();

    const shareCode = themeCodeFor(randomAttrs, elementFlags.value);

    const parsed = parseShareCode(shareCode);
    if (parsed) {
      applyTheme(parsed);

      if (!silent) {
        loadSuccess.value = true;
        setTimeout(() => {
          loadSuccess.value = false;
        }, 2000);
      }
    } else {
      console.error('Failed to parse generated random theme');
    }

  } catch (error) {
    console.error('Error generating random theme:', error);
  }
}

// A fresh load behaves as if "🎲 Random Theme" had been clicked; a theme code in the hash
// wins, so shared links stay reproducible.
function initTheme() {
  const hash = window.location.hash;
  if (hash && hash.length > 1) {
    const parsed = parseShareCode(hash.substring(1));
    if (parsed) {
      applyTheme(parsed);
      return;
    }
  }
  generateRandomTheme({ silent: true });
}

initTheme();

// --- Accent (page chrome) colors, driven by the theme's BORDER COLOR ---
// The frame is what a prompt and this preview show most of, so BORDCOL skins the page.
const ACCENT_COLOR_KEY = 'BORDCOL';

const accentPalette = computed(() =>
  buildAccentPalette(getPreviewColorFromBash(generatedColors.value[ACCENT_COLOR_KEY]))
);

// Registered after the theme is chosen, so the CSS variables are right before the first
// paint and the page never flashes in a fallback colour.
watchEffect(() => {
  applyAccentPalette(accentPalette.value);
});

function onHashChange() {
  const hash = window.location.hash;
  if (!hash || hash.length <= 1) return;
  const parsed = parseShareCode(hash.substring(1));
  if (parsed) applyTheme(parsed);
}

onMounted(() => {
  window.addEventListener('hashchange', onHashChange);
});

onBeforeUnmount(() => {
  window.removeEventListener('hashchange', onHashChange);
});

</script>

<style scoped src="./style.css"></style>
