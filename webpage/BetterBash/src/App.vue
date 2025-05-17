<template>
  <div class="container">
    <h1>Better Bash Customizer</h1>

    <div class="customizer">
      <div class="color-controls">
        <div
          v-for="(label, colorKey) in colorLabels"
          :key="colorKey"
          class="color-select-group"
        >
          <div class="color-selector-main">
            <label :for="`select-${colorKey}`">
              {{ label }}
              <div
                class="color-preview"
                :style="{ backgroundColor: getPreviewColorFromBash(generatedColors[colorKey]) }"
              ></div>
            </label>
            <select :id="`select-${colorKey}`" v-model="selectedColorAttributes[colorKey].baseCode" @change="updatePromptDetails">
              <option
                v-for="colorOpt in baseColorOptions"
                :key="colorOpt.value"
                :value="colorOpt.value"
              >
                {{ colorOpt.name }}
              </option>            
            </select>
          </div>
          <div class="color-modifier-checkboxes">
            <label :for="`light-${colorKey}`">
              <input :id="`light-${colorKey}`" type="checkbox" v-model="selectedColorAttributes[colorKey].isLight" @change="updatePromptDetails" />
              Light
            </label>
            <label :for="`bold-${colorKey}`">
              <input :id="`bold-${colorKey}`" type="checkbox" v-model="selectedColorAttributes[colorKey].isBold" @change="updatePromptDetails" />
              Bold
            </label>
          </div>
        </div>
      </div>

      <div class="terminal">
        <div class="ps1-line">
          <span :class="getColorClassFromBash(generatedColors.BORDCOL)">┌─</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.SECONDARY_COLOR)">user</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">@</span
          ><span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">myhost:pts/5</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">──</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span class="text-yellow">▶</span
          ><span class="text-bright-black">▬</span
          ><span class="text-bright-white">▲</span
          ><span class="text-cyan">◀▶</span
          ><span class="text-bright-white">▲</span
          ><span class="text-bright-black">▬</span
          ><span class="text-yellow">◀</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">──</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.SECONDARY_COLOR)">1 ↻</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">─────────────────────────────</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.TIME_COLOR)">Wed May 14</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">───</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">00:40:03</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">────</span>
        </div>
        <div class="ps1-line">
          <span :class="getColorClassFromBash(generatedColors.BORDCOL)">└─</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.PATH_COLOR)">~/repo</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">─</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">$</span
          ><span :class="getColorClassFromBash(generatedColors.RST)"> on </span
          ><span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">master</span
          ><span :class="getColorClassFromBash(generatedColors.RST)">=</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">-&gt;</span>
        </div>

        <div class="ps1-line">&nbsp;</div>
        <div class="ps1-line">&nbsp;</div>

        <div class="ps1-line">
          <span :class="getColorClassFromBash(generatedColors.BORDCOL)">┌─</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.ROOT_COLOR)">ROOT</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">@</span
          ><span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">myhost:pts/5</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">──</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span class="text-yellow">▶</span
          ><span class="text-bright-black">▬</span
          ><span class="text-bright-white">▲</span
          ><span class="text-cyan">◀▶</span
          ><span class="text-bright-white">▲</span
          ><span class="text-bright-black">▬</span
          ><span class="text-yellow">◀</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">───────────────────────────</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.ERR_COLOR)">127 ↵</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">──</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.TIME_COLOR)">Wed May 14</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">───</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.ERR_COLOR)">00:40:12</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">────</span>
        </div>
        <div class="ps1-line">
          <span :class="getColorClassFromBash(generatedColors.BORDCOL)">└─</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.PATH_COLOR)">~</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">─</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">$</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">-&gt;</span>
        </div>
      </div>

      <div class="share-section">
        <h3>Share Your Theme</h3>
        <div class="share-url-container">
            <input type="text" :value="shareableUrl" readonly id="shareUrlInput" @click="selectUrlText" />
            <button @click="copyUrlToClipboard">Copy URL</button>
        </div>
        <p v-if="copySuccess" class="copy-success-message">Copied to clipboard!</p>
      </div>

      <div class="info-section">
        <h3>About This Customizer</h3>
        <p>
          This tool allows you to customize the colors of your bash PS1 prompt.
          Select different terminal colors for each component and individually toggle
          "light" (bright) or "bold" styles to see how they
          look in the preview. You can share your theme using the URL generated above.
        </p>
        <h3>Decoding the Share URL</h3>
        <div class="decoding-explanation">
            <p>The string after "betterba.sh/" in the URL is an 8-character code representing your theme. Here's how it works:</p>
            <ol>
                <li><strong>Fixed Order:</strong> Colors are encoded for 9 components in this fixed order:
                    Primary, Secondary, Root User, Time, Error Code, Separator, Border, Path, and Reset colors.</li>
                <li><strong>Per-Component Encoding (5 bits):</strong>
                    <ul>
                        <li>Base Color (30-37) is mapped to 0-7 (3 bits).</li>
                        <li>Light State (normal/bright) is 0 or 1 (1 bit).</li>
                        <li>Bold State is 0 or 1 (1 bit).</li>
                        <li>These are combined: <code>(base_color_0_7 &lt;&lt; 2) | (light_bit &lt;&lt; 1) | bold_bit</code>.</li>
                    </ul>
                </li>
                <li><strong>Concatenation (45 bits):</strong> The 9 five-bit values are joined, forming a 45-bit sequence.</li>
                <li><strong>Byte Packing (6 bytes):</strong> These 45 bits are packed into 6 bytes. The first 45 bits contain the data, and the last 3 bits of the 6th byte are zero-padded. Bits are packed MSB-first from the component data into the bytes.
                    <ul>
                        <li>Byte 1: <code>C1_b4 C1_b3 C1_b2 C1_b1 C1_b0 C2_b4 C2_b3 C2_b2</code></li>
                        <li>Byte 2: <code>C2_b1 C2_b0 C3_b4 C3_b3 C3_b2 C3_b1 C3_b0 C4_b4</code></li>
                        <li>Byte 3: <code>C4_b3 C4_b2 C4_b1 C4_b0 C5_b4 C5_b3 C5_b2 C5_b1</code></li>
                        <li>Byte 4: <code>C5_b0 C6_b4 C6_b3 C6_b2 C6_b1 C6_b0 C7_b4 C7_b3</code></li>
                        <li>Byte 5: <code>C7_b2 C7_b1 C7_b0 C8_b4 C8_b3 C8_b2 C8_b1 C8_b0</code></li>
                        <li>Byte 6: <code>C9_b4 C9_b3 C9_b2 C9_b1 C9_b0  0   0   0</code></li>
                        (<code>Cn_bx</code> is bit <code>x</code> of component <code>n</code>'s 5-bit value, <code>C1</code>=Primary, <code>C2</code>=Secondary, etc.)
                    </ul>
                </li>
                <li><strong>URL-Safe Base64:</strong> The 6 bytes are encoded using Base64, then <code>+</code> is replaced with <code>-</code>, <code>/</code> with <code>_</code>, and padding <code>=</code> are removed. This produces the 8-character code.</li>
            </ol>
            <p>To decode, reverse the process: Base64 decode, unpack bytes into 5-bit values, then extract base color, light, and bold states for each component.</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'; // Added onMounted if needed for URL parsing later

// Color labels for UI - THE ORDER HERE IS IMPORTANT FOR `Object.keys(colorLabels)` if used
// but we'll use a hardcoded list for encoding/decoding for stability.
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
if (ENCODING_ORDERED_COLOR_KEYS.length !== 8) {
    console.error("Encoding logic assumes 8 color keys. Please update bit packing if this changes.");
}


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
    35: { hex: "#ad7fa8", css: "text-bold-magenta" }, // Often same as bright in some terminals
    36: { hex: "#34e2e2", css: "text-bold-cyan" },   // Often same as bright
    37: { hex: "#ffffff", css: "text-bold-white" },  // True white for bold light gray
    90: { hex: "#7c7c7c", css: "text-bold-bright-black" },
    95: { hex: "#d070d0", css: "text-bold-bright-magenta" },
    97: { hex: "#ffffff", css: "text-bold-bright-white" }, // True white for bold white
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
    selectedColorAttributes.value[key] = { baseCode: 37, isLight: false, isBold: false }; // Default
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
      // Ensure "normal" style is explicit if no bold, using '0' or just the color
      finalCodes[key] = `\\[\\033[0;${actualCode}m\\]`; 
    }
  }
  // Handle RST specifically if it shouldn't have complex styling (e.g. only \[\033[0m\] or \[\033[37m\])
  // For this general tool, we keep RST configurable like others.
  // If RST should always be \[\033[0m\], you can override:
  // finalCodes['RST'] = '\\[\\033[0m\\]';
  return finalCodes;
});

function parseGeneratedBashCode(bashCode) {
  const match = bashCode.match(/\[(?:(1);)?(\d{2})m/); // Bold group, color group
  if (match) {
    const isBold = !!match[1];
    const colorNum = parseInt(match[2]);
    return { colorNum, isBold };
  }
  // Try matching pattern like \[\033[0;32m\] or \[\033[0;92m\]
   const nonBoldMatch = bashCode.match(/\[0;(\d{2})m/);
   if (nonBoldMatch) {
    return { colorNum: parseInt(nonBoldMatch[1]), isBold: false };
  }
  // Try matching pattern like \[\033[32m\] (implicit normal)
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
  // This function is called on change, can be used for debugging or future enhancements
};

// --- URL Sharing Logic ---
function bytesToUrlSafeBase64(bytes) {
  const base64 = btoa(String.fromCharCode(...bytes));
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

// function urlSafeBase64ToBytes(base64Str) { // For decoding if implemented
//   let base64 = base64Str.replace(/-/g, '+').replace(/_/g, '/');
//   const padding = base64.length % 4 === 0 ? '' : '='.repeat(4 - (base64.length % 4));
//   const raw = atob(base64 + padding);
//   const bytes = new Uint8Array(raw.length);
//   for (let i = 0; i < raw.length; i++) {
//     bytes[i] = raw.charCodeAt(i);
//   }
//   return bytes;
// }

function generateShareCode(selectedAttrs) {
  const numParts = ENCODING_ORDERED_COLOR_KEYS.length;
  if (numParts * 5 > 48) { // 45 bits for 9 parts, max 48 in 6 bytes
      console.error("Too many parts for 6 bytes with 5 bits each");
      return "";
  }

  const fiveBitValues = [];
  for (const key of ENCODING_ORDERED_COLOR_KEYS) {
    const attr = selectedAttrs[key];
    if (!attr) { // Should not happen if selectedColorAttributes is initialized correctly
        fiveBitValues.push(0); // Default: (0<<2)|0|0 = Black, not light, not bold
        continue;
    }
    const shortBaseCode = attr.baseCode - 30; // 0-7
    const lightBit = attr.isLight ? 1 : 0;
    const boldBit = attr.isBold ? 1 : 0;
    const value = (shortBaseCode << 2) | (lightBit << 1) | boldBit; // 0-31
    fiveBitValues.push(value);
  }

  const bytes = new Uint8Array(6); // 48 bits
  // Pack 9 * 5-bit values (45 bits) into 6 bytes
  bytes[0] = (fiveBitValues[0] << 3) | (fiveBitValues[1] >> 2);
  bytes[1] = ((fiveBitValues[1] & 0x03) << 6) | (fiveBitValues[2] << 1) | (fiveBitValues[3] >> 4);
  bytes[2] = ((fiveBitValues[3] & 0x0F) << 4) | (fiveBitValues[4] >> 1);
  bytes[3] = ((fiveBitValues[4] & 0x01) << 7) | (fiveBitValues[5] << 2) | (fiveBitValues[6] >> 3);
  bytes[4] = ((fiveBitValues[6] & 0x07) << 5) | (fiveBitValues[7]);
  bytes[5] = (fiveBitValues[8] << 3); // Last 3 bits of this byte will be 0 (padding)

  return bytesToUrlSafeBase64(bytes);
}

const shareableUrl = computed(() => {
  const code = generateShareCode(selectedColorAttributes.value);
  return `https://betterba.sh/${code}`;
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

function selectUrlText() {
    const inputElement = document.getElementById('shareUrlInput');
    if (inputElement) {
        inputElement.select();
    }
}

// Optional: Logic to parse code from URL on load
// onMounted(() => {
//   const path = window.location.pathname;
//   const parts = path.split('/');
//   if (parts.length > 1 && parts[1]) { // e.g. /XyZ123Ab
//     const code = parts[1];
//     // const decodedAttributes = parseShareCode(code); // You'd need to implement this
//     // if (decodedAttributes) {
//     //   selectedColorAttributes.value = decodedAttributes;
//     // }
//   }
// });

</script>

<style scoped>
body {
  font-family: 'Courier New', monospace;
  margin: 0;
  padding: 20px;
  background-color: #1e1e1e;
  color: #f0f0f0;
}
.container {
  max-width: 1200px;
  margin: 0 auto;
  background-color: #1e1e1e;
  color: #f0f0f0;
}
h1 {
  text-align: center;
  margin-bottom: 30px;
  color: #10b981; /* A pleasant green */
}
.customizer {
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.color-controls {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 20px;
}
.color-select-group {
  display: flex;
  flex-direction: column;
  background-color: #2d2d2d;
  padding: 15px;
  border-radius: 8px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
  gap: 10px;
}
.color-selector-main label {
  margin-bottom: 8px;
  font-weight: bold;
  display: flex;
  align-items: center;
}
.color-selector-main select {
  width: 100%;
  padding: 8px;
  background-color: #3a3a3a;
  color: #fff;
  border: 1px solid #555;
  border-radius: 4px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
}
.color-modifier-checkboxes {
  display: flex;
  gap: 15px;
  margin-top: 5px;
}
.color-modifier-checkboxes label {
  display: flex;
  align-items: center;
  gap: 5px;
  font-weight: normal;
}
.color-modifier-checkboxes input[type="checkbox"] {
  margin-right: 4px;
}
.terminal {
  background-color: #000;
  padding: 20px;
  border-radius: 8px;
  min-height: 180px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
  overflow-x: auto;
  margin-top: 20px;
  white-space: pre-wrap;
  line-height: 0.9;
  font-size: 18px;
}
.ps1-line {
  margin-bottom: 0px;
}
.color-preview {
  display: inline-block;
  width: 20px;
  height: 20px;
  margin-left: 10px;
  border: 1px solid #555;
  vertical-align: middle;
}
.info-section, .share-section {
  margin-top: 30px;
  background-color: #2d2d2d;
  padding: 20px;
  border-radius: 8px;
}
.info-section h3, .share-section h3 {
  margin-top: 0;
  color: #10b981;
}
.share-url-container {
  display: flex;
  gap: 10px;
  align-items: center;
}
.share-url-container input[type="text"] {
  flex-grow: 1;
  padding: 8px;
  background-color: #3a3a3a;
  color: #f0f0f0;
  border: 1px solid #555;
  border-radius: 4px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
}
.share-url-container button {
  padding: 8px 15px;
  background-color: #10b981;
  color: #fff;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: bold;
}
.share-url-container button:hover {
  background-color: #0da874;
}
.copy-success-message {
  color: #8ae234; /* Bright Green */
  font-size: 0.9em;
  margin-top: 5px;
}
.decoding-explanation {
    font-size: 0.9em;
    line-height: 1.6;
}
.decoding-explanation ul {
    padding-left: 20px;
}
.decoding-explanation code {
    background-color: #3a3a3a;
    padding: 2px 4px;
    border-radius: 3px;
    font-family: Consolas, Monaco, 'Lucida Console', monospace;
}

.font-bold-style {
  font-weight: bold !important;
}

/* Terminal text colors (unchanged) */
.text-black { color: #000000; }
.text-red { color: #cc0000; }
.text-green { color: #4e9a06; }
.text-yellow { color: #c4a000; }
.text-blue { color: #3465a4; }
.text-magenta { color: #75507b; }
.text-cyan { color: #06989a; }
.text-white { color: #d3d7cf; }

.text-bright-black { color: #555753; }
.text-bright-red { color: #ef2929; }
.text-bright-green { color: #8ae234; }
.text-bright-yellow { color: #fce94f; }
.text-bright-blue { color: #729fcf; }
.text-bright-magenta { color: #ad7fa8; }
.text-bright-cyan { color: #34e2e2; }
.text-bright-white { color: #eeeeec; }

.text-bold-red { color: #ff4d4d; font-weight: bold; }
.text-bold-green { color: #73d216; font-weight: bold; }
.text-bold-yellow { color: #edd400; font-weight: bold; }
.text-bold-blue { color: #3584e4; font-weight: bold; }
.text-bold-magenta { color: #ad7fa8; font-weight: bold; }
.text-bold-cyan { color: #34e2e2; font-weight: bold; }
.text-bold-white { color: #ffffff; font-weight: bold; }

.text-bold-bright-magenta { color: #d070d0; font-weight: bold; }
.text-bold-bright-black { color: #7c7c7c; font-weight: bold; }
.text-bold-bright-white { color: #ffffff; font-weight: bold; }

.text-red-on-white { color: #ffffff; background-color: #c00; }
.text-reset { color: #d3d7cf; }

</style>
