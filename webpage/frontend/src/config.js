// Environment resolved configuration of the WebUI.
//
// The endpoints of the install commands are read from the Vite env files
// (.env.development, .env.production) selected by the build mode. Every value
// falls back to its production counterpart, so a build that forgot to select a
// mode can never publish localhost installers.
//
//   pnpm build      -> production endpoints (bb.cz0.cz + the app service host)
//   pnpm dev        -> local backend started by ./dev.sh (localhost:8081/8443)
//   pnpm build:dev  -> a local build pointing at the local backend

const PRODUCTION = 'production';

const PRODUCTION_DEFAULTS = {
  installBaseUrl: 'https://bb.cz0.cz',
  // curl and wget reach the app service through bb.cz0.cz, the openssl variant
  // has to address the app service directly, as it sends a raw HTTP request.
  tlsHost: 'bbb-f4hxb4escnacbpe6.westeurope-01.azurewebsites.net',
  tlsPort: '443',
  siteUrl: 'https://betterbash.cz0.cz',
};

const DEVELOPMENT_DEFAULTS = {
  installBaseUrl: 'http://localhost:8081',
  tlsHost: 'localhost',
  tlsPort: '8443',
  siteUrl: 'http://localhost:5173',
};

const mode = import.meta.env.MODE;
const defaults = mode === PRODUCTION ? PRODUCTION_DEFAULTS : DEVELOPMENT_DEFAULTS;

const fromEnv = (name, fallback) => {
  const value = import.meta.env[name];
  return typeof value === 'string' && value.trim() !== '' ? value.trim() : fallback;
};

/** 'production' or 'development'. */
export const APP_ENV = fromEnv('VITE_BB_ENV', mode === PRODUCTION ? PRODUCTION : 'development');

export const IS_PRODUCTION = APP_ENV === PRODUCTION;

/** Base URL the curl and wget install commands download from. */
export const INSTALL_BASE_URL = fromEnv('VITE_BB_INSTALL_BASE_URL', defaults.installBaseUrl).replace(/\/+$/, '');

/** Host and port the openssl install command connects to (it always speaks TLS). */
export const TLS_HOST = fromEnv('VITE_BB_TLS_HOST', defaults.tlsHost);
export const TLS_PORT = fromEnv('VITE_BB_TLS_PORT', defaults.tlsPort);

/** Public address of the WebUI, used to recognise shared theme links. */
export const SITE_URL = fromEnv('VITE_BB_SITE_URL', defaults.siteUrl);

/** Host name of the WebUI, matched when a theme is loaded from a pasted URL. */
export const SITE_HOST = hostOf(SITE_URL);

function hostOf(url) {
  try {
    return new URL(url).host;
  } catch {
    return url;
  }
}

/**
 * The three install commands of the current theme. `code` is the theme code
 * (or the backend "rand" keyword) and `scriptName` either getbb.sh or
 * removebb.sh.
 */
export function installCommands(code, scriptName) {
  const target = `${INSTALL_BASE_URL}/${code}/${scriptName}`;

  return {
    curl: `curl -sL ${target} | bash -s curl && . ~/.bashrc`,
    wget: `wget -q -O - ${target} | bash -s wget && . ~/.bashrc`,
    openssl: opensslCommand(code, scriptName),
  };
}

/**
 * The dependency free install command: a raw HTTP request piped through
 * openssl s_client, which is why the host, the port and the path have to be
 * spelled out separately.
 */
export function opensslCommand(code, scriptName) {
  const connectTarget = `${TLS_HOST}:${TLS_PORT}`;
  // Only a non standard port belongs in the Host header, which keeps the
  // production command byte for byte identical to the released one.
  const hostHeader = String(TLS_PORT) === '443' ? TLS_HOST : connectTarget;
  const request = `GET /${code}/${scriptName} HTTP/1.1\\r\\nHost: ${hostHeader}\\r\\nConnection: close\\r\\n\\r\\n`;

  return (
    `echo -e "${request}" \\\r\n` +
    `| openssl s_client -quiet -connect ${connectTarget} 2>/dev/null \\\r\n` +
    `| sed '1,/^\\r$/d' | bash -s openssl && . ~/.bashrc`
  );
}
