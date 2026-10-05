// Environment resolved configuration of the WebUI.
//
// The commands below fetch the BetterBash tree into ~/.bb and then source the prompt of
// the tree, whose first sourcing installs it and puts the prompt on the shell that
// asked. Nothing is piped into a shell, and every command asks once before running.
//
//   pnpm build     -> production endpoints, the package fetched from the serving origin
//   pnpm dev       -> ./dev.sh serves the staged package from public/ on the dev server
//   pnpm build:dev -> the same local endpoints as a built bundle

const PRODUCTION = 'production';

/** Where a release lives; the fallback when the build cannot use its own origin. */
const PRODUCTION_ORIGIN = 'https://betterbash.cz0.cz';

// Optional chaining keeps this importable by plain node (tests/install-commands.mjs),
// which has no import.meta.env.
const mode = import.meta.env?.MODE ?? 'production';
const isProductionMode = mode === PRODUCTION;

// A build time setting; outside a Vite build the same variable comes from the
// process environment.
const fromEnv = (name, fallback = '') => {
  const value = import.meta.env?.[name] ?? globalThis.process?.env?.[name];
  return typeof value === 'string' && value.trim() !== '' ? value.trim() : fallback;
};

/** 'production' or 'development'. */
export const APP_ENV = fromEnv('VITE_BB_ENV', isProductionMode ? PRODUCTION : 'development');

/** Origin of the page, when it was loaded over http(s). */
function pageOrigin() {
  if (typeof window === 'undefined') return '';
  const origin = window.location?.origin ?? '';
  return /^https?:\/\//.test(origin) ? origin : '';
}

const trimSlashes = (url) => url.replace(/\/+$/, '');

/**
 * Origin the package is fetched from. An explicitly configured URL wins, otherwise the
 * page fetches from its own origin, which makes every domain of the deployment self
 * contained.
 */
export const INSTALL_BASE_URL = trimSlashes(
  fromEnv('VITE_BB_INSTALL_BASE_URL') || pageOrigin() || PRODUCTION_ORIGIN,
);

/**
 * Base URL of the openssl variant: the same package, but the request is written by hand
 * so its host and port come from here. Only a development setup needs its own value, as
 * a dev server speaks http and openssl insists on TLS.
 */
export const TLS_BASE_URL = trimSlashes(
  fromEnv('VITE_BB_TLS_BASE_URL') || INSTALL_BASE_URL,
);

/** The git tree of this project, for the git method. */
export const REPO_URL = trimSlashes(
  fromEnv('VITE_BB_REPO_URL') || 'https://github.com/czoczo/BetterBash',
);

/**
 * The ref every fetch is pinned to: the release tag of this build, taken from
 * VERSION_APP.txt by vite.config.js. Pinning is what makes the command of the page
 * repeatable years later, so both versions have to move together.
 */
export const RELEASE_REF = fromEnv('VITE_BB_RELEASE_REF') || 'main';

/** The package of a release, built by tests/stage-downloads.sh. */
export const PACKAGE_PATH = 'bb.tgz';

/**
 * Where BetterBash lives, written as it should be typed into a shell: `~` is left
 * unexpanded so the shell running the command decides whose home it is, which is also
 * what lets a test run the same command in a throwaway HOME. Every fetch method leaves
 * the tree here, so the rest of a command is the same for all four.
 */
export const BB_DIR = fromEnv('VITE_BB_DIR') || '~/.bb';

// bb.tgz holds the tree at its own root, so the destination is written on the command
// line: `tar -C ~/.bb` wants the directory to exist, unlike `git clone`.
const MAKE_BB_DIR = `mkdir -p ${BB_DIR} && `;

const PROMPT = 'bb.sh';
const UNINSTALLER = 'removebb.sh';

/** The question of an install, carried by the tree it fetched: a file rather than a
 *  string of the command, so the message can be long and the command short. */
const QUESTION = 'q';

/**
 * The question asked before anything runs. Anything but y leaves the fetched files on
 * disk and installs nothing; without a terminal it cannot be answered, which is what
 * the `auto` variant is for. An install asks with the words of the tree it fetched
 * (`~/.bb/q`); removing fetches nothing, so its question is written into its command.
 */
export function confirmClause(kind = 'install', dir = BB_DIR) {
  if (kind === 'uninstall') {
    return `read -p"remove BetterBash from ${dir}? [y/N] " -n1 && [[ $REPLY == [Yy] ]] && `;
  }
  return `read -p"$(<${dir}/${QUESTION})" -n1 && [[ $REPLY == [Yy] ]] && `;
}

/**
 * What the fetched tree is asked to do: source its prompt. The first sourcing of a
 * pending tree installs it and puts the prompt on the shell that asked, so there is no
 * second step. `code` is the theme code, or the "rand:<code>" draw the page writes
 * while its Random box is ticked.
 */
function installClause({ code = null, dir = BB_DIR } = {}) {
  const args = [`. ${dir}/prompt/${PROMPT}`];
  // The question is read by the command itself, so dropping it (auto) leaves no trace
  // in the install call.
  if (code) args.push(code);
  return args.join(' ');
}

/** The question and the install, appended to a fetch command. */
function fetchTail({ code = null, auto = false, dir = BB_DIR } = {}) {
  const confirm = auto ? '' : confirmClause('install', dir);
  return ` && ${confirm}${installClause({ code, dir })}`;
}

/**
 * Removing BetterBash needs no fetch - ~/.bb holds the uninstaller of what was
 * installed - so it is one command for every method. A shell restart shows it.
 */
export function uninstallCommand({ auto = false } = {}) {
  const confirm = auto ? '' : confirmClause('uninstall', BB_DIR);
  return `${confirm}sh ${BB_DIR}/${UNINSTALLER}`;
}

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

/**
 * The four fetch commands of the WebUI. `kind` is install or uninstall, `code` the
 * theme code, `auto` drops the question. Every method fetches into ~/.bb and ends the
 * same way, so only the first part differs.
 */
export function installCommands({ kind = 'install', code = null, auto = false } = {}) {
  if (kind === 'uninstall') {
    const command = uninstallCommand({ auto });
    return { git: command, curl: command, wget: command, openssl: command };
  }
  const tail = fetchTail({ code, auto });

  return {
    git: `git clone -q --depth 1 --branch ${RELEASE_REF} ${REPO_URL} ${BB_DIR}${tail}`,
    curl:
      `${MAKE_BB_DIR}curl -sL ${INSTALL_BASE_URL}/${PACKAGE_PATH} | tar -C ${BB_DIR} -xz${tail}`,
    wget:
      `${MAKE_BB_DIR}wget -q -O - ${INSTALL_BASE_URL}/${PACKAGE_PATH} | tar -C ${BB_DIR} -xz${tail}`,
    openssl: opensslCommand({ code, auto }),
  };
}

/**
 * The dependency free fetch: a raw HTTP request through openssl s_client, so host,
 * port and path are spelled out. -servername is not optional (a shared front proxy
 * answers many names from one address) and only the headers are removed afterwards -
 * the body is the package, and an earlier text pipeline ate bytes out of exactly this
 * file (checked in ./test-install.sh). printf, not `echo -e`, which dash answers with
 * a literal "-e".
 */
export function opensslCommand({ code = null, auto = false } = {}) {
  const { host, port } = endpointOf(TLS_BASE_URL);
  // Only a non standard port belongs in the Host header.
  const hostHeader = port === '443' ? host : `${host}:${port}`;

  const tail = fetchTail({ code, auto });

  // Joined with plain newlines, so copying from the page gives the shell what is shown.
  return (
    `${MAKE_BB_DIR}printf 'GET /${PACKAGE_PATH} HTTP/1.1\\r\\nHost: ${hostHeader}\\r\\nConnection: close\\r\\n\\r\\n' \\\n` +
    `| openssl s_client -quiet -connect ${host}:${port} -servername ${host} 2>/dev/null \\\n` +
    `| sed '1,/^\\r$/d' | tar -C ${BB_DIR} -xz${tail}`
  );
}
