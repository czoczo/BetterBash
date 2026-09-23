// Environment resolved configuration of the WebUI.
//
// BetterBash is a static site. The WebUI and the files the installer downloads
// are one deployment (the Pages workflow stages them with
// tests/stage-downloads.sh), so the install commands download from the origin
// that served this page: bb.cz0.cz installs from bb.cz0.cz, betterbash.cz0.cz
// from betterbash.cz0.cz, and a local checkout from its own dev server. The
// theme is an argument of the installer, never part of a URL, so nothing that
// comes from the page has to be escaped into a request.
//
//   pnpm build     -> production endpoints, downloads from the serving origin
//   pnpm dev       -> ./dev.sh serves the staged files from public/ on the dev server
//   pnpm build:dev -> the same local endpoints as a built bundle

const PRODUCTION = 'production';

/** Where the files of a release live; a build that cannot use its own origin
 *  (opened from disk, or a WebUI hosted without the installer files) falls back
 *  to this. */
const PRODUCTION_ORIGIN = 'https://betterbash.cz0.cz';

// Optional chaining keeps this file importable by plain node (see
// tests/install-commands.mjs), which has no import.meta.env.
const mode = import.meta.env?.MODE ?? 'production';
const isProductionMode = mode === PRODUCTION;

// Reads a build time setting of the WebUI. Outside a Vite build (plain node, the
// tests in tests/) the same variable is taken from the process environment.
const fromEnv = (name, fallback = '') => {
  const value = import.meta.env?.[name] ?? globalThis.process?.env?.[name];
  return typeof value === 'string' && value.trim() !== '' ? value.trim() : fallback;
};

/** 'production' or 'development'. */
export const APP_ENV = fromEnv('VITE_BB_ENV', isProductionMode ? PRODUCTION : 'development');

export const IS_PRODUCTION = APP_ENV === PRODUCTION;

/** Origin of the page, when it was loaded over http(s). */
function pageOrigin() {
  if (typeof window === 'undefined') return '';
  const origin = window.location?.origin ?? '';
  return /^https?:\/\//.test(origin) ? origin : '';
}

const trimSlashes = (url) => url.replace(/\/+$/, '');

/**
 * Base URL the curl and wget install commands download from. An explicitly
 * configured URL wins; otherwise the page downloads from its own origin, which
 * is what makes every domain of the deployment self contained.
 */
export const INSTALL_BASE_URL = trimSlashes(
  fromEnv('VITE_BB_INSTALL_BASE_URL') || pageOrigin() || PRODUCTION_ORIGIN,
);

/**
 * Base URL of the openssl variant. It is the same file over the same origin,
 * but the request is written by hand, so its host and port are taken from here.
 * Only a development setup needs a value of its own, because a dev server speaks
 * plain http while openssl insists on TLS.
 */
export const TLS_BASE_URL = trimSlashes(
  fromEnv('VITE_BB_TLS_BASE_URL') || INSTALL_BASE_URL,
);

// getbb.sh cannot know which URL it was piped from, so a page that is not served
// from the canonical origin tells it where the rest of the files are, and
// installing from a mirror installs the files of that mirror. On the canonical
// origin the commands stay as short as they have always been, and the
// uninstaller, which downloads nothing, needs no origin at all.
const UNINSTALL_SCRIPT = 'removebb.sh';

const baseAssignment = (script, base) => {
  if (script === UNINSTALL_SCRIPT) return '';
  return base === PRODUCTION_ORIGIN ? '' : `BB_BASE_URL=${base} `;
};

/** Host and port of a URL, for the hand written request of the openssl method. */
function endpointOf(url) {
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    // Not a URL at all: keep the old behaviour of using the value as a host.
    return { host: url, port: '443' };
  }
  return {
    host: parsed.hostname,
    port: parsed.port || (parsed.protocol === 'https:' ? '443' : '80'),
  };
}

/** The installer is fetched through a pipe, so its own arguments follow a "--". */
function installerArgs(method, code) {
  return code ? ` -- ${method} ${code}` : ` -- ${method}`;
}

/**
 * The three install commands for one script of the deployment.
 *
 * `script` is getbb.sh or removebb.sh; `code` is the theme code (or the word
 * "rand", which lets the machine draw its own theme) and is left out for the
 * uninstaller, which does not care about colours.
 */
export function installCommands({ script = 'getbb.sh', code = null } = {}) {
  const target = `${INSTALL_BASE_URL}/${script}`;

  return {
    curl:
      `curl -sL ${target} | ${baseAssignment(script, INSTALL_BASE_URL)}bash -s${installerArgs('curl', code)} && . ~/.bashrc`,
    wget:
      `wget -q -O - ${target} | ${baseAssignment(script, INSTALL_BASE_URL)}bash -s${installerArgs('wget', code)} && . ~/.bashrc`,
    openssl: opensslCommand({ script, code }),
  };
}

/**
 * The dependency free install command: a raw HTTP request through
 * openssl s_client, which is why the host, the port and the path have to be
 * spelled out. -servername is not optional - a shared front proxy answers many
 * host names from one address - and the carriage returns of the headers are
 * removed before the script reaches the shell.
 */
export function opensslCommand({ script = 'getbb.sh', code = null } = {}) {
  const { host, port } = endpointOf(TLS_BASE_URL);
  // Only a non standard port belongs in the Host header.
  const hostHeader = port === '443' ? host : `${host}:${port}`;
  const request = `GET /${script} HTTP/1.1\\r\\nHost: ${hostHeader}\\r\\nConnection: close\\r\\n\\r\\n`;

  // Joined with plain newlines, so copying the command out of the page gives the
  // shell exactly what is shown.
  return (
    `echo -e "${request}" \\\n` +
    `| openssl s_client -quiet -connect ${host}:${port} -servername ${host} 2>/dev/null \\\n` +
    `| sed '1,/^\\r$/d' | sed 's/\\r$//' | ${baseAssignment(script, TLS_BASE_URL)}bash -s${installerArgs('openssl', code)} && . ~/.bashrc`
  );
}
