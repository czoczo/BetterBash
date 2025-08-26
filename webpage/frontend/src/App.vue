<template>
  <div class="container">
    <iframe src="https://ghbtns.com/github-btn.html?user=czoczo&repo=BetterBash&type=star&size=large&text=false" frameborder="0" scrolling="0" width="40" height="30" title="GitHub" class="ghlink"></iframe>
    <div class="customizer">
    <div class="header">
      <img src="/banner.png" class="banner">
    </div>

      <div class="color-controls">
        <div
          v-for="(label, colorKey) in colorLabels"
          :key="colorKey"
          class="color-select-group"
        >
          <div class="color-selector-main">
            <label :for="`select-${colorKey}`">
              <div
                class="color-preview"
                :style="{ backgroundColor: getPreviewColorFromBash(generatedColors[colorKey]) }"
              ></div>
              {{ label }}
            </label>
          </div>
          <div class="color-modifier-checkboxes">
            <select :id="`select-${colorKey}`" v-model="selectedColorAttributes[colorKey].baseCode" @change="updatePromptDetails">
              <option
                v-for="colorOpt in baseColorOptions"
                :key="colorOpt.value"
                :value="colorOpt.value"
              >
                {{ colorOpt.name }}
              </option>            
            </select>
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
        
        <!-- Avatar Toggle Control -->
        <div class="color-select-group">
          <div class="color-modifier-checkboxes">
            <input id="avatar-toggle" type="checkbox" v-model="showAvatar" @change="updatePromptDetails" />
            <label for="avatar-toggle">Show Avatar</label>
          </div>
          <button @click="generateRandomTheme()" class="default-btn">
            🎲 Random Theme
          </button>
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
          ><template v-if="showAvatar">
            <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
            ><span class="text-yellow">▶</span
            ><span class="text-bright-black">▬</span
            ><span class="text-bright-white">▲</span
            ><span class="text-cyan">◀▶</span
            ><span class="text-bright-white">▲</span
            ><span class="text-bright-black">▬</span
            ><span class="text-yellow">◀</span
            ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
            ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">──</span
          ></template>
          <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.SECONDARY_COLOR)">1 ↻</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span>
          <template v-if="!showAvatar">
            <span :class="getColorClassFromBash(generatedColors.BORDCOL)">────────────</span
          ></template>
          <span :class="getColorClassFromBash(generatedColors.BORDCOL)">─────────────────────────────</span
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
          ><span :class="getColorClassFromBash(generatedColors.PATH_COLOR)">~/git_repo</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ><span :class="getColorClassFromBash(generatedColors.BORDCOL)">─</span
          ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
          ><span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">$</span
          ><span :class="getColorClassFromBash(generatedColors.RST)"> on </span
          ><span class="text-green">main</span
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
          ><template v-if="showAvatar">
            <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span
            ><span class="text-yellow">▶</span
            ><span class="text-bright-black">▬</span
            ><span class="text-bright-white">▲</span
            ><span class="text-cyan">◀▶</span
            ><span class="text-bright-white">▲</span
            ><span class="text-bright-black">▬</span
            ><span class="text-yellow">◀</span
            ><span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span
          ></template>
          <template v-if="!showAvatar">
            <span :class="getColorClassFromBash(generatedColors.BORDCOL)">──────────</span
          ></template>
          <span :class="getColorClassFromBash(generatedColors.BORDCOL)">───────────────────────────</span
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
        <h3>Quick install/uninstall</h3>
        
        <!-- Tab navigation -->
        <div class="tab-navigation">
          <button 
            class="tab-button" 
            :class="{ active: activeTab === 'curl' }"
            @click="activeTab = 'curl'"
          >
            curl
          </button>
          <button 
            class="tab-button" 
            :class="{ active: activeTab === 'wget' }"
            @click="activeTab = 'wget'"
          >
            wget
          </button>
          <button 
            class="tab-button" 
            :class="{ active: activeTab === 'openssl' }"
            @click="activeTab = 'openssl'"  
          >
            openssl
          </button>
        </div>

        <!-- Tab content -->
        <div class="tab-content">
          <div v-show="activeTab === 'curl'" class="tab-panel">
            <div class="share-url-container">
              <input type="text" :value="curlInstallUrl" readonly id="installCurlCmd" @click="selectUrlText" />
              <div class="color-modifier-checkboxes">
                <input id="uninstall-toggle" type="checkbox" v-model="uninstallFlag" />
                <label for="uninstall-toggle">Uninstall</label>
              </div>
              <button @click="copyCurlCmdToClipboard">Copy command</button>
            </div>
          </div>
          
          <div v-show="activeTab === 'wget'" class="tab-panel">
            <div class="share-url-container">
              <input type="text" :value="wgetInstallUrl" readonly id="installWgetCmd" @click="selectUrlText" />
              <div class="color-modifier-checkboxes">
                <input id="uninstall-toggle" type="checkbox" v-model="uninstallFlag" />
                <label for="uninstall-toggle">Uninstall</label>
              </div>
              <button @click="copyWgetCmdToClipboard">Copy command</button>
            </div>
          </div>
          
          <div v-show="activeTab === 'openssl'" class="tab-panel">
            <div class="share-url-container multiline">
              <textarea :value="opensslInstallUrl" readonly id="installOpensslCmd" @click="selectUrlText" rows="5"></textarea>
              <button @click="copyOpensslCmdToClipboard">Copy command</button>
            </div>
            <div class="color-modifier-checkboxes">
              <input id="uninstall-toggle" type="checkbox" v-model="uninstallFlag" />
              <label for="uninstall-toggle">Uninstall</label>
            </div>
          </div>
        </div>
        

        <p v-if="copyCmdSuccess" class="copy-success-message">Copied to clipboard!</p>
      </div>

      <div class="share-section">
        <h3>Share your theme</h3>
        <div class="share-url-container">
            <input type="text" :value="shareableUrl" readonly id="shareUrlInput" @click="selectUrlText" />
            <button @click="copyUrlToClipboard">Copy URL</button>
        </div>
        <p v-if="copySuccess" class="copy-success-message">Copied to clipboard!</p>
      </div>

      <div class="share-section">
        <div>
        <h3>What am I looking at?</h3>
        <p>Mostly Bash configuration focused on usability. Pick your favorite colors and do a quick install to take advantage of the features below, or read about the <a href="https://github.com/czoczo/BetterBash/blob/main/MOTIVATION.md">motivation behind the project</a>. Share your theme with others with the generated URL.</p>
        <h3>Features:</h3>
        </div>
        <div>
        <ul>
          <li>
            <span class="terminal-inline">
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span>
              <span :class="getColorClassFromBash(generatedColors.SECONDARY_COLOR)">user</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">@</span>
              <span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">myhost:pts/5</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span>
            </span>
            - Username (highlighted if root) and hostname.
          </li>
          <li>
            <span class="terminal-inline">
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span>
              <span class="text-yellow">▶</span>
              <span class="text-bright-black">▬</span>
              <span class="text-bright-white">▲</span>
              <span class="text-cyan">◀▶</span>
              <span class="text-bright-white">▲</span>
              <span class="text-bright-black">▬</span>
              <span class="text-yellow">◀</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span>
            </span>
            - Unique host avatar based on hostname. Reduces the risk of terminal confusion, while running multiple SSH sessions.
          </li>
          <li>
            <span class="terminal-inline">
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span>
              <span :class="getColorClassFromBash(generatedColors.SECONDARY_COLOR)">1 ↻</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span>
            </span>
            - Shows number of background processes if more than zero.
          </li>
          <li> 
            <span class="terminal-inline">
              <span :class="getColorClassFromBash(generatedColors.BORDCOL)">──────</span>
            </span>
            - Line separating commands output.
          </li>
          <li>
            <span class="terminal-inline">
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span>
              <span :class="getColorClassFromBash(generatedColors.ERR_COLOR)">127 ↵</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span>
            </span>
            - Shows exit code if other than zero.
          </li>
          <li>
            <span class="terminal-inline">
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span>
              <span :class="getColorClassFromBash(generatedColors.TIME_COLOR)">Wed May 14</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span>
              <span :class="getColorClassFromBash(generatedColors.BORDCOL)">───</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span>
              <span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">00:40:12</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span>
            </span>
            - Date and time. Time changes color if exit code other than zero.
          </li>
          <li>
            <span class="terminal-inline">
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span>
              <span :class="getColorClassFromBash(generatedColors.PATH_COLOR)">~/repo</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span>
            </span>
            - Current directory.
          </li>
          <li>
            <span class="terminal-inline">
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">(</span>
              <span :class="getColorClassFromBash(generatedColors.PRIMARY_COLOR)">$</span>
              <span :class="getColorClassFromBash(generatedColors.RST)"> on </span>
              <span class="text-green">master</span>
              <span :class="getColorClassFromBash(generatedColors.RST)">=</span>
              <span :class="getColorClassFromBash(generatedColors.SEPARATOR_COLOR)">)</span>
            </span>
            - Git status (if current directory inside git repository).
          </li>
          <li>
            <span class="terminal-inline">
            <span>&lt;cmd_prefix&gt; + ⇅</span>
            </span>
            - Rapid search history with up/down keyboard arrows
          </li>
        </ul>
        </div>
      </div>

    </div>
  </div>
</template>

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
  return `curl -sL https://bb.cz0.cz/${code}/${scriptName} | bash && . ~/.bashrc`;
});

const wgetInstallUrl = computed(() => {
  const code = generateShareCode(selectedColorAttributes.value, showAvatar.value);
  const scriptName = uninstallFlag.value ? 'removebb.sh' : 'getbb.sh';
  return `wget -q -O - https://bb.cz0.cz/${code}/${scriptName} | bash && . ~/.bashrc`;
});

const opensslInstallUrl = computed(() => {
  const code = generateShareCode(selectedColorAttributes.value, showAvatar.value);
  const scriptName = uninstallFlag.value ? 'removebb.sh' : 'getbb.sh';
  const backend = 'bbbt-bdewcgb9h5h6dfda.westeurope-01.azurewebsites.net'
  return `echo -e "GET /${code}/${scriptName} HTTP/1.1\\r\\nHost: ${backend}\\r\\nConnection: close\\r\\n\\r\\n" \\\r\n| openssl s_client -quiet -connect ${backend}:443 2>/dev/null \\\r\n| sed '1,/^\\r$/d' | bash && . ~/.bashrc`;
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

<style scoped>
body {
  font-family: 'Courier New', monospace;
  margin: 0;
  padding: 20px;
  background-color: #1e1e1e;
  color: #f0f0f0;
}
p {
  margin-bottom: 16px;
}

li {
  padding: 2px 0px 2px 0px
}
.banner {
  float: left;
  margin-right: 15px;
}
.logo {
  float: left;
  width: 150px;
  image-rendering: pixelated;
  margin-right: 15px;
}
.container {
  max-width: 1000px;
  /*max-width: 1200px;*/
  margin: 0 auto;
  background-color: #1e1e1e;
  color: #f0f0f0;
}
h1 {
  color: #4e9a06; /* A pleasant green */
  font-family: "Tiny5", sans-serif;
  font-weight: 400;
  font-style: normal;
  font-size: 64px;
}
a {
  color: #4e9a06;
  border-bottom: 2px dotted #4e9a06;
}
a:hover {
  color: #076519;  
}
.customizer {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.color-controls {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 14px;
}
.color-select-group {
  display: flex;
  flex-direction: column;
  background-color: #2d2d2d;
  padding: 12px;
  border-radius: 8px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
  gap: 4px;
}
.color-selector-main label {
  /*margin-bottom: 8px;*/
  font-weight: bold;
  /*display: flex;*/
  align-items: center;
  flex: 1;
  flex-basis: 30%;
}
/*.color-selector-main select {*/
.color-modifier-checkboxes select {
  /*width: 100%;*/
  padding: 3px;
  margin-right: 10px;
  background-color: #3a3a3a;
  color: #fff;
  border: 1px solid #555;
  border-radius: 4px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
  flex: 1;
  flex-basis: 30%;
}
.color-modifier-checkboxes {
  /*display: flex;*/
  gap: 15px;
  /*margin-top: 5px;*/
}
.color-modifier-checkboxes label {
  /*display: flex;*/
  align-items: center;
  gap: 5px;
  font-weight: normal;
}
.color-modifier-checkboxes input[type="checkbox"] {
  margin-right: 4px;
}
.terminal-inline {
  background-color: #000;
  padding: 4px 6px 4px 8px;
  border-radius: 4px;
  min-height: 180px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
  white-space: pre-wrap;
  line-height: 0.9;
  font-size: 18px;
}
.terminal {
  background-color: #000;
  padding: 20px;
  border-radius: 8px;
  font-family: "Source Code Pro", Consolas, Monaco, 'Lucida Console', monospace;
  overflow-x: auto;
  margin-top: 10px;
  white-space: pre-wrap;
  line-height: 0.9;
  container-type: inline-size;
  letter-spacing: -0.05rem;
  /*font-size: 18px;*/
}
.ps1-line {
  /*font-size: min(1cqw, 19px);*/
  font-size: 1.4cqw;
  margin-bottom: 0px;
}
.color-preview {
  display: inline-block;
  width: 20px;
  height: 20px;
  /*margin-left: 10px*/;
  border: 1px solid #555;
  vertical-align: middle;
}
.info-section, .share-section {
  margin-top: 0px;
  background-color: #2d2d2d;
  padding: 14px 14px 20px 14px;
  border-radius: 8px;
}
.info-section h3, .share-section h3 {
  margin-top: 0;
  color: #4e9a06;
}
.share-url-container {
  display: flex;
  gap: 10px;
  align-items: center;
}
.share-url-container input[type="text"] {
  min-width: 50px;
  flex-grow: 1;
  padding: 8px;
  background-color: #3a3a3a;
  color: #f0f0f0;
  border: 1px solid #555;
  border-radius: 4px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
}
.share-url-container textarea {
  flex-grow: 1;
  padding: 8px;
  background-color: #3a3a3a;
  color: #f0f0f0;
  border: 1px solid #555;
  border-radius: 4px;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
  resize: vertical;
  min-height: 80px;
}
.share-url-container.multiline {
  align-items: flex-start;
}
.share-url-container button, .default-btn {
  padding: 8px 15px;
  background-color: #4e9a06;
  color: #fff;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: bold;
}
.share-url-container button:hover, .default-btn:hover {
  background-color: #076519;
}

/* Tab styles */
.tab-navigation {
  display: flex;
  margin-bottom: 15px;
  border-bottom: 1px solid #555;
}
.tab-button {
  padding: 10px 20px;
  background-color: transparent;
  color: #f0f0f0;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  font-family: Consolas, Monaco, 'Lucida Console', monospace;
  font-size: 14px;
  transition: all 0.3s ease;
}
.tab-button:hover {
  background-color: #3a3a3a;
}
.tab-button.active {
  color: #4e9a06;
  border-bottom-color: #4e9a06;
  font-weight: bold;
}
.tab-content {
  margin-top: 15px;
}
.tab-panel {
  min-height: 50px;
}

.copy-success-message {
  position: absolute;
  color: #8ae234; /* Bright Green */
  font-size: 0.9em;
}
.decoding-explanation {
    font-size: 0.9em;
    /*line-height: 1.6;*/
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

.ghlink {
  float: right;
  position: relative;
  top: 8px;
  right: 40px;
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
