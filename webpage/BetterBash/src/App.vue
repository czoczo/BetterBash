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
          ><span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">00:40:00</span
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
          ><span :class="getColorClassFromBash(generatedColors.ERR_COLOR)">128 ↵</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">──</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.TIME_COLOR)">Wed May 14</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">───</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.ERR_COLOR)">00:40:00</span
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

      <div class="info-section">
        <h3>About This Customizer</h3>
        <p>
          This tool allows you to customize the colors of your bash PS1 prompt.
          Select different terminal colors for each component and individually toggle
          "light" (bright) or "bold" styles to see how they
          look in the preview.
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';

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

// --- Create a comprehensive map for lookup: codeNum-isBold -> {hex, cssClass} ---
const finalColorMappings = {};
// Normal (non-bold, non-light)
for (const code in baseColorDefinitions) {
    finalColorMappings[`${code}-false`] = { hex: baseColorDefinitions[code].hex, cssClass: baseColorDefinitions[code].css };
}
// Light (non-bold, light)
for (const code in lightColorDefinitions) {
    finalColorMappings[`${code}-false`] = { hex: lightColorDefinitions[code].hex, cssClass: lightColorDefinitions[code].css };
}
// Bold Normal
for (const code in baseColorDefinitions) {
    const numCode = parseInt(code);
    if (boldColorSpecifics[numCode] && !(numCode >= 90)) {
        finalColorMappings[`${numCode}-true`] = { hex: boldColorSpecifics[numCode].hex, cssClass: boldColorSpecifics[numCode].css };
    } else {
        finalColorMappings[`${numCode}-true`] = { hex: baseColorDefinitions[numCode].hex, cssClass: `${baseColorDefinitions[numCode].css} font-bold-style` };
    }
}
// Bold Light
for (const code in lightColorDefinitions) {
    const numCode = parseInt(code);
    if (boldColorSpecifics[numCode]) {
        finalColorMappings[`${numCode}-true`] = { hex: boldColorSpecifics[numCode].hex, cssClass: boldColorSpecifics[numCode].css };
    } else {
        finalColorMappings[`${numCode}-true`] = { hex: lightColorDefinitions[numCode].hex, cssClass: `${lightColorDefinitions[numCode].css} font-bold-style` };
    }
}

// --- Options for Select Dropdowns ---
const baseColorOptions = Object.entries(baseColorDefinitions).map(([value, { name }]) => ({
  name,
  value: parseInt(value),
}));

// --- Initial state of selected color attributes for each prompt part ---
const initialBashColorCodes = {
  PRIMARY_COLOR: '\\[\\033[00;92m\\]',
  SECONDARY_COLOR: '\\[\\033[00;95;1m\\]',
  ROOT_COLOR: '\\[\\033[00;31;1m\\]',
  TIME_COLOR: '\\[\\033[00;33;1m\\]',
  ERR_COLOR: '\\[\\033[00;31;1m\\]',
  SEPARATOR_COLOR: '\\[\\033[00;97;1m\\]',
  BORDCOL: '\\[\\033[00;90;1m\\]',
  PATH_COLOR: '\\[\\033[00;97;1m\\]',
  RST: '\\[\\033[00;37m\\]',
};

function parseInitialBashCodeToAttributes(bashCode) {
  // Regex to capture style (like '00'), color code, and optional bold marker ';1m'
  // Example: \[\\033[00;92m\]  -> style: 00, colorNum: 92, boldSuffix: undefined
  // Example: \[\\033[00;31;1m\] -> style: 00, colorNum: 31, boldSuffix: ;1m
  // Example: \[\\033[1;31m\]   -> style: 1,  colorNum: 31, boldSuffix: undefined (if we adapt to this)
  const match = bashCode.match(/\[(?:(\d{1,2});)?(\d{2})(;1)?m/);
  let baseCode = 37; // Default: Light Gray
  let isLight = false;
  let isBold = false;

  if (match) {
    const stylePart = match[1]; // Might be undefined if only color code is present e.g. \[\033[32m\]
    let colorNum = parseInt(match[2]);
    const boldSuffix = match[3]; // ';1m'

    isLight = colorNum >= 90 && colorNum <= 97;
    baseCode = isLight ? colorNum - 60 : colorNum;
    
    // Determine boldness:
    // 1. If there's a ';1m' suffix (specific to some original formats)
    // 2. If the style part itself is '1' or '01' (standard bold)
    isBold = !!boldSuffix || stylePart === '1' || stylePart === '01';

  } else {
    // Fallback for very simple codes like \[\033[32m\]
    const simpleMatch = bashCode.match(/\[(\d{2})m/);
    if (simpleMatch) {
        let colorNum = parseInt(simpleMatch[1]);
        isLight = colorNum >= 90 && colorNum <= 97;
        baseCode = isLight ? colorNum - 60 : colorNum;
        isBold = false; // No bold info in this simple format
    }
  }
  return { baseCode, isLight, isBold };
}

const selectedColorAttributes = ref({});
for (const key in colorLabels) {
  if (initialBashColorCodes[key]) {
    selectedColorAttributes.value[key] = parseInitialBashCodeToAttributes(initialBashColorCodes[key]);
  } else {
    // Default for any new keys not in initialBashColorCodes
    selectedColorAttributes.value[key] = { baseCode: 37, isLight: false, isBold: false };
  }
}

// --- Computed property to generate final Bash escape codes ---
const generatedColors = computed(() => {
  const finalCodes = {};
  for (const key in selectedColorAttributes.value) {
    const attrs = selectedColorAttributes.value[key];
    let actualCode = attrs.isLight ? attrs.baseCode + 60 : attrs.baseCode;
    
    if (attrs.isBold) {
      finalCodes[key] = `\\[\\033[1;${actualCode}m\\]`;
    } else {
      finalCodes[key] = `\\[\\033[${actualCode}m\\]`;
    }
  }
  return finalCodes;
});

// --- Helper function to parse generated Bash codes for preview ---
function parseGeneratedBashCode(bashCode) {
  const match = bashCode.match(/\[(?:(1);)?(\d{2})m/);
  if (match) {
    const isBold = !!match[1];
    const colorNum = parseInt(match[2]);
    return { colorNum, isBold };
  }
   const simplerMatch = bashCode.match(/\[(?:0;)?(\d{2})m/);
   if (simplerMatch) {
    return { colorNum: parseInt(simplerMatch[1]), isBold: false };
  }
  // Fallback if parsing fails, try to determine from current individual attribute
  // This part is tricky as this function only gets the bash code, not the key.
  // For robustness, stick to parsing the code or a safe default.
  console.warn("Could not parse bash code for preview:", bashCode);
  return { colorNum: 37, isBold: false }; // Default to non-bold light gray
}

// --- Get Hex Color for Preview Box ---
const getPreviewColorFromBash = (bashCode) => {
  if (!bashCode) return baseColorDefinitions[37].hex; // Default for undefined
  const { colorNum, isBold } = parseGeneratedBashCode(bashCode);
  const mappingKey = `${colorNum}-${isBold}`;
  const fallbackKeyNormal = `${colorNum}-false`;
  const colorData = finalColorMappings[mappingKey] || finalColorMappings[fallbackKeyNormal];

  if (colorData) return colorData.hex;
  return baseColorDefinitions[37].hex; // Ultimate fallback
};

// --- Get CSS Class for Prompt Preview ---
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
  return 'text-white font-bold-style'; // Ultimate fallback
};

const updatePromptDetails = () => {
  // console.log("Prompt attributes updated:", JSON.parse(JSON.stringify(selectedColorAttributes.value)));
};

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
  color: #10b981;
}
.customizer {
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.color-controls {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); /* Adjusted minmax for more space */
  gap: 20px;
}
.color-select-group {
  display: flex;
  flex-direction: column;
  background-color: #2d2d2d;
  padding: 15px;
  border-radius: 8px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
  gap: 10px; /* Space between main selector and checkboxes */
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
  gap: 15px; /* Space between Light and Bold checkboxes */
  margin-top: 5px;
}
.color-modifier-checkboxes label {
  display: flex;
  align-items: center;
  gap: 5px;
  font-weight: normal; /* Normal weight for checkbox labels */
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
.info-section {
  margin-top: 30px;
  background-color: #2d2d2d;
  padding: 15px;
  border-radius: 8px;
}

.font-bold-style {
  font-weight: bold !important;
}

/* Terminal text colors from original CSS */
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
