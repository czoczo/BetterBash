# BetterBash WebUI

Vue 3 + Vite configurator shown at [betterbash.cz0.cz](https://betterbash.cz0.cz).

## Environments

The endpoints offered in the install commands are not hardcoded in the
components, they come from the env file matching the build mode and are read in
[`src/config.js`](src/config.js):

| | `pnpm build` (default) | `pnpm dev`, `pnpm build:dev` |
|---|---|---|
| env file | `.env.production` | `.env.development` |
| curl / wget method | `https://bb.cz0.cz` | `http://localhost:8081` |
| openssl method | `bbb-...azurewebsites.net:443` | `localhost:8443` |

Every value has its production counterpart as a fallback, so a build that forgot
to select a mode cannot publish localhost installers. A non-production build
says so with a badge next to the banner.

Variables (all prefixed with `VITE_`, see the env files): `VITE_BB_ENV`,
`VITE_BB_INSTALL_BASE_URL`, `VITE_BB_TLS_HOST`, `VITE_BB_TLS_PORT`,
`VITE_BB_SITE_PORT`, `VITE_BB_SITE_URL`.

The local endpoints belong to the backend started by `./dev.sh` from the
repository root (see the [project README](../../README.md)).

### Reaching the dev server from another machine

`pnpm dev` binds `localhost`. `./dev.sh` passes `--host 0.0.0.0` and sets
`VITE_BB_SITE_ALLOWED_HOSTS`, so a browser elsewhere can open the page and still
get install commands that work: `--site-host` selects the interface, and
`--public-host` the address the page advertises (an unlisted host name answers
403, plain IPv4 addresses are always allowed by Vite).

## Project Setup

```sh
pnpm install
```

### Compile and hot-reload for development

```sh
pnpm dev              # WebUI on http://localhost:5173
pnpm dev:backend      # the backend it points at, in another terminal
```

### Compile and minify for production

```sh
pnpm build
```

### Compile for a local deployment (points at the local backend)

```sh
pnpm build:dev
pnpm preview
```

## Recommended IDE Setup

[VSCode](https://code.visualstudio.com/) + [Volar](https://marketplace.visualstudio.com/items?itemName=Vue.volar) (and disable Vetur).

## Customize configuration

See [Vite Configuration Reference](https://vite.dev/config/).
