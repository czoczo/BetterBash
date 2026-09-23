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
The eight characters after `-- curl` are the theme: `vN-y_5uA` is one colour
scheme, another code is another scheme, and the word `rand` draws a random theme
on the machine that runs the command and keeps it there. Configure the code at
[betterbash.cz0.cz](https://betterbash.cz0.cz), which shows exactly the command
for what you picked.

with **curl**
```
curl -sL https://betterbash.cz0.cz/getbb.sh | bash -s -- curl vN-y_5uA && . ~/.bashrc
```
with **wget**
```
wget -q -O - https://betterbash.cz0.cz/getbb.sh | bash -s -- wget vN-y_5uA && . ~/.bashrc
```
with **openssl** (no dependencies needed)
```
echo -e "GET /getbb.sh HTTP/1.1\r\nHost: betterbash.cz0.cz\r\nConnection: close\r\n\r\n" \
| openssl s_client -quiet -connect betterbash.cz0.cz:443 -servername betterbash.cz0.cz 2>/dev/null \
| sed '1,/^\r$/d' | sed 's/\r$//' | bash -s -- openssl vN-y_5uA && . ~/.bashrc
```
## :wrench: Uninstall:
bash session needs a restart in order to uninstall to take effect. Colours are
not the uninstaller's business, so it takes no theme code.

with **curl**
```
curl -sL https://betterbash.cz0.cz/removebb.sh | bash -s -- curl && . ~/.bashrc
```
with **wget**
```
wget -q -O - https://betterbash.cz0.cz/removebb.sh | bash -s -- wget && . ~/.bashrc
```
with **openssl** (no dependencies needed)
```
echo -e "GET /removebb.sh HTTP/1.1\r\nHost: betterbash.cz0.cz\r\nConnection: close\r\n\r\n" \
| openssl s_client -quiet -connect betterbash.cz0.cz:443 -servername betterbash.cz0.cz 2>/dev/null \
| sed '1,/^\r$/d' | sed 's/\r$//' | bash -s -- openssl && . ~/.bashrc
```

## :microscope: Development

Everything BetterBash needs is in this repository, and nothing runs a server:

| Path | What it is |
|---|---|
| `prompt/bb.sh` | the prompt itself (bash) |
| `prompt/bb-theme.sh` | theme library: validates a code, decodes it to the nine prompt colours, draws a random one (`sh`, POSIX) |
| `prompt/git-prompt.sh` | vendored [git-prompt](https://github.com/git/git/blob/master/contrib/prompt/git-prompt.sh) |
| `getbb.sh`, `removebb.sh` | installer and uninstaller a user pipes into a shell (`sh`, POSIX) |
| `.inputrc` | readline bindings for history search on the arrow keys |
| `webpage/frontend` | the configurator page (Vue, built statically) |

The Pages workflow builds the page and stages the installer files next to it, so
`https://betterbash.cz0.cz/getbb.sh`, `/removebb.sh`, `/prompt/bb.sh` and
`/.inputrc` are the files of this repository, and the page downloads from its own
origin. That is what makes both domains of the deployment - `betterbash.cz0.cz`
and `bb.cz0.cz` - install from themselves.

A theme code is an argument of the installer, never part of a URL, and it is
decoded by `prompt/bb-theme.sh` on the target machine. `tests/golden/` pins the
colours of every code that has ever been handed out, so decoding cannot drift.

### Run the WebUI and the downloaded files locally
```
./dev.sh                     # WebUI on :5173, HTTPS file server on :8443
./dev.sh --help              # ports, interfaces, alternative checkout, files only
```
`./dev.sh` stages `getbb.sh`, `removebb.sh`, `.inputrc` and `prompt/` into
`webpage/frontend/public/` (generated, not in version control), so the dev server
serves them and the curl and wget commands on the page point at the dev server.
Only the openssl method, which insists on TLS, gets the second listener with a
self-signed certificate under `.dev/`. Restart `./dev.sh` after editing the shell
scripts, or restage them with `./tests/stage-downloads.sh webpage/frontend/public`.

The WebUI dev server listens on **`0.0.0.0`** (`--site-host`), so a browser on
another machine can open `http://<this machine>:5173` and install from it. A page
that is not the canonical origin says in its commands where the rest of the files
come from (`BB_BASE_URL=... bash -s -- ...`), which is also what makes a local
checkout install its own files rather than the released ones.

### Try every installation method
```
./test-install-methods.sh    # installs and uninstalls with curl, wget and openssl
                             # into throwaway HOMEs, then reports every check
./test-install-methods.sh --live https://betterbash.cz0.cz   # against a deployment
```
It stages the working copy, serves it over HTTP and HTTPS on free ports, and runs
each method under `sh`, `bash` and `dash`. Every method is verified end to end:
download of the prompt scripts, the decoded theme, `.inputrc`, the `~/.bashrc`
hook, a `PS1` built by the installed prompt, the commands exactly as the page
prints them, and the clean uninstall.

### Tests
```
./tests/test-theme.sh        # decoder against the golden fixtures, under dash and bash
./test-install-methods.sh    # installation methods, see above
./tests/test-shellcheck.sh   # shellcheck over every script, in its own dialect
```

### WebUI options

Endpoints come from `webpage/frontend/.env.production` and `.env.development`
(`VITE_BB_INSTALL_BASE_URL`, `VITE_BB_TLS_BASE_URL`), read in
`webpage/frontend/src/config.js`. Empty means *download from the origin that
served this page*, which is what production does. A non-production build marks
itself with a badge next to the banner, because its commands point at the local
server.

### Hosting

`.github/workflows/pages_deploy.yaml` builds the page, stages the installer files
and deploys both to GitHub Pages, then waits for the new artifact and runs the
installation tests against it (`--live`). The domains answer from there; TLS is
the host's job. The Azure container app that used to serve
`https://bb.cz0.cz/<code>/getbb.sh` keeps answering those older commands for a
while, because a static host cannot rewrite a path - once its traffic drops to
zero it can be deleted together with its registry and its DNS records.

## :bar_chart: Star History

[![Star History Chart](https://api.star-history.com/svg?repos=czoczo/BetterBash&type=Date)](https://www.star-history.com/#czoczo/BetterBash&Date)


## License

GNU General Public License v3.0 or later

See [LICENSE](LICENSE) to see the full text.
