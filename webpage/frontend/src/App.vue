<template src="./template.html"></template>

<script setup>
import { ref, computed, watchEffect, onMounted, onBeforeUnmount } from 'vue';
import { buildAccentPalette, applyAccentPalette } from './theme';
import { hostAvatar } from './avatar';
import { APP_ENV, installCommands } from './config';
import { copyText } from './clipboard';
// The theme code and the top line of the prompt, shared with the tests so that
// what this page writes, shows and calls a theme is one thing read three ways: by
// the page, by the tests, and by the shell the code is handed to. theme-code.js
// holds the layout of the code, preview.js builds the line the boxes change.
import {
  ALL_ELEMENTS_ON,
  COLOR_KEYS as ENCODING_ORDERED_COLOR_KEYS,
  decode as readThemeCode,
  encode as writeThemeCode,
} from './theme-code';
import { ELEMENTS as PROMPT_ELEMENTS, SAMPLE, SAMPLE_ROOT, bitsOfFlags, flagsOf, topLine } from './preview';
// default theme vN-y_5uA

// Surfaced in the page so a development build cannot be mistaken for the
// published one (the install commands differ).
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

// Which element of the top line each box of the page speaks for, and the two
// halves those boxes stand in, are in preview.js - the file that builds the line
// the boxes change. The order of the colours in a theme code is in theme-code.js,
// which the shell library and the tests read it out of as well.
const promptElements = PROMPT_ELEMENTS;

// Which elements of the top line the theme shows. Each of them shows unless its
// box is unticked, and a theme that says nothing about them - a code of eight
// characters, from before the boxes existed - shows them all.
const elementFlags = ref(flagsOf(ALL_ELEMENTS_ON));

// The avatar is one of these elements, and its box stood by itself for longer than
// the rest of them did: it keeps being called that, here and in the tour that
// points at it.
const showAvatar = computed({
  get: () => elementFlags.value.AVATAR !== false,
  set: (on) => {
    elementFlags.value.AVATAR = !!on;
  },
});

// The prompt draws its avatar from the machine's own name (hashColor over
// `cat /etc/hostname` in prompt/bb.sh), and this page cannot read that file, so
// the name is asked for. It is the same string the preview line prints as the
// host, so what the preview hashes and what it shows are one name. "myhost" is
// the host the preview always showed, and the avatar of the preview is therefore
// the one it always showed - see tests/golden/avatars.txt.
const previewHostname = ref('myhost');
const avatarSegments = computed(() => hostAvatar(previewHostname.value, 4));

// The two top lines of the preview, as prompt/bb.sh would draw them: the same
// elements, the same separators, the same fill - over the elements the boxes of the
// page show. One line stands for a command that ended well, the other for a machine
// logged in as root whose last command failed and nothing runs behind it.
// prompt/bb.sh sizes the fill from what the two halves show, so a longer host
// shortens it and the line keeps its length; tests/test-frame.mjs draws the frame
// with bash and compares it with these lines, glyph for glyph, at a few widths and a
// few settings of the boxes. A line longer than the preview box is padded to would
// break under the font size it scales to, so the hostname field stops at 32
// characters.
const previewLineOf = (sample) =>
  topLine({
    flags: elementFlags.value,
    host: previewHostname.value,
    avatar: avatarSegments.value.map((s) => ({ text: s.glyph, code: s.code })),
    sample,
  });
const previewTopLines = computed(() => [previewLineOf(SAMPLE), previewLineOf(SAMPLE_ROOT)]);
const uninstallFlag = ref(false);
// Random mode: the install command asks for the word "rand" instead of a theme
// code, so the machine that runs it draws its own theme - and draws a new one
// every time the command is run again.
const randomFlag = ref(false);
// Automatic mode: the command drops the question it asks before running the
// installer. It is meant for scripts and containers, where nobody can answer.
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

const updatePromptDetails = () => {
  // This function is called on change
};

// --- The theme code -----------------------------------------------------
//
// A theme leaves this page as a code and comes back as one: the eight characters
// the shell library has always read, or the thirteen of a theme that says which
// elements of its top line it shows. theme-code.js holds that layout, and holds it
// once - the page, tests/test-theme-code.mjs and prompt/bb-theme.sh read a theme
// code by the same rules, and disagreeing about one of them is a failing test.
//
// Nothing here writes a code of eight characters any more, and everything still
// reads one: they are out in the wild, and a code of that shape means every element
// of the top line showing, apart from the avatar, whose bit it always carried.
function themeCodeFor(attrs, flags) {
  return writeThemeCode({ colors: attrs, elements: bitsOfFlags(flags) });
}

// The same read the other way, as the page holds a theme: the colours as the
// pickers hold them, and the elements of the top line as the boxes of its tile hold
// them. Null for anything that is not a code of either shape, which is also what
// the page should make of a fragment it cannot read.
function parseShareCode(code) {
  const read = readThemeCode(code);
  if (!read) return null;
  return { selectedAttrs: read.colors, elements: read.elements };
}

// Theme code of the install commands. In random mode it is the word "rand", and
// the machine running the command draws the theme itself every time it runs, so
// the colors selected in the UI are irrelevant for that command.
const installThemeCode = computed(() =>
  randomFlag.value ? 'rand' : themeCodeFor(selectedColorAttributes.value, elementFlags.value)
);

// What the fetched tree is asked to do, and with which theme code.
const installKind = computed(() => (uninstallFlag.value ? 'uninstall' : 'install'));

// The sentences of the two bubbles the template hangs over the Random and Auto
// checkboxes. A toggle changes the command line below it in ways that are not to be
// seen in it - the word "rand" where a theme code stands, one clause less where the
// question of the command was - so the consequence is spelled out here, and spelled
// out for the command that is actually being shown: removing takes no theme, so while
// Uninstall is checked Random has nothing to do with the command at all.
const randomToggleHint = computed(() =>
  uninstallFlag.value
    ? 'Random theme mode: nothing to do with this command - removing a theme takes neither a code nor the word "rand". Turn Uninstall off and the command carries "rand" in place of a theme code.'
    : 'Random theme mode: the command carries the word "rand" instead of a theme code, so the machine that runs it draws its own theme - a different one on every run, which makes running the command again a reroll. The colors selected above are ignored; turn this off to install the theme you can see here.',
);

const autoToggleHint = computed(() =>
  uninstallFlag.value
    ? 'Automatic mode: the command drops the question it asks before removing BetterBash, so it removes it without asking anyone. Without a question nothing can be answered, so this is the variant for scripts and containers; an interactive shell should keep being asked.'
    : 'Automatic mode: the command drops the question it asks before installing anything, so it installs without asking anyone. Without a question nothing can be answered, so this is the variant for scripts and containers; an interactive shell should keep being asked.',
);

// Every install command fetches from the origin serving this page into ~/.bb and
// ends by sourcing the prompt of that tree, which installs it (see src/config.js).
// Removing needs no fetch at all, so the four methods show one and the same
// uninstall command; the uninstaller gets no theme code, colors are not its
// business.
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
//
// Both boxes below copy through ./clipboard.js rather than reaching for
// navigator.clipboard themselves: that API lives only in a secure context, so on a
// page served over plain http - `./dev.sh` reached by its host name - reading
// navigator.clipboard threw before anything was attempted, and every button
// answered with an alert telling the user to copy by hand. The helper falls back to
// a copied selection, which an insecure page still gets; when even that fails, the
// field of the button that was pressed is selected here and the reason is shown
// under the box, so Ctrl+C stays a way out that says why it is needed.

/**
 * Copy `text`, and on failure select the field the button belongs to and leave the
 * reason in `showError`. Says whether the clipboard took the text.
 *
 * The field is looked up before anything is awaited: the button is still there when
 * the copy turns out to have failed, but the event that led to it is not.
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

/** The message of a failure fades with the "Copied!" of the next try, so each of
 *  the two boxes keeps its own pair of feedback. */
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

// One button per tab, and only the panel of the active tab is ever shown, so the
// command to copy is always the one of activeTab - the same string the textarea of
// that panel shows.
async function copyInstallCmd(event) {
  const command = currentInstallCommands.value[activeTab.value] ?? '';
  if (!command) return; // nothing shown, so nothing to copy
  const copied = await copyOut(command, event?.currentTarget, (why) => {
    copyCmdError.value = why;
  });
  if (copied) flashCopied(copyCmdSuccess);
}

// Clicking a box selects its own text, so a click and Ctrl+C copy what is in front
// of the user whichever box they clicked. The command boxes and the URL box all
// share this handler; taking the field from the event is what keeps them from
// selecting one another.
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
    // A shared link keeps the theme code in its fragment, and a bare code is
    // accepted as it is. Install URLs of the retired backend ("/CODE/getbb.sh")
    // are still understood, because people keep them in bookmarks and notes.
    let code = '';
    const url = loadUrlInput.value.trim();

    if (url.includes('#')) {
      code = url.split('#')[1];
    } else {
      // A theme code of either shape, and the longer one first: eight characters
      // taken from the front of a thirteen character code would match nothing.
      const legacy = url.match(/\/([A-Za-z0-9_-]{8}|1[A-Za-z0-9_-]{12})\/(?:getbb|removebb)\.sh/);
      code = legacy ? legacy[1] : url;
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
    // Random colours, and only colours: which elements of the top line the theme
    // shows is asked for in the boxes next to the preview, and a dice that answers
    // that question too would untick a box the page was opened with.
    const randomAttrs = buildRandomAttrs();

    const shareCode = themeCodeFor(randomAttrs, elementFlags.value);

    // Parse and apply the generated theme using existing logic
    const parsed = parseShareCode(shareCode);
    if (parsed) {
      applyTheme(parsed);

      if (!silent) {
        // Optional: Show success feedback
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

// Every fresh page load behaves as if "🎲 Random Theme" had been clicked.
// An explicit theme code in the URL hash (shared theme) still wins, so links
// stay reproducible.
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
// The frame is what a BetterBash prompt shows most of, and what the preview of
// this page shows of a theme, so the border colour - not PRIMARY_COLOR - is what
// skins the page. The slot of the theme is named here once.
const ACCENT_COLOR_KEY = 'BORDCOL';

const accentPalette = computed(() =>
  buildAccentPalette(getPreviewColorFromBash(generatedColors.value[ACCENT_COLOR_KEY]))
);

// The theme is chosen before this watcher is registered, so the CSS variables
// are correct before the first paint and the page never flashes in the
// hardcoded fallback green.
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
