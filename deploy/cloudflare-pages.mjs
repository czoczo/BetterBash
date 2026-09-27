#!/usr/bin/env node
//
// The Cloudflare Pages deployment of the develop branch:
// https://dev.bb.cz0.cz.
//
//   CLOUDFLARE_API_TOKEN=... node deploy/cloudflare-pages.mjs check
//   CLOUDFLARE_API_TOKEN=... node deploy/cloudflare-pages.mjs ensure
//   CLOUDFLARE_API_TOKEN=... node deploy/cloudflare-pages.mjs deploy
//
// `check` prints what the Cloudflare account holds for this host today: the Pages
// projects and their custom domains, the DNS records of the zone, and the Worker
// routes - a host that already answers something else has to be freed before Pages
// can take it. `ensure` creates what is missing (the project, its production branch,
// its custom domain) and is safe to run twice, which is why the deploy workflow runs
// it before every upload. `deploy` uploads the built WebUI with wrangler.
//
// Nothing here is built: the artifact is webpage/frontend/dist, the page with the
// installer files tests/stage-downloads.sh stages next to it - the same artifact the
// GitHub Pages workflow publishes. Only the host differs, so a domain of Cloudflare
// rehearses a deployment of the very same files.
//
// Setup, once and by hand, because a token is not something to commit:
//
//   * CLOUDFLARE_API_TOKEN - an API token (see the Cloudflare dashboard, My Profile
//     -> API tokens) granted Pages:Edit, Zone:Zone:Read and Zone:DNS:Edit.
//   * CLOUDFLARE_ACCOUNT_ID - the account holding the cz0.cz zone; taken from the
//     token when it is not given, so only the token is really needed.
//
// The GitHub secrets of the workflow carry the same two values.

import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..');

/** What this deployment is called and where it answers; a second preview domain
 *  of another branch is a matter of naming these three, not of another script. */
const HOST = process.env.BB_PAGES_HOST || 'dev.bb.cz0.cz';
const PROJECT = process.env.BB_PAGES_PROJECT || 'betterbash-dev';
const BRANCH = process.env.BB_PAGES_BRANCH || 'develop';
const DIST = process.env.BB_PAGES_DIST || join(repoRoot, 'webpage', 'frontend', 'dist');

const API = 'https://api.cloudflare.com/client/v4';
const TOKEN = process.env.CLOUDFLARE_API_TOKEN || process.env.CF_API_TOKEN || '';

const fail = (message) => {
  console.error(`cloudflare-pages: ${message}`);
  process.exit(1);
};

async function api(path, { method = 'GET', body, account } = {}) {
  const response = await fetch(`${API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    fail(`${method} ${path} answered ${response.status} and not JSON:\n${text.slice(0, 400)}`);
  }
  if (!parsed.success) {
    const problems = (parsed.errors || [])
      .map((e) => `${e.code ?? '-'} ${e.message}`)
      .join('; ');
    fail(`${method} ${path} failed (${response.status}): ${problems || text.slice(0, 200)}`);
  }
  // The list endpoints page, and a missed page is a conflict that goes unnoticed,
  // so every page is asked for until one comes back short.
  if (Array.isArray(parsed.result) && parsed.result_info?.page && parsed.result_info.total_pages > 1) {
    const rest = [];
    for (let page = 2; page <= parsed.result_info.total_pages; page += 1) {
      const sep = path.includes('?') ? '&' : '?';
      const next = await api(`${path}${sep}page=${page}`, { method });
      rest.push(...(Array.isArray(next.result) ? next.result : []));
    }
    return { ...parsed, result: [...parsed.result, ...rest] };
  }
  return parsed;
}

/** The two numbers a token alone does not give: which account to work in, and
 *  which zone answers this host. */
async function context() {
  const accounts = (await api('/accounts')).result;
  if (!accounts.length) fail('this token can see no Cloudflare account');
  const account = process.env.CLOUDFLARE_ACCOUNT_ID || process.env.CF_ACCOUNT_ID || '';
  if (account && !accounts.some((a) => a.id === account)) {
    fail(`${account} is not an account this token can use (${accounts.map((a) => `${a.name} ${a.id}`).join(', ')})`);
  }
  const chosen = account || (accounts.length === 1 ? accounts[0].id
    : fail(`more than one account, name one: ${accounts.map((a) => `${a.name} ${a.id}`).join(', ')}`));

  // The zone of a host is the longest suffix of it the account owns: dev.bb.cz0.cz
  // is served by the cz0.cz zone, not by a zone of its own.
  const labels = HOST.split('.');
  const candidates = labels.slice(1).map((_, i) => labels.slice(i).join('.')).filter((z) => z !== HOST);
  let zone = null;
  for (const name of candidates) {
    const found = (await api(`/zones?name=${encodeURIComponent(name)}`)).result;
    if (found.length) {
      zone = found[0];
      break;
    }
  }
  return { account: chosen, accounts, zone };
}

const pagesProjects = (account) => api(`/accounts/${account}/pages/projects`).then((r) => r.result);
const customDomains = (account, name) =>
  api(`/accounts/${account}/pages/projects/${name}/custom-domains`).then((r) => r.result);
const workerScripts = (account) => api(`/accounts/${account}/workers/scripts?per_page=100`).then((r) => r.result);
const dnsRecords = (zone) => api(`/zones/${zone.id}/dns_records?per_page=100`).then((r) => r.result);
const workerRoutes = (zone) => api(`/zones/${zone.id}/routes?per_page=100`).then((r) => r.result);

/** A Worker route answers a host when its pattern is that host, or a wildcard
 *  whose suffix it is; `*` alone answers everything, which is worth naming. */
function routeAnswers(route, host) {
  const pattern = route.pattern.replace(/^https?:\/\//, '');
  const base = pattern.replace(/\/\*$/, '');
  if (base === '*') return true;
  if (!pattern.endsWith('/*') && base !== host) return false;
  return base === host || (base.startsWith('*.') && host.endsWith(`.${base.slice(2)}`));
}

async function check({ quiet = false } = {}) {
  const { account, accounts, zone } = await context();
  const report = console; // the report goes to the terminal in `check`, nowhere in `ensure`
  if (!quiet) {
    report.log(`account  ${accounts.map((a) => `${a.name} (${a.id})`).join(', ')}`);
    report.log(`zone     ${zone ? `${zone.name} (${zone.id})` : `no zone of the account owns ${HOST}`}`);
  }

  const projects = await pagesProjects(account);
  const mine = projects.find((p) => p.name === PROJECT);
  if (!quiet) {
    report.log(`pages    ${projects.length ? projects.map((p) => `${p.name} [${p.production_branch}]`).join(', ') : 'none'}`);
    for (const project of projects) {
      const domains = await customDomains(account, project.name);
      if (domains.length) report.log(`domains  ${project.name}: ${domains.map((d) => d.id).join(', ')}`);
    }
  }

  const claimed = [];
  for (const project of projects) {
    const domains = await customDomains(account, project.name);
    if (domains.some((d) => d.id === HOST)) claimed.push(`Pages project ${project.name}`);
  }
  if (zone) {
    const records = (await dnsRecords(zone)).filter((r) => r.name === HOST);
    if (records.length && !quiet) {
      report.log(`dns      ${records.map((r) => `${r.type} ${r.content}${r.proxied ? ' (proxied)' : ''}`).join(', ')}`);
    }
    const routes = (await workerRoutes(zone)).filter((r) => routeAnswers(r, HOST));
    const workers = routes.length ? await workerScripts(account) : [];
    for (const route of routes) {
      const script = route.script || workers.find((w) => route.pattern.includes(w.id))?.id || 'unknown';
      claimed.push(`Worker route ${route.pattern} of script ${script || 'unknown'}`);
      if (!quiet) report.log(`worker   route ${route.pattern} -> script ${script || 'unknown'}`);
    }
  }

  if (quiet) return { account, zone, projects, mine, claimed };
  const ours = mine && (await customDomains(account, PROJECT)).some((d) => d.id === HOST)
    && mine.production_branch === BRANCH;
  report.log(`${ours ? 'ready' : 'not ready'}: https://${HOST} as project ${PROJECT} [${BRANCH}]`);
  return { account, zone, projects, mine, claimed };
}

async function ensure() {
  const { account, zone, mine } = await check({ quiet: true });

  if (!zone) fail(`no zone of this account owns ${HOST}, so its custom domain cannot be created`);

  if (!mine) {
    console.log(`creating Pages project ${PROJECT} (production branch ${BRANCH})`);
    await api(`/accounts/${account}/pages/projects`, {
      method: 'POST',
      body: { name: PROJECT, production_branch: BRANCH },
    });
  } else if (mine.production_branch !== BRANCH) {
    console.log(`setting the production branch of ${PROJECT} to ${BRANCH}`);
    await api(`/accounts/${account}/pages/projects/${PROJECT}`, {
      method: 'PATCH',
      body: { production_branch: BRANCH },
    });
  }

  // A hostname two things answer is a hostname neither serves, so a route of a
  // Worker is reported rather than removed: what lives behind it is somebody's
  // decision, not this script's.
  const { claimed } = await check({ quiet: true });
  if (claimed.filter((c) => !c.startsWith(`Pages project ${PROJECT}`)).length) {
    console.error(`cloudflare-pages: ${HOST} is answered by:`);
    for (const claim of claimed) console.error(`  ${claim}`);
    console.error(`free it (Cloudflare dashboard, or the Workers route above) and run this again.`);
    process.exitCode = 1;
    return;
  }

  const domains = await customDomains(account, PROJECT);
  if (!domains.some((d) => d.id === HOST)) {
    console.log(`attaching ${HOST} to ${PROJECT}`);
    await api(`/accounts/${account}/pages/projects/${PROJECT}/custom-domains`, {
      method: 'POST',
      body: { name: HOST },
    });
  }

  // Attaching a domain of a zone this account owns brings its DNS record with it;
  // anything else would leave a hostname that answers with the wrong thing, so
  // say what the record is afterwards either way.
  const records = (await dnsRecords(zone)).filter((r) => r.name === HOST);
  console.log(`dns: ${records.length
    ? records.map((r) => `${r.name} ${r.type} ${r.content}${r.proxied ? ' (proxied)' : ''}`).join(', ')
    : `no record of ${zone.name} for ${HOST} (Cloudflare creates it with the domain)`}`);
  console.log(`https://${HOST} belongs to Pages project ${PROJECT} [${BRANCH}]`);
}

async function deploy() {
  if (!existsSync(DIST)) {
    fail(`nothing built at ${DIST} (pnpm build --base=/ and ./tests/stage-downloads.sh ${DIST})`);
  }
  // wrangler wants an account of its own, and an API token without a name next to
  // it does not say which one that is.
  if (!process.env.CLOUDFLARE_ACCOUNT_ID && !process.env.CF_ACCOUNT_ID) {
    const { account } = await context();
    process.env.CLOUDFLARE_ACCOUNT_ID = account;
  }
  const args = [
    '--yes', 'wrangler@latest', 'pages', 'deploy', DIST,
    `--project-name=${PROJECT}`,
    `--branch=${BRANCH}`,
  ];
  console.log(`npx ${args.join(' ')}`);
  const result = spawnSync('npx', args, { cwd: repoRoot, stdio: 'inherit', env: process.env });
  process.exit(result.status ?? 1);
}

if (!TOKEN) {
  fail('CLOUDFLARE_API_TOKEN is not set (a token granted Pages:Edit and Zone:DNS:Edit)');
}

const command = process.argv[2];
const commands = { check, ensure, deploy };
if (!(command in commands)) {
  console.error(`usage: node deploy/cloudflare-pages.mjs ${Object.keys(commands).join('|')}`);
  process.exit(2);
}
await commands[command]();
