import { readFileSync } from 'node:fs'
import { fileURLToPath, URL } from 'node:url'

import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

// https://vite.dev/config/
//
// The endpoints shown in the install commands do not live here, they come from
// the mode specific env files (.env.development, .env.production) and are read
// in src/config.js. Building for production is the default, development has to
// be asked for explicitly ("pnpm dev", "pnpm build:dev").
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  // Every fetch command of the WebUI is pinned to the release tag of this build,
  // and VERSION_APP.txt is the single source of that number (release_tag.yaml
  // creates the tag from it). A build that cannot read it pins `main` instead.
  let releaseRef = 'main'
  try {
    releaseRef = readFileSync(new URL('../../VERSION_APP.txt', import.meta.url), 'utf8').trim() || 'main'
  } catch {
    console.warn('vite: no ../../VERSION_APP.txt, install commands will pin main')
  }

  // The dev server is reachable from other machines through ./dev.sh, which
  // exports the interface to listen on and the host clients announce.
  const siteHost = env.VITE_BB_SITE_HOST || 'localhost'
  const sitePort = Number(env.VITE_BB_SITE_PORT || 5173)
  const announcedHosts = (env.VITE_BB_SITE_ALLOWED_HOSTS || '')
    .split(',')
    .map((host) => host.trim())
    .filter((host) => host && host !== 'localhost')

  return {
    // base: '/BetterBash',
    plugins: [
      vue(),
      vueDevTools(),
    ],
    server: {
      host: siteHost,
      port: sitePort,
      // IPv4 addresses are allowed by Vite itself, names have to be listed.
      allowedHosts: [
        'devcode.dom.cz0.cz',
        'czoczo.github.io',
        'hermes-dev.dom.cz0.cz',
        ...announcedHosts,
      ],
    },
    preview: {
      host: siteHost,
      port: sitePort,
    },
    define: {
      // Read by src/config.js as RELEASE_REF.
      'import.meta.env.VITE_BB_RELEASE_REF': JSON.stringify(releaseRef),
    },
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      },
    },
  }
})
