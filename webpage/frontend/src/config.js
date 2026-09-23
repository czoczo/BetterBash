// Environment resolved configuration of the WebUI.
//
// BetterBash is a static site and its installer is a tree of files, not a
// script that downloads things. The commands below fetch that tree - with git, or
// with the package tests/stage-downloads.sh builds into the same deployment - and
// then run installbb.sh from it, which copies the prompt into ~/.bb. Nothing is
// piped into a shell, and every command asks once before it runs anything.
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
 * Where every fetch method leaves the tree, so the rest of the command is the
 * same for git, curl, wget and openssl. /tmp/bb is a shared name on purpose (the
 * alternative is a longer command); installbb.sh refuses a tree it is not the
 * owner of, and the README shows the mktemp -d variant for anyone who prefers a
 * private one.
 *
 * VITE_BB_STAGE_DIR exists for the tests: they may not write into the /tmp of the
 * machine running them. The page never sets it, so what it shows stays /tmp/bb.
 */
export const STAGE_DIR = fromEnv('VITE_BB_STAGE_DIR') || '/tmp/bb';

// Where tar unpacks the package: the bb/ prefix inside it creates STAGE_DIR.
const EXTRACT_DIR = STAGE_DIR.replace(/\/[^/]+$/, '') || '/';

const INSTALLER = 'installbb.sh';
const UNINSTALLER = 'removebb.sh';

/**
 * The question the command asks before it runs anything. Answering anything but
 * y leaves the fetched files on disk and installs nothing; without a terminal the
 * question cannot be answered at all, which is what the `auto` variant of the
 * command is for.
 */
export function confirmClause(kind = 'install', stage = STAGE_DIR) {
  const label = kind === 'uninstall' ? 'remove' : 'install';
  return `read -p"${label} BetterBash from ${stage}? [y/N] " -n1 && [[ $REPLY == [Yy] ]] && `;
}

/**
 * What the fetched tree is asked to do: install the theme, or uninstall.
 * `code` is the theme code (or the word "rand", which lets the machine draw its
 * own theme) and is left out for the uninstaller, which does not care about
 * colours. The installer never downloads, so it needs no origin of its own.
 */
function installerClause({ kind = 'install', code = null, auto = false, stage = STAGE_DIR } = {}) {
  const script = kind === 'uninstall' ? UNINSTALLER : INSTALLER;
  const args = [];
  // The question lives in the command line, so --yes only records that there was
  // deliberately none; automation keeps one shape either way.
  if (auto) args.push('--yes');
  if (code && kind !== 'uninstall') args.push(code);
  return `sh ${stage}/${script}${args.length ? ` ${args.join(' ')}` : ''}`;
}

function commandTail({ kind = 'install', auto = false, stage = STAGE_DIR } = {}) {
  const confirm = auto ? '' : confirmClause(kind, stage);
  return ` && ${confirm}`;
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
 * drops the question (see confirmClause) and passes --yes to the installer.
 */
export function installCommands({ kind = 'install', code = null, auto = false } = {}) {
  const stage = STAGE_DIR;
  const tail = `${commandTail({ kind, auto, stage })}${installerClause({ kind, code, auto, stage })} && . ~/.bashrc`;

  return {
    git: `git clone -q --depth 1 --branch ${RELEASE_REF} ${REPO_URL} ${stage}${tail}`,
    curl:
      `curl -sL ${INSTALL_BASE_URL}/${PACKAGE_PATH} | tar -C ${EXTRACT_DIR} -xz${tail}`,
    wget:
      `wget -q -O - ${INSTALL_BASE_URL}/${PACKAGE_PATH} | tar -C ${EXTRACT_DIR} -xz${tail}`,
    openssl: opensslCommand({ kind, code, auto }),
  };
}

/**
 * The dependency free fetch command: a raw HTTP request through openssl
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
export function opensslCommand({ kind = 'install', code = null, auto = false } = {}) {
  const stage = STAGE_DIR;
  const { host, port } = endpointOf(TLS_BASE_URL);
  // Only a non standard port belongs in the Host header.
  const hostHeader = port === '443' ? host : `${host}:${port}`;

  const tail = `${commandTail({ kind, auto, stage })}${installerClause({ kind, code, auto, stage })} && . ~/.bashrc`;

  // Joined with plain newlines, so copying the command out of the page gives the
  // shell exactly what is shown.
  return (
    `printf 'GET /${PACKAGE_PATH} HTTP/1.1\\r\\nHost: ${hostHeader}\\r\\nConnection: close\\r\\n\\r\\n' \\\n` +
    `| openssl s_client -quiet -connect ${host}:${port} -servername ${host} 2>/dev/null \\\n` +
    `| sed '1,/^\\r$/d' | tar -C ${EXTRACT_DIR} -xz${tail}`
  );
}
