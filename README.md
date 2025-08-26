<h1>
    <a href="https://betterbash.cz0.cz">
    <img src="webpage/frontend/public/banner.png">
    </a>
</h1>
  
  
# Visit [https://betterbash.cz0.cz](https://betterbash.cz0.cz) for GUI configurator!
  
## Features
- Username (highlighted if root) and hostname.
- Unique host avatar based on hostname. Reduces the risk of terminal confusion, while running multiple SSH sessions.
- Shows number of background processes if more than zero.
- Line separating commands output.
- Shows exit code if other than zero.
- Date and time. Time changes color if exit code other than zero.
- Current directory.
- Git status (if current directory inside git repository).
- Rapid search history with up/down keyboard arrows.

![alt text](/screenshot.png?raw=true "BetterBash screenshot")

## Install:
with **curl**
```
curl -sL https://bb.cz0.cz/vN-y_5uA/getbb.sh | bash && . ~/.bashrc
```
with **wget**
```
wget -q -O - https://bb.cz0.cz/vN-y_5uA/getbb.sh | bash && . ~/.bashrc
```
with **git**
```
tmpdir=$(mktemp -d /tmp/betterbash.XXXXXX) && \
git clone --depth=1 --filter=blob:none --no-checkout https://github.com/czoczo/BetterBash.git "$tmpdir" 2>/dev/null && \
git -C "$tmpdir" checkout HEAD getbb.sh 2>/dev/null && \
bash "$tmpdir/getbb.sh"
```
with **openssl** (no dependencies needed)
```
echo -e "GET /vN-y_5uA/getbb.sh HTTP/1.1\r\nHost: bbbt-bdewcgb9h5h6dfda.westeurope-01.azurewebsites.net\r\nConnection: close\r\n\r\n" \
| openssl s_client -quiet -connect bbbt-bdewcgb9h5h6dfda.westeurope-01.azurewebsites.net:443 2>/dev/null \
| sed '1,/^\r$/d' | bash && . ~/.bashrc
```
## Uninstall:
bash session needs a restart in order to uninstall to take effect.

with **curl**
```
curl -sL https://bb.cz0.cz/vN-y_5uA/removebb.sh | bash
```
with **wget**
```
wget -q -O - https://bb.cz0.cz/vN-y_5uA/removebb.sh | bash
```
with **git**
```
tmpdir=$(mktemp -d /tmp/betterbash.XXXXXX) && \
git clone --depth=1 --filter=blob:none --no-checkout https://github.com/czoczo/BetterBash.git "$tmpdir" 2>/dev/null && \
git -C "$tmpdir" checkout HEAD getbb.sh 2>/dev/null && \
bash "$tmpdir/removebb.sh"
```
with **openssl** (no dependencies needed)
```
echo -e "GET /vN-y_5uA/removebb.sh HTTP/1.1\r\nHost: bbbt-bdewcgb9h5h6dfda.westeurope-01.azurewebsites.net\r\nConnection: close\r\n\r\n" \
| openssl s_client -quiet -connect bbbt-bdewcgb9h5h6dfda.westeurope-01.azurewebsites.net:443 2>/dev/null \
| sed '1,/^\r$/d' | bash && . ~/.bashrc
```
