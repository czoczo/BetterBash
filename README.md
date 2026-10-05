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
- :white_check_mark: Every element of the first line - username, hostname, terminal, avatar, background jobs, exit code, duration, date, clock - is optional; the theme code says which ones stand.
- :1234: Shows number of background processes if more than zero.
- :straight_ruler: Line separating commands output.
- :arrow_down: Shows exit code if other than zero.
- :clock4: Date and time. Time changes color if exit code other than zero.
- :stopwatch: Duration of the previous command in seconds, in the primary color whatever that command ended with.
- :file_folder: Current directory.
- :traffic_light: Git status (if current directory inside git repository).
- :scroll: Rapid history search with up/down arrows based on current input.
- :accordion: Alt+c collapses the prompt to the line you type on, Alt+c draws the two-line frame back.
- :lock: No service behind it: the prompt, the installer and the theme decoder are shell scripts, the configurator is a static page.

## Preview
<p align="center">
    <a href="https://betterbash.cz0.cz">
    <img src="./screenshot.png">
    </a>
</p>

### :star: Give a Star! 

Support this project by **giving it a star**. Thanks!

## :rocket: Install:
Every command does the same three things: **fetch** the BetterBash tree into `~/.bb`,
**ask** whether to go on (answer `y`, or `n` and nothing happened beyond a directory of
readable files), then **source the prompt of what was fetched**, which installs the tree
and puts it on that very shell. Nothing is piped into a shell, so the fetched scripts can
be read before they are run, and no `. ~/.bashrc` is needed.

`vN-y_5uA` is the theme code. `rand` draws a random theme on the machine that runs the
command, and a new one on every run; `rand:CODE` draws new colours over the elements of
`CODE`; no code at all keeps whatever this machine already wears. Configure it at
[betterbash.cz0.cz](https://betterbash.cz0.cz), which prints these commands for what you
picked - pinned to the release it points at, which is worth knowing when you update.

with **git**
```
git clone -q --depth 1 --branch 0.1.3 https://github.com/czoczo/BetterBash ~/.bb && read -p"$(<~/.bb/q)" -n1 && [[ $REPLY == [Yy] ]] && . ~/.bb/prompt/bb.sh vN-y_5uA
```
with **curl**
```
mkdir -p ~/.bb && curl -sL https://betterbash.cz0.cz/bb.tgz | tar -C ~/.bb -xz && read -p"$(<~/.bb/q)" -n1 && [[ $REPLY == [Yy] ]] && . ~/.bb/prompt/bb.sh vN-y_5uA
```
with **wget**
```
mkdir -p ~/.bb && wget -q -O - https://betterbash.cz0.cz/bb.tgz | tar -C ~/.bb -xz && read -p"$(<~/.bb/q)" -n1 && [[ $REPLY == [Yy] ]] && . ~/.bb/prompt/bb.sh vN-y_5uA
```
with **openssl** (needs no git, curl or wget)
```
mkdir -p ~/.bb && printf 'GET /bb.tgz HTTP/1.1\r\nHost: betterbash.cz0.cz\r\nConnection: close\r\n\r\n' \
| openssl s_client -quiet -connect betterbash.cz0.cz:443 -servername betterbash.cz0.cz 2>/dev/null \
| sed '1,/^\r$/d' | tar -C ~/.bb -xz && read -p"$(<~/.bb/q)" -n1 && [[ $REPLY == [Yy] ]] && . ~/.bb/prompt/bb.sh vN-y_5uA
```
The question is written for bash (`[[ ]]`). For a script or a container, tick **Auto** on
the page and the command has no question in it; there, `sh ~/.bb/installbb.sh vN-y_5uA`
installs without sourcing anything, because a script is not the shell that wants the
prompt. The words of the question are not in the command either - they are read out of
`~/.bb/q`, a file of the tree that was just fetched.

Answering `n` leaves the fetched tree where it is, still pending: read it, and run
`. ~/.bb/prompt/bb.sh` later if you decide, or take it away with `rm -rf ~/.bb`. Nothing
in it installs itself at a later shell start - a fetched tree carries an
`install-pending` flag, and only its **first** sourcing installs.

## :wrench: Uninstall:
The uninstaller is installed with the prompt, so removing needs no fetch and no theme
code - the page prints this one command under all four methods:
```
sh ~/.bb/removebb.sh
```
A bash session needs a restart in order to uninstall to take effect.

## :microscope: Development

Everything BetterBash needs is in this repository, and nothing runs a server:

| Path | What it is |
|---|---|
| `prompt/bb.sh` | the prompt itself (bash) |
| `prompt/bb-theme.sh` | theme library: validates a code, decodes it to the prompt colours, draws a random one (`sh`, POSIX) |
| `prompt/git-prompt.sh` | vendored [git-prompt](https://github.com/git/git/blob/master/contrib/prompt/git-prompt.sh) |
| `installbb.sh` | installer: copies the prompt out of a fetched tree into `~/.bb`, the directory the tree was fetched into (`sh`, POSIX) |
| `install-pending` | the flag inside a fetched tree: its first `prompt/bb.sh` sourcing installs it, and this file is what the install takes away |
| `q` | the question an install command asks, read out of the fetched tree |
| `removebb.sh` | uninstaller, installed with the prompt so removing needs no fetch (`sh`, POSIX) |
| `.inputrc` | readline bindings for history search on the arrow keys |
| `webpage/frontend` | the configurator page (Vue, built statically) |

The Pages workflow stages `bb.tgz` next to the built page, so every domain of the
deployment - `betterbash.cz0.cz`, `bb.cz0.cz`, a local dev server - installs from itself.

A theme code is an argument of the installer, never part of a URL, and it is decoded on
the target machine by `prompt/bb-theme.sh` and on the page by
`webpage/frontend/src/theme-code.js` - `tests/test-theme-code.mjs` holds the two to one
reading. Eight characters is the shape of every code handed out so far: the colours and
the avatar bit. Thirteen characters adds the elements of the first line, the order they
stand in, and a bit for the border fill; unused bits are written zero and refused
otherwise, so a later version can take them. `tests/golden/` pins the colours of every
code that has ever been handed out, so decoding cannot drift.

### Run the WebUI and the downloaded files locally
```
./dev.sh                     # WebUI on :5173, HTTPS file server on :8443
./dev.sh --help              # ports, interfaces, alternative checkout, files only
```
`./dev.sh` stages `bb.tgz` into `webpage/frontend/public/`, so the fetch commands of
the page point at the dev server;
only the openssl method, which insists on TLS, gets the second listener. Restart it
after editing the shell scripts, or restage them with
`./tests/stage-downloads.sh webpage/frontend/public`.

### Try the installation commands
```
./test-install.sh            # all four fetch commands of the page, run as printed
                             # into throwaway HOMEs, then reports every check
./test-install.sh --live https://betterbash.cz0.cz   # against a deployment
```
It stages the working copy into `bb.tgz`, serves it over HTTP and HTTPS on free ports,
and turns the package into a local git repository tagged like a release, so even the git
command needs no network.

### Tests
```
./tests/test-theme.sh        # decoder against the golden fixtures, under dash and bash
node tests/test-avatar.mjs   # the host avatar of the page, drawn as the shell draws it
node tests/test-theme-code.mjs # a theme code, spelled alike by the page and the shell
bash tests/test-timer.sh     # the duration of the last command, in an interactive shell too
node tests/test-frame.mjs    # the frame of the prompt and the frame the page previews
bash tests/test-compact.sh   # the one-line prompt Alt+c switches to, key pressed in a pty
node tests/test-accent.mjs   # the colour of the theme that skins the page (BORDCOL)
node tests/test-copy.mjs     # the copy buttons: clipboard API, selection, and neither
./test-install.sh            # the fetch commands of the page, see above
node tests/test-toggle-hints.mjs # what the Random and Auto checkboxes do to a command
./tests/test-shellcheck.sh   # shellcheck over every script, in its own dialect
```

### Hosting

What the commands are built from lives in `webpage/frontend/src/config.js` and its
`.env.production` / `.env.development`: `VITE_BB_INSTALL_BASE_URL` (empty means *the
origin that served this page*, which is what production does), `VITE_BB_TLS_BASE_URL`
(the openssl request), `VITE_BB_REPO_URL` and `VITE_BB_RELEASE_REF` (pinned to the tag in
`VERSION_APP.txt`). A non-production build marks itself with a badge next to the banner.

`.github/workflows/pages_deploy.yaml` builds the page, stages `bb.tgz` next to it,
deploys to GitHub Pages, then waits for the new artifact and installs
from it. `develop` is published the same way on Cloudflare Pages, at
`https://dev.bb.cz0.cz`: the same artifact built the same way, so the domain is a
rehearsal of a production deployment. `deploy/cloudflare-pages.mjs` provisions it
(`check`, `ensure`, `deploy`) and needs the secrets `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID`.

The old "download one file at a time, pipe it into a shell" installer (`getbb.sh`) and
the Azure container app that served `bb.cz0.cz/<code>/getbb.sh` are gone: every install
command the page prints fetches one archive.

## :bar_chart: Star History

[![Star History Chart](https://api.star-history.com/svg?repos=czoczo/BetterBash&type=Date)](https://www.star-history.com/#czoczo/BetterBash&Date)


## License

GNU General Public License v3.0 or later

See [LICENSE](LICENSE) to see the full text.
