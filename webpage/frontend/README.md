# BetterBash WebUI

Vue 3 + Vite configurator shown at [betterbash.cz0.cz](https://betterbash.cz0.cz).

## Environments

The endpoints offered in the install commands are not hardcoded in the
components, they come from the env file matching the build mode and are read in
[`src/config.js`](src/config.js):

| | `pnpm build` (default) | `pnpm dev`, `pnpm build:dev` |
|---|---|---|
| env file | `.env.production` | `.env.development` |
| curl / wget method | the origin that served the page, `https://betterbash.cz0.cz` in production | `http://localhost:5173` |
| openssl method | the same origin over TLS | `https://localhost:8443` |

The install base is empty in `.env.production` on purpose: the page and the files
it installs are one deployment, so every domain of it installs from itself and no
domain name has to be compiled in. `src/config.js` falls back to the production
origin when it cannot know its own (opened from disk), so a build that forgot to
select a mode cannot publish localhost installers. A non-production build says so
with a badge next to the banner.

Variables (all prefixed with `VITE_`, see the env files): `VITE_BB_ENV`,
`VITE_BB_INSTALL_BASE_URL`, `VITE_BB_TLS_BASE_URL`, `VITE_BB_SITE_PORT`,
`VITE_BB_SITE_HOST`, `VITE_BB_SITE_ALLOWED_HOSTS`.

The local endpoints belong to the dev server and the HTTPS file server started by
`./dev.sh` from the repository root (see the
[project README](../../README.md)).

## The files the page installs

`getbb.sh`, `removebb.sh`, `.inputrc` and `prompt/` live in the repository root
and are staged next to the built page, by `tests/stage-downloads.sh` in the Pages
workflow and locally by `./dev.sh`. `pnpm stage` does the same into `public/`,
where the dev server serves them from.

The commands in the three tabs are built in `src/config.js`, and
`tests/install-commands.mjs` renders them outside a browser. That is how
`./test-install-methods.sh` manages to run literally what the page shows, against
a local server and against the deployment.

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
pnpm stage            # copy the installer files into public/, so the page can install
```
`./dev.sh` from the repository root does both and adds the HTTPS file server the
openssl tab needs, which is the setup worth using.

### Compile and minify for production

```sh
pnpm build
```

### Compile for a local deployment (points at the local server)

```sh
pnpm build:dev
pnpm preview
```

## Recommended IDE Setup

[VSCode](https://code.visualstudio.com/) + [Volar](https://marketplace.visualstudio.com/items?itemName=Vue.volar) (and disable Vetur).

## Customize configuration

See [Vite Configuration Reference](https://vite.dev/config/).
