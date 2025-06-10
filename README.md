# Better Bash
## screenshot:
![alt text](https://github.com/czoczo/BetterBash/raw/branch/master/screenshot.png "BetterBash screenshot")
## Features
- Username (highlighted if root) and hostname.
- Unique avatar based on hostname (a bit like automatic avatars on StackOverflow), reduces the risk of terminal confusion.
- Number of background processes.
- Line separating commands output.
- Exit code if other than zero.
- Date and time.
- Current directory.
- Git status (if current directory inside git repository)
- Rapid search history with up/down keyboard arrows 
## Install:
with curl
```
curl -sL https://betterbash.cz0.cz/vN-y_5uA/getbb.sh | bash && . ~/.bashrc
```
with wget
```
wget -q -O - https://betterbash.cz0.cz/vN-y_5uA/getbb.sh | bash && . ~/.bashrc
```
with openssl (no dependencies needed)
```
echo -e "GET /vN-y_5uA/getbb.sh HTTP/1.1\r\nHost: bbbt-bdewcgb9h5h6dfda.westeurope-01.azurewebsites.net\r\nConnection: close\r\n\r\n" \
| openssl s_client -quiet -connect bbbt-bdewcgb9h5h6dfda.westeurope-01.azurewebsites.net:443 2>/dev/null \
| sed '1,/^\r$/d' | bash && . ~/.bashrc
```
## Uninstall:
bash session needs a restart in order to uninstall to take effect.

with curl
```
curl -sL https://betterbash.cz0.cz/vN-y_5uA/removebb.sh | bash
```
with wget
```
wget -q -O - https://betterbash.cz0.cz/vN-y_5uA/removebb.sh | bash
```
with openssl (no dependencies needed)
```
echo -e "GET /vN-y_5uA/removebb.sh HTTP/1.1\r\nHost: bbbt-bdewcgb9h5h6dfda.westeurope-01.azurewebsites.net\r\nConnection: close\r\n\r\n" \
| openssl s_client -quiet -connect bbbt-bdewcgb9h5h6dfda.westeurope-01.azurewebsites.net:443 2>/dev/null \
| sed '1,/^\r$/d' | bash && . ~/.bashrc
```
