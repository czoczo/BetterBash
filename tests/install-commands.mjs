#!/usr/bin/env node
//
// Print the install commands the WebUI shows, for the shell tests.
//
//   node tests/install-commands.mjs --origin URL [--tls-base-url URL]
//        [--code CODE] [--kind install|uninstall] [--auto] [--field
//        git|curl|wget|openssl|all] [--repo-url URL] [--stage-dir DIR]
//
// src/config.js builds the four tab commands from the origin the page was loaded
// from and from the release tag in VERSION_APP.txt, so this renders them as a
// browser at --origin would see them. The installation tests execute what is
// printed here, which is how "the command on the page" and "the script that
// installs" are kept the same thing.
//
// --repo-url points the git method somewhere else than github.com (a local bare
// repository), so the fetch methods can be tested without a network. --auto drops
// the question of the command, exactly like the Auto checkbox on the page.
// --stage-dir moves the fetched tree out of /tmp, which is what lets the tests
// run without touching the /tmp of their machine.

import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { readFileSync } from 'node:fs';

const here = dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);

const option = (name, fallback) => {
  const at = argv.indexOf(`--${name}`);
  return at === -1 ? fallback : argv[at + 1];
};

const origin = option('origin', '');
const tlsBaseUrl = option('tls-base-url', '');
const code = option('code', '');
const kind = option('kind', 'install');
const repoUrl = option('repo-url', '');
const stageDir = option('stage-dir', '');
const field = option('field', 'curl');
const auto = argv.includes('--auto');

if (!origin) {
  console.error('install-commands: --origin URL is required');
  process.exit(2);
}
if (kind !== 'install' && kind !== 'uninstall') {
  console.error('install-commands: --kind is install or uninstall');
  process.exit(2);
}

if (tlsBaseUrl) process.env.VITE_BB_TLS_BASE_URL = tlsBaseUrl;
if (repoUrl) process.env.VITE_BB_REPO_URL = repoUrl;
if (stageDir) process.env.VITE_BB_STAGE_DIR = stageDir;

// The release tag vite.config.js compiles into a bundle is read from
// VERSION_APP.txt the same way, so a test renders what the workflow deploys.
if (!process.env.VITE_BB_RELEASE_REF) {
  try {
    process.env.VITE_BB_RELEASE_REF = readFileSync(
      join(here, '..', 'VERSION_APP.txt'),
      'utf8',
    ).trim();
  } catch {
    process.env.VITE_BB_RELEASE_REF = 'main';
  }
}

// The page's own origin: where the WebUI was loaded from is where the package is
// served from, and that is what src/config.js is asked about.
globalThis.window = { location: { origin } };

const config = await import(
  pathToFileURL(join(here, '..', 'webpage', 'frontend', 'src', 'config.js')).href
);

const commands = config.installCommands({ kind, code: code || null, auto });

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
