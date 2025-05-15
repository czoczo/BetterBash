<template>
  <div class="container">
    <h1>Bash PS1 Prompt Customizer</h1>

    <div class="customizer">
      <div class="color-controls">
        <div
          v-for="(colorCode, colorName) in colors"
          :key="colorName"
          class="color-select"
        >
          <label>
            {{ colorLabels[colorName] || colorName }}
            <div
              class="color-preview"
              :style="{ backgroundColor: getPreviewColor(colorCode) }"
            ></div>
          </label>
          <select v-model="colors[colorName]" @change="updatePrompt">
            <option
              v-for="(color, name) in terminalColors"
              :key="name"
              :value="color.code"
            >
              {{ name }} ({{ color.code }})
            </option>
          </select>
        </div>
      </div>

      <div class="terminal">
        <div class="ps1-line">
          <span :class="getColorClass(colors.BORDCOL)">┌─</span
          ><span :class="getColorClass(colors.WHITEB)">(</span><span
            :class="getColorClass(colors.SECONDARY_COLOR)"
            >user</span
          ><span :class="getColorClass(colors.WHITEB)">@</span
          ><span :class="getColorClass(colors.PRIMARY_COLOR)">hostname</span
          ><span :class="getColorClass(colors.WHITEB)">:pts/5)</span
          ><span :class="getColorClass(colors.BORDCOL)">──</span
          ><span :class="getColorClass(colors.WHITEB)">(</span><span
            :class="getColorClass(colors.PRIMARY_COLOR)"
            >◢▼◢◆◆◣▼◣</span
          ><span :class="getColorClass(colors.WHITEB)">)</span
          ><span :class="getColorClass(colors.BORDCOL)"
            >───────────────────────</span
          ><span :class="getColorClass(colors.WHITEB)">(</span><span
            :class="getColorClass(colors.TIME_COLOR)"
            >Wed May 14</span
          ><span :class="getColorClass(colors.WHITEB)">)</span
          ><span :class="getColorClass(colors.BORDCOL)">───</span
          ><span :class="getColorClass(colors.WHITEB)">(</span><span
            :class="getColorClass(colors.PRIMARY_COLOR)"
            >00:40:00</span
          ><span :class="getColorClass(colors.WHITEB)">)</span
          ><span :class="getColorClass(colors.BORDCOL)">────</span>
        </div>
        <div class="ps1-line">
          <span :class="getColorClass(colors.BORDCOL)">└─</span
          ><span :class="getColorClass(colors.WHITEB)">(</span><span
            :class="getColorClass(colors.PATH_COLOR)"
            >~</span
          ><span :class="getColorClass(colors.WHITEB)">)─</span
          ><span :class="getColorClass(colors.BORDCOL)">(</span><span
            :class="getColorClass(colors.PRIMARY_COLOR)"
            >$</span
          ><span :class="getColorClass(colors.WHITEB)">)-></span>
        </div>
      </div>

      <div class="info-section">
        <h3>About This Customizer</h3>
        <p>
          This tool allows you to customize the colors of your bash PS1 prompt.
          Select different terminal colors for each component to see how they
          look in the preview.
        </p>
        <p>
          To use your customized prompt, you'll need to replace the color
          variables in your .bashrc file with the selected values.
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';

// Terminal colors mapping
const terminalColors = {
  Black: { code: '\\[\\033[00;30m\\]', hex: '#000000', cssClass: 'text-black' },
  Red: { code: '\\[\\033[00;31m\\]', hex: '#cc0000', cssClass: 'text-red' },
  Green: { code: '\\[\\033[00;32m\\]', hex: '#4e9a06', cssClass: 'text-green' },
  Yellow: { code: '\\[\\033[00;33m\\]', hex: '#c4a000', cssClass: 'text-yellow' },
  Blue: { code: '\\[\\033[00;34m\\]', hex: '#3465a4', cssClass: 'text-blue' },
  Magenta: { code: '\\[\\033[00;35m\\]', hex: '#75507b', cssClass: 'text-magenta' },
  Cyan: { code: '\\[\\033[00;36m\\]', hex: '#06989a', cssClass: 'text-cyan' },
  White: { code: '\\[\\033[00;37m\\]', hex: '#d3d7cf', cssClass: 'text-white' },
  'Bright Black': { code: '\\[\\033[00;90m\\]', hex: '#555753', cssClass: 'text-bright-black' },
  'Bright Red': { code: '\\[\\033[00;91m\\]', hex: '#ef2929', cssClass: 'text-bright-red' },
  'Bright Green': { code: '\\[\\033[00;92m\\]', hex: '#8ae234', cssClass: 'text-bright-green' },
  'Bright Yellow': { code: '\\[\\033[00;93m\\]', hex: '#fce94f', cssClass: 'text-bright-yellow' },
  'Bright Blue': { code: '\\[\\033[00;94m\\]', hex: '#729fcf', cssClass: 'text-bright-blue' },
  'Bright Magenta': { code: '\\[\\033[00;95m\\]', hex: '#ad7fa8', cssClass: 'text-bright-magenta' },
  'Bright Cyan': { code: '\\[\\033[00;96m\\]', hex: '#34e2e2', cssClass: 'text-bright-cyan' },
  'Bright White': { code: '\\[\\033[00;97m\\]', hex: '#eeeeec', cssClass: 'text-bright-white' },
  'Bold Red': { code: '\\[\\033[00;31;1m\\]', hex: '#ff4d4d', cssClass: 'text-bold-red' },
  'Bold Green': { code: '\\[\\033[00;32;1m\\]', hex: '#73d216', cssClass: 'text-bold-green' },
  'Bold Yellow': { code: '\\[\\033[00;33;1m\\]', hex: '#edd400', cssClass: 'text-bold-yellow' },
  'Bold Blue': { code: '\\[\\033[00;34;1m\\]', hex: '#3584e4', cssClass: 'text-bold-blue' },
  'Bold Magenta': { code: '\\[\\033[00;35;1m\\]', hex: '#ad7fa8', cssClass: 'text-bold-magenta' },
  'Bold Cyan': { code: '\\[\\033[00;36;1m\\]', hex: '#34e2e2', cssClass: 'text-bold-cyan' },
  'Bold White': { code: '\\[\\033[00;37;1m\\]', hex: '#ffffff', cssClass: 'text-bold-white' },
  'Bold Bright Magenta': { code: '\\[\\033[00;95;1m\\]', hex: '#d070d0', cssClass: 'text-bold-bright-magenta' },
  'Bold Bright Black': { code: '\\[\\033[00;90;1m\\]', hex: '#7c7c7c', cssClass: 'text-bold-bright-black' },
  'Bold Bright White': { code: '\\[\\033[00;97;1m\\]', hex: '#ffffff', cssClass: 'text-bold-bright-white' },
  'Red on White': { code: '\\033[00;41;97;1m', hex: '#ff0000', cssClass: 'text-red-on-white' },
  Reset: { code: '\\[\\033[0m\\]', hex: '#ffffff', cssClass: 'text-reset' },
};

// Color labels for better readability
const colorLabels = {
  PRIMARY_COLOR: 'Primary Color',
  SECONDARY_COLOR: 'Secondary Color',
  ROOT_COLOR: 'Root Color',
  TIME_COLOR: 'Time Color',
  ERR_COLOR: 'Error Color',
  WHITEB: 'White Bold',
  RST: 'Reset',
  BOLD: 'Bold',
  BORDCOL: 'Border Color',
  PATH_COLOR: 'Path Color',
};

// Default colors
const colors = ref({
  PRIMARY_COLOR: '\\[\\033[00;92m\\]',
  SECONDARY_COLOR: '\\[\\033[00;95;1m\\]',
  ROOT_COLOR: '\\033[00;41;97;1m',
  TIME_COLOR: '\\[\\033[00;93;1m\\]',
  ERR_COLOR: '\\[\\033[00;31;1m\\]',
  WHITEB: '\\[\\033[00;97;1m\\]',
  RST: '\\[\\033[0m\\]',
  BOLD: '\\[\\033[1m\\]',
  BORDCOL: '\\[\\033[00;90;1m\\]',
  PATH_COLOR: '\\[\\033[00;97;1m\\]',
});

// Get the hex color for preview
const getPreviewColor = (colorCode) => {
  for (const color of Object.values(terminalColors)) {
    if (color.code === colorCode) {
      return color.hex;
    }
  }
  return '#ffffff';
};

// Get CSS class for a color code
const getColorClass = (colorCode) => {
  for (const color of Object.values(terminalColors)) {
    if (color.code === colorCode) {
      return color.cssClass;
    }
  }
  return 'text-reset';
};

// Update the prompt preview when colors change
const updatePrompt = () => {
  console.log('Updating prompt colors');
};

onMounted(() => {
  // Initial update - no direct DOM manipulation in setup, but the template binding works
  console.log('Component mounted');
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
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 15px;
}
.color-select {
  display: flex;
  flex-direction: column;
  background-color: #2d2d2d;
  padding: 15px;
  border-radius: 8px;
}
label {
  margin-bottom: 8px;
  font-weight: bold;
}
select {
  padding: 8px;
  background-color: #3a3a3a;
  color: #fff;
  border: 1px solid #555;
  border-radius: 4px;
}
.terminal {
  background-color: #000;
  padding: 20px;
  border-radius: 8px;
  min-height: 180px;
  font-family: 'Courier New', monospace;
  overflow-x: auto;
  margin-top: 20px;
  white-space: pre-wrap;
}
.ps1-line {
  margin-bottom: 5px;
}
.ps1-input {
  margin-top: 5px;
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

/* Terminal text colors */
.text-black {
  color: #000000;
}
.text-red {
  color: #cc0000;
}
.text-green {
  color: #4e9a06;
}
.text-yellow {
  color: #c4a000;
}
.text-blue {
  color: #3465a4;
}
.text-magenta {
  color: #75507b;
}
.text-cyan {
  color: #06989a;
}
.text-white {
  color: #d3d7cf;
}
.text-bright-black {
  color: #555753;
}
.text-bright-red {
  color: #ef2929;
}
.text-bright-green {
  color: #8ae234;
}
.text-bright-yellow {
  color: #fce94f;
}
.text-bright-blue {
  color: #729fcf;
}
.text-bright-magenta {
  color: #ad7fa8;
}
.text-bright-cyan {
  color: #34e2e2;
}
.text-bright-white {
  color: #eeeeec;
}
.text-bold-red {
  color: #ff4d4d;
  font-weight: bold;
}
.text-bold-green {
  color: #73d216;
  font-weight: bold;
}
.text-bold-yellow {
  color: #edd400;
  font-weight: bold;
}
.text-bold-blue {
  color: #3584e4;
  font-weight: bold;
}
.text-bold-magenta {
  color: #ad7fa8;
  font-weight: bold;
}
.text-bold-cyan {
  color: #34e2e2;
  font-weight: bold;
}
.text-bold-white {
  color: #ffffff;
  font-weight: bold;
}
.text-bold-bright-magenta {
  color: #d070d0;
  font-weight: bold;
}
.text-bold-bright-black {
  color: #7c7c7c;
  font-weight: bold;
}
.text-bold-bright-white {
  color: #ffffff;
  font-weight: bold;
}
.text-red-on-white {
  color: #ffffff;
  background-color: #cc0000;
  font-weight: bold;
}
.text-reset {
  color: inherit;
}
</style>
