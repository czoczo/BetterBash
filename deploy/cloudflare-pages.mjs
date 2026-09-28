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
// GitHub Pages workflow publishes. Only the host differs, so a second domain
// rehearses a deployment of the very same files.
//
// Setup, once and by hand, because a token is not something to commit:
//
//   * CLOUDFLARE_API_TOKEN - an API token (Cloudflare dashboard, My Profile -> API
//     tokens) granted Account · Cloudflare Pages · Edit. A token scoped to the
//     zone instead of to the account works too: the zone says which account it
//     belongs to. Reading DNS needs Zone · Zone · Read and is only used for
//     reporting, so a token without it reports less and still deploys.
//   * CLOUDFLARE_ACCOUNT_ID - optional, taken from the token or from its zone.
//
// Changing DNS is never done from here: attaching a custom domain makes Cloudflare
// write the record itself, and if that is not allowed for the token it is reported
// as a job for a human who can see the zone's DNS.
//
// The GitHub secrets of the workflow carry the same two values.

import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..');

/** What this deployment is called and where it answers; a preview domain of
 *  another branch is a matter of naming these three, not of another script. */
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

/** One call to the API. `soft` is for everything a token may not be allowed to
 *  see - the DNS of the zone, the Workers of the account - and returns null with
 *  the reason in the returned object, so a report says what it could not see
 *  rather than dying on the first forbidden endpoint. */
async function api(path, { method = 'GET', body, soft = false } = {}) {
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
    if (soft) return { ok: false, error: `${response.status} ${text.slice(0, 120)}` };
    return fail(`${method} ${path} answered ${response.status} and not JSON:\n${text.slice(0, 400)}`);
  }
  if (!parsed.success) {
    const problems = (parsed.errors || []).map((e) => `${e.code ?? '-'} ${e.message}`).join('; ');
    if (soft) return { ok: false, error: `${response.status}: ${problems || text.slice(0, 160)}` };
    return fail(`${method} ${path} failed (${response.status}): ${problems || text.slice(0, 200)}`);
  }
  // The list endpoints page, and a missed page is a conflict that goes unnoticed,
  // so every page is asked for until one comes back short.
  let results = parsed.result;
  if (Array.isArray(results) && parsed.result_info?.page && parsed.result_info.total_pages > 1) {
    for (let page = 2; page <= parsed.result_info.total_pages; page += 1) {
      const sep = path.includes('?') ? '&' : '?';
      const next = await api(`${path}${sep}page=${page}`, { method, soft });
      if (!next?.ok && next?.result === undefined) return next ?? { ok: false, error: 'no page' };
      results = results.concat(next.result);
    }
  }
  return { ok: true, result: results, info: parsed.result_info };
}

const list = async (path, { soft = false } = {}) => {
  const answer = await api(path, { soft });
  if (!answer) return null;
  if (!answer.ok) return { denied: answer.error };
  return { items: answer.result ?? [] };
};

const described = (what, seen) => (seen?.denied ? `${what}: the token cannot read it (${seen.denied})` : null);

/** The zone that answers this host: the longest suffix of it Cloudflare knows, since
 *  dev.bb.cz0.cz is served by the cz0.cz zone and not by a zone of its own. */
async function findZone() {
  const labels = HOST.split('.');
  const candidates = labels.slice(1).map((_, i) => labels.slice(i).join('.')).filter((z) => z !== HOST);
  for (const name of candidates) {
    const found = await api(`/zones?name=${encodeURIComponent(name)}`, { soft: true });
    if (found?.ok && found.result.length) return found.result[0];
  }
  return null;
}

/** The account to work in. A token scoped to a zone rather than to an account lists
 *  no accounts at all - the zone itself says which one it belongs to, and that is
 *  the one whose Pages the deployment lives under. */
async function context() {
  const zone = await findZone();
  const listed = await api('/accounts', { soft: true });
  const accounts = listed?.ok ? listed.result : [];
  const named = process.env.CLOUDFLARE_ACCOUNT_ID || process.env.CF_ACCOUNT_ID || '';
  if (named) {
    if (accounts.length && !accounts.some((a) => a.id === named)) {
      fail(`${named} is not an account this token can use (${accounts.map((a) => `${a.name} ${a.id}`).join(', ')})`);
    }
    return { account: named, accounts, zone };
  }
  if (accounts.length === 1) return { account: accounts[0].id, accounts, zone };
  if (accounts.length) {
    fail(`more than one account, name one with CLOUDFLARE_ACCOUNT_ID: ${accounts.map((a) => `${a.name} ${a.id}`).join(', ')}`);
  }
  if (!zone?.account?.id) fail(`this token sees neither an account nor the zone of ${HOST}`);
  console.log(`(the token is scoped to a zone; working in the account it belongs to, ${zone.account.id})`);
  return { account: zone.account.id, accounts, zone };
}

const pagesProjects = async (account) => list(`/accounts/${account}/pages/projects`);
/** The custom domains of a project. Every one of them carries a status: attaching a
 *  domain is not the same as serving it, and Cloudflare only serves it once the
 *  domain is verified, so `initializing` means "wait or look at the DNS". */
const customDomains = async (account, name) =>
  list(`/accounts/${account}/pages/projects/${name}/domains`, { soft: true });
const workerScripts = async (account) => list(`/accounts/${account}/workers/scripts?per_page=100`, { soft: true });
const dnsRecords = async (zone) => list(`/zones/${zone.id}/dns_records?per_page=100`, { soft: true });
const workerRoutes = async (zone) => list(`/zones/${zone.id}/routes?per_page=100`, { soft: true });

/** One custom domain, named the way a terminal reads it: what it is, and whether
 *  Cloudflare has verified it yet. */
const describeDomain = (domain) =>
  `${domain.name}${domain.status && domain.status !== 'active' ? ` (${domain.status})` : ''}`;

/** A Worker route answers a host when its pattern is that host, or a wildcard
 *  whose suffix it is; `*` alone answers everything, which is worth naming. */
function routeAnswers(route, host) {
  const pattern = route.pattern.replace(/^https?:\/\//, '');
  const base = pattern.replace(/\/\*$/, '');
  if (base === '*') return true;
  if (!pattern.endsWith('/*') && base !== host) return false;
  return base === host || (base.startsWith('*.') && host.endsWith(`.${base.slice(2)}`));
}

/** Everything about this host as it stands: which projects exist, which of them
 *  claim the host, what the zone has for it, and what the token was not allowed to
 *  see on the way. */
async function survey() {
  const { account, accounts, zone } = await context();
  const blind = [];
  const projects = await pagesProjects(account);
  if (projects?.denied) blind.push(`Pages projects (${projects.denied})`);

  const byProject = new Map();
  for (const project of projects?.items ?? []) {
    const domains = await customDomains(account, project.name);
    if (domains?.denied) blind.push(`custom domains of ${project.name}`);
    byProject.set(project.name, domains?.items ?? []);
  }

  let records = null;
  let routes = null;
  if (zone) {
    records = await dnsRecords(zone);
    if (records?.denied) blind.push(`DNS records of ${zone.name}`);
    routes = await workerRoutes(zone);
    if (routes?.denied) blind.push(`Worker routes of ${zone.name}`);
  }

  const claimed = [];
  for (const [name, domains] of byProject) {
    if (domains.some((d) => d.name === HOST)) claimed.push(`Pages project ${name}`);
  }
  for (const route of (routes?.items ?? []).filter((r) => routeAnswers(r, HOST))) {
    claimed.push(`Worker route ${route.pattern}${route.script ? ` of script ${route.script}` : ''}`);
  }

  return {
    account,
    accounts,
    zone,
    projects: projects?.items ?? [],
    byProject,
    mine: (projects?.items ?? []).find((p) => p.name === PROJECT) ?? null,
    records: (records?.items ?? []).filter((r) => r.name === HOST),
    claimed,
    blind,
  };
}

async function check() {
  const seen = await survey();
  console.log(`account  ${seen.accounts.length
    ? seen.accounts.map((a) => `${a.name} (${a.id})`).join(', ')
    : `${seen.account} (taken from the zone)`}`);
  console.log(`zone     ${seen.zone ? `${seen.zone.name} (${seen.zone.id})` : `no zone answers ${HOST}`}`);
  console.log(`pages    ${seen.projects.length
    ? seen.projects.map((p) => `${p.name} [${p.production_branch}]`).join(', ')
    : 'none'}`);
  for (const [name, domains] of seen.byProject) {
    if (domains.length) console.log(`domains  ${name}: ${domains.map(describeDomain).join(', ')}`);
  }
  const dnsBlind = seen.blind.some((why) => why.startsWith('DNS records'));
  console.log(`dns      ${seen.records.length
    ? seen.records.map((r) => `${r.type} ${r.content}${r.proxied ? ' (proxied)' : ''}`).join(', ')
    : dnsBlind ? 'the token cannot read it' : `nothing of ${seen.zone?.name ?? 'the zone'} for this host`}`);
  console.log(`claimed  ${seen.claimed.length ? seen.claimed.join(' + ') : 'nothing'}`);
  for (const why of seen.blind) console.log(`blind    ${why}`);
  const ours = seen.mine && (seen.byProject.get(PROJECT) ?? []).some((d) => d.name === HOST);
  console.log(`${ours ? 'ready' : 'not ready'}: https://${HOST} as Pages project ${PROJECT} [${BRANCH}]`);
  return seen;
}

async function ensure() {
  const seen = await survey();
  if (!seen.zone) fail(`no zone answers ${HOST}, so its custom domain cannot be created`);

  if (!seen.mine) {
    console.log(`creating Pages project ${PROJECT} (production branch ${BRANCH})`);
    await api(`/accounts/${seen.account}/pages/projects`, {
      method: 'POST',
      body: { name: PROJECT, production_branch: BRANCH },
    });
  } else if (seen.mine.production_branch !== BRANCH) {
    console.log(`setting the production branch of ${PROJECT} to ${BRANCH}`);
    await api(`/accounts/${seen.account}/pages/projects/${PROJECT}`, {
      method: 'PATCH',
      body: { production_branch: BRANCH },
    });
  }

  // A hostname two things answer is a hostname neither serves, so a route of a
  // Worker is reported rather than removed: what lives behind it is somebody's
  // decision, not this script's.
  const rivals = seen.claimed.filter((c) => !c.startsWith(`Pages project ${PROJECT}`));
  if (rivals.length) {
    console.error(`cloudflare-pages: ${HOST} is answered by:`);
    for (const rival of rivals) console.error(`  ${rival}`);
    console.error('free it in the Cloudflare dashboard (Workers & Pages -> Dev URLs / Routes) and run this again.');
    process.exitCode = 1;
    return;
  }

  const domains = await customDomains(seen.account, PROJECT);
  if (!domains?.items?.some((d) => d.name === HOST)) {
    console.log(`attaching ${HOST} to ${PROJECT}`);
    const attached = await api(`/accounts/${seen.account}/pages/projects/${PROJECT}/domains`, {
      method: 'POST',
      body: { name: HOST },
      soft: true,
    });
    if (!attached?.ok) {
      // The usual reason is a token that may not touch the DNS of the zone: the
      // domain has to be attached by hand, or by a token that can.
      fail(`attaching ${HOST} failed (${attached?.error}); a token needs Cloudflare Pages · Edit and the DNS of ${seen.zone.name} written by its owner`);
    }
  }

  // Attaching a domain of a zone this account owns brings its DNS record with it;
  // anything else would leave a hostname that answers with the wrong thing, so
  // say what the record is afterwards either way.
  const after = await survey();
  console.log(`dns      ${after.records.length
    ? after.records.map((r) => `${r.name} ${r.type} ${r.content}${r.proxied ? ' (proxied)' : ''}`).join(', ')
    : after.zone && after.blind.length ? `not readable with this token (${after.blind.join(', ')})`
      : `no record of ${after.zone?.name ?? 'the zone'} for ${HOST} yet`}`);
  for (const rival of after.claimed.filter((c) => !c.startsWith(`Pages project ${PROJECT}`))) {
    console.log(`claimed  ${rival}`);
  }
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
    console.log(`CLOUDFLARE_ACCOUNT_ID=${account}`);
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
  fail('CLOUDFLARE_API_TOKEN is not set (a token granted Account · Cloudflare Pages · Edit)');
}

const command = process.argv[2];
const commands = { check, ensure, deploy };
if (!(command in commands)) {
  console.error(`usage: node deploy/cloudflare-pages.mjs ${Object.keys(commands).join('|')}`);
  process.exit(2);
}
await commands[command]();
