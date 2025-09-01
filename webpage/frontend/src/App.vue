<template src="./template.html"></template>

<script setup>
import { ref, computed, onMounted } from 'vue';
// default theme vN-y_5uA

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
const uninstallFlag = ref(false);

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

const curlInstallUrl = computed(() => {
  const code = generateShareCode(selectedColorAttributes.value, showAvatar.value);
  const scriptName = uninstallFlag.value ? 'removebb.sh' : 'getbb.sh';
  return `curl -sL https://bb.cz0.cz/${code}/${scriptName} | bash -s curl && . ~/.bashrc`;
});

const wgetInstallUrl = computed(() => {
  const code = generateShareCode(selectedColorAttributes.value, showAvatar.value);
  const scriptName = uninstallFlag.value ? 'removebb.sh' : 'getbb.sh';
  return `wget -q -O - https://bb.cz0.cz/${code}/${scriptName} | bash -s wget && . ~/.bashrc`;
});

const opensslInstallUrl = computed(() => {
  const code = generateShareCode(selectedColorAttributes.value, showAvatar.value);
  const scriptName = uninstallFlag.value ? 'removebb.sh' : 'getbb.sh';
  const backend = 'bbb-f4hxb4escnacbpe6.westeurope-01.azurewebsites.net'
  return `echo -e "GET /${code}/${scriptName} HTTP/1.1\\r\\nHost: ${backend}\\r\\nConnection: close\\r\\n\\r\\n" \\\r\n| openssl s_client -quiet -connect ${backend}:443 2>/dev/null \\\r\n| sed '1,/^\\r$/d' | bash -s openssl && . ~/.bashrc`;
});

const shareableUrl = computed(() => {
  const code = generateShareCode(selectedColorAttributes.value, showAvatar.value);
  return `${window.location.origin}${window.location.pathname}#${code}`;
});

const copySuccess = ref(false);
async function copyUrlToClipboard() {
  try {
    await navigator.clipboard.writeText(shareableUrl.value);
    copySuccess.value = true;
    setTimeout(() => {
      copySuccess.value = false;
    }, 2000);
  } catch (err) {
    console.error('Failed to copy URL: ', err);
    alert('Failed to copy URL. Please copy it manually.');
  }
}

const copyCmdSuccess = ref(false);

async function copyCurlCmdToClipboard() {
  try {
    await navigator.clipboard.writeText(installCurlCmd.value);
    copyCmdSuccess.value = true;
    setTimeout(() => {
      copyCmdSuccess.value = false;
    }, 2000);
  } catch (err) {
    console.error('Failed to copy install command: ', err);
        alert('Failed to copy install command. Please copy it manually.');
  }
}

async function copyWgetCmdToClipboard() {
  try {
    await navigator.clipboard.writeText(installWgetCmd.value);
    copyCmdSuccess.value = true;
    setTimeout(() => {
      copyCmdSuccess.value = false;
    }, 2000);
  } catch (err) {
    console.error('Failed to copy install command: ', err);
        alert('Failed to copy install command. Please copy it manually.');
  }
}

async function copyOpensslCmdToClipboard() {
  try {
    await navigator.clipboard.writeText(installOpensslCmd.value);
    copyCmdSuccess.value = true;
    setTimeout(() => {
      copyCmdSuccess.value = false;
    }, 2000);
  } catch (err) {
    console.error('Failed to copy install command: ', err);
        alert('Failed to copy install command. Please copy it manually.');
  }
}

function selectUrlText() {
    const inputElement = document.getElementById('shareUrlInput');
    if (inputElement) {
        inputElement.select();
    }
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
    // Extract code from URL - handle both hash and path formats
    let code = '';
    const url = loadUrlInput.value.trim();
    
    if (url.includes('#')) {
      code = url.split('#')[1];
    } else if (url.includes('betterbash.cz0.cz/')) {
      const parts = url.split('betterbash.cz0.cz/');
      if (parts.length > 1) {
        code = parts[1].split(/[?&#]/)[0];
      }
    } else {
      // Assume the entire input is the code
      code = url;
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

function generateRandomTheme() {
  try {
    // Generate random attributes for each color key
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
    
    // Generate random avatar setting
    const randomAvatar = Math.random() < 0.5;
    
    // Generate share code from random attributes
    const shareCode = generateShareCode(randomAttrs, randomAvatar);
    
    // Parse and apply the generated theme using existing logic
    const parsed = parseShareCode(shareCode);
    if (parsed) {
      selectedColorAttributes.value = parsed.selectedAttrs;
      showAvatar.value = parsed.avatarEnabled;
      
      // Optional: Show success feedback
      loadSuccess.value = true;
      setTimeout(() => {
        loadSuccess.value = false;
      }, 2000);
    } else {
      console.error('Failed to parse generated random theme');
    }
    
  } catch (error) {
    console.error('Error generating random theme:', error);
  }
}

// Load theme from URL hash on mount
onMounted(() => {
  const hash = window.location.hash;
  if (hash && hash.length > 1) {
    const code = hash.substring(1);
    const parsed = parseShareCode(code);
    if (parsed) {
      selectedColorAttributes.value = parsed.selectedAttrs;
      showAvatar.value = parsed.avatarEnabled;
    }
  }
});

</script>

<style scoped src="./style.css"></style>
