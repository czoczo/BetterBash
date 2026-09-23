# BetterBash WebUI

Vue 3 + Vite configurator shown at [betterbash.cz0.cz](https://betterbash.cz0.cz).

## Environments

The endpoints offered in the install commands are not hardcoded in the
components, they come from the env file matching the build mode and are read in
[`src/config.js`](src/config.js):

| | `pnpm build` (default) | `pnpm dev`, `pnpm build:dev` |
|---|---|---|
| env file | `.env.production` | `.env.development` |
| curl / wget fetch | the origin that served the page, `https://betterbash.cz0.cz` in production | `http://localhost:5173` |
| openssl fetch | the same origin over TLS | `https://localhost:8443` |
| git clone | `main` of this project at the tag in `VERSION_APP.txt` | origin and branch of the checkout `./dev.sh` was started in |

The install base is empty in `.env.production` on purpose: the page and the package
it offers are one deployment, so every domain of it offers its own files and no
domain name has to be compiled in. `src/config.js` falls back to the production
origin when it cannot know its own (opened from disk), so a build that forgot to
select a mode cannot publish localhost fetches. A non-production build says so with
a badge next to the banner.

Variables (all prefixed with `VITE_`, see the env files): `VITE_BB_ENV`,
`VITE_BB_INSTALL_BASE_URL`, `VITE_BB_TLS_BASE_URL`, `VITE_BB_REPO_URL`,
`VITE_BB_RELEASE_REF` (injected from `VERSION_APP.txt` by `vite.config.js`),
`VITE_BB_STAGE_DIR` (where the fetched tree lands, `/tmp/bb`; the tests name their
own), `VITE_BB_SITE_PORT`, `VITE_BB_SITE_HOST`, `VITE_BB_SITE_ALLOWED_HOSTS`.

The local endpoints belong to the dev server and the HTTPS file server started by
`./dev.sh` from the repository root (see the
[project README](../../README.md)).

## The files the page offers

`installbb.sh`, `removebb.sh`, `getbb.sh` (legacy), `.inputrc` and `prompt/` live in
the repository root. `tests/stage-downloads.sh` stages them next to the built page
and packs them into `bb.tgz` - the package the fetch commands download, with the
directory `bb` inside so it unpacks where the command says it will. The Pages
workflow stages into `dist`, `pnpm stage` into `public`, where the dev server serves
them from.

The commands of the four tabs are built in `src/config.js`, and
`tests/install-commands.mjs` renders them outside a browser. That is how
`./test-install.sh` manages to run literally what the page shows, against a local
server, a local git repository and a deployment.

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
