<h1>
    <a href="https://betterbash.cz0.cz">
    <img src="webpage/frontend/public/banner.png">
    </a>
</h1>
  
  
# :point_right: Visit [betterbash.cz0.cz](https://betterbash.cz0.cz) for WebUI configurator! :point_left:

## :sparkles: Features
- :zap: Simple installation without dependencies or additional fonts.
- :performing_arts: Username (highlighted if root) and hostname.
- :art: Unique host avatar based on hostname. Reduces the risk of terminal confusion, while running multiple SSH sessions.
- :1234: Shows number of background processes if more than zero.
- :straight_ruler: Line separating commands output.
- :arrow_down: Shows exit code if other than zero.
- :clock4: Date and time. Time changes color if exit code other than zero.
- :file_folder: Current directory.
- :traffic_light: Git status (if current directory inside git repository).
- :scroll: Rapid history search with up/down arrows based on current input.
- :lock: No service behind it: the prompt, the installer and the theme decoder are shell scripts, and the configurator is a static page.

## Preview
<p align="center">
    <a href="https://betterbash.cz0.cz">
    <img src="./screenshot.png">
    </a>
</p>

### :star: Give a Star! 

Support this project by **giving it a star**. Thanks!

## :rocket: Install:
Every command does the same three things: **fetch** the BetterBash tree, **ask**
whether to go on (answer `y`, or `n` and nothing at all happened beyond a
directory in `/tmp`), then **install** from what was fetched. Nothing is piped
into a shell, so the fetched scripts can be read before they are run.

The eight characters of the theme are `vN-y_5uA`: one code, one colour scheme,
and the word `rand` draws a random theme on the machine that runs the command and
keeps it there. Configure it at [betterbash.cz0.cz](https://betterbash.cz0.cz),
which prints these commands for what you picked - including the tag of the
release it points at, which is worth knowing when you update.

with **git**
```
git clone -q --depth 1 --branch 0.1.3 https://github.com/czoczo/BetterBash /tmp/bb && read -p"install BetterBash from /tmp/bb? [y/N] " -n1 && [[ $REPLY == [Yy] ]] && sh /tmp/bb/installbb.sh vN-y_5uA && . ~/.bashrc
```
with **curl**
```
curl -sL https://betterbash.cz0.cz/bb.tgz | tar -C /tmp -xz && read -p"install BetterBash from /tmp/bb? [y/N] " -n1 && [[ $REPLY == [Yy] ]] && sh /tmp/bb/installbb.sh vN-y_5uA && . ~/.bashrc
```
with **wget**
```
wget -q -O - https://betterbash.cz0.cz/bb.tgz | tar -C /tmp -xz && read -p"install BetterBash from /tmp/bb? [y/N] " -n1 && [[ $REPLY == [Yy] ]] && sh /tmp/bb/installbb.sh vN-y_5uA && . ~/.bashrc
```
with **openssl** (needs no git, curl or wget)
```
printf 'GET /bb.tgz HTTP/1.1\r\nHost: betterbash.cz0.cz\r\nConnection: close\r\n\r\n' \
| openssl s_client -quiet -connect betterbash.cz0.cz:443 -servername betterbash.cz0.cz 2>/dev/null \
| sed '1,/^\r$/d' | tar -C /tmp -xz && read -p"install BetterBash from /tmp/bb? [y/N] " -n1 && [[ $REPLY == [Yy] ]] && sh /tmp/bb/installbb.sh vN-y_5uA && . ~/.bashrc
```
The question is written for bash (`[[ ]]`); for a script or a container, tick
**Auto** on the page and the command answers itself by running
`installbb.sh --yes`.

`bb.tgz` unpacks a directory named `bb`, so `/tmp` is where it lands and `/tmp/bb`
is what you say yes to. `/tmp` is shared with every other user of the machine, so
`installbb.sh` refuses to copy a tree that anyone but you can write, and it copies
only the files it knows instead of the whole tree.

## :wrench: Uninstall:
The uninstaller is installed with the prompt, so removing needs no theme code and
nothing is fetched either:
```
sh ~/.bb/removebb.sh
```
A bash session needs a restart for it to take effect. If you would rather fetch
the tree again (or never installed), the page prints uninstall commands for all
four methods, which fetch the tree into `/tmp/bb` and ask the same question about
removing.

## :microscope: Development

Everything BetterBash needs is in this repository, and nothing runs a server:

| Path | What it is |
|---|---|
| `prompt/bb.sh` | the prompt itself (bash) |
| `prompt/bb-theme.sh` | theme library: validates a code, decodes it to the nine prompt colours, draws a random one (`sh`, POSIX) |
| `prompt/git-prompt.sh` | vendored [git-prompt](https://github.com/git/git/blob/master/contrib/prompt/git-prompt.sh) |
| `installbb.sh` | installer: copies the prompt out of a fetched tree into `~/.bb` (`sh`, POSIX) |
| `removebb.sh` | uninstaller, installed with the prompt so removing needs no fetch (`sh`, POSIX) |
| `getbb.sh` | installer of the legacy path, downloading one file at a time (`sh`, POSIX) |
| `.inputrc` | readline bindings for history search on the arrow keys |
| `webpage/frontend` | the configurator page (Vue, built statically) |

The Pages workflow builds the page and stages `bb.tgz` next to it, so
`https://betterbash.cz0.cz/bb.tgz` holds exactly `prompt/`, `installbb.sh`,
`removebb.sh`, `VERSION_APP.txt` and `.inputrc`, and the page fetches from its own
origin. That is what makes both domains of the deployment - `betterbash.cz0.cz`
and `bb.cz0.cz` - install from themselves. The same files are staged loose as
well, which is what the legacy `getbb.sh` path downloads.

A theme code is an argument of the installer, never part of a URL, and it is
decoded by `prompt/bb-theme.sh` on the target machine. `tests/golden/` pins the
colours of every code that has ever been handed out, so decoding cannot drift.

### Run the WebUI and the downloaded files locally
```
./dev.sh                     # WebUI on :5173, HTTPS file server on :8443
./dev.sh --help              # ports, interfaces, alternative checkout, files only
```
`./dev.sh` stages `bb.tgz` (and the loose files of the legacy path: `getbb.sh`,
`removebb.sh`, `.inputrc`, `prompt/`) into `webpage/frontend/public/` (generated,
not in version control), so the dev server serves them and the fetch commands on
the page point at the dev server. Only the openssl method, which insists on TLS,
gets the second listener with a self-signed certificate under `.dev/`. The git tab
would otherwise clone a tag that does not exist yet, so locally it points at the
origin and branch of this checkout. Restart `./dev.sh` after editing the shell
scripts, or restage them with `./tests/stage-downloads.sh webpage/frontend/public`.

The WebUI dev server listens on **`0.0.0.0`** (`--site-host`), so a browser on
another machine can open `http://<this machine>:5173` and install from it - the
commands it prints fetch from that address, because they follow the origin the page
was loaded from.

### Try the installation commands
```
./test-install.sh            # all four fetch commands of the page, run as printed
                             # into throwaway HOMEs, then reports every check
./test-install.sh --live https://betterbash.cz0.cz   # against a deployment
```
It stages the working copy into `bb.tgz`, serves it over HTTP and HTTPS on free
ports, and turns the package into a local git repository tagged like a release, so
even the git command needs no network. What it checks, among others: the installed
files and the decoded theme and the `PS1` the prompt builds; that answering `n`, or
having no terminal, installs nothing; that openssl delivers the package byte for
byte (the legacy text pipeline used to eat four bytes of it); that
`installbb.sh` refuses a planted, incomplete or faked tree; the installer under
`sh`, `bash` and `dash`; and the theme rules of a reinstall.

### Tests
```
./tests/test-theme.sh        # decoder against the golden fixtures, under dash and bash
./test-install.sh            # the fetch commands of the page, see above
./tests/test-legacy-pipe.sh  # the legacy getbb.sh path, while it is served
./tests/test-shellcheck.sh   # shellcheck over every script, in its own dialect
```

### WebUI options

What the commands are built from lives in `webpage/frontend/src/config.js` and its
`.env.production` / `.env.development`: `VITE_BB_INSTALL_BASE_URL` (where `bb.tgz`
is fetched from; empty means *the origin that served this page*, which is what
production does), `VITE_BB_TLS_BASE_URL` (the openssl request), `VITE_BB_REPO_URL`
and `VITE_BB_RELEASE_REF` (the git command, pinned to the tag in
`VERSION_APP.txt`). A non-production build marks itself with a badge next to the
banner, because its commands point at the local server.

### Hosting

`.github/workflows/pages_deploy.yaml` builds the page, stages `bb.tgz` and the
loose files next to it, deploys to GitHub Pages, then waits for the new artifact
and installs from it (`--live` runs of both install paths). The domains answer from
there; TLS is the host's job.

Two bridges are still standing and both are meant to go. `getbb.sh` - the old
"download one file at a time, pipe it into a shell" installer - is no longer what
the page prints, but install commands of that shape are in other people's notes, so
it is still served and still tested (`./tests/test-legacy-pipe.sh`); deleting it is
a documentation change plus a removal. The Azure container app that served
`https://bb.cz0.cz/<code>/getbb.sh` answers those older commands for a while,
because a static host cannot rewrite a path - once its traffic drops to zero it can
be deleted together with its registry and its DNS records.

## :bar_chart: Star History

[![Star History Chart](https://api.star-history.com/svg?repos=czoczo/BetterBash&type=Date)](https://www.star-history.com/#czoczo/BetterBash&Date)


## License

GNU General Public License v3.0 or later

See [LICENSE](LICENSE) to see the full text.
