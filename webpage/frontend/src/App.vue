<template src="./template.html"></template>

<script setup>
import { ref, computed, watchEffect, onMounted, onBeforeUnmount } from 'vue';
import { buildAccentPalette, applyAccentPalette } from './theme';
import { hostAvatar } from './avatar';
import { APP_ENV, installCommands } from './config';
import { copyText } from './clipboard';
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

// --- Hardcoded order for URL encoding/decoding stability ---
const ENCODING_ORDERED_COLOR_KEYS = [
  'PRIMARY_COLOR', 'SECONDARY_COLOR', 'ROOT_COLOR', 'TIME_COLOR',
  'ERR_COLOR', 'SEPARATOR_COLOR', 'BORDCOL', 'PATH_COLOR'
];

// Avatar state
const showAvatar = ref(true);

// The prompt draws its avatar from the machine's own name (hashColor over
// `cat /etc/hostname` in prompt/bb.sh), and this page cannot read that file, so
// the name is asked for. It is the same string the preview line prints as the
// host, so what the preview hashes and what it shows are one name. "myhost" is
// the host the preview always showed, and the avatar of the preview is therefore
// the one it always showed - see tests/golden/avatars.txt.
const previewHostname = ref('myhost');
const avatarSegments = computed(() => hostAvatar(previewHostname.value, 4));

// __prompt_command of prompt/bb.sh sizes the dashes between the two halves of a
// prompt from what the two halves show, so a longer host shortens the fill and
// the line keeps its length. The two numbers are the fill runs the template held
// before they became computed - the shorter of them is spent by a 33rd character
// - and tests/test-frame.mjs keeps them such that the two prompt lines of the
// preview measure the same, with the avatar showing and with it hidden, as the
// two fill runs of a preview line may not differ by anything else either: one
// line of the preview stands for a command that ended well and carries the five
// dashes that stand for it, the other stands for a failed one and carries its
// exit code. A line longer than the 98 glyphs the template is padded to would
// break under the font size the box scales to, so the hostname field stops at 32
// characters.
const previewFill = (base) =>
  computed(() => '─'.repeat(Math.max(1, base + 'myhost'.length - previewHostname.value.length)));
const previewFillOne = previewFill(16);
const previewFillTwo = previewFill(21);
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

// --- URL Sharing Logic ---
function bytesToUrlSafeBase64(bytes) {
  const base64 = btoa(String.fromCharCode(...bytes));
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function urlSafeBase64ToBytes(base64Str) {
  let base64 = base64Str.replace(/-/g, '+').replace(/_/g, '/');
  const padding = base64.length % 4 === 0 ? '' : '='.repeat(4 - (base64.length % 4));
  const raw = atob(base64 + padding);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    bytes[i] = raw.charCodeAt(i);
  }
  return bytes;
}

function generateShareCode(selectedAttrs, avatarEnabled) {
  const numParts = ENCODING_ORDERED_COLOR_KEYS.length;
  const bytes = new Uint8Array(6); // 48 bits
  
  const fiveBitValues = [];
  for (const key of ENCODING_ORDERED_COLOR_KEYS) {
    const attr = selectedAttrs[key];
    if (!attr) {
        fiveBitValues.push(0);
        continue;
    }
    const shortBaseCode = attr.baseCode - 30; // 0-7
    const lightBit = attr.isLight ? 1 : 0;
    const boldBit = attr.isBold ? 1 : 0;
    const value = (shortBaseCode << 2) | (lightBit << 1) | boldBit; // 0-31
    fiveBitValues.push(value);
  }

  // Pack 8 * 5-bit values (40 bits) into 6 bytes, with avatar bit at the end
  bytes[0] = (fiveBitValues[0] << 3) | (fiveBitValues[1] >> 2);
  bytes[1] = ((fiveBitValues[1] & 0x03) << 6) | (fiveBitValues[2] << 1) | (fiveBitValues[3] >> 4);
  bytes[2] = ((fiveBitValues[3] & 0x0F) << 4) | (fiveBitValues[4] >> 1);
  bytes[3] = ((fiveBitValues[4] & 0x01) << 7) | (fiveBitValues[5] << 2) | (fiveBitValues[6] >> 3);
  bytes[4] = ((fiveBitValues[6] & 0x07) << 5) | (fiveBitValues[7]);
  bytes[5] = avatarEnabled ? 0x80 : 0x00; // Use first bit for avatar state

  return bytesToUrlSafeBase64(bytes);
}

function parseShareCode(code) {
  try {
    const bytes = urlSafeBase64ToBytes(code);
    if (bytes.length !== 6) return null;

    // Extract avatar state from first bit of last byte
    const avatarEnabled = (bytes[5] & 0x80) !== 0;

    // Extract 8 * 5-bit values
    const fiveBitValues = [];
    fiveBitValues.push(bytes[0] >> 3);
    fiveBitValues.push(((bytes[0] & 0x07) << 2) | (bytes[1] >> 6));
    fiveBitValues.push((bytes[1] >> 1) & 0x1F);
    fiveBitValues.push(((bytes[1] & 0x01) << 4) | (bytes[2] >> 4));
    fiveBitValues.push(((bytes[2] & 0x0F) << 1) | (bytes[3] >> 7));
    fiveBitValues.push((bytes[3] >> 2) & 0x1F);
    fiveBitValues.push(((bytes[3] & 0x03) << 3) | (bytes[4] >> 5));
    fiveBitValues.push(bytes[4] & 0x1F);

    const selectedAttrs = {};
    for (let i = 0; i < ENCODING_ORDERED_COLOR_KEYS.length; i++) {
      const key = ENCODING_ORDERED_COLOR_KEYS[i];
      const value = fiveBitValues[i];
      const shortBaseCode = value >> 2; // 0-7
      const lightBit = (value >> 1) & 1;
      const boldBit = value & 1;
      
      selectedAttrs[key] = {
        baseCode: shortBaseCode + 30, // 30-37
        isLight: lightBit === 1,
        isBold: boldBit === 1
      };
    }

    return { selectedAttrs, avatarEnabled };
  } catch (error) {
    console.error('Error parsing share code:', error);
    return null;
  }
}

// Theme code of the install commands. In random mode it is the word "rand", and
// the machine running the command draws the theme itself every time it runs, so
// the colors selected in the UI are irrelevant for that command.
const installThemeCode = computed(() =>
  randomFlag.value ? 'rand' : generateShareCode(selectedColorAttributes.value, showAvatar.value)
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
  const code = generateShareCode(selectedColorAttributes.value, showAvatar.value);
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
      const legacy = url.match(/\/([A-Za-z0-9_-]{8})\/(?:getbb|removebb)\.sh/);
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

    // Apply the loaded theme
    selectedColorAttributes.value = parsed.selectedAttrs;
    showAvatar.value = parsed.avatarEnabled;
    
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

// Apply a parsed theme ({ selectedAttrs, avatarEnabled }) to the UI.
function applyTheme(theme) {
  if (!theme) return;
  selectedColorAttributes.value = theme.selectedAttrs;
  showAvatar.value = theme.avatarEnabled;
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
    // Generate random attributes for each color key
    const randomAttrs = buildRandomAttrs();

    // Generate random avatar setting
    const randomAvatar = Math.random() < 0.5;

    // Generate share code from random attributes
    const shareCode = generateShareCode(randomAttrs, randomAvatar);

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
