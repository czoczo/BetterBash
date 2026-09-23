#!/usr/bin/env node
//
// Print the install commands the WebUI shows, for the shell tests.
//
//   node tests/install-commands.mjs --origin URL [--tls-base-url URL]
//        [--code CODE] [--script getbb.sh|removebb.sh] [--field curl|wget|openssl|all]
//
// src/config.js builds the three tab commands from the origin the page was
// loaded from, so this renders them as a browser at --origin would see them. The
// installation tests execute what is printed here, which is how "the command on
// the page" and "the script that installs" are kept the same thing.

import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);

const option = (name, fallback) => {
  const at = argv.indexOf(`--${name}`);
  return at === -1 ? fallback : argv[at + 1];
};

const origin = option('origin', '');
const tlsBaseUrl = option('tls-base-url', '');
const code = option('code', '');
const script = option('script', 'getbb.sh');
const field = option('field', 'curl');

if (!origin) {
  console.error('install-commands: --origin URL is required');
  process.exit(2);
}

if (tlsBaseUrl) process.env.VITE_BB_TLS_BASE_URL = tlsBaseUrl;

// The page's own origin: where the WebUI was loaded from is where the installer
// files are served from, and that is what src/config.js is asked about.
globalThis.window = { location: { origin } };

const config = await import(
  pathToFileURL(join(here, '..', 'webpage', 'frontend', 'src', 'config.js')).href
);

const commands = config.installCommands({ script, code: code || null });

if (field === 'all') {
  for (const [name, command] of Object.entries(commands)) {
    console.log(`### ${name}`);
    console.log(command);
  }
  process.exit(0);
}

if (!(field in commands)) {
  console.error(`install-commands: unknown field ${field}`);
  process.exit(2);
}

process.stdout.write(`${commands[field]}\n`);
