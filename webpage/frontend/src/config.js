// Environment resolved configuration of the WebUI.
//
// BetterBash is a static site and its installer is a tree of files, not a
// script that downloads things. The commands below fetch that tree - with git, or
// with the package tests/stage-downloads.sh builds into the same deployment - into
// ~/.bb itself, and then source the prompt of the tree, which installs the tree
// into ~/.bb the first time it is sourced and puts the prompt on the shell that
// asked.
// Nothing is piped into a shell, and every command asks once before it runs
// anything.
//
//   pnpm build     -> production endpoints, the package fetched from the serving origin
//   pnpm dev       -> ./dev.sh serves the staged package from public/ on the dev server
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
 * Origin the package is fetched from. An explicitly configured URL wins;
 * otherwise the page fetches from its own origin, which is what makes every
 * domain of the deployment self contained: bb.cz0.cz fetches from bb.cz0.cz,
 * betterbash.cz0.cz from betterbash.cz0.cz, a local checkout from its dev server.
 */
export const INSTALL_BASE_URL = trimSlashes(
  fromEnv('VITE_BB_INSTALL_BASE_URL') || pageOrigin() || PRODUCTION_ORIGIN,
);

/**
 * Base URL of the openssl variant. It is the same package over the same origin,
 * but the request is written by hand, so its host and port are taken from here.
 * Only a development setup needs a value of its own, because a dev server speaks
 * plain http while openssl insists on TLS.
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
 * VERSION_APP.txt by vite.config.js. Pinning is what makes "the command of the
 * page" repeatable years later, and it is why the version in the command and the
 * version in VERSION_APP.txt have to move together.
 */
export const RELEASE_REF = fromEnv('VITE_BB_RELEASE_REF') || 'main';

/** The package of a release, built by tests/stage-downloads.sh, with a checksum
 *  next to it. */
export const PACKAGE_PATH = 'bb.tgz';
export const PACKAGE_CHECKSUM_PATH = 'bb.tgz.sha256';

/**
 * Where BetterBash lives, written the way it should be typed into a shell. `~` is
 * left unexpanded on purpose: it is the shell running the command that knows whose
 * home directory this is, which is also what lets a test run the very same command
 * in a throwaway HOME.
 *
 * It is also where every fetch method leaves the tree, so the rest of a command is
 * the same for git, curl, wget and openssl. Nothing is unpacked into ~ and no
 * directory of its own is made under it: the fetched tree sits in ~/.bb, `prompt/`
 * and `installbb.sh` next to the `bb.sh` copied out of them. installbb.sh refuses a
 * tree it is not the owner of, and a fetched tree installs nothing until it is
 * sourced (see install-pending and prompt/bb.sh).
 */
export const BB_DIR = fromEnv('VITE_BB_DIR') || '~/.bb';

// bb.tgz holds the tree at its own root, so the destination is written on the
// command line instead of being carried inside the archive: `tar -C ~/.bb` wants
// that directory to exist, unlike `git clone`, which creates it.
const MAKE_BB_DIR = `mkdir -p ${BB_DIR} && `;

const PROMPT = 'bb.sh';
const UNINSTALLER = 'removebb.sh';

/**
 * The question the command asks before it runs anything, about the directory it is
 * about to work in. Answering anything but y leaves the fetched files on disk and
 * installs nothing; without a terminal the question cannot be answered at all,
 * which is what the `auto` variant of the command is for.
 */
export function confirmClause(kind = 'install', dir = BB_DIR) {
  const label = kind === 'uninstall' ? 'remove' : 'install';
  return `read -p"${label} BetterBash from ${dir}? [y/N] " -n1 && [[ $REPLY == [Yy] ]] && `;
}

/**
 * What the fetched tree is asked to do: source its prompt. A fetched tree carries
 * the file install-pending, and the first sourcing of prompt/bb.sh in such a tree
 * installs the tree and takes the flag away, so the same sourcing both installs
 * BetterBash and puts the prompt on the shell that asked for it - there is no
 * second step to reload the shell into, and every later sourcing of that file is
 * only a prompt.
 *
 * `code` is the theme code (or the word "rand", which lets the machine draw its
 * own theme); it is an argument of the sourcing.
 */
function installClause({ code = null, dir = BB_DIR } = {}) {
  const args = [`. ${dir}/prompt/${PROMPT}`];
  // Nothing is passed for the question: it lives in the command line, so dropping
  // it (auto) removes it from there and leaves no trace in the install call.
  if (code) args.push(code);
  return args.join(' ');
}

/** The question and the install, appended to a fetch command. */
function fetchTail({ code = null, auto = false, dir = BB_DIR } = {}) {
  const confirm = auto ? '' : confirmClause('install', dir);
  return ` && ${confirm}${installClause({ code, dir })}`;
}

/**
 * Removing BetterBash, which needs no fetch and is therefore the same command for
 * every method: ~/.bb holds the uninstaller of the version it was installed from,
 * together with the tree the last install command left there. Nothing has to be
 * downloaded to take it away; a shell has to be restarted for the change to show.
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
 * The four fetch commands of the WebUI.
 *
 * `kind` is install or uninstall, `code` the theme code for an install, `auto`
 * drops the question (see confirmClause). Every install method fetches into
 * ~/.bb and ends the same way, so only the first part of a command differs
 * between git, curl, wget and openssl; removing needs no fetch, so all four methods
 * show one and the same uninstall command.
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
 * The dependency free fetch command of an install: a raw HTTP request through openssl
 * s_client, which is why the host, the port and the path have to be spelled out.
 * -servername is not optional - a shared front proxy answers many host names from
 * one address - and only the headers are removed afterwards. The carriage returns
 * of the body are NOT removed here, as the response is the package: the old text
 * pipeline of the legacy path ate four bytes out of exactly this file and left a
 * corrupt gzip behind (checked in ./test-install.sh).
 *
 * The request is written with printf rather than `echo -e`, because dash answers
 * `echo -e` with a literal "-e" and there is no reason to require bash for a
 * request (only the question the command asks needs bash).
 */
export function opensslCommand({ code = null, auto = false } = {}) {
  const { host, port } = endpointOf(TLS_BASE_URL);
  // Only a non standard port belongs in the Host header.
  const hostHeader = port === '443' ? host : `${host}:${port}`;

  const tail = fetchTail({ code, auto });

  // Joined with plain newlines, so copying the command out of the page gives the
  // shell exactly what is shown.
  return (
    `${MAKE_BB_DIR}printf 'GET /${PACKAGE_PATH} HTTP/1.1\\r\\nHost: ${hostHeader}\\r\\nConnection: close\\r\\n\\r\\n' \\\n` +
    `| openssl s_client -quiet -connect ${host}:${port} -servername ${host} 2>/dev/null \\\n` +
    `| sed '1,/^\\r$/d' | tar -C ${BB_DIR} -xz${tail}`
  );
}
