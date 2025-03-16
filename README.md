# Better Bash
## screenshot:
![alt text](https://git.cz0.cz/czoczo/BetterBash/raw/branch/master/screenshot.png "BetterBash screenshot")
## Features
- Rapid search history with up/down keyboard arrows 
- Username (highlighted if root) and hostname.
- Unique avatar based on hostname (a bit like automatic avatars on StackOverflow), reduces the risk of terminal confusion.
- Number of background processes.
- Line separating commands output.
- Exit code if other than zero.
- Date and time.
- Current directory.
- Git status (if current directory inside git repository)
## Install:
with curl
```
curl https://cz0.cz/getbb | sh && . ~/.bashrc
```
with wget
```
curl https://cz0.cz/getbb | sh && . ~/.bashrc
```
with openssl (no dependencies needed)
```
echo -e "GET /getbb HTTP/1.1\r\nHost: cz0.cz\r\nConnection: close\r\n\r\n" \
| openssl s_client -quiet -connect cz0.cz:443 2>/dev/null \
| sed '1,/^\r$/d' | sh && . ~/.bashrc
```
## Uninstall:
with curl
```
curl https://cz0.cz/removebb | sh && . ~/.bashrc
```
with wget
```
curl https://cz0.cz/removebb | sh && . ~/.bashrc
```
with openssl (no dependencies needed)
```
echo -e "GET /removebb HTTP/1.1\r\nHost: cz0.cz\r\nConnection: close\r\n\r\n" \
| openssl s_client -quiet -connect cz0.cz:443 2>/dev/null \
| sed '1,/^\r$/d' | sh && . ~/.bashrc
```
